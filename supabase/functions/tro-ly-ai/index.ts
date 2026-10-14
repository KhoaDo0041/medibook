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

    // 4. Gọi Gemini, yêu cầu trả JSON đúng khuôn
    // Gemini đôi khi quá tải (503) → thử lại tối đa 3 lần, rồi chuyển model dự phòng nếu có
    const DU_PHONG = Deno.env.get('GEMINI_MODEL_DU_PHONG');
    const dsModel = DU_PHONG ? [MODEL, DU_PHONG] : [MODEL];
    const noiDung = JSON.stringify({
      systemInstruction: { parts: [{ text: loiNhacHeThong(khoa) }] },
      contents,
      generationConfig: {
        temperature: 0.4,
        responseMimeType: 'application/json',
        responseSchema: SCHEMA,
      },
    });
    let res!: Response;
    thu: for (const m of dsModel) {
      for (let lan = 0; lan < 3; lan++) {
        res = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'x-goog-api-key': GEMINI_KEY },
            body: noiDung,
          },
        );
        if (res.ok) break thu;
        if (![429, 500, 503].includes(res.status)) break thu;
        if (m === dsModel[dsModel.length - 1] && lan === 2) break thu; // hết lượt thử
        console.warn(`Gemini ${m} lỗi ${res.status}, thử lại lần ${lan + 2}`);
        await res.body?.cancel();
        await new Promise((r) => setTimeout(r, 1000 * (lan + 1)));
      }
    }
    if (!res.ok) {
      const chiTiet = await res.text();
      console.error('Gemini lỗi', res.status, chiTiet);
      const s = res.status;
      const loi = s === 429 ? 'Trợ lý AI đang quá tải hoặc hết lượt miễn phí, thử lại sau ít phút'
        : s === 400 && chiTiet.includes('API_KEY') ? 'Khoá Gemini không hợp lệ (kiểm tra secret GEMINI_API_KEY)'
        : s === 403 ? 'Khoá Gemini bị từ chối (403) – kiểm tra key hoặc bật Generative Language API'
        : s === 404 ? `Không tìm thấy model ${MODEL} – đặt secret GEMINI_MODEL`
        : 'Trợ lý AI đang bận, vui lòng thử lại sau ít phút';
      return json({ loi: `${loi} [mã ${s}]` }, 502);
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
