import 'package:flutter/material.dart';

import '../../core/kiem_tra_nhap.dart';
import '../../core/widgets/khung_xac_thuc.dart';
import '../../core/widgets/hieu_ung.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_nhap_ma.dart';

/// Màn hình đăng ký tài khoản bệnh nhân.
/// (Tài khoản bác sĩ do bệnh viện cấp, không đăng ký trong app.)
class ManHinhDangKy extends StatefulWidget {
  const ManHinhDangKy({super.key});

  @override
  State<ManHinhDangKy> createState() => _ManHinhDangKyState();
}

class _ManHinhDangKyState extends State<ManHinhDangKy> {
  final _khoaForm = GlobalKey<FormState>();
  final _oHoTen = TextEditingController();
  final _oEmail = TextEditingController();
  final _oMatKhau = TextEditingController();
  final _oNhapLai = TextEditingController();

  bool _anMatKhau = true;
  bool _dangXuLy = false;
  String? _loi;

  @override
  void dispose() {
    _oHoTen.dispose();
    _oEmail.dispose();
    _oMatKhau.dispose();
    _oNhapLai.dispose();
    super.dispose();
  }

  Future<void> _dangKy() async {
    if (!_khoaForm.currentState!.validate()) return;

    setState(() {
      _dangXuLy = true;
      _loi = null;
    });

    final email = _oEmail.text.trim();
    try {
      await DichVuTaiKhoan.dangKy(
        hoTen: _oHoTen.text.trim(),
        email: email,
        matKhau: _oMatKhau.text,
      );
      if (!mounted) return;
      Navigator.of(context).push(trangMem(ManHinhNhapMa(email: email)));
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

  Widget _nutConMat() {
    return IconButton(
      tooltip: _anMatKhau ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(
        _anMatKhau ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KhungXacThuc(
      tieuDe: 'Tạo tài khoản',
      moTa: 'Đăng ký để đặt lịch khám và nhận tư vấn từ AI',
      lanLac: _loi?.hashCode ?? 0,
      child: Form(
        key: _khoaForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _oHoTen,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Họ và tên',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: KiemTraNhap.hoTen,
            ),
            const SizedBox(height: 16),
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                helperText: 'Ít nhất 8 ký tự, có chữ hoa, chữ thường và số',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: _nutConMat(),
              ),
              validator: KiemTraNhap.matKhauMoi,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _oNhapLai,
              obscureText: _anMatKhau,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _dangKy(),
              decoration: InputDecoration(
                labelText: 'Nhập lại mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: _nutConMat(),
              ),
              validator: (giaTri) {
                if (giaTri == null || giaTri.isEmpty) {
                  return 'Vui lòng nhập lại mật khẩu';
                }
                if (giaTri != _oMatKhau.text)
                  return 'Mật khẩu nhập lại không khớp';
                return null;
              },
            ),
            HopThongBao(noiDung: _loi),
            const SizedBox(height: 24),
            NutGradient(
              nhan: 'Đăng ký',
              dangXuLy: _dangXuLy,
              onPressed: _dangKy,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã có tài khoản? Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
