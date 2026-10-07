import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// Hai vai trò trong MediBook, khớp với cột `vai_tro` của bảng `ho_so`.
class VaiTro {
  static const String benhNhan = 'benh_nhan';
  static const String bacSi = 'bac_si';
}

/// Thông tin hồ sơ của người đang đăng nhập (bảng `ho_so`).
class HoSo {
  final String id;
  final String hoTen;
  final String vaiTro;

  const HoSo({required this.id, required this.hoTen, required this.vaiTro});

  bool get laBacSi => vaiTro == VaiTro.bacSi;
}

/// Lỗi có câu thông báo tiếng Việt để hiện cho người dùng.
class LoiTaiKhoan implements Exception {
  final String thongBao;
  const LoiTaiKhoan(this.thongBao);
}

/// Mọi thao tác về tài khoản: đăng nhập, đăng xuất, lấy hồ sơ.
class DichVuTaiKhoan {
  /// Đăng nhập rồi trả về hồ sơ. Ném [LoiTaiKhoan] nếu thất bại.
  static Future<HoSo> dangNhap({
    required String email,
    required String matKhau,
    required String vaiTroMongMuon,
  }) async {
    try {
      await supabase.auth.signInWithPassword(email: email, password: matKhau);
    } on AuthException catch (e) {
      final loi = e.message.toLowerCase();
      if (loi.contains('invalid login credentials')) {
        throw const LoiTaiKhoan('Sai email hoặc mật khẩu');
      }
      if (loi.contains('email not confirmed')) {
        throw const LoiTaiKhoan('Email chưa được xác nhận');
      }
      throw LoiTaiKhoan('Đăng nhập thất bại: ${e.message}');
    } catch (_) {
      throw const LoiTaiKhoan(
          'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.');
    }

    final hoSo = await layHoSoHienTai();
    if (hoSo == null) {
      await dangXuat();
      throw const LoiTaiKhoan('Tài khoản chưa có hồ sơ. Vui lòng liên hệ hỗ trợ.');
    }

    // Chọn "Tôi là Bác sĩ" nhưng tài khoản là bệnh nhân (hoặc ngược lại)
    if (hoSo.vaiTro != vaiTroMongMuon) {
      await dangXuat();
      throw LoiTaiKhoan(vaiTroMongMuon == VaiTro.bacSi
          ? 'Tài khoản này không phải tài khoản bác sĩ'
          : 'Đây là tài khoản bác sĩ. Vui lòng chọn "Tôi là Bác sĩ".');
    }
    return hoSo;
  }

  /// Hồ sơ của người đang đăng nhập, hoặc `null` nếu chưa đăng nhập / chưa có hồ sơ.
  static Future<HoSo?> layHoSoHienTai() async {
    final nguoiDung = supabase.auth.currentUser;
    if (nguoiDung == null) return null;

    final dong = await supabase
        .from('ho_so')
        .select('id, ho_ten, vai_tro')
        .eq('id', nguoiDung.id)
        .maybeSingle();
    if (dong == null) return null;

    return HoSo(
      id: dong['id'] as String,
      hoTen: (dong['ho_ten'] as String?) ?? '',
      vaiTro: (dong['vai_tro'] as String?) ?? VaiTro.benhNhan,
    );
  }

  static Future<void> dangXuat() => supabase.auth.signOut();
}
