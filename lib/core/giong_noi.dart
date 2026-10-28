import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// Đọc to một câu tiếng Việt bằng bộ chuyển văn bản thành giọng nói (TTS)
/// có sẵn trên máy (Android: Google TTS; trình duyệt: Web Speech API).
/// Máy không có giọng tiếng Việt hoặc lỗi gì thì im lặng bỏ qua, không làm hỏng app.
class GiongNoi {
  static final FlutterTts _tts = FlutterTts();
  static bool _daCauHinh = false;

  static Future<void> doc(String cau) async {
    try {
      if (!_daCauHinh) {
        await _tts.setLanguage('vi-VN');
        // Android: 0.5 là tốc độ bình thường; trình duyệt: 1.0 là bình thường
        await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        _daCauHinh = true;
      }
      await _tts.stop();
      await _tts.speak(cau);
    } catch (_) {
      // Không có giọng đọc: bỏ qua
    }
  }

  /// "Phòng 204 · Tầng 2" → "Phòng 204, tầng 2" cho giọng đọc tự nhiên hơn
  static String docPhong(String viTri) =>
      viTri.replaceAll('·', ',').replaceAll('Tầng', 'tầng');
}
