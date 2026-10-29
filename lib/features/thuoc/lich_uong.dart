import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/don_thuoc.dart';
import '../../core/supabase_client.dart';
import '../tro_ly_ai/cau_hinh_ai.dart';
import 'thoi_quen.dart';

/// Giờ uống trong ngày của một loại thuốc.
class LichThuoc {
  final DongDonThuoc dong;
  final List<int> gio; // số phút từ 00:00, đã sắp xếp

  const LichThuoc({required this.dong, required this.gio});

  LichThuoc doiGio(int viTri, int phut) {
    final moi = [...gio]..[viTri] = phut;
    moi.sort();
    return LichThuoc(dong: dong, gio: moi);
  }
}

/// Lịch uống thuốc của một đơn (một lượt khám).
class LichUong {
  final int luotKhamId;
  final String tieuDe; // VD "Viêm giác mạc · BS. Võ Thị Hà"
  final DateTime batDau; // ngày bắt đầu uống (chỉ phần ngày)
  final List<LichThuoc> thuoc;
  final bool batNhac;

  const LichUong({
    required this.luotKhamId,
    required this.tieuDe,
    required this.batDau,
    required this.thuoc,
    this.batNhac = true,
  });

  DateTime ketThucCua(LichThuoc t) => batDau.add(Duration(days: t.dong.soNgay - 1));

  DateTime get ketThuc => thuoc
      .map(ketThucCua)
      .fold(batDau, (a, b) => b.isAfter(a) ? b : a);

  bool conDung(DateTime ngay, LichThuoc t) {
    final d = DateTime(ngay.year, ngay.month, ngay.day);
    return !d.isBefore(batDau) && !d.isAfter(ketThucCua(t));
  }

  bool conHieuLuc(DateTime ngay) => thuoc.any((t) => conDung(ngay, t));

  /// Các cữ uống trong một ngày: mỗi giờ một nhóm thuốc.
  List<(int, List<LichThuoc>)> cacCu(DateTime ngay) {
    final nhom = <int, List<LichThuoc>>{};
    for (final t in thuoc) {
      if (!conDung(ngay, t)) continue;
      for (final g in t.gio) {
        nhom.putIfAbsent(g, () => []).add(t);
      }
    }
    final ds = nhom.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return ds;
  }

  LichUong copyWith({List<LichThuoc>? thuoc, bool? batNhac}) => LichUong(
    luotKhamId: luotKhamId,
    tieuDe: tieuDe,
    batDau: batDau,
    thuoc: thuoc ?? this.thuoc,
    batNhac: batNhac ?? this.batNhac,
  );

  Map<String, dynamic> toJson() => {
    'luot': luotKhamId,
    'tieu_de': tieuDe,
    'bat_dau': batDau.toIso8601String(),
    'bat_nhac': batNhac,
    'thuoc': [
      for (final t in thuoc)
        {
          'thuoc': {'id': t.dong.thuoc.id, 'ten': t.dong.thuoc.ten, 'don_vi': t.dong.thuoc.donVi},
          'lieu': t.dong.lieu,
          'so_lan': t.dong.soLan,
          'thoi_diem': t.dong.thoiDiem.ma,
          'so_ngay': t.dong.soNgay,
          'ghi_chu': t.dong.ghiChu,
          'gio': t.gio,
        },
    ],
  };

  factory LichUong.tuJson(Map<String, dynamic> j) => LichUong(
    luotKhamId: j['luot'] as int,
    tieuDe: j['tieu_de'] as String? ?? 'Đơn thuốc',
    batDau: DateTime.parse(j['bat_dau'] as String),
    batNhac: j['bat_nhac'] != false,
    thuoc: [
      for (final t in (j['thuoc'] as List))
        LichThuoc(
          dong: DongDonThuoc(
            thuoc: ThuocMau.tuJson(Map<String, dynamic>.from(t['thuoc'] as Map)),
            lieu: (t['lieu'] as num).toDouble(),
            soLan: t['so_lan'] as int,
            thoiDiem: ThoiDiemUong.tuMa(t['thoi_diem'] as String?),
            soNgay: t['so_ngay'] as int,
            ghiChu: t['ghi_chu'] as String?,
          ),
          gio: [for (final g in (t['gio'] as List)) (g as num).toInt()],
        ),
    ],
  );
}

/// Lịch được xếp thế nào (hiện cho người dùng biết).
enum NguonLich {
  ai, // AI xếp, toàn bộ đúng luật
  aiMotPhan, // AI xếp, một số giờ sai luật nên thay bằng luật
  khongKetNoi, // không gọi được máy chủ AI → toàn bộ theo luật
}

