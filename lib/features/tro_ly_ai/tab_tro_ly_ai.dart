import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/hieu_ung.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../dat_lich/man_hinh_chon_benh_vien.dart';
import 'dich_vu_ai.dart';

/// Tab "Trợ lý AI": trò chuyện về triệu chứng, chụp ảnh nhận định sơ bộ,
/// nhận gợi ý chuyên khoa và đặt lịch ngay.
class TabTroLyAi extends StatefulWidget {
  final HoSo hoSo;

  /// Tăng giá trị này (từ trang chủ, nút "Chụp ảnh") để mở camera ngay.
  final int lenhChupAnh;

  const TabTroLyAi({super.key, required this.hoSo, this.lenhChupAnh = 0});

  @override
  State<TabTroLyAi> createState() => _TabTroLyAiState();
}

class _TabTroLyAiState extends State<TabTroLyAi> {
  static const _loiChao =
      'Chào bạn! Mình là trợ lý sức khoẻ của MediBook. '
      'Bạn đang gặp triệu chứng gì? Kể cho mình nghe, hoặc chụp ảnh vùng da bị tổn thương nhé.';
  static const _goiYNhanh = [
    ('🤒', 'Sốt'),
    ('😷', 'Ho, đau họng'),
    ('🤢', 'Đau bụng'),
    ('🔴', 'Nổi mẩn da'),
    ('🤕', 'Đau đầu'),
    ('🦴', 'Đau lưng'),
  ];

  final _dichVu = DichVuAi();
  final _oNhap = TextEditingController();
  final _oTapTrung = FocusNode();
  final _cuon = ScrollController();

  final List<TinNhan> _tinNhan = [];
  Uint8List? _anhChoGui;
  bool _dangChoTraLoi = false;

