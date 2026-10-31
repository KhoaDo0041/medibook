import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cau_hinh_ai.dart';
import '../../core/api_client.dart';

enum MucDo { thongThuong, nenKhamSom, capCuu }

class GoiYKhoa {
  final int id;
  final String ten;
  final String lyDo;

  const GoiYKhoa({required this.id, required this.ten, required this.lyDo});

  Map<String, dynamic> toJson() => {'id': id, 'ten': ten, 'ly_do': lyDo};

  factory GoiYKhoa.tuJson(Map<String, dynamic> j) => GoiYKhoa(
    id: (j['id'] as num).toInt(),
    ten: j['ten'] as String? ?? '',
    lyDo: j['ly_do'] as String? ?? '',
  );
}

/// Câu trả lời có cấu trúc của Trợ lý AI.
class KetQuaAi {
  final String traLoi;
  final MucDo mucDo;
  final bool canHoiThem;
  final List<GoiYKhoa> goiYKhoa;

  /// true = máy chủ AI không phản hồi, đây là gợi ý nhanh theo từ khoá.
  final bool duPhong;

  /// Thông tin AI đã thu thập được qua cuộc trò chuyện (dùng làm phiếu tiền khám).
  final PhieuTienKham phieu;

  const KetQuaAi({
    required this.traLoi,
    required this.mucDo,
    required this.canHoiThem,
    required this.goiYKhoa,
    this.duPhong = false,
    this.phieu = const PhieuTienKham(),
  });

  // Lưu / đọc lại khi mở lịch sử trò chuyện
  Map<String, dynamic> toJson() => {
    'tra_loi': traLoi,
    'muc_do': mucDo.name,
    'can_hoi_them': canHoiThem,
    'goi_y_khoa': [for (final g in goiYKhoa) g.toJson()],
    'du_phong': duPhong,
    'phieu': phieu.toJson(),
  };

  factory KetQuaAi.tuJson(Map<String, dynamic> j) => KetQuaAi(
    traLoi: j['tra_loi'] as String? ?? '',
    mucDo: MucDo.values.firstWhere(
      (m) => m.name == j['muc_do'],
      orElse: () => MucDo.thongThuong,
    ),
    canHoiThem: j['can_hoi_them'] == true,
    goiYKhoa: [
      for (final g in (j['goi_y_khoa'] as List? ?? []))
        GoiYKhoa.tuJson(Map<String, dynamic>.from(g as Map)),
    ],
    duPhong: j['du_phong'] == true,
    phieu: PhieuTienKham.tuJson(
      j['phieu'] is Map ? Map<String, dynamic>.from(j['phieu'] as Map) : null,
    ),
  );
}

/// Phiếu tiền khám: AI điền dần qua từng lượt hỏi đáp, bác sĩ xem trước khi khám.
class PhieuTienKham {
  final String nguoiBenh; // VD "Trẻ 3 tuổi", "Nữ 45 tuổi"
  final String trieuChungChinh;
  final String batDauTu; // VD "2 ngày trước"
  final String mucDo; // VD "sốt 38.5°C, ho nhiều về đêm"
  final String trieuChungKem;
  final String tienSu; // bệnh nền, dị ứng, thuốc đang dùng
  final String moTaAnh; // nếu bệnh nhân gửi ảnh

  const PhieuTienKham({
    this.nguoiBenh = '',
    this.trieuChungChinh = '',
    this.batDauTu = '',
    this.mucDo = '',
    this.trieuChungKem = '',
    this.tienSu = '',
    this.moTaAnh = '',
  });

  static String _s(dynamic v) {
    final t = (v as String?)?.trim() ?? '';
    final thuong = t.toLowerCase();
    // AI hay điền "không rõ", "chưa có" → coi như trống
    return thuong.isEmpty || thuong.startsWith('không rõ') ||
            thuong.startsWith('chưa') || thuong == 'n/a' ||
            const ['thong_thuong', 'nen_kham_som', 'cap_cuu'].contains(thuong)
        ? ''
        : t;
  }