/// Xếp giờ uống: AI (Qwen cục bộ) đề xuất theo thói quen, CODE kiểm tra lại bằng luật.
/// AI xếp sai luật hoặc máy chủ tắt → dùng lịch tính bằng luật.
class XepLich {
  /// Nguyên văn câu trả lời gần nhất của AI (hiện ở màn lập lịch để kiểm chứng).
  static String? aiTraVeGanNhat;

  static const _sauAnTu = 10, _sauAnDen = 60, _sauAnChuan = 20;
  static const _truocAnTu = -60, _truocAnDen = -15, _truocAnChuan = -30;
  static const _cachToiThieu = 120; // 2 giờ giữa 2 lần uống cùng một thuốc

  /// Lịch tính bằng luật (dự phòng, luôn hợp lệ).
  static List<int> theoLuat(DongDonThuoc d, ThoiQuen tq) {
    final n = d.soLan;
    if (d.thoiDiem == ThoiDiemUong.khongPhuThuoc) {
      final dau = tq.thucDay + 30, cuoi = tq.diNgu - 30;
      if (n == 1) return [tq.anSang];
      return [
        for (var i = 0; i < n; i++) (dau + (cuoi - dau) * i / (n - 1)).round(),
      ];
    }
    final lech = d.thoiDiem == ThoiDiemUong.sauAn ? _sauAnChuan : _truocAnChuan;
    final bua = switch (n) {
      1 => [tq.anSang],
      2 => [tq.anSang, tq.anToi],
      _ => tq.baBua,
    };
    final gio = [for (final b in bua) b + lech];
    if (n >= 4) gio.add(tq.diNgu - 30); // lần thứ 4: trước khi ngủ
    return gio..sort();
  }

  /// null = hợp lệ; ngược lại là lý do sai.
  static String? kiemTra(DongDonThuoc d, List<int> gio, ThoiQuen tq) {
    if (gio.length != d.soLan) return 'Phải đủ ${d.soLan} lần/ngày';
    final s = [...gio]..sort();
    for (final g in s) {
      if (g < tq.thucDay || g > tq.diNgu) return 'Có giờ uống rơi vào lúc đang ngủ';
    }
    for (var i = 1; i < s.length; i++) {
      if (s[i] - s[i - 1] < _cachToiThieu) return 'Hai lần uống phải cách nhau ít nhất 2 giờ';
    }
    if (d.thoiDiem == ThoiDiemUong.khongPhuThuoc) return null;
    final (tu, den) = d.thoiDiem == ThoiDiemUong.sauAn
        ? (_sauAnTu, _sauAnDen)
        : (_truocAnTu, _truocAnDen);
    final canKhop = d.soLan >= 4 ? 3 : d.soLan;
    var khop = 0;
    final daDung = <int>{};
    for (final g in s) {
      for (final b in tq.baBua) {
        if (!daDung.contains(b) && g - b >= tu && g - b <= den) {
          daDung.add(b);
          khop++;
          break;
        }
      }
    }
    if (khop < canKhop) {
      return d.thoiDiem == ThoiDiemUong.sauAn
          ? 'Thuốc uống sau ăn phải sau bữa ăn 10–60 phút'
          : 'Thuốc uống trước ăn phải trước bữa ăn 15–60 phút';
    }
    return null;
  }

  /// Chuẩn hoá giờ AI đề xuất: AI hay ghi đúng giờ ăn (VD 06:30) cho thuốc "sau ăn".
  /// Giờ nằm sát bữa ăn thì dời về đúng khoảng (sau ăn +20 phút, trước ăn −30 phút).
  static List<int> chuanHoa(DongDonThuoc d, List<int> gio, ThoiQuen tq) {
    if (d.thoiDiem == ThoiDiemUong.khongPhuThuoc) return gio;
    return [
      for (final g in gio)
        () {
          if (d.thoiDiem == ThoiDiemUong.truocAn && g < tq.thucDay && tq.thucDay - g <= 30) {
            return tq.thucDay; // chưa dậy thì nhắc ngay lúc thức dậy
          }
          for (final b in tq.baBua) {
            final lech = g - b;
            if (d.thoiDiem == ThoiDiemUong.sauAn && lech >= -15 && lech < _sauAnTu) {
              return b + _sauAnChuan;
            }
            if (d.thoiDiem == ThoiDiemUong.truocAn && lech > _truocAnDen && lech <= 15) {
              return b + _truocAnChuan;
            }
          }
          return g;
        }(),
    ];
  }

  /// Các giờ gợi ý cho một lần uống, theo đúng "trước/sau ăn" của đơn.
  static List<(String, int)> goiYGio(DongDonThuoc d, ThoiQuen tq) {
    const ten = ['sáng', 'trưa', 'tối'];
    return switch (d.thoiDiem) {
      ThoiDiemUong.sauAn => [
        for (var i = 0; i < 3; i++) ('Sau bữa ${ten[i]}', tq.baBua[i] + _sauAnChuan),
      ],
      ThoiDiemUong.truocAn => [
        for (var i = 0; i < 3; i++) ('Trước bữa ${ten[i]}', tq.baBua[i] + _truocAnChuan),
      ],
      ThoiDiemUong.khongPhuThuoc => [
        ('Buổi sáng', tq.anSang),
        ('Buổi trưa', tq.anTrua),
        ('Buổi tối', tq.anToi),
        ('Trước khi ngủ', tq.diNgu - 30),
      ],
    };
  }