  @override
  void didUpdateWidget(covariant TabTroLyAi cu) {
    super.didUpdateWidget(cu);
    if (widget.lenhChupAnh != cu.lenhChupAnh) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _layAnh(ImageSource.camera),
      );
    }
  }

  @override
  void dispose() {
    _oNhap.dispose();
    _oTapTrung.dispose();
    _cuon.dispose();
    super.dispose();
  }

  // ---------------- hành động ----------------

  Future<void> _gui([String? noiDungSan]) async {
    final noiDung = (noiDungSan ?? _oNhap.text).trim();
    final anh = _anhChoGui;
    if ((noiDung.isEmpty && anh == null) || _dangChoTraLoi) return;

    setState(() {
      _tinNhan.add(TinNhan(laNguoiDung: true, noiDung: noiDung, anh: anh));
      _anhChoGui = null;
      _dangChoTraLoi = true;
      _oNhap.clear();
    });
    _cuonXuong();

    try {
      final kq = await _dichVu.hoi(_tinNhan, anh: anh);
      if (!mounted) return;
      setState(
        () => _tinNhan.add(
          TinNhan(laNguoiDung: false, noiDung: kq.traLoi, ketQua: kq),
        ),
      );
    } on LoiAi catch (e) {
      if (!mounted) return;
      setState(
        () => _tinNhan.add(
          TinNhan(laNguoiDung: false, noiDung: '⚠️ ${e.thongBao}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _dangChoTraLoi = false);
      _cuonXuong();
    }
  }

  Future<void> _layAnh(ImageSource nguon) async {
    try {
      final f = await ImagePicker().pickImage(
        source: nguon,
        maxWidth: 1024,
        imageQuality: 75,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _anhChoGui = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được camera / thư viện ảnh')),
        );
      }
    }
  }

  void _chonNguonAnh() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppTheme.mauChinh,
              ),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _layAnh(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppTheme.mauChinh,
              ),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _layAnh(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _cuocMoi() {
    setState(() {
      _tinNhan.clear();
      _anhChoGui = null;
      _oNhap.clear();
    });
  }

  /// Gộp những gì bệnh nhân đã kể để điền sẵn vào phần triệu chứng khi đặt lịch.
  String get _tomTatTrieuChung {
    final cau = _tinNhan
        .where((t) => t.laNguoiDung && t.noiDung.trim().isNotEmpty)
        .map((t) => t.noiDung.trim())
        .join('. ');
    return cau.length > 400 ? '${cau.substring(0, 400)}…' : cau;
  }

  void _datLich(GoiYKhoa khoa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManHinhChonBenhVien(
          hoSo: widget.hoSo,
          chuyenKhoaId: khoa.id,
          tenKhoa: khoa.ten,
          trieuChung: _tomTatTrieuChung,
        ),
      ),
    );
  }

  Future<void> _goi115() async {
    await launchUrl(Uri(scheme: 'tel', path: '115'));
  }

  void _cuonXuong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cuon.hasClients) {
        _cuon.animateTo(
          _cuon.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------- giao diện ----------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ThanhTieuDe(onCuocMoi: _tinNhan.isEmpty ? null : _cuocMoi),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFF4FF), AppTheme.mauNen],
              ),
            ),
            child: ListView(
              controller: _cuon,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (_tinNhan.isEmpty)
                  ...lanLuot([
                    const _ManChaoAi(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _OTinhNang(
                            icon: Icons.chat_bubble_outline_rounded,
                            tieuDe: 'Kể triệu chứng',
                            moTa: 'AI hỏi thêm để hiểu rõ',
                            onTap: () => _oTapTrung.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OTinhNang(
                            icon: Icons.photo_camera_outlined,
                            tieuDe: 'Chụp ảnh',
                            moTa: 'Vết da, vết thương…',
                            onTap: _chonNguonAnh,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Expanded(
                          child: _OTinhNang(
                            icon: Icons.medical_services_outlined,
                            tieuDe: 'Gợi ý chuyên khoa',
                            moTa: 'Biết nên khám khoa nào',
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _OTinhNang(
                            icon: Icons.near_me_outlined,
                            tieuDe: 'Bệnh viện gần',
                            moTa: 'Đặt lịch ngay sau đó',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Bạn đang gặp vấn đề gì?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.mauChuDam,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (emoji, ten) in _goiYNhanh)
                          _ChipGoiY(
                            emoji: emoji,
                            ten: ten,
                            onTap: () => _gui(ten),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _LuuY(),
                  ])
                else
                  const _BongBong(laNguoiDung: false, child: Text(_loiChao)),
                for (final t in _tinNhan)
                  XuatHien(
                    key: ObjectKey(t),
                    child: _TinNhanWidget(
                      tin: t,
                      onDatLich: _datLich,
                      onGoi115: _goi115,
                    ),
                  ),
                if (_dangChoTraLoi) const XuatHien(child: _DangGo()),
              ],
            ),
          ),
        ),
        _ONhap(
          oNhap: _oNhap,
          oTapTrung: _oTapTrung,
          anh: _anhChoGui,
          dangCho: _dangChoTraLoi,
          onBoAnh: () => setState(() => _anhChoGui = null),
          onChonAnh: _chonNguonAnh,
          onGui: () => _gui(),
        ),
      ],
    );
  }
}

// ============================ WIDGET CON ============================

/// Ảnh đại diện AI: vòng tròn gradient, có quầng sáng "thở" nhẹ.
class _AnhAi extends StatefulWidget {
  final double co;
  final bool sang; // có quầng sáng hay không

  const _AnhAi({this.co = 42, this.sang = true});

  @override
  State<_AnhAi> createState() => _AnhAiState();
}

class _AnhAiState extends State<_AnhAi> with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.sang &&
        !MediaQuery.of(context).disableAnimations &&
        !_ac.isAnimating) {
      _ac.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final co = widget.co;
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) => Container(
        width: co,
        height: co,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8), Color(0xFF7C3AED)],
          ),
          boxShadow: widget.sang
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6)
                        .withValues(alpha: 0.25 + 0.3 * _ac.value),
                    blurRadius: co * (0.3 + 0.4 * _ac.value),
                    spreadRadius: co * 0.04 * _ac.value,
                  ),
                ]
              : null,
        ),
        child: Icon(Icons.auto_awesome, color: Colors.white, size: co * 0.5),
      ),
    );
  }
}

class _ThanhTieuDe extends StatelessWidget {
  final VoidCallback? onCuocMoi;

  const _ThanhTieuDe({required this.onCuocMoi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const _AnhAi(co: 42, sang: false),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý sức khoẻ AI',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                SizedBox(height: 1),
                Text(
                  'Đang hoạt động · tư vấn ban đầu',
                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: onCuocMoi,
            icon: const Icon(Icons.edit_square),
            color: AppTheme.mauChinh,
          ),
        ],
      ),
    );
  }
}

