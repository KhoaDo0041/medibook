import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
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
        MaterialPageRoute(builder: (_) => TrangChuBenhNhan(hoSo: hoSo)),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  size: 64, color: AppTheme.mauChinh),
              const SizedBox(height: 16),
              Text(
                'Nhập mã xác nhận',
                textAlign: TextAlign.center,
                style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Chúng tôi đã gửi mã xác nhận đến\n${widget.email}',
                textAlign: TextAlign.center,
                style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _oMa,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 8,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                ),
                onSubmitted: (_) => _xacNhan(),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 12),
                Text(
                  _loi!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_thongBao != null) ...[
                const SizedBox(height: 12),
                Text(
                  _thongBao!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF15803D)),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _dangXuLy ? null : _xacNhan,
                child: _dangXuLy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Xác nhận'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _giayConLai > 0 ? null : _guiLai,
                child: Text(_giayConLai > 0
                    ? 'Gửi lại mã sau $_giayConLai giây'
                    : 'Gửi lại mã'),
              ),
              const SizedBox(height: 8),
              Text(
                'Không thấy email? Hãy kiểm tra mục Thư rác.',
                textAlign: TextAlign.center,
                style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
