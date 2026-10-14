// Supabase Edge Function: Trợ lý sức khoẻ MediBook (gọi Google Gemini).
// API key Gemini chỉ nằm ở đây (biến bí mật GEMINI_API_KEY), KHÔNG nằm trong app.
//
// App gửi lên:
//   { "tin_nhan": [ { "vai_tro": "nguoi_dung" | "tro_ly", "noi_dung": "..." }, ... ],
//     "anh": { "mime": "image/jpeg", "base64": "..." }   // tuỳ chọn, gắn vào tin cuối
//   }
// Trả về:
//   { "tra_loi": "...", "muc_do": "thong_thuong" | "nen_kham_som" | "cap_cuu",
//     "can_hoi_them": true/false, "goi_y_khoa": [ { "id": 1, "ten": "Nhi", "ly_do": "..." } ] }

import { createClient } from 'npm:@supabase/supabase-js@2';

const GEMINI_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.8-flash';
const SO_TIN_TOI_DA = 12; // chỉ gửi 12 tin gần nhất cho đỡ tốn

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function loiNhacHeThong(dsKhoa: { id: number; ten_khoa: string }[]) {
  const danhSach = dsKhoa.map((k) => `- id ${k.id}: ${k.ten_khoa}`).join('\n');
  return `Bạn là "Trợ lý sức khoẻ MediBook", trợ lý tư vấn ban đầu trong ứng dụng đặt lịch khám bệnh tại TP.HCM.
Nhiệm vụ: lắng nghe triệu chứng, hỏi thêm cho rõ, rồi gợi ý NÊN KHÁM CHUYÊN KHOA NÀO để bệnh nhân đặt lịch.

QUY TẮC BẮT BUỘC
1. Bạn KHÔNG chẩn đoán bệnh và KHÔNG kê đơn, không nêu liều thuốc. Chỉ nói "có thể liên quan đến…", "nên được bác sĩ … kiểm tra".
2. Mỗi lượt chỉ hỏi tối đa 2 câu, ngắn gọn. Thông tin hay cần: tuổi (nhất là trẻ em, người già), triệu chứng bắt đầu từ khi nào, mức độ, có sốt không, bệnh nền.
3. Khi đã đủ thông tin (thường sau 1–3 lượt), đặt can_hoi_them = false và gợi ý 1–2 chuyên khoa CHỈ LẤY TỪ DANH SÁCH DƯỚI ĐÂY (dùng đúng id). Nếu không khoa nào phù hợp, để goi_y_khoa rỗng và khuyên đến khoa khám tổng quát/cơ sở y tế gần nhất.
4. DẤU HIỆU NGUY HIỂM → muc_do = "cap_cuu", bảo gọi 115 hoặc đến cấp cứu NGAY, không gợi ý đặt lịch: đau ngực dữ dội, khó thở nặng, yếu/liệt nửa người, méo miệng, nói khó, co giật, lơ mơ/ngất, chảy máu không cầm, sốt cao kèm cổ cứng, trẻ dưới 3 tháng sốt, nôn ra máu, đau bụng dữ dội, ý định tự hại.
5. muc_do = "nen_kham_som" khi triệu chứng kéo dài, tăng dần hoặc ảnh hưởng sinh hoạt; còn lại "thong_thuong".
6. Nếu có ẢNH: mô tả ngắn những gì quan sát được (màu, kích thước ước chừng, vị trí), nói rõ đây chỉ là nhận định sơ bộ qua ảnh. Ảnh không liên quan sức khoẻ thì nói lịch sự là không thể nhận định.
7. Câu hỏi ngoài lĩnh vực sức khoẻ: từ chối nhẹ nhàng, hướng về triệu chứng.
8. Trả lời tiếng Việt, thân thiện, xưng "mình" gọi "bạn", tối đa khoảng 120 chữ. Kết thúc phần tư vấn (khi đã gợi ý khoa) bằng câu: "Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ."

DANH SÁCH CHUYÊN KHOA CÓ TRONG HỆ THỐNG
${danhSach}`;
}