/// Phần chào khi chưa có tin nhắn: ảnh AI phát sáng + lời chào lớn.
class _ManChaoAi extends StatelessWidget {
  const _ManChaoAi();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const _AnhAi(co: 76),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
          ).createShader(r),
          child: const Text(
            'Xin chào! Mình có thể giúp gì?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kể triệu chứng hoặc chụp ảnh, mình sẽ gợi ý chuyên khoa '
          'và bệnh viện gần bạn để đặt lịch.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.mauChuNhat,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _OTinhNang extends StatelessWidget {
  final IconData icon;
  final String tieuDe;
  final String moTa;
  final VoidCallback? onTap;

  const _OTinhNang({
    required this.icon,
    required this.tieuDe,
    required this.moTa,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.boGocThe),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.boGocThe),
            border: Border.all(color: AppTheme.mauVien),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.mauChinhNhat,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppTheme.mauChinh),
              ),
              const SizedBox(height: 10),
              Text(
                tieuDe,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.mauChuDam,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                moTa,
                style: const TextStyle(
                  color: AppTheme.mauChuNhat,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipGoiY extends StatelessWidget {
  final String emoji;
  final String ten;
  final VoidCallback onTap;

  const _ChipGoiY({
    required this.emoji,
    required this.ten,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFC7D2FE))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            '$emoji  $ten',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.mauChuDam,
            ),
          ),
        ),
      ),
    );
  }
}

class _LuuY extends StatelessWidget {
  const _LuuY();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 20,
            color: Color(0xFFC2410C),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trợ lý chỉ gợi ý chuyên khoa nên khám, không chẩn đoán hay kê thuốc. '
              'Khi khó thở, đau ngực dữ dội, co giật… hãy gọi 115 ngay.',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BongBong extends StatelessWidget {
  final bool laNguoiDung;
  final Widget child;

  const _BongBong({required this.laNguoiDung, required this.child});

  @override
  Widget build(BuildContext context) {
    final bong = Container(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width * (laNguoiDung ? 0.78 : 0.74),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: laNguoiDung ? null : Colors.white,
        gradient: laNguoiDung
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(laNguoiDung ? 20 : 6),
          bottomRight: Radius.circular(laNguoiDung ? 6 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: (laNguoiDung ? AppTheme.mauChinh : const Color(0xFF0F172A))
                .withValues(alpha: laNguoiDung ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: laNguoiDung ? Colors.white : AppTheme.mauChuDam,
          fontSize: 15,
          height: 1.45,
        ),
        child: child,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: laNguoiDung
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!laNguoiDung) ...[
            const _AnhAi(co: 28, sang: false),
            const SizedBox(width: 8),
          ],
          Flexible(child: bong),
        ],
      ),
    );
  }
}

class _TinNhanWidget extends StatelessWidget {
  final TinNhan tin;
  final ValueChanged<GoiYKhoa> onDatLich;
  final VoidCallback onGoi115;

  const _TinNhanWidget({
    required this.tin,
    required this.onDatLich,
    required this.onGoi115,
  });

