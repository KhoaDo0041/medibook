import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_client.dart';
import '../tro_ly_ai/cau_hinh_ai.dart';

/// "07:05" ↔ số phút tính từ 00:00
String chuPhut(int phut) =>
    '${(phut ~/ 60).toString().padLeft(2, '0')}:${(phut % 60).toString().padLeft(2, '0')}';

/// Đọc giờ linh hoạt: "07:05", "7:05", "7h05", "7h", "07:05:00", "7:05 PM", "19.30"…
int? docPhut(String? s) {
  final van = (s ?? '').trim().toLowerCase();
  final m = RegExp(r'(\d{1,2})\s*[:hg.]\s*(\d{2})?').firstMatch(van);
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final p = int.tryParse(m.group(2) ?? '0') ?? 0;
  if (van.contains('pm') && h < 12) h += 12;
  if (van.contains('am') && h == 12) h = 0;
  if (h > 23 || p > 59) return null;
  return h * 60 + p;
}

/// Thói quen sinh hoạt của bệnh nhân (khai một lần, dùng để xếp giờ uống thuốc).
/// Lưu trên điện thoại, theo từng tài khoản.
class ThoiQuen {
  final int thucDay, anSang, anTrua, anToi, diNgu; // số phút từ 00:00

  const ThoiQuen({
    required this.thucDay,
    required this.anSang,
    required this.anTrua,
    required this.anToi,
    required this.diNgu,
  });

  static const macDinh = ThoiQuen(
    thucDay: 6 * 60,
    anSang: 6 * 60 + 30,
    anTrua: 11 * 60 + 30,
    anToi: 18 * 60 + 30,
    diNgu: 22 * 60 + 30,
  );

  List<int> get baBua => [anSang, anTrua, anToi];

  /// Thứ tự hợp lý: dậy < sáng < trưa < tối < ngủ.
  String? get loi {
    if (!(thucDay < anSang && anSang < anTrua && anTrua < anToi && anToi < diNgu)) {
      return 'Giờ phải theo thứ tự: thức dậy → ăn sáng → ăn trưa → ăn tối → đi ngủ';
    }
    return null;
  }

  ThoiQuen copyWith({int? thucDay, int? anSang, int? anTrua, int? anToi, int? diNgu}) =>
      ThoiQuen(
        thucDay: thucDay ?? this.thucDay,
        anSang: anSang ?? this.anSang,
        anTrua: anTrua ?? this.anTrua,
        anToi: anToi ?? this.anToi,
        diNgu: diNgu ?? this.diNgu,
      );

  Map<String, String> toJson() => {
    'thuc_day': chuPhut(thucDay),
    'an_sang': chuPhut(anSang),
    'an_trua': chuPhut(anTrua),
    'an_toi': chuPhut(anToi),
    'di_ngu': chuPhut(diNgu),
  };

  static ThoiQuen? tuJson(Map<String, dynamic> j, {ThoiQuen goc = macDinh}) {
    final tq = ThoiQuen(
      thucDay: docPhut(j['thuc_day'] as String?) ?? goc.thucDay,
      anSang: docPhut(j['an_sang'] as String?) ?? goc.anSang,
      anTrua: docPhut(j['an_trua'] as String?) ?? goc.anTrua,
      anToi: docPhut(j['an_toi'] as String?) ?? goc.anToi,
      diNgu: docPhut(j['di_ngu'] as String?) ?? goc.diNgu,
    );
    return tq.loi == null ? tq : null;
  }

  // ---------------- lưu trên máy ----------------

  static String get _khoa =>
      'thoi_quen_${supabase.auth.currentUser?.id ?? 'khach'}';

  /// null = chưa khai lần nào.
  static Future<ThoiQuen?> tai() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_khoa);
      if (s == null) return null;
      return tuJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> luu() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_khoa, jsonEncode(toJson()));
    } catch (_) {}
  }

  // ---------------- AI điền từ một câu nói tự do ----------------

  /// VD "Tôi dậy 6h, ăn sáng 6 rưỡi, trưa ăn ở công ty 11h30, tối 7 giờ, ngủ 11 giờ đêm".
  /// Trả về null nếu máy chủ AI không phản hồi hoặc kết quả không hợp lệ.
  static Future<ThoiQuen?> tuCauNoi(String cau, {ThoiQuen goc = macDinh}) async {
    const chuoi = {'type': 'string'};
    try {
      final res = await http
          .post(
            Uri.parse('${CauHinhAi.mayChu}/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': CauHinhAi.model,
              'stream': false,
              'keep_alive': '30m',
              'options': {'temperature': 0},
              'format': {
                'type': 'object',
                'properties': {
                  'thuc_day': chuoi,
                  'an_sang': chuoi,
                  'an_trua': chuoi,
                  'an_toi': chuoi,
                  'di_ngu': chuoi,
                },
                'required': ['thuc_day', 'an_sang', 'an_trua', 'an_toi', 'di_ngu'],
              },
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Trích giờ sinh hoạt từ câu tiếng Việt, ghi dạng HH:mm 24 giờ '
                      '(VD "7 giờ tối" = 19:00, "6 rưỡi" = 06:30, "11 giờ đêm" = 23:00). '
                      'Mục nào câu không nói tới thì để chuỗi rỗng. '
                      'Các mục: thuc_day, an_sang, an_trua, an_toi, di_ngu.',
                },
                {'role': 'user', 'content': cau},
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      final noiDung =
          jsonDecode(utf8.decode(res.bodyBytes))['message']?['content'] as String? ?? '';
      return tuJson(Map<String, dynamic>.from(jsonDecode(noiDung) as Map), goc: goc);
    } catch (_) {
      return null;
    }
  }
}
