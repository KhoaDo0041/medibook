import 'package:flutter/material.dart';

import '../../core/kiem_tra_nhap.dart';
import '../../core/widgets/hieu_ung.dart';
import '../../core/widgets/khung_xac_thuc.dart';
import 'dich_vu_tai_khoan.dart';

/// Đổi mật khẩu khi đang đăng nhập — mở từ tab Hồ sơ (bệnh nhân và bác sĩ).
class ManHinhDoiMatKhau extends StatefulWidget {
  const ManHinhDoiMatKhau({super.key});

  @override
  State<ManHinhDoiMatKhau> createState() => _ManHinhDoiMatKhauState();
}

class _ManHinhDoiMatKhauState extends State<ManHinhDoiMatKhau> {
  final _khoaForm = GlobalKey<FormState>();
  final _oHienTai = TextEditingController();
  final _oMoi = TextEditingController();
  final _oNhapLai = TextEditingController();

  bool _dangXuLy = false;
  String? _loi;
  int _lanLoi = 0;

  @override
  void dispose() {
    _oHienTai.dispose();
    _oMoi.dispose();
    _oNhapLai.dispose();
    super.dispose();
  }

  void _baoLoi(String? loi) => setState(() {
    _loi = loi;
    _lanLoi++;
  });

  Future<void> _doiMatKhau() async {
    if (_dangXuLy) return;
    FocusScope.of(context).unfocus();
    if (!_khoaForm.currentState!.validate()) {
      _baoLoi(null);
      return;
    }
    setState(() {
      _dangXuLy = true;
      _loi = null;
    });
    try {
      await DichVuTaiKhoan.doiMatKhau(
        matKhauHienTai: _oHienTai.text,
        matKhauMoi: _oMoi.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đổi mật khẩu thành công')),
      );
      Navigator.of(context).pop();
    } on LoiTaiKhoan catch (e) {
      if (mounted) _baoLoi(e.thongBao);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungXacThuc(
      tieuDe: 'Đổi mật khẩu',
      moTa: 'Nhập mật khẩu hiện tại và mật khẩu mới của bạn',
      icon: Icons.lock_reset_rounded,
      lanLac: _lanLoi,
      child: Form(
        key: _khoaForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            XuatHien(
              thuTu: 1,
              child: OMatKhau(
                controller: _oHienTai,
                nhan: 'Mật khẩu hiện tại',
                textInputAction: TextInputAction.next,
                validator: KiemTraNhap.matKhauDangNhap,
              ),
            ),
            const SizedBox(height: 16),
            XuatHien(
              thuTu: 2,
              child: OMatKhau(
                controller: _oMoi,
                nhan: 'Mật khẩu mới',
                goiY: 'Ít nhất 8 ký tự, có chữ hoa, chữ thường và số',
                icon: Icons.key_rounded,
                textInputAction: TextInputAction.next,
                validator: KiemTraNhap.matKhauMoi,
              ),
            ),
            const SizedBox(height: 16),
            XuatHien(
              thuTu: 3,
              child: OMatKhau(
                controller: _oNhapLai,
                nhan: 'Nhập lại mật khẩu mới',
                icon: Icons.key_rounded,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _doiMatKhau(),
                validator: (giaTri) {
                  if (giaTri == null || giaTri.isEmpty) {
                    return 'Vui lòng nhập lại mật khẩu mới';
                  }
                  if (giaTri != _oMoi.text)
                    return 'Mật khẩu nhập lại không khớp';
                  return null;
                },
              ),
            ),
            HopThongBao(noiDung: _loi),
            const SizedBox(height: 24),
            XuatHien(
              thuTu: 4,
              child: NutGradient(
                nhan: 'Đổi mật khẩu',
                dangXuLy: _dangXuLy,
                onPressed: _doiMatKhau,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