  @override
  Widget build(BuildContext context) {
    final kq = tin.ketQua;
    return _BongBong(
      laNguoiDung: tin.laNguoiDung,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tin.anh != null)
            Padding(
              padding: EdgeInsets.only(bottom: tin.noiDung.isEmpty ? 0 : 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(tin.anh!, width: 220, fit: BoxFit.cover),
              ),
            ),
          if (tin.noiDung.isNotEmpty) Text(tin.noiDung),
          if (kq != null && kq.mucDo == MucDo.capCuu) ...[
            const SizedBox(height: 12),
            _TheCapCuu(onGoi115: onGoi115),
          ] else if (kq != null && kq.goiYKhoa.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final k in kq.goiYKhoa) ...[
              _TheGoiYKhoa(
                khoa: k,
                mucDo: kq.mucDo,
                onDatLich: () => onDatLich(k),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _TheGoiYKhoa extends StatelessWidget {
  final GoiYKhoa khoa;
  final MucDo mucDo;
  final VoidCallback onDatLich;

  const _TheGoiYKhoa({
    required this.khoa,
    required this.mucDo,
    required this.onDatLich,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: AppTheme.mauChinh,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GỢI Ý CHUYÊN KHOA',
                      style: TextStyle(
                        color: AppTheme.mauChinh,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      khoa.ten,
                      style: const TextStyle(
                        color: AppTheme.mauChuDam,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (mucDo == MucDo.nenKhamSom)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: const ShapeDecoration(
                    color: Color(0xFFFFEDD5),
                    shape: StadiumBorder(),
                  ),
                  child: const Text(
                    'Nên khám sớm',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (khoa.lyDo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              khoa.lyDo,
              style: const TextStyle(
                color: AppTheme.mauChuNhat,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _NutDatLich(ten: khoa.ten, onTap: onDatLich),
        ],
      ),
    );
  }
}

class _NutDatLich extends StatelessWidget {
  final String ten;
  final VoidCallback onTap;

  const _NutDatLich({required this.ten, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bo = BorderRadius.circular(AppTheme.boGoc);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: bo,
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mauChinh.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: bo,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.event_available,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Đặt lịch khoa $ten gần bạn',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ cấp cứu: nút Gọi 115 có vòng sáng nhấp nháy để thu hút chú ý.
class _TheCapCuu extends StatefulWidget {
  final VoidCallback onGoi115;

  const _TheCapCuu({required this.onGoi115});

  @override
  State<_TheCapCuu> createState() => _TheCapCuuState();
}

class _TheCapCuuState extends State<_TheCapCuu>
    with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dấu hiệu nguy hiểm — cần cấp cứu ngay',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _ac,
            builder: (context, child) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626)
                        .withValues(alpha: 0.2 + 0.35 * _ac.value),
                    blurRadius: 8 + 14 * _ac.value,
                    spreadRadius: 1 + 3 * _ac.value,
                  ),
                ],
              ),
              child: child,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onGoi115,
                icon: const Icon(Icons.call),
                label: const Text('Gọi 115'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Đang suy nghĩ": 3 chấm nhảy lên xuống lần lượt.
class _DangGo extends StatefulWidget {
  const _DangGo();

  @override
  State<_DangGo> createState() => _DangGoState();
}

class _DangGoState extends State<_DangGo> with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BongBong(
      laNguoiDung: false,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(
                  0,
                  -5 *
                      math.max(
                        0.0,
                        math.sin((_ac.value - i * 0.15) * 2 * math.pi),
                      ),
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            const Text(
              'Đang suy nghĩ…',
              style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ONhap extends StatelessWidget {
  final TextEditingController oNhap;
  final FocusNode oTapTrung;
  final Uint8List? anh;
  final bool dangCho;
  final VoidCallback onBoAnh;
  final VoidCallback onChonAnh;
  final VoidCallback onGui;

  const _ONhap({
    required this.oNhap,
    required this.oTapTrung,
    required this.anh,
    required this.dangCho,
    required this.onBoAnh,
    required this.onChonAnh,
    required this.onGui,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: anh == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                anh!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: -8,
                              top: -8,
                              child: GestureDetector(
                                onTap: onBoAnh,
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: AppTheme.mauChuDam,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Ảnh sẽ được gửi kèm tin nhắn. Bạn có thể mô tả thêm vị trí, thời gian xuất hiện.',
                            style: TextStyle(
                              color: AppTheme.mauChuNhat,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Chụp / chọn ảnh',
                        onPressed: dangCho ? null : onChonAnh,
                        icon: const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppTheme.mauChinh,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: oNhap,
                          focusNode: oTapTrung,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Mô tả triệu chứng…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(0, 14, 14, 14),
                          ),
                          onSubmitted: (_) => onGui(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút gửi sáng lên khi có chữ hoặc có ảnh
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: oNhap,
                builder: (context, v, _) {
                  final coNoiDung = v.text.trim().isNotEmpty || anh != null;
                  final bat = coNoiDung && !dangCho;
                  return AnimatedScale(
                    scale: bat ? 1 : 0.88,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: bat
                            ? const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              )
                            : null,
                        color: bat ? null : const Color(0xFFCBD5E1),
                        boxShadow: bat
                            ? [
                                BoxShadow(
                                  color: AppTheme.mauChinh.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: bat ? onGui : null,
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
