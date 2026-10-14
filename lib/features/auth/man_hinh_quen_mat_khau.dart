import 'package:flutter/material.dart';

import '../../core/kiem_tra_nhap.dart';
import '../../core/widgets/khung_xac_thuc.dart';
import '../../core/widgets/hieu_ung.dart';
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
      Navigator.of(context).push(trangMem(ManHinhDatLaiMatKhau(email: email)));
    } on LoiTaiKhoan catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.thongBao);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungXacThuc(
      tieuDe: 'Quên mật khẩu',
      moTa: 'Nhập email của tài khoản, chúng tôi sẽ gửi mã để bạn đặt mật khẩu mới.',
      icon: Icons.lock_reset_rounded,
      lanLac: _loi?.hashCode ?? 0,
      child: Form(
        key: _khoaForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            HopThongBao(noiDung: _loi),
            const SizedBox(height: 24),
            NutGradient(nhan: 'Gửi mã', dangXuLy: _dangXuLy, onPressed: _guiMa),
          ],
        ),
      ),
    );
  }
}