  factory PhieuTienKham.tuJson(Map<String, dynamic>? j) => j == null
      ? const PhieuTienKham()
      : PhieuTienKham(
          nguoiBenh: _s(j['nguoi_benh']),
          trieuChungChinh: _s(j['trieu_chung_chinh']),
          batDauTu: _s(j['bat_dau_tu']),
          mucDo: _s(j['dien_bien']),
          trieuChungKem: _s(j['trieu_chung_kem']),
          tienSu: _s(j['tien_su']),
          moTaAnh: _s(j['mo_ta_anh']),
        );

  Map<String, String> toJson() => {
    'nguoi_benh': nguoiBenh,
    'trieu_chung_chinh': trieuChungChinh,
    'bat_dau_tu': batDauTu,
    'dien_bien': mucDo,
    'trieu_chung_kem': trieuChungKem,
    'tien_su': tienSu,
    'mo_ta_anh': moTaAnh,
  };

  /// Giữ thông tin cũ nếu lượt mới AI để trống.
  PhieuTienKham gopVoi(PhieuTienKham moi) => PhieuTienKham(
    nguoiBenh: moi.nguoiBenh.isNotEmpty ? moi.nguoiBenh : nguoiBenh,
    trieuChungChinh: moi.trieuChungChinh.isNotEmpty ? moi.trieuChungChinh : trieuChungChinh,
    batDauTu: moi.batDauTu.isNotEmpty ? moi.batDauTu : batDauTu,
    mucDo: moi.mucDo.isNotEmpty ? moi.mucDo : mucDo,
    trieuChungKem: moi.trieuChungKem.isNotEmpty ? moi.trieuChungKem : trieuChungKem,
    tienSu: moi.tienSu.isNotEmpty ? moi.tienSu : tienSu,
    moTaAnh: moi.moTaAnh.isNotEmpty ? moi.moTaAnh : moTaAnh,
  );

  /// Các dòng của phiếu (chỉ mục đã có thông tin), dùng để hiển thị và gửi bác sĩ.
  List<(String, String)> get cacDong => [
    if (nguoiBenh.isNotEmpty) ('Người bệnh', nguoiBenh),
    if (trieuChungChinh.isNotEmpty) ('Triệu chứng chính', trieuChungChinh),
    if (batDauTu.isNotEmpty) ('Bắt đầu', batDauTu),
    if (mucDo.isNotEmpty) ('Diễn biến', mucDo),
    if (trieuChungKem.isNotEmpty) ('Kèm theo', trieuChungKem),
    if (tienSu.isNotEmpty) ('Tiền sử', tienSu),
    if (moTaAnh.isNotEmpty) ('Ảnh gửi kèm', moTaAnh),
  ];

  bool get coNoiDung => cacDong.isNotEmpty;

  /// Dạng chữ để lưu vào phần triệu chứng của lượt khám (bác sĩ xem trên web).
  String get vanBan => [
    'Phiếu tiền khám (AI tổng hợp, bệnh nhân đã xem lại):',
    for (final (nhan, giaTri) in cacDong) '• $nhan: $giaTri',
  ].join('\n');

  /// Các câu cần hỏi thêm cho những mục bắt buộc còn trống (tối đa 2).
  /// Vấn đề ngoài da: người lớn hay trẻ em đều khám Da liễu nên không bắt hỏi tuổi.
  List<String> cauHoiConThieu({bool veDa = false}) => [
    if (nguoiBenh.isEmpty && !veDa) 'Người bệnh bao nhiêu tuổi?',
    if (batDauTu.isEmpty)
      veDa ? 'Bạn bị như vậy từ khi nào?' : 'Triệu chứng bắt đầu từ khi nào?',
    if (mucDo.isEmpty)
      veDa
          ? 'Vùng da có ngứa hay đau không, có lan rộng ra không?'
          : 'Mức độ thế nào (ví dụ sốt bao nhiêu độ, đau nhiều hay ít)?',
  ].take(2).toList();
}