const SCHEMA = {
  type: 'OBJECT',
  properties: {
    tra_loi: { type: 'STRING' },
    muc_do: { type: 'STRING', enum: ['thong_thuong', 'nen_kham_som', 'cap_cuu'] },
    can_hoi_them: { type: 'BOOLEAN' },
    goi_y_khoa: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: { id: { type: 'INTEGER' }, ly_do: { type: 'STRING' } },
        required: ['id', 'ly_do'],
      },
    },
  },
  required: ['tra_loi', 'muc_do', 'can_hoi_them', 'goi_y_khoa'],
};

// ---------- Gọi Gemini có giới hạn thời gian ----------
async function goiGemini(model: string, noiDung: string): Promise<Response | null> {
  try {
    return await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': GEMINI_KEY },
        body: noiDung,
        signal: AbortSignal.timeout(12_000),
      },
    );
  } catch {
    return null; // hết 12 giây hoặc lỗi mạng
  }
}

// ---------- Danh sách model để thử lần lượt ----------
// Model chính (secret GEMINI_MODEL) trước, rồi model dự phòng (GEMINI_MODEL_DU_PHONG),
// rồi tự hỏi Google xem tài khoản đang dùng được những model "flash" nào.
let boNhoModel: string[] | null = null;
async function danhSachModel(): Promise<string[]> {
  const ds = [MODEL, Deno.env.get('GEMINI_MODEL_DU_PHONG') ?? ''].filter(Boolean);
  if (boNhoModel === null) {
    boNhoModel = [];
    try {
      const r = await fetch('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200', {
        headers: { 'x-goog-api-key': GEMINI_KEY },
        signal: AbortSignal.timeout(5_000),
      });
      if (r.ok) {
        const j = await r.json();
        boNhoModel = (j.models ?? [])
          .filter((m: { name: string; supportedGenerationMethods?: string[] }) =>
            m.supportedGenerationMethods?.includes('generateContent') &&
            /flash/.test(m.name) &&
            !/(image|tts|audio|live|embedding|preview|exp)/.test(m.name))
          .map((m: { name: string }) => m.name.replace('models/', ''))
          // ưu tiên bản "lite" (ít người dùng hơn, nhanh hơn), rồi bản mới hơn
          .sort((x: string, y: string) =>
            Number(y.includes('lite')) - Number(x.includes('lite')) || y.localeCompare(x));
      }
    } catch { /* không lấy được danh sách: chỉ dùng model đã cấu hình */ }
  }
  return [...new Set([...ds, ...boNhoModel])].slice(0, 4);
}

