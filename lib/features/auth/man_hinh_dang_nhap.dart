import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/kiem_tra_nhap.dart';
import '../bac_si/trang_chu_bac_si.dart';
import '../benh_nhan/trang_chu_benh_nhan.dart';
import 'dich_vu_tai_khoan.dart';

/// Màn hình đăng nhập, dùng chung cho bệnh nhân và bác sĩ.
class ManHinhDangNhap extends StatefulWidget {
  /// [VaiTro.benhNhan] hoặc [VaiTro.bacSi], do người dùng chọn ở màn hình chào mừng.
  final String vaiTro;

  const ManHinhDangNhap({super.key, required this.vaiTro});

  @override
  State<ManHinhDangNhap> createState() => _ManHinhDangNhapState();
}

class _ManHinhDangNhapState extends State<ManHinhDangNhap> {
  final _khoaForm = GlobalKey<FormState>();
  final _oEmail = TextEditingController();
  final _oMatKhau = TextEditingController();

  bool _anMatKhau = true;
  bool _dangXuLy = false;
  String? _loi;

  bool get _laBacSi => widget.vaiTro == VaiTro.bacSi;

  @override
  void dispose() {
    _oEmail.dispose();
    _oMatKhau.dispose();
    super.dispose();
  }

  Future<void> _dangNhap() async {
    // Kiểm tra từng ô, lỗi hiện ngay dưới ô đó
    if (!_khoaForm.currentState!.validate()) return;

    setState(() {
      _dangXuLy = true;
      _loi = null;
    });

    try {
      final hoSo = await DichVuTaiKhoan.dangNhap(
        email: _oEmail.text.trim(),
        matKhau: _oMatKhau.text,
        vaiTroMongMuon: widget.vaiTro,
      );
      if (!mounted) return;

      // Vào trang chủ và xoá các màn hình trước đó khỏi nút Back
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => hoSo.laBacSi
              ? TrangChuBacSi(hoSo: hoSo)
              : TrangChuBenhNhan(hoSo: hoSo),
        ),
        (route) => false,
      );
    } on LoiTaiKhoan catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.thongBao);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loi = 'Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _khoaForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _laBacSi ? 'Đăng nhập bác sĩ' : 'Đăng nhập',
                  style: chu.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _laBacSi
                      ? 'Dùng tài khoản do bệnh viện cấp'
                      : 'Chào mừng bạn quay lại MediBook',
                  style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _oEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: KiemTraNhap.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _oMatKhau,
                  obscureText: _anMatKhau,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _dangNhap(),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    // Nút con mắt: ẩn / hiện mật khẩu
                    suffixIcon: IconButton(
                      tooltip: _anMatKhau ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      icon: Icon(_anMatKhau
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
                    ),
                  ),
                  validator: KiemTraNhap.matKhauDangNhap,
                ),
                if (_loi != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _loi!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _dangXuLy ? null : _dangNhap,
                  child: _dangXuLy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Đăng nhập'),
                ),
                if (!_laBacSi) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Đăng ký sẽ có ở bước tiếp theo')));
                    },
                    child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
