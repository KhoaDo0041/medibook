import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/kiem_tra_nhap.dart';
import '../../core/widgets/hieu_ung.dart';
import '../../core/widgets/khung_xac_thuc.dart';
import '../bac_si/trang_chu_bac_si.dart';
import '../benh_nhan/trang_chu_benh_nhan.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_dang_ky.dart';
import 'man_hinh_nhap_ma.dart';
import 'man_hinh_quen_mat_khau.dart';

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

  bool _dangXuLy = false;
  bool _thanhCong = false; // đăng nhập đúng: nút chuyển dấu tích xanh
  String? _loi;
  int _lanLoi = 0; // tăng mỗi lần lỗi để form lắc

  bool get _laBacSi => widget.vaiTro == VaiTro.bacSi;

  @override
  void dispose() {
    _oEmail.dispose();
    _oMatKhau.dispose();
    super.dispose();
  }

  void _baoLoi(String? loi) {
    HapticFeedback.mediumImpact(); // rung nhẹ khi sai
    setState(() {
      _loi = loi;
      _lanLoi++;
    });
  }

  Future<void> _dangNhap() async {
    if (_dangXuLy) return;
    FocusScope.of(context).unfocus();
    // Kiểm tra từng ô, lỗi hiện ngay dưới ô đó
    if (!_khoaForm.currentState!.validate()) {
      _baoLoi(null);
      return;
    }

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

      // Hiện dấu tích xanh một nhịp rồi mới vào trang chủ
      setState(() => _thanhCong = true);
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;

      // Vào trang chủ và xoá các màn hình trước đó khỏi nút Back
      Navigator.of(context).pushAndRemoveUntil(
        trangMem(
          hoSo.laBacSi
              ? TrangChuBacSi(hoSo: hoSo)
              : TrangChuBenhNhan(hoSo: hoSo),
        ),
        (route) => false,
      );
    } on LoiTaiKhoan catch (e) {
      if (!mounted) return;
      // Đã đăng ký nhưng chưa nhập mã: gửi lại mã rồi mở màn hình nhập mã
      if (e.chuaXacNhanEmail) {
        final email = _oEmail.text.trim();
        try {
          await DichVuTaiKhoan.guiLaiMaDangKy(email);
        } catch (_) {
          // gửi lại thất bại (ví dụ vừa gửi xong): vẫn cho nhập mã cũ
        }
        if (!mounted) return;
        Navigator.of(context).push(trangMem(ManHinhNhapMa(email: email)));
        return;
      }
      _baoLoi(e.thongBao);
    } catch (_) {
      if (!mounted) return;
      _baoLoi('Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KhungXacThuc(
      tieuDe: _laBacSi ? 'Đăng nhập bác sĩ' : 'Chào mừng trở lại',
      moTa: _laBacSi
          ? 'Dùng tài khoản do bệnh viện cấp'
          : 'Đăng nhập để tiếp tục với MediBook',
      lanLac: _lanLoi,
      nhipTim: true,
      child: Form(
        key: _khoaForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            XuatHien(
              thuTu: 1,
              child: SangKhiChon(
                child: TextFormField(
                  controller: _oEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: KiemTraNhap.email,
                ),
              ),
            ),
            const SizedBox(height: 16),
            XuatHien(
              thuTu: 2,
              child: OMatKhau(
                controller: _oMatKhau,
                nhan: 'Mật khẩu',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _dangNhap(),
                validator: KiemTraNhap.matKhauDangNhap,
              ),
            ),
            XuatHien(
              thuTu: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      trangMem(
                        ManHinhQuenMatKhau(emailBanDau: _oEmail.text.trim()),
                      ),
                    );
                  },
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
            ),
            HopThongBao(noiDung: _loi),
            const SizedBox(height: 16),
            XuatHien(
              thuTu: 4,
              child: NutGradient(
                nhan: 'Đăng nhập',
                dangXuLy: _dangXuLy,
                thanhCong: _thanhCong,
                onPressed: _dangNhap,
              ),
            ),
            if (!_laBacSi) ...[
              const SizedBox(height: 16),
              XuatHien(
                thuTu: 5,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(trangMem(const ManHinhDangKy()));
                  },
                  child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
