import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cấu hình máy chủ AI chạy cục bộ (Ollama trên laptop, cùng mạng wifi với điện thoại).
/// Địa chỉ lưu trong máy (SharedPreferences) để đổi mạng không phải build lại app.
class CauHinhAi {
  /// Model Qwen3-VL bản 4B instruct: đọc được cả chữ và ảnh, trả lời thẳng (không "thinking").
  static const String model = 'qwen3-vl:4b-instruct';
  static const String _khoaLuu = 'ai_may_chu';
  static const String macDinh = 'http://192.168.1.5:11434';

  static String mayChu = macDinh;

  /// Đọc địa chỉ đã lưu (gọi một lần khi mở app).
  static Future<void> tai() async {
    try {
      final p = await SharedPreferences.getInstance();
      mayChu = p.getString(_khoaLuu) ?? macDinh;
    } catch (_) {
      mayChu = macDinh;
    }
  }

  /// "192.168.1.5" hoặc "192.168.1.5:11434" → "http://192.168.1.5:11434"
  static String chuanHoa(String nhap) {
    var s = nhap.trim();
    if (s.isEmpty) return macDinh;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return s;
    final cong = uri.hasPort ? uri.port : 11434;
    return '${uri.scheme}://${uri.host}:$cong';
  }

  static Future<void> luu(String nhap) async {
    mayChu = chuanHoa(nhap);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_khoaLuu, mayChu);
    } catch (_) {}
  }

  /// Kiểm tra máy chủ: trả về null nếu ổn, ngược lại là câu báo lỗi tiếng Việt.
  static Future<String?> kiemTra([String? diaChi]) async {
    final goc = diaChi == null ? mayChu : chuanHoa(diaChi);
    try {
      final r = await http
          .get(Uri.parse('$goc/api/tags'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return 'Máy chủ trả lỗi ${r.statusCode}';
      final ds = (jsonDecode(r.body)['models'] as List? ?? [])
          .map((m) => m['name'] as String? ?? '')
          .toList();
      if (!ds.contains(model)) {
        return 'Đã kết nối nhưng máy chủ chưa có model $model';
      }
      return null;
    } catch (_) {
      return 'Không kết nối được $goc. Kiểm tra laptop đã bật Ollama và cùng mạng wifi.';
    }
  }
}
