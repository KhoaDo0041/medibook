import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/kiem_tra_nhap.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_dat_lai_mat_khau.dart';

/// Quên mật khẩu, bước 1: nhập email để nhận mã.
class ManHinhQuenMatKhau extends StatefulWidget {
  /// Email đã gõ ở màn hình đăng nhập (nếu có) để khỏi nhập lại.
  final String emailBanDau;

  const ManHinhQuenMatKhau({super.key, this.emailBanDau = ''});

  @override
  State<ManHinhQuenMatKhau> createState() => _ManHinhQuenMatKhauState();
}

class _ManHinhQuenMatKhauState extends State<ManHinhQuenMatKhau> {
  final _khoaForm = GlobalKey<FormState>();
  late final _oEmail = TextEditingController(text: widget.emailBanDau);

  bool _dangXuLy = false;
  String? _loi;

  @override
  void dispose() {
    _oEmail.dispose();
    super.dispose();
  }

  Future<void> _guiMa() async {
    if (!_khoaForm.currentState!.validate()) return;

    setState(() {
      _dangXuLy = true;
      _loi = null;
    });

    final email = _oEmail.text.trim();
    try {
      await DichVuTaiKhoan.guiMaDatLaiMatKhau(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ManHinhDatLaiMatKhau(email: email)),
      );
    } on LoiTaiKhoan catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.thongBao);
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
                  'Quên mật khẩu',
                  style: chu.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập email của tài khoản. Chúng tôi sẽ gửi mã để bạn đặt mật khẩu mới.',
                  style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _oEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onFieldSubmitted: (_) => _guiMa(),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: KiemTraNhap.email,
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
                  onPressed: _dangXuLy ? null : _guiMa,
                  child: _dangXuLy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Gửi mã'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
