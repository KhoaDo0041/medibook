/// Các hàm kiểm tra dữ liệu người dùng nhập vào form.
/// Trả về `null` nếu hợp lệ, trả về câu báo lỗi nếu không hợp lệ.
class KiemTraNhap {
  static final RegExp _mauEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? giaTri) {
    final email = giaTri?.trim() ?? '';
    if (email.isEmpty) return 'Email không được để trống';
    if (!_mauEmail.hasMatch(email)) return 'Email không hợp lệ';
    return null;
  }

  /// Dùng cho màn hình đăng nhập: chỉ cần không để trống.
  static String? matKhauDangNhap(String? giaTri) {
    if (giaTri == null || giaTri.isEmpty) return 'Mật khẩu không được để trống';
    return null;
  }

  /// Dùng cho màn hình đăng ký: mật khẩu mạnh.
  static String? matKhauMoi(String? giaTri) {
    final mk = giaTri ?? '';
    if (mk.isEmpty) return 'Mật khẩu không được để trống';
    if (mk.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
    if (!mk.contains(RegExp(r'[A-Z]'))) return 'Mật khẩu cần có chữ in hoa';
    if (!mk.contains(RegExp(r'[a-z]'))) return 'Mật khẩu cần có chữ thường';
    if (!mk.contains(RegExp(r'[0-9]'))) return 'Mật khẩu cần có chữ số';
    return null;
  }

  static String? hoTen(String? giaTri) {
    final ten = giaTri?.trim() ?? '';
    if (ten.isEmpty) return 'Họ và tên không được để trống';
    if (ten.length < 2) return 'Họ và tên quá ngắn';
    return null;
  }
}