// ---------- Gợi ý dự phòng khi Gemini không phản hồi ----------
// Đọc từ khoá trong lời kể của bệnh nhân để gợi ý chuyên khoa có trong hệ thống.
function goiYDuPhong(
  tinNhan: { vai_tro: string; noi_dung: string }[],
  dsKhoa: { id: number; ten_khoa: string }[],
  coAnh: boolean,
) {
  const loi = tinNhan
    .filter((t) => t.vai_tro !== 'tro_ly')
    .map((t) => String(t.noi_dung ?? ''))
    .join(' ')
    .toLowerCase();
  // So khớp nguyên từ (để "ho" không khớp nhầm với "cho", "hoặc"…)
  const co = (...tu: string[]) =>
    tu.some((x) => new RegExp(`(^|[^\\p{L}])${x}([^\\p{L}]|$)`, 'u').test(loi));

  const ghiChu = '\n\n(Trợ lý AI đang quá tải nên đây là gợi ý nhanh theo từ khoá. '
    + 'Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ.)';

  if (co('đau ngực', 'khó thở', 'méo miệng', 'nói khó', 'liệt', 'co giật', 'ngất', 'bất tỉnh',
         'lơ mơ', 'nôn ra máu', 'chảy máu không cầm', 'cổ cứng', 'tự tử', 'tự hại')) {
    return {
      tra_loi: 'Các dấu hiệu bạn kể có thể nguy hiểm. Hãy gọi 115 hoặc đến cơ sở cấp cứu gần nhất NGAY, đừng chờ đặt lịch.',
      muc_do: 'cap_cuu', can_hoi_them: false, goi_y_khoa: [], du_phong: true,
    };
  }

  const quyTac: [string, string[], string][] = [
    ['Nhi', ['con mình', 'con tôi', 'con em', 'bé', 'bé nhà', 'trẻ', 'cháu', 'tháng tuổi', 'em bé'],
      'Người bệnh là trẻ nhỏ nên khám chuyên khoa Nhi.'],
    ['Mắt', ['mắt', 'nhìn mờ', 'cộm', 'chảy nước mắt', 'ghèn'],
      'Triệu chứng liên quan đến mắt.'],
    ['Răng Hàm Mặt', ['răng', 'nướu', 'lợi', 'hàm', 'nhổ', 'sâu răng', 'hôi miệng'],
      'Triệu chứng ở răng, nướu hoặc hàm.'],
    ['Tai Mũi Họng', ['họng', 'ho', 'mũi', 'tai', 'khàn tiếng', 'nghẹt', 'sổ mũi', 'amidan', 'ù tai'],
      'Triệu chứng ở tai, mũi hoặc họng.'],
    ['Da liễu', ['da', 'mẩn', 'ngứa', 'mụn', 'phát ban', 'dị ứng', 'cháy nắng', 'bỏng nắng', 'nấm', 'lở', 'vết'],
      'Triệu chứng biểu hiện trên da.'],
  ];
  const tim = (ten: string) => dsKhoa.find((k) => k.ten_khoa.toLowerCase() === ten.toLowerCase());
  const goiY: { id: number; ten: string; ly_do: string }[] = [];
  for (const [ten, tu, lyDo] of quyTac) {
    const k = tim(ten);
    if (k && co(...tu) && goiY.length < 2) goiY.push({ id: k.id, ten: k.ten_khoa, ly_do: lyDo });
    if (goiY[0]?.ten === 'Nhi') break; // trẻ em: chỉ gợi ý khoa Nhi
  }
  if (goiY.length === 0 && coAnh) {
    const k = tim('Da liễu');
    if (k) goiY.push({ id: k.id, ten: k.ten_khoa, ly_do: 'Ảnh bạn gửi có thể là tổn thương trên da.' });
  }
  if (goiY.length === 0) {
    const k = tim('Nội tổng quát');
    if (k) goiY.push({ id: k.id, ten: k.ten_khoa, ly_do: 'Bác sĩ Nội tổng quát sẽ khám ban đầu và hướng dẫn tiếp.' });
  }

  const kamSom = co('sốt cao', 'kéo dài', 'nhiều ngày', 'tuần', 'ngày càng', 'nặng hơn', 'không đỡ');
  return {
    tra_loi: `Dựa trên những gì bạn kể, bạn nên đến khám ${goiY.map((g) => 'khoa ' + g.ten).join(' hoặc ')}.`
      + (kamSom ? ' Triệu chứng đã kéo dài hoặc nặng dần, bạn nên đi khám sớm.' : '') + ghiChu,
    muc_do: kamSom ? 'nen_kham_som' : 'thong_thuong',
    can_hoi_them: false,
    goi_y_khoa: goiY,
    du_phong: true,
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    if (!GEMINI_KEY) return json({ loi: 'Máy chủ chưa cấu hình GEMINI_API_KEY' }, 500);

    // 1. Chỉ người đã đăng nhập mới được dùng
    const auth = req.headers.get('Authorization');
    if (!auth) return json({ loi: 'Bạn cần đăng nhập' }, 401);
    // Dự án Supabase mới có thể dùng tên biến khác cho khoá công khai
    const khoaCongKhai = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
    if (!khoaCongKhai) return json({ loi: 'Máy chủ thiếu SUPABASE_ANON_KEY' }, 500);
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, khoaCongKhai, {
      global: { headers: { Authorization: auth } },
    });
    const { data: { user } } = await sb.auth.getUser();
    if (!user) return json({ loi: 'Phiên đăng nhập đã hết hạn' }, 401);

    // 2. Danh sách chuyên khoa thật trong database
    const { data: dsKhoa } = await sb.from('chuyen_khoa').select('id, ten_khoa').order('id');
    const khoa = dsKhoa ?? [];

    // 3. Ghép lịch sử hội thoại theo định dạng Gemini
    const body = await req.json();
    const tinNhan: { vai_tro: string; noi_dung: string }[] = (body.tin_nhan ?? []).slice(-SO_TIN_TOI_DA);
    if (tinNhan.length === 0) return json({ loi: 'Chưa có nội dung' }, 400);

    const contents = tinNhan.map((t) => ({
      role: t.vai_tro === 'tro_ly' ? 'model' : 'user',
      parts: [{ text: String(t.noi_dung ?? '').slice(0, 2000) }] as Record<string, unknown>[],
    }));
    const anh = body.anh;
    if (anh?.base64 && anh?.mime) {
      if (anh.base64.length > 6_000_000) return json({ loi: 'Ảnh quá lớn, vui lòng chụp lại' }, 400);
      contents[contents.length - 1].parts.push({ inline_data: { mime_type: anh.mime, data: anh.base64 } });
    }

    // 4. Gọi Gemini, yêu cầu trả JSON đúng khuôn.
    //    Gemini miễn phí hay quá tải (503) → thử lần lượt nhiều model, mỗi lần tối đa 12 giây.
    //    Nếu tất cả đều lỗi → dùng bộ gợi ý dự phòng theo từ khoá, app KHÔNG bao giờ báo lỗi.
    const noiDung = JSON.stringify({
      systemInstruction: { parts: [{ text: loiNhacHeThong(khoa) }] },
      contents,
      generationConfig: {
        temperature: 0.4,
        responseMimeType: 'application/json',
        responseSchema: SCHEMA,
      },
    });
    const batDau = Date.now();
    let res: Response | null = null;
    const dsModel = await danhSachModel();
    for (let i = 0; i < dsModel.length && Date.now() - batDau < 25_000; i++) {
      const m = dsModel[i];
      const r = await goiGemini(m, noiDung);
      if (r?.ok) {
        res = r;
        if (i > 0) console.warn(`Đã chuyển sang model dự phòng ${m}`);
        break;
      }
      console.warn(`Gemini ${m} lỗi ${r ? r.status : 'quá thời gian'}`, r ? (await r.text()).slice(0, 300) : '');
      // Model chính: chờ chút rồi thử lại 1 lần trước khi đổi model
      if (i === 0 && r && [429, 500, 503].includes(r.status)) {
        await new Promise((x) => setTimeout(x, 700));
        const r2 = await goiGemini(m, noiDung);
        if (r2?.ok) { res = r2; break; }
        if (r2) await r2.body?.cancel();
      }
    }
    if (!res) {
      console.error('Tất cả model Gemini đều lỗi → dùng gợi ý dự phòng');
      return json(goiYDuPhong(tinNhan, khoa, Boolean(anh?.base64)));
    }
    const g = await res.json();
    const text: string = (g.candidates?.[0]?.content?.parts ?? []).map((p: { text?: string }) => p.text ?? '').join('');
    if (!text) {
      return json({
        tra_loi: 'Mình chưa thể trả lời nội dung này. Bạn hãy mô tả triệu chứng của mình nhé.',
        muc_do: 'thong_thuong', can_hoi_them: true, goi_y_khoa: [],
      });
    }

    let kq;
    try {
      kq = JSON.parse(text);
    } catch {
      kq = { tra_loi: text, muc_do: 'thong_thuong', can_hoi_them: true, goi_y_khoa: [] };
    }

    // 5. Chỉ giữ chuyên khoa có thật, gắn tên khoa từ database
    const tenTheoId = new Map(khoa.map((k) => [k.id, k.ten_khoa]));
    kq.goi_y_khoa = (kq.goi_y_khoa ?? [])
      .filter((x: { id: number }) => tenTheoId.has(x.id))
      .slice(0, 2)
      .map((x: { id: number; ly_do: string }) => ({ id: x.id, ten: tenTheoId.get(x.id), ly_do: x.ly_do }));
    if (kq.muc_do === 'cap_cuu') kq.goi_y_khoa = [];

    return json(kq);
  } catch (e) {
    console.error(e);
    return json({ loi: 'Có lỗi xảy ra, vui lòng thử lại' }, 500);
  }
});
