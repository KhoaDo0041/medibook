import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/kiem_tra_nhap.dart';
import '../../core/widgets/khung_xac_thuc.dart';
import '../../core/widgets/hieu_ung.dart';
import 'dich_vu_tai_khoan.dart';
import 'dieu_huong.dart';

/// Quên mật khẩu, bước 2: nhập mã nhận qua email và mật khẩu mới.
class ManHinhDatLaiMatKhau extends StatefulWidget {
  final String email;

  const ManHinhDatLaiMatKhau({super.key, required this.email});

  @override
  State<ManHinhDatLaiMatKhau> createState() => _ManHinhDatLaiMatKhauState();
}

class _ManHinhDatLaiMatKhauState extends State<ManHinhDatLaiMatKhau> {
  static const int _giayChoGuiLai = 60;

  final _khoaForm = GlobalKey<FormState>();
  final _oMa = TextEditingController();
  final _oMatKhau = TextEditingController();
  final _oNhapLai = TextEditingController();

  bool _dangXuLy = false;
  String? _loi;
  String? _thongBao;

  Timer? _dongHo;
  int _giayConLai = _giayChoGuiLai;

  @override
  void initState() {
    super.initState();
    _batDauDemNguoc();
  }

  @override
  void dispose() {
    _dongHo?.cancel();
    _oMa.dispose();
    _oMatKhau.dispose();
    _oNhapLai.dispose();
    super.dispose();
  }

  void _batDauDemNguoc() {
    _dongHo?.cancel();
    setState(() => _giayConLai = _giayChoGuiLai);
    _dongHo = Timer.periodic(const Duration(seconds: 1), (dongHo) {
      if (!mounted) return;
      setState(() => _giayConLai--);
      if (_giayConLai <= 0) dongHo.cancel();
    });
  }

  Future<void> _datLai() async {
    if (!_khoaForm.currentState!.validate()) return;

    setState(() {
      _dangXuLy = true;
      _loi = null;
      _thongBao = null;
    });

    try {
      await DichVuTaiKhoan.datLaiMatKhau(
        email: widget.email,
        ma: _oMa.text.trim(),
        matKhauMoi: _oMatKhau.text,
      );
      if (!mounted) return;

      // Về màn hình chào mừng để đăng nhập lại bằng mật khẩu mới
      final thongBao = ScaffoldMessenger.of(context);
      Navigator.of(
        context,
      ).pushAndRemoveUntil(trangMem(manHinhChuaDangNhap()), (route) => false);
      thongBao.showSnackBar(
        const SnackBar(
          content: Text('Đã đổi mật khẩu. Vui lòng đăng nhập lại.'),
        ),
      );
    } on LoiTaiKhoan catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.thongBao);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _guiLai() async {
    setState(() {
      _loi = null;
      _thongBao = null;
    });
    try {
      await DichVuTaiKhoan.guiMaDatLaiMatKhau(widget.email);
      if (!mounted) return;
      setState(() => _thongBao = 'Đã gửi lại mã. Vui lòng kiểm tra email.');
      _batDauDemNguoc();
    } on LoiTaiKhoan catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.thongBao);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungXacThuc(
      tieuDe: 'Đặt mật khẩu mới',
      moTa:
          'Nếu ${widget.email} đã đăng ký MediBook, mã xác nhận đã được gửi đến email này.',
      icon: Icons.password_rounded,
      lanLac: _loi?.hashCode ?? 0,
      child: Form(
        key: _khoaForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _oMa,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Mã xác nhận',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
              validator: (giaTri) {
                if (giaTri == null || giaTri.trim().length < 6) {
                  return 'Vui lòng nhập đủ mã xác nhận';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            OMatKhau(
              controller: _oMatKhau,
              nhan: 'Mật khẩu mới',
              goiY: 'Ít nhất 8 ký tự, có chữ hoa, chữ thường và số',
              textInputAction: TextInputAction.next,
              validator: KiemTraNhap.matKhauMoi,
            ),
            const SizedBox(height: 16),
            OMatKhau(
              controller: _oNhapLai,
              nhan: 'Nhập lại mật khẩu mới',
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _datLai(),
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
            HopThongBao(noiDung: _thongBao, thanhCong: true),
            const SizedBox(height: 24),
            NutGradient(
              nhan: 'Đổi mật khẩu',
              dangXuLy: _dangXuLy,
              onPressed: _datLai,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _giayConLai > 0 ? null : _guiLai,
              child: Text(
                _giayConLai > 0
                    ? 'Gửi lại mã sau $_giayConLai giây'
                    : 'Gửi lại mã',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