  /// Mô tả ngắn cho một giờ uống: "sau bữa sáng", "trước bữa tối", "trước khi ngủ".
  static String moTaGio(int g, ThoiQuen tq) {
    const ten = ['sáng', 'trưa', 'tối'];
    for (var i = 0; i < 3; i++) {
      final lech = g - tq.baBua[i];
      if (lech == 0) return 'đúng giờ ăn ${ten[i]}';
      if (lech > 0 && lech <= _sauAnDen) return '$lech phút sau bữa ${ten[i]}';
      if (lech < 0 && lech >= _truocAnTu) return '${-lech} phút trước bữa ${ten[i]}';
    }
    if (tq.diNgu - g <= 60 && g <= tq.diNgu) return 'trước khi ngủ';
    return '';
  }

  /// Xếp lịch cho cả đơn. Trả về (lịch từng thuốc, lời giải thích của AI, nguồn lịch,
  /// danh sách lý do AI xếp sai theo từng thuốc).
  static Future<(List<LichThuoc>, String?, NguonLich, List<String>)> xep(
    List<DongDonThuoc> don,
    ThoiQuen tq, {
    double nhietDo = 0.2, // xếp lại thì tăng lên để AI thử phương án khác
  }) async {
    Map<int, List<int>> deXuat = {};
    String? giaiThich;
    var ketNoiDuoc = true;
    aiTraVeGanNhat = null;
    try {
      (deXuat, giaiThich) = await _hoiAi(don, tq, nhietDo);
    } catch (e) {
      ketNoiDuoc = false;
      debugPrint('[MediBook][AI] xếp lịch: không gọi được máy chủ AI: $e → dùng luật');
    }

    final saiLuat = <String>[];
    final kq = <LichThuoc>[];
    for (var i = 0; i < don.length; i++) {
      final d = don[i];
      final aiGoc = deXuat[i];
      final ai = aiGoc == null ? null : chuanHoa(d, aiGoc, tq);
      final loi = ai == null ? 'AI không xếp thuốc này' : kiemTra(d, ai, tq);
      if (ai != null && loi == null) {
        kq.add(LichThuoc(dong: d, gio: [...ai]..sort()));
      } else {
        if (ketNoiDuoc) {
          saiLuat.add('${d.thuoc.ten}: $loi'
              '${ai == null ? '' : ' (AI đề xuất ${ai.map(chuPhut).join(', ')})'}');
        }
        kq.add(LichThuoc(dong: d, gio: theoLuat(d, tq)));
      }
    }
    final nguon = !ketNoiDuoc
        ? NguonLich.khongKetNoi
        : saiLuat.isEmpty
        ? NguonLich.ai
        : NguonLich.aiMotPhan;
    for (final s in saiLuat) {
      debugPrint('[MediBook][AI] xếp lịch sai luật → $s');
    }
    // Lời giải thích của AI chỉ hiện khi toàn bộ lịch đúng là do AI xếp (tránh lệch giờ)
    return (kq, nguon == NguonLich.ai ? giaiThich : null, nguon, saiLuat);
  }

