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

  /// true khi tài khoản đã đăng ký nhưng chưa nhập mã xác nhận email.
  final bool chuaXacNhanEmail;

  const LoiTaiKhoan(this.thongBao, {this.chuaXacNhanEmail = false});
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
        throw const LoiTaiKhoan(
          'Email chưa được xác nhận',
          chuaXacNhanEmail: true,
        );
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

  /// Đăng ký tài khoản bệnh nhân. Supabase sẽ gửi mã xác nhận đến email.
  /// Hồ sơ (bảng `ho_so`) do database tự tạo từ `ho_ten` gửi kèm.
  static Future<void> dangKy({
    required String hoTen,
    required String email,
    required String matKhau,
  }) async {
    try {
      final ketQua = await supabase.auth.signUp(
        email: email,
        password: matKhau,
        data: {'ho_ten': hoTen},
      );
      // Email đã có tài khoản: Supabase không báo lỗi mà trả về người dùng "rỗng"
      final danhTinh = ketQua.user?.identities;
      if (danhTinh != null && danhTinh.isEmpty) {
        throw const LoiTaiKhoan('Email này đã được đăng ký');
      }
    } on LoiTaiKhoan {
      rethrow;
    } on AuthException catch (e) {
      throw LoiTaiKhoan(_dichLoi(e));
    } catch (_) {
      throw const LoiTaiKhoan(
          'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// Kiểm tra mã xác nhận gửi qua email. Thành công thì người dùng được đăng nhập luôn.
  static Future<HoSo> xacNhanMaDangKy({
    required String email,
    required String ma,
  }) async {
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: ma,
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      throw LoiTaiKhoan(_dichLoi(e));
    } catch (_) {
      throw const LoiTaiKhoan(
          'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.');
    }

    final hoSo = await layHoSoHienTai();
    if (hoSo == null) {
      throw const LoiTaiKhoan(
          'Đã xác nhận email nhưng chưa có hồ sơ. Vui lòng liên hệ hỗ trợ.');
    }
    return hoSo;
  }

  /// Gửi lại mã xác nhận đăng ký.
  static Future<void> guiLaiMaDangKy(String email) async {
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      throw LoiTaiKhoan(_dichLoi(e));
    } catch (_) {
      throw const LoiTaiKhoan(
          'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// Đổi thông báo lỗi tiếng Anh của Supabase sang tiếng Việt.
  static String _dichLoi(AuthException e) {
    final loi = e.message.toLowerCase();
    if (loi.contains('already registered')) return 'Email này đã được đăng ký';
    if (loi.contains('expired') || loi.contains('invalid')) {
      return 'Mã không đúng hoặc đã hết hạn';
    }
    if (loi.contains('rate limit') || loi.contains('security purposes')) {
      return 'Bạn thao tác quá nhanh. Vui lòng đợi khoảng 1 phút rồi thử lại.';
    }
    if (loi.contains('password')) return 'Mật khẩu chưa đủ mạnh';
    if (loi.contains('sending') && loi.contains('email')) {
      return 'Không gửi được email xác nhận. Vui lòng thử lại sau.';
    }
    return 'Có lỗi xảy ra: ${e.message}';
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
