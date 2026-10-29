import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_client.dart';
import 'dich_vu_ai.dart';

/// Một cuộc trò chuyện đã lưu.
class CuocTroChuyen {
  final String id;
  final DateTime capNhat;
  final List<TinNhan> tinNhan;

  const CuocTroChuyen({
    required this.id,
    required this.capNhat,
    required this.tinNhan,
  });

  /// Câu đầu tiên bệnh nhân kể (hoặc "Ảnh gửi kèm").
  String get tieuDe {
    for (final t in tinNhan) {
      if (!t.laNguoiDung) continue;
      final s = t.noiDung.trim();
      if (s.isNotEmpty) return s;
      if (t.anh != null) return 'Ảnh gửi kèm';
    }
    return 'Cuộc trò chuyện';
  }

  /// Kết quả cuối cùng của trợ lý (khoa gợi ý, mức độ).
  KetQuaAi? get ketQuaCuoi {
    for (final t in tinNhan.reversed) {
      if (t.ketQua != null) return t.ketQua;
    }
    return null;
  }

  bool get coAnh => tinNhan.any((t) => t.anh != null);

  Map<String, dynamic> toJson() => {
    'id': id,
    'cap_nhat': capNhat.toIso8601String(),
    'tin_nhan': [for (final t in tinNhan) t.toJson()],
  };

  factory CuocTroChuyen.tuJson(Map<String, dynamic> j) => CuocTroChuyen(
    id: j['id'] as String,
    capNhat: DateTime.tryParse(j['cap_nhat'] as String? ?? '') ?? DateTime.now(),
    tinNhan: [
      for (final t in (j['tin_nhan'] as List? ?? []))
        TinNhan.tuJson(Map<String, dynamic>.from(t as Map)),
    ],
  );
}

/// Lịch sử trò chuyện với Trợ lý AI, LƯU NGAY TRÊN ĐIỆN THOẠI (SharedPreferences),
/// không gửi lên máy chủ để bảo vệ thông tin sức khoẻ.
/// Mỗi tài khoản một danh sách riêng; giữ tối đa [toiDa] cuộc gần nhất.
class LichSuChat {
  static const toiDa = 20;

  static String get _khoa {
    final uid = supabase.auth.currentUser?.id ?? 'khach';
    return 'lich_su_chat_ai_$uid';
  }

  static Future<List<CuocTroChuyen>> danhSach() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ds = p.getStringList(_khoa) ?? [];
      final kq = <CuocTroChuyen>[];
      for (final s in ds) {
        try {
          kq.add(CuocTroChuyen.tuJson(Map<String, dynamic>.from(jsonDecode(s) as Map)));
        } catch (_) {
          // bỏ qua bản ghi hỏng
        }
      }
      kq.sort((a, b) => b.capNhat.compareTo(a.capNhat));
      return kq;
    } catch (_) {
      return [];
    }
  }

  /// Thêm mới hoặc cập nhật một cuộc trò chuyện (theo id).
  static Future<void> luu(CuocTroChuyen cuoc) async {
    if (cuoc.tinNhan.isEmpty) return;
    try {
      final ds = await danhSach();
      ds.removeWhere((c) => c.id == cuoc.id);
      ds.insert(0, cuoc);
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_khoa, [
        for (final c in ds.take(toiDa)) jsonEncode(c.toJson()),
      ]);
    } catch (_) {
      // không lưu được cũng không ảnh hưởng việc trò chuyện
    }
  }

  static Future<void> xoa(String id) async {
    try {
      final ds = await danhSach();
      ds.removeWhere((c) => c.id == id);
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_khoa, [for (final c in ds) jsonEncode(c.toJson())]);
    } catch (_) {}
  }

  static Future<void> xoaTatCa() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_khoa);
    } catch (_) {}
  }
}