/// Một tin nhắn trong cuộc trò chuyện.
class TinNhan {
  final bool laNguoiDung;
  final String noiDung;
  final Uint8List? anh;
  final KetQuaAi? ketQua; // chỉ có ở tin của trợ lý

  const TinNhan({
    required this.laNguoiDung,
    required this.noiDung,
    this.anh,
    this.ketQua,
  });

  Map<String, dynamic> toJson() => {
    'nguoi_dung': laNguoiDung,
    'noi_dung': noiDung,
    if (anh != null) 'anh': base64Encode(anh!),
    if (ketQua != null) 'ket_qua': ketQua!.toJson(),
  };

  factory TinNhan.tuJson(Map<String, dynamic> j) => TinNhan(
    laNguoiDung: j['nguoi_dung'] == true,
    noiDung: j['noi_dung'] as String? ?? '',
    anh: j['anh'] is String ? base64Decode(j['anh'] as String) : null,
    ketQua: j['ket_qua'] is Map
        ? KetQuaAi.tuJson(Map<String, dynamic>.from(j['ket_qua'] as Map))
        : null,
  );
}

class LoiAi implements Exception {
  final String thongBao;
  const LoiAi(this.thongBao);
  @override
  String toString() => thongBao;
}

typedef _Khoa = ({int id, String ten});

/// Trợ lý AI chạy CỤC BỘ: gọi Ollama (model Qwen3-VL) trên laptop cùng mạng wifi.
/// Không gọi dịch vụ AI nào trên Internet.
///
/// Các lớp an toàn (đều nằm trong code, không phụ thuộc AI):
/// 1. Chỉ gợi ý chuyên khoa có trong database (lọc lại theo id).
/// 2. Luật từ khoá cấp cứu luôn được kiểm tra, AI bỏ sót thì vẫn báo gọi 115.
/// 3. Máy chủ AI tắt / quá thời gian → gợi ý dự phòng theo từ khoá, app không báo lỗi.
class DichVuAi {
  static const _soTinToiDa = 12;
  static List<_Khoa>? _boNhoKhoa;
  static DateTime? _lanKhoiDong;

