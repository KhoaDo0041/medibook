import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../../core/app_theme.dart';
import '../../../core/dinh_dang.dart';
import '../../../core/widgets/the_trang.dart';
import '../../../core/widgets/tuong_tac.dart';
import '../../dat_lich/dich_vu_dat_lich.dart';
import '../../dat_lich/mo_hinh.dart';

/// Thẻ "Hàng chờ trực tiếp": chỉ hiện trong ngày khám.
/// Nghe Supabase Realtime trên dòng ca khám; mỗi lần bác sĩ gọi số / hoàn tất /
/// tạm hoãn thì tải lại số đang khám và số người còn chờ trước mình.
class TheHangCho extends StatefulWidget {
  final LuotKhamCuaToi luot;

  /// Gọi khi lượt khám không còn chờ nữa (đã khám xong, vắng mặt…) để trang chủ tải lại.
  final VoidCallback khiKetThuc;

  const TheHangCho({super.key, required this.luot, required this.khiKetThuc});

  /// Chỉ hiện thẻ khi hôm nay là ngày khám và ca chưa kết thúc.
  static bool nenHien(LuotKhamCuaToi l) =>
      cungNgay(l.ca.ngay, DateTime.now()) && !l.ca.daKetThuc;

  @override
  State<TheHangCho> createState() => _TheHangChoState();
}

class _TheHangChoState extends State<TheHangCho> {
  final _dv = DichVuDatLich();
  HangCho? _hc;
  bool _loiMang = false;
  RealtimeChannel? _kenh;
  Timer? _dongHoDuPhong;

  @override
  void initState() {
    super.initState();
    _tai();
    _kenh = _dv.theoDoiCaKham(widget.luot.ca.id, _tai);
    // Dự phòng khi mất kết nối Realtime: 30 giây tự hỏi lại một lần
    _dongHoDuPhong = Timer.periodic(const Duration(seconds: 30), (_) => _tai());
  }

  @override
  void dispose() {
    _dongHoDuPhong?.cancel();
    final k = _kenh;
    if (k != null) _dv.boTheoDoi(k);
    super.dispose();
  }

  Future<void> _tai() async {
    try {
      final moi = await _dv.layHangCho(widget.luot.id);
      if (!mounted || moi == null) return;
      final cu = _hc;
      // Vừa tới lượt: rung để bệnh nhân chú ý
      if (moi.trangThai == TrangThaiLuot.dangKham &&
          cu?.trangThai != TrangThaiLuot.dangKham) {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _hc = moi;
        _loiMang = false;
      });
      if (moi.trangThai != TrangThaiLuot.choKham &&
          moi.trangThai != TrangThaiLuot.dangKham &&
          moi.trangThai != TrangThaiLuot.tamHoan) {
        widget.khiKetThuc();
      }
    } on LoiDatLich {
      if (mounted) setState(() => _loiMang = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = _hc;
    return TheTrang(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _ChamNhapNhay(),
              const SizedBox(width: 8),
              Text(
                'Hàng chờ trực tiếp',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_loiMang)
                const Tooltip(
                  message: 'Mất kết nối, đang thử lại',
                  child: Icon(Icons.wifi_off, size: 18, color: AppTheme.mauCam),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: hc == null
                ? const SizedBox(
                    key: ValueKey('cho'),
                    height: 72,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : KeyedSubtree(
                    key: ValueKey('${hc.trangThai}-${hc.soDangKham}-${hc.soNguoiTruoc}'),
                    child: _noiDung(context, hc),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _noiDung(BuildContext context, HangCho hc) {
    final chu = Theme.of(context).textTheme;
    final phong = widget.luot.ca.viTriPhong;

    if (hc.trangThai == TrangThaiLuot.dangKham) {
      return _Bang(
        mau: const Color(0xFF16A34A),
        icon: Icons.campaign_outlined,
        tieuDe: 'Đến lượt bạn!',
        noiDung: phong == null
            ? 'Mời bạn vào phòng khám.'
            : 'Mời bạn vào $phong.',
      );
    }
    if (hc.trangThai == TrangThaiLuot.tamHoan) {
      return const _Bang(
        mau: AppTheme.mauCam,
        icon: Icons.pause_circle_outline,
        tieuDe: 'Lượt của bạn đang tạm hoãn',
        noiDung:
            'Bác sĩ đã gọi nhưng bạn chưa có mặt. Hãy đến phòng khám và báo với '
            'bác sĩ để được khám trong ca.',
      );
    }

    final dang = hc.soDangKham;
    final String loiNhan;
    if (hc.soNguoiTruoc == 0) {
      loiNhan = 'Bạn là người tiếp theo, hãy có mặt trước phòng khám.';
    } else {
      loiNhan = 'Còn ${hc.soNguoiTruoc} người trước bạn.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _OSo(
                nhan: 'ĐANG KHÁM',
                so: dang,
                mauNen: AppTheme.mauChinhNhat,
                mauChu: AppTheme.mauChinh,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OSo(
                nhan: 'SỐ CỦA BẠN',
                so: hc.soThuTu,
                mauNen: AppTheme.mauChinh,
                mauChu: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          dang == null && hc.soNguoiTruoc > 0
              ? 'Bác sĩ chưa gọi số. $loiNhan'
              : loiNhan,
          style: chu.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: hc.soNguoiTruoc <= 1 ? AppTheme.mauCam : AppTheme.mauChuDam,
          ),
        ),
      ],
    );
  }
}

/// Ô hiển thị một con số lớn kèm nhãn.
class _OSo extends StatelessWidget {
  final String nhan;
  final int? so;
  final Color mauNen;
  final Color mauChu;

  const _OSo({
    required this.nhan,
    required this.so,
    required this.mauNen,
    required this.mauChu,
  });

  @override
  Widget build(BuildContext context) {
    final kieu = TextStyle(
      color: mauChu,
      fontSize: 30,
      fontWeight: FontWeight.w800,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: mauNen,
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: Column(
        children: [
          Text(
            nhan,
            style: TextStyle(
              color: mauChu.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          so == null ? Text('--', style: kieu) : SoChay(so: so!, style: kieu),
        ],
      ),
    );
  }
}

/// Khung thông báo màu (đến lượt / tạm hoãn).
class _Bang extends StatelessWidget {
  final Color mau;
  final IconData icon;
  final String tieuDe;
  final String noiDung;

  const _Bang({
    required this.mau,
    required this.icon,
    required this.tieuDe,
    required this.noiDung,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        border: Border.all(color: mau.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: mau, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: chu.titleMedium?.copyWith(
                    color: mau,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(noiDung, style: chu.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chấm đỏ nhấp nháy báo "đang trực tiếp".
class _ChamNhapNhay extends StatefulWidget {
  const _ChamNhapNhay();

  @override
  State<_ChamNhapNhay> createState() => _ChamNhapNhayState();
}

class _ChamNhapNhayState extends State<_ChamNhapNhay>
    with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_ac),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFDC2626),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
