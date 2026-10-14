import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

enum MucDo { thongThuong, nenKhamSom, capCuu }

class GoiYKhoa {
  final int id;
  final String ten;
  final String lyDo;

  const GoiYKhoa({required this.id, required this.ten, required this.lyDo});
}

/// Câu trả lời có cấu trúc của Trợ lý AI (do Edge Function tro-ly-ai trả về).
class KetQuaAi {
  final String traLoi;
  final MucDo mucDo;
  final bool canHoiThem;
  final List<GoiYKhoa> goiYKhoa;

  const KetQuaAi({
    required this.traLoi,
    required this.mucDo,
    required this.canHoiThem,
    required this.goiYKhoa,
  });

  factory KetQuaAi.tuJson(Map<String, dynamic> j) => KetQuaAi(
    traLoi: (j['tra_loi'] as String?)?.trim() ?? '',
    mucDo: switch (j['muc_do']) {
      'cap_cuu' => MucDo.capCuu,
      'nen_kham_som' => MucDo.nenKhamSom,
      _ => MucDo.thongThuong,
    },
    canHoiThem: j['can_hoi_them'] == true,
    goiYKhoa: [
      for (final g in (j['goi_y_khoa'] as List? ?? []))
        GoiYKhoa(
          id: (g['id'] as num).toInt(),
          ten: (g['ten'] as String?) ?? '',
          lyDo: (g['ly_do'] as String?) ?? '',
        ),
    ],
  );
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
}

class LoiAi implements Exception {
  final String thongBao;
  const LoiAi(this.thongBao);
  @override
  String toString() => thongBao;
}

class DichVuAi {
  /// Gửi toàn bộ hội thoại (ảnh nếu có thì gắn vào tin cuối) lên Edge Function.
  Future<KetQuaAi> hoi(List<TinNhan> hoiThoai, {Uint8List? anh}) async {
    try {
      final res = await supabase.functions.invoke(
        'tro-ly-ai',
        body: {
          'tin_nhan': [
            for (final t in hoiThoai)
              {
                'vai_tro': t.laNguoiDung ? 'nguoi_dung' : 'tro_ly',
                'noi_dung': t.noiDung.isEmpty && t.anh != null
                    ? '(Gửi một ảnh)'
                    : t.noiDung,
              },
          ],
          if (anh != null)
            'anh': {'mime': 'image/jpeg', 'base64': base64Encode(anh)},
        },
      );
      final data = res.data;
      if (data is Map && data['loi'] != null)
        throw LoiAi(data['loi'] as String);
      return KetQuaAi.tuJson(Map<String, dynamic>.from(data as Map));
    } on FunctionException catch (e) {
      debugPrint('[MediBook][AI] status=${e.status} details=${e.details}');
      final chiTiet = e.details;
      if (chiTiet is Map && chiTiet['loi'] != null)
        throw LoiAi(chiTiet['loi'] as String);
      throw const LoiAi('Trợ lý AI đang gặp sự cố, vui lòng thử lại.');
    } on LoiAi {
      rethrow;
    } catch (e) {
      debugPrint('[MediBook][AI] $e');
      throw const LoiAi('Không kết nối được trợ lý. Kiểm tra mạng và thử lại.');
    }
  }
}
