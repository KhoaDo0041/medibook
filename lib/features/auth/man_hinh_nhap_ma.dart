import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/khung_xac_thuc.dart';
import '../../core/widgets/hieu_ung.dart';
import '../benh_nhan/trang_chu_benh_nhan.dart';
import 'dich_vu_tai_khoan.dart';

/// Màn hình nhập mã xác nhận được gửi đến email sau khi đăng ký.
class ManHinhNhapMa extends StatefulWidget {
  final String email;

  const ManHinhNhapMa({super.key, required this.email});

  @override
  State<ManHinhNhapMa> createState() => _ManHinhNhapMaState();
}

class _ManHinhNhapMaState extends State<ManHinhNhapMa> {
  static const int _giayChoGuiLai = 60;

  final _oMa = TextEditingController();
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
    super.dispose();
  }

  // Phải chờ 60 giây mới được bấm "Gửi lại mã"
  void _batDauDemNguoc() {
    _dongHo?.cancel();
    setState(() => _giayConLai = _giayChoGuiLai);
    _dongHo = Timer.periodic(const Duration(seconds: 1), (dongHo) {
      if (!mounted) return;
      setState(() => _giayConLai--);
      if (_giayConLai <= 0) dongHo.cancel();
    });
  }

  Future<void> _xacNhan() async {
    final ma = _oMa.text.trim();
    if (ma.length < 6) {
      setState(() => _loi = 'Vui lòng nhập đủ mã xác nhận');
      return;
    }

    setState(() {
      _dangXuLy = true;
      _loi = null;
      _thongBao = null;
    });

    try {
      final hoSo = await DichVuTaiKhoan.xacNhanMaDangKy(
        email: widget.email,
        ma: ma,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        trangMem(TrangChuBenhNhan(hoSo: hoSo)),
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

  Future<void> _guiLai() async {
    setState(() {
      _loi = null;
      _thongBao = null;
    });
    try {
      await DichVuTaiKhoan.guiLaiMaDangKy(widget.email);
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
    final chu = Theme.of(context).textTheme;
    return KhungXacThuc(
      tieuDe: 'Nhập mã xác nhận',
      moTa: 'Chúng tôi đã gửi mã xác nhận đến\n${widget.email}',
      icon: Icons.mark_email_read_rounded,
      lanLac: _loi?.hashCode ?? 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _oMa,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
            ),
            onSubmitted: (_) => _xacNhan(),
          ),
          HopThongBao(noiDung: _loi),
          HopThongBao(noiDung: _thongBao, thanhCong: true),
          const SizedBox(height: 24),
          NutGradient(
            nhan: 'Xác nhận',
            dangXuLy: _dangXuLy,
            onPressed: _xacNhan,
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
          const SizedBox(height: 8),
          Text(
            'Không thấy email? Hãy kiểm tra mục Thư rác.',
            textAlign: TextAlign.center,
            style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
          ),
        ],
      ),
    );
  }
}