  static Future<(Map<int, List<int>>, String?)> _hoiAi(
    List<DongDonThuoc> don,
    ThoiQuen tq,
    double nhietDo,
  ) async {
    final moTaDon = [
      for (var i = 0; i < don.length; i++)
        {
          'chi_so': i,
          'ten': don[i].thuoc.ten,
          'so_lan_moi_ngay': don[i].soLan,
          'thoi_diem': don[i].thoiDiem.nhan,
        },
    ];
    final res = await http
        .post(
          Uri.parse('${CauHinhAi.mayChu}/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': CauHinhAi.model,
            'stream': false,
            'keep_alive': '30m',
            'options': {'temperature': nhietDo},
            'format': {
              'type': 'object',
              'properties': {
                'lich': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'chi_so': {'type': 'integer'},
                      'ten': {'type': 'string'},
                      'gio': {
                        'type': 'array',
                        'items': {'type': 'string'},
                      },
                    },
                    'required': ['chi_so', 'ten', 'gio'],
                  },
                },
                'giai_thich': {'type': 'string'},
              },
              'required': ['lich', 'giai_thich'],
            },
            'messages': [
              {
                'role': 'system',
                'content': '''Bạn xếp GIỜ UỐNG THUỐC trong ngày cho bệnh nhân theo đúng đơn bác sĩ và thói quen sinh hoạt.
QUY TẮC: KHÔNG đổi thuốc, KHÔNG đổi liều, KHÔNG đổi số lần. Mỗi thuốc đúng "so_lan_moi_ngay" giờ, dạng HH:mm.
- "Sau ăn": 15–30 phút sau bữa ăn. 1 lần → sau bữa sáng; 2 lần → sau bữa sáng và tối; 3 lần → sau 3 bữa.
- "Trước ăn": khoảng 30 phút trước bữa ăn, theo cách chọn bữa như trên.
- "Không phụ thuộc bữa ăn": chia đều trong thời gian thức.
- Không xếp giờ khi bệnh nhân đang ngủ; hai lần cùng một thuốc cách nhau ít nhất 2 giờ.
- Gộp các thuốc vào cùng giờ khi có thể để bệnh nhân dễ nhớ.
- KHÔNG ghi đúng giờ ăn. Chọn giờ nằm trong "khung_gio_hop_le" của bữa tương ứng.
giai_thich: 2–3 câu tiếng Việt dễ hiểu, xưng "bạn", tóm tắt khi nào uống thuốc nào. Không khuyên gì ngoài đơn.''',
              },
              {
                'role': 'user',
                'content': jsonEncode({
                  'thoi_quen': tq.toJson(),
                  'khung_gio_hop_le': {
                    for (final (i, ten) in const [(0, 'sang'), (1, 'trua'), (2, 'toi')])
                      'bua_$ten': {
                        'sau_an': '${chuPhut(tq.baBua[i] + 15)}–${chuPhut(tq.baBua[i] + 30)}',
                        'truoc_an':
                            '${chuPhut(i == 0 && tq.baBua[i] - 45 < tq.thucDay ? tq.thucDay : tq.baBua[i] - 45)}'
                            '–${chuPhut(tq.baBua[i] - 20)}',
                      },
                  },
                  'don_thuoc': moTaDon,
                }),
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final noiDung =
        jsonDecode(utf8.decode(res.bodyBytes))['message']?['content'] as String? ?? '';
    debugPrint('[MediBook][AI] xếp lịch, AI trả về: $noiDung');
    aiTraVeGanNhat = noiDung;
    final j = Map<String, dynamic>.from(jsonDecode(noiDung) as Map);
    final kq = <int, List<int>>{};
    final dsLich = [for (final l in (j['lich'] as List? ?? [])) if (l is Map) l];
    for (var vt = 0; vt < dsLich.length; vt++) {
      final l = dsLich[vt];
      var i = int.tryParse('${l['chi_so'] ?? ''}');
      if (i == null || i < 0 || i >= don.length) {
        // AI đánh số từ 1 hoặc ghi tên thuốc thay cho chỉ số
        final ten = (l['ten'] as String?)?.trim().toLowerCase();
        final theoTen = ten == null
            ? -1
            : don.indexWhere((d) => d.thuoc.ten.toLowerCase() == ten);
        if (theoTen >= 0) {
          i = theoTen;
        } else if (i != null && i >= 1 && i <= don.length && !kq.containsKey(i - 1)) {
          i = i - 1;
        } else if (dsLich.length == don.length) {
          i = vt;
        } else {
          continue;
        }
      }
      final gio = [
        for (final g in (l['gio'] as List? ?? [])) docPhut(g?.toString()),
      ];
      if (gio.any((g) => g == null)) continue;
      kq[i] = [for (final g in gio) g!];
    }
    final gt = (j['giai_thich'] as String?)?.trim();
    return (kq, (gt == null || gt.isEmpty) ? null : gt);
  }
}

/// Lưu các lịch uống thuốc trên điện thoại (theo tài khoản).
class KhoLichUong {
  static String get _khoa =>
      'lich_uong_${supabase.auth.currentUser?.id ?? 'khach'}';

  static Future<List<LichUong>> danhSach() async {
    try {
      final p = await SharedPreferences.getInstance();
      return [
        for (final s in p.getStringList(_khoa) ?? [])
          LichUong.tuJson(Map<String, dynamic>.from(jsonDecode(s) as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<LichUong?> cuaLuot(int luotKhamId) async {
    for (final l in await danhSach()) {
      if (l.luotKhamId == luotKhamId) return l;
    }
    return null;
  }

  static Future<void> luu(LichUong lich) async {
    final ds = (await danhSach())..removeWhere((l) => l.luotKhamId == lich.luotKhamId);
    ds.add(lich);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_khoa, [for (final l in ds) jsonEncode(l.toJson())]);
  }

  static Future<void> xoa(int luotKhamId) async {
    final ds = (await danhSach())..removeWhere((l) => l.luotKhamId == luotKhamId);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_khoa, [for (final l in ds) jsonEncode(l.toJson())]);
  }
}
