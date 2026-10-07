import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/kiem_tra_nhap.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_chao_mung.dart';

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

  bool _anMatKhau = true;
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ManHinhChaoMung()),
        (route) => false,
      );
      thongBao.showSnackBar(const SnackBar(
        content: Text('Đã đổi mật khẩu. Vui lòng đăng nhập lại.'),
      ));
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

  Widget _nutConMat() {
    return IconButton(
      tooltip: _anMatKhau ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(_anMatKhau
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
    );
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
                  'Đặt mật khẩu mới',
                  style: chu.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nếu ${widget.email} đã đăng ký MediBook, mã xác nhận đã được gửi đến email này.',
                  style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat),
                ),
                const SizedBox(height: 32),
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
                TextFormField(
                  controller: _oMatKhau,
                  obscureText: _anMatKhau,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
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
                  onFieldSubmitted: (_) => _datLai(),
                  decoration: InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: _nutConMat(),
                  ),
                  validator: (giaTri) {
                    if (giaTri == null || giaTri.isEmpty) {
                      return 'Vui lòng nhập lại mật khẩu';
                    }
                    if (giaTri != _oMatKhau.text) return 'Mật khẩu nhập lại không khớp';
                    return null;
                  },
                ),
                if (_loi != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _loi!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_thongBao != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _thongBao!,
                    style: const TextStyle(color: Color(0xFF15803D)),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _dangXuLy ? null : _datLai,
                  child: _dangXuLy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Đổi mật khẩu'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _giayConLai > 0 ? null : _guiLai,
                  child: Text(_giayConLai > 0
                      ? 'Gửi lại mã sau $_giayConLai giây'
                      : 'Gửi lại mã'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