  /// Nạp sẵn model vào GPU (gọi khi mở tab Trợ lý AI) để câu hỏi đầu tiên không phải chờ lâu.
  /// Ollama: gửi /api/generate không có prompt thì chỉ nạp model. Lỗi thì bỏ qua.
  static Future<void> khoiDong() async {
    final truoc = _lanKhoiDong;
    if (truoc != null && DateTime.now().difference(truoc).inMinutes < 10) return;
    _lanKhoiDong = DateTime.now();
    try {
      await http
          .post(
            Uri.parse('${CauHinhAi.mayChu}/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'model': CauHinhAi.model, 'keep_alive': '30m'}),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      _lanKhoiDong = null; // máy chủ chưa bật: lần sau thử lại
    }
  }

  Future<KetQuaAi> hoi(List<TinNhan> hoiThoai, {Uint8List? anh}) async {
    final khoa = await _layKhoa();
    final tin = hoiThoai.length > _soTinToiDa
        ? hoiThoai.sublist(hoiThoai.length - _soTinToiDa)
        : hoiThoai;

    // Lớp 2: dấu hiệu nguy hiểm → trả lời cấp cứu ngay, không chờ AI
    final capCuu = _kiemTraCapCuu(tin);
    if (capCuu != null) return capCuu;

    // Phiếu tiền khám đã thu thập ở lượt trước (AI cập nhật tiếp)
    var phieuCu = const PhieuTienKham();
    for (final t in hoiThoai.reversed) {
      final p = t.ketQua?.phieu;
      if (p != null) {
        phieuCu = p;
        break;
      }
    }

    try {
      return await _hoiOllama(tin, khoa, anh, phieuCu);
    } catch (e) {
      debugPrint('[MediBook][AI] Ollama lỗi: $e → dùng gợi ý dự phòng');
      return _goiYDuPhong(tin, khoa, coAnh: anh != null);
    }
  }

  // ---------------- danh sách chuyên khoa thật ----------------

  Future<List<_Khoa>> _layKhoa() async {
    final daCo = _boNhoKhoa;
    if (daCo != null) return daCo;
    try {
      final rows = await Api.get('/api/chuyen-khoa') as List;
      return _boNhoKhoa = [
        for (final r in rows)
          (id: r['id'] as int, ten: r['ten_khoa'] as String),
      ];
    } catch (_) {
      throw const LoiAi('Không tải được danh sách chuyên khoa. Kiểm tra mạng.');
    }
  }

  // ---------------- gọi Ollama ----------------

  static const _chuoi = {'type': 'string'};
  static const _schema = {
    'type': 'object',
    'properties': {
      'tra_loi': _chuoi,
      'muc_do': {
        'type': 'string',
        'enum': ['thong_thuong', 'nen_kham_som', 'cap_cuu'],
      },
      'can_hoi_them': {'type': 'boolean'},
      'thong_tin': {
        'type': 'object',
        'properties': {
          'nguoi_benh': _chuoi,
          'trieu_chung_chinh': _chuoi,
          'bat_dau_tu': _chuoi,
          'dien_bien': _chuoi,
          'trieu_chung_kem': _chuoi,
          'tien_su': _chuoi,
          'mo_ta_anh': _chuoi,
        },
        'required': [
          'nguoi_benh', 'trieu_chung_chinh', 'bat_dau_tu', 'dien_bien',
          'trieu_chung_kem', 'tien_su', 'mo_ta_anh',
        ],
      },
      'goi_y_khoa': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer'},
            'ly_do': {'type': 'string'},
          },
          'required': ['id', 'ly_do'],
        },
      },
    },
    'required': ['tra_loi', 'muc_do', 'can_hoi_them', 'thong_tin', 'goi_y_khoa'],
  };

  Future<KetQuaAi> _hoiOllama(
    List<TinNhan> tin,
    List<_Khoa> khoa,
    Uint8List? anh,
    PhieuTienKham phieuCu,
  ) async {
    final veDaTruoc = anh != null || tin.any((t) => t.anh != null) ||
        _co('${_loiBenhNhan(tin)} ${phieuCu.trieuChungChinh}'.toLowerCase(), _tuVeDa);
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _loiNhacHeThong(khoa, phieuCu, veDa: veDaTruoc)},
      for (var i = 0; i < tin.length; i++)
        {
          'role': tin[i].laNguoiDung ? 'user' : 'assistant',
          'content': tin[i].noiDung.isEmpty && tin[i].anh != null
              ? 'Mình gửi một ảnh, bạn xem giúp.'
              : tin[i].noiDung,
          // Ảnh chỉ gắn vào tin cuối (tin vừa gửi)
          if (i == tin.length - 1 && anh != null) 'images': [base64Encode(anh)],
        },
    ];

    final res = await http
        .post(
          Uri.parse('${CauHinhAi.mayChu}/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': CauHinhAi.model,
            'messages': messages,
            'stream': false,
            'format': _schema,
            'keep_alive': '30m', // giữ model trong GPU để lần sau trả lời nhanh
            'options': {'temperature': 0.3, 'num_ctx': 6144},
          }),
        )
        // Lần đầu phải nạp model vào GPU nên cho chờ lâu hơn
        .timeout(Duration(seconds: anh == null ? 90 : 150));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final noiDung =
        (jsonDecode(utf8.decode(res.bodyBytes))['message']?['content']
            as String?) ??
        '';
    final Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(noiDung) as Map);
    } catch (_) {
      throw Exception('AI không trả JSON đúng khuôn: $noiDung');
    }

    final phieu = phieuCu.gopVoi(
      PhieuTienKham.tuJson(
        j['thong_tin'] is Map ? Map<String, dynamic>.from(j['thong_tin'] as Map) : null,
      ),
    );
    var mucDo = switch (j['muc_do']) {
      'cap_cuu' => MucDo.capCuu,
      'nen_kham_som' => MucDo.nenKhamSom,
      _ => MucDo.thongThuong,
    };
    var traLoi = (j['tra_loi'] as String?)?.trim() ?? '';
    if (traLoi.isEmpty) throw Exception('AI trả lời rỗng');
    if (mucDo == MucDo.capCuu) {
      return KetQuaAi(
        traLoi: traLoi,
        mucDo: mucDo,
        canHoiThem: false,
        goiYKhoa: const [],
        phieu: phieu,
      );
    }

    // Luật trong code: lượt đầu còn thiếu tuổi / thời gian / mức độ thì PHẢI hỏi thêm,
    // để phiếu tiền khám gửi bác sĩ đủ thông tin. Sau 3 lượt thì không ép nữa.
    final soLuotHoi = tin.where((t) => t.laNguoiDung).length;
    final veDa = tin.any((t) => t.anh != null) ||
        _co('${_loiBenhNhan(tin)} ${phieu.trieuChungChinh}'.toLowerCase(), _tuVeDa);
    final cauHoi = phieu.cauHoiConThieu(veDa: veDa);
    // Đang hỏi thêm thì chưa nhắc tới chuyên khoa; ca về da thì bỏ câu hỏi tuổi của AI
    var cauHoiAi = _boCauNhacKhoa(traLoi);
    if (veDa) cauHoiAi = _boCauChua(cauHoiAi, const ['tuổi']);
    // AI muốn hỏi thêm nhưng chỉ còn câu hỏi tuổi (đã bỏ) → không cần hỏi nữa
    final aiMuonHoi = j['can_hoi_them'] == true && (!veDa || cauHoiAi.contains('?'));
    if ((cauHoi.isNotEmpty || aiMuonHoi) && soLuotHoi < 3) {
      final hoiThem = cauHoi.isEmpty
          ? 'Bạn kể thêm giúp mình triệu chứng đi kèm hoặc bệnh nền (nếu có) nhé?'
          : 'Để gợi ý chính xác hơn, cho mình hỏi thêm: ${cauHoi.join(' ')}';
      return KetQuaAi(
        traLoi: cauHoiAi.contains('?')
            ? cauHoiAi
            : [cauHoiAi, hoiThem].where((x) => x.isNotEmpty).join('\n\n'),
        mucDo: mucDo,
        canHoiThem: true,
        goiYKhoa: const [],
        phieu: phieu,
      );
    }

    // Lớp 1: chỉ giữ khoa có thật trong database, tối đa 2
    final tenTheoId = {for (final k in khoa) k.id: k.ten};
    var goiY = [
      for (final g in (j['goi_y_khoa'] as List? ?? []))
        if (g is Map && tenTheoId.containsKey((g['id'] as num?)?.toInt()))
          GoiYKhoa(
            id: (g['id'] as num).toInt(),
            ten: tenTheoId[(g['id'] as num).toInt()]!,
            lyDo: (g['ly_do'] as String?)?.trim() ?? '',
          ),
    ].take(2).toList();

    // AI đã chốt (không hỏi thêm) nhưng quên gợi ý khoa / ghi sai id → bổ sung bằng luật từ khoá
    final coAnh = tin.any((t) => t.anh != null);
    if (goiY.isEmpty) {
      goiY = _goiYTheoTuKhoa(
        '${_loiBenhNhan(tin)} ${phieu.trieuChungChinh} ${phieu.moTaAnh}'.toLowerCase(),
        khoa,
        coAnh: coAnh,
      );
    }
    // Có ảnh tổn thương da mà chưa có khoa Da liễu → thêm vào (VD trẻ em: Nhi + Da liễu)
    if (coAnh && goiY.length < 2 && !goiY.any((g) => g.ten == 'Da liễu')) {
      for (final k in khoa) {
        if (k.ten == 'Da liễu') {
          goiY.add(GoiYKhoa(id: k.id, ten: k.ten, lyDo: 'Ảnh gửi kèm cho thấy tổn thương trên da.'));
        }
      }
    }

    // Câu nhắc khoa do CODE viết từ danh sách đã lọc → luôn khớp với thẻ gợi ý bên dưới
    final tomTat = _boCauNhacKhoa(traLoi);
    final tenKhoa = goiY.map((g) => 'khoa ${g.ten}').join(' hoặc ');
    traLoi = [
      tomTat,
      if (goiY.isNotEmpty) 'Bạn nên đến khám $tenKhoa.',
      'Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ.',
    ].where((x) => x.isNotEmpty).join(' ');
    if (goiY.isNotEmpty && mucDo == MucDo.thongThuong &&
        _co(_loiBenhNhan(tin), _tuKhamSom)) {
      mucDo = MucDo.nenKhamSom;
    }

    return KetQuaAi(
      traLoi: traLoi,
      mucDo: mucDo,
      canHoiThem: false,
      goiYKhoa: goiY,
      phieu: phieu,
    );
  }

  static String _loiNhacHeThong(
    List<_Khoa> khoa,
    PhieuTienKham phieuCu, {
    bool veDa = false,
  }) {
    final danhSach = khoa.map((k) => '- id ${k.id}: ${k.ten}').join('\n');
    final daBiet = jsonEncode(phieuCu.toJson());
    return '''Bạn là "Trợ lý sức khoẻ MediBook", trợ lý tiếp đón ban đầu trong ứng dụng đặt lịch khám bệnh tại TP.HCM.
Nhiệm vụ: hỏi chuyện như điều dưỡng tiếp đón để thu thập thông tin cho PHIẾU TIỀN KHÁM gửi bác sĩ, rồi gợi ý NÊN KHÁM CHUYÊN KHOA NÀO.

QUY TẮC BẮT BUỘC
1. LUÔN trả lời bằng tiếng Việt, thân thiện, xưng "mình" gọi "bạn", khoảng 50–120 chữ. KHÔNG bao giờ ghi mã id trong tra_loi.
2. KHÔNG chẩn đoán bệnh, KHÔNG kê thuốc, KHÔNG nêu liều thuốc. Chỉ nói "có thể liên quan đến…", "nên được bác sĩ … kiểm tra".
3. Phiếu tiền khám (thong_tin) cần: nguoi_benh (tuổi, giới nếu biết), trieu_chung_chinh, bat_dau_tu (từ khi nào), dien_bien (mức độ cụ thể theo lời bệnh nhân: sốt bao nhiêu độ, đau nhiều hay ít, ho có đờm không…), trieu_chung_kem, tien_su (bệnh nền, dị ứng, thuốc đang dùng). KHÔNG ghi các giá trị thong_thuong/nen_kham_som/cap_cuu vào thong_tin.
4. Lượt đầu tiên LUÔN hỏi thêm. Còn thiếu tuổi (vấn đề ngoài da thì không cần hỏi tuổi), thời gian bắt đầu hoặc diễn biến cụ thể (với da: ngứa hay đau, có lan rộng không): can_hoi_them = true, goi_y_khoa rỗng, tra_loi chỉ hỏi tối đa 2 câu ngắn, CHƯA nhắc tới chuyên khoa.
5. Khi đã đủ thông tin: can_hoi_them = false, tra_loi tóm tắt ngắn tình trạng + gợi ý 1–2 chuyên khoa CHỈ LẤY TỪ DANH SÁCH DƯỚI ĐÂY, dùng đúng id. Trẻ em → khoa Nhi. Ảnh vùng da (mẩn, đỏ, ngứa, phát ban, vết thương ngoài da) → khoa Da liễu. Kết thúc bằng câu: "Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ."
6. Dấu hiệu nguy hiểm (đau ngực dữ dội, khó thở nặng, yếu liệt, méo miệng, co giật, ngất, chảy máu không cầm, nôn ra máu, ý định tự hại) → muc_do = "cap_cuu", khuyên gọi 115 ngay, goi_y_khoa rỗng.
7. muc_do = "nen_kham_som" khi triệu chứng kéo dài, tăng dần hoặc ảnh hưởng sinh hoạt; còn lại "thong_thuong".
8. Nếu có ẢNH: mô tả điều quan sát được (màu, vị trí, kích thước ước chừng) vào thong_tin.mo_ta_anh, và nói rõ đây chỉ là nhận định sơ bộ qua ảnh.
9. thong_tin: luôn trả về ĐẦY ĐỦ các mục, giữ nguyên thông tin đã biết dưới đây và bổ sung thông tin mới từ lời bệnh nhân. Mục chưa biết để chuỗi rỗng "". Ghi ngắn gọn, đúng lời bệnh nhân kể, không tự suy diễn.
10. Câu hỏi ngoài sức khoẻ: từ chối nhẹ nhàng, hướng về triệu chứng.

${veDa ? 'LƯU Ý: đây là vấn đề ngoài da. KHÔNG hỏi tuổi. Chỉ hỏi: bị từ khi nào, có ngứa/đau không, có lan rộng không, có tiếp xúc gì lạ không.\n\n' : ''}THÔNG TIN ĐÃ BIẾT (từ các lượt trước)
$daBiet

DANH SÁCH CHUYÊN KHOA CÓ TRONG HỆ THỐNG
$danhSach''';
  }

  /// Bỏ các câu có chứa một trong các từ cho trước.
  static String _boCauChua(String van, List<String> tu) => van
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((c) => !_co(c.toLowerCase(), tu))
      .join(' ')
      .trim();

  /// Bỏ các câu AI tự nhắc tới chuyên khoa / mã id và câu "tham khảo"
  /// (code tự viết lại cho khớp với danh sách khoa đã lọc).
  static String _boCauNhacKhoa(String van) {
    final boId = van.replaceAll(RegExp(r'\s*\(?\bid\s*\d+\)?', caseSensitive: false), '');
    final cau = boId.split(RegExp(r'(?<=[.!?])\s+'));
    return cau
        .where((c) =>
            !_co(c.toLowerCase(), const ['khoa', 'chuyên khoa']) &&
            !c.toLowerCase().contains('tham khảo'))
        .join(' ')
        .trim();
  }

  // ---------------- luật từ khoá (không cần AI) ----------------

  static String _loiBenhNhan(List<TinNhan> tin) => tin
      .where((t) => t.laNguoiDung)
      .map((t) => t.noiDung)
      .join(' ')
      .toLowerCase();

  /// So khớp nguyên từ ("ho" không khớp nhầm "cho", "hoặc").
  static bool _co(String loi, List<String> tu) => tu.any(
    (x) => RegExp('(^|[^\\p{L}])$x([^\\p{L}]|\$)', unicode: true).hasMatch(loi),
  );

  static const _tuCapCuu = [
    'đau ngực', 'khó thở', 'méo miệng', 'nói khó', 'liệt', 'co giật', 'ngất',
    'bất tỉnh', 'lơ mơ', 'nôn ra máu', 'chảy máu không cầm', 'cổ cứng',
    'tự tử', 'tự hại',
  ];

  KetQuaAi? _kiemTraCapCuu(List<TinNhan> tin) {
    // Chỉ xét tin mới nhất để không lặp lại cảnh báo ở các lượt sau
    final cuoi = tin.lastWhere((t) => t.laNguoiDung, orElse: () => tin.last);
    if (!_co(cuoi.noiDung.toLowerCase(), _tuCapCuu)) return null;
    return const KetQuaAi(
      traLoi:
          'Các dấu hiệu bạn kể có thể nguy hiểm. Hãy gọi 115 hoặc đến cơ sở cấp cứu gần nhất NGAY, đừng chờ đặt lịch.',
      mucDo: MucDo.capCuu,
      canHoiThem: false,
      goiYKhoa: [],
    );
  }

  static const _quyTac = <(String, List<String>, String)>[
    ('Nhi', ['con mình', 'con tôi', 'con em', 'bé', 'bé nhà', 'trẻ', 'cháu', 'tháng tuổi', 'em bé'],
        'Người bệnh là trẻ nhỏ nên khám chuyên khoa Nhi.'),
    ('Mắt', ['mắt', 'nhìn mờ', 'cộm', 'chảy nước mắt', 'ghèn'],
        'Triệu chứng liên quan đến mắt.'),
    ('Răng Hàm Mặt', ['răng', 'nướu', 'lợi', 'hàm', 'nhổ', 'sâu răng', 'hôi miệng'],
        'Triệu chứng ở răng, nướu hoặc hàm.'),
    ('Tai Mũi Họng', ['họng', 'ho', 'mũi', 'tai', 'khàn tiếng', 'nghẹt', 'sổ mũi', 'amidan', 'ù tai'],
        'Triệu chứng ở tai, mũi hoặc họng.'),
    ('Da liễu', ['da', 'mẩn', 'ngứa', 'mụn', 'phát ban', 'dị ứng', 'cháy nắng', 'bỏng nắng', 'nấm', 'lở', 'vết'],
        'Triệu chứng biểu hiện trên da.'),
  ];

  /// Từ khoá nhận ra ca ngoài da (chỉ những ca này mới không hỏi tuổi).
  static const _tuVeDa = [
    'da', 'mẩn', 'mẩn ngứa', 'mụn', 'phát ban', 'nổi đỏ', 'mề đay', 'nổi mề đay',
    'cháy nắng', 'bỏng nắng', 'nấm da', 'hắc lào', 'lang ben', 'chàm', 'vảy nến',
  ];

  static const _tuKhamSom = [
    'sốt cao', 'kéo dài', 'nhiều ngày', 'tuần', 'ngày càng', 'nặng hơn', 'không đỡ',
  ];

  /// Gợi ý chuyên khoa theo từ khoá (dùng khi AI không gợi ý hoặc máy chủ tắt).
  static List<GoiYKhoa> _goiYTheoTuKhoa(String loi, List<_Khoa> khoa, {required bool coAnh}) {
    _Khoa? tim(String ten) {
      for (final k in khoa) {
        if (k.ten.toLowerCase() == ten.toLowerCase()) return k;
      }
      return null;
    }

    final goiY = <GoiYKhoa>[];
    for (final (ten, tu, lyDo) in _quyTac) {
      final k = tim(ten);
      if (k != null && goiY.length < 2 && _co(loi, tu)) {
        goiY.add(GoiYKhoa(id: k.id, ten: k.ten, lyDo: lyDo));
      }
      if (goiY.isNotEmpty && goiY.first.ten == 'Nhi') break; // trẻ em: chỉ khoa Nhi
    }
    if (goiY.isEmpty && coAnh) {
      final k = tim('Da liễu');
      if (k != null) {
        goiY.add(GoiYKhoa(id: k.id, ten: k.ten, lyDo: 'Ảnh bạn gửi có thể là tổn thương trên da.'));
      }
    }
    if (goiY.isEmpty) {
      final k = tim('Nội tổng quát');
      if (k != null) {
        goiY.add(GoiYKhoa(id: k.id, ten: k.ten, lyDo: 'Bác sĩ Nội tổng quát sẽ khám ban đầu và hướng dẫn tiếp.'));
      }
    }

    return goiY;
  }

  /// Lớp 3: máy chủ AI không phản hồi → gợi ý nhanh theo từ khoá.
  KetQuaAi _goiYDuPhong(List<TinNhan> tin, List<_Khoa> khoa, {required bool coAnh}) {
    final loi = _loiBenhNhan(tin);
    final goiY = _goiYTheoTuKhoa(loi, khoa, coAnh: coAnh);
    final khamSom = _co(loi, _tuKhamSom);
    final tenKhoa = goiY.map((g) => 'khoa ${g.ten}').join(' hoặc ');
    return KetQuaAi(
      traLoi:
          'Dựa trên những gì bạn kể, bạn nên đến khám $tenKhoa.'
          '${khamSom ? ' Triệu chứng đã kéo dài hoặc nặng dần, bạn nên đi khám sớm.' : ''}'
          '\n\n(Máy chủ AI đang không kết nối được nên đây là gợi ý nhanh theo từ khoá. '
          'Thông tin chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ.)',
      mucDo: khamSom ? MucDo.nenKhamSom : MucDo.thongThuong,
      canHoiThem: false,
      goiYKhoa: goiY,
      duPhong: true,
    );
  }
}
