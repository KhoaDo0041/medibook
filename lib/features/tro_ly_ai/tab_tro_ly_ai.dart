import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
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
  static const _loiChao = 'Chào bạn! Mình là trợ lý sức khoẻ của MediBook. '
      'Bạn đang gặp triệu chứng gì? Kể cho mình nghe, hoặc chụp ảnh vùng da bị tổn thương nhé.';
  static const _goiYNhanh = ['Sốt', 'Ho, đau họng', 'Đau bụng', 'Nổi mẩn da', 'Đau đầu', 'Đau lưng'];

  final _dichVu = DichVuAi();
  final _oNhap = TextEditingController();
  final _cuon = ScrollController();

  final List<TinNhan> _tinNhan = [];
  Uint8List? _anhChoGui;
  bool _dangChoTraLoi = false;

  @override
  void didUpdateWidget(covariant TabTroLyAi cu) {
    super.didUpdateWidget(cu);
    if (widget.lenhChupAnh != cu.lenhChupAnh) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _layAnh(ImageSource.camera));
    }
  }

  @override
  void dispose() {
    _oNhap.dispose();
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
      setState(() => _tinNhan.add(TinNhan(laNguoiDung: false, noiDung: kq.traLoi, ketQua: kq)));
    } on LoiAi catch (e) {
      if (!mounted) return;
      setState(() => _tinNhan.add(TinNhan(laNguoiDung: false, noiDung: '⚠️ ${e.thongBao}')));
    } finally {
      if (mounted) setState(() => _dangChoTraLoi = false);
      _cuonXuong();
    }
  }

  Future<void> _layAnh(ImageSource nguon) async {
    try {
      final f = await ImagePicker().pickImage(source: nguon, maxWidth: 1024, imageQuality: 75);
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.mauChinh),
            title: const Text('Chụp ảnh'),
            onTap: () {
              Navigator.pop(context);
              _layAnh(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppTheme.mauChinh),
            title: const Text('Chọn từ thư viện'),
            onTap: () {
              Navigator.pop(context);
              _layAnh(ImageSource.gallery);
            },
          ),
        ]),
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
        _cuon.animateTo(_cuon.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
          child: ListView(
            controller: _cuon,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const _BongBong(laNguoiDung: false, child: Text(_loiChao)),
              if (_tinNhan.isEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in _goiYNhanh)
                      ActionChip(
                        label: Text(g),
                        onPressed: () => _gui(g),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.mauVien),
                        shape: const StadiumBorder(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const _LuuY(),
              ],
              for (final t in _tinNhan) _TinNhanWidget(tin: t, onDatLich: _datLich, onGoi115: _goi115),
              if (_dangChoTraLoi) const _DangGo(),
            ],
          ),
        ),
        _ONhap(
          oNhap: _oNhap,
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

class _ThanhTieuDe extends StatelessWidget {
  final VoidCallback? onCuocMoi;

  const _ThanhTieuDe({required this.onCuocMoi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.mauVien)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF2563EB), AppTheme.mauChinh]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trợ lý sức khoẻ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text('Tư vấn ban đầu · không thay thế bác sĩ',
                    style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            onPressed: onCuocMoi,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppTheme.mauChuNhat),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trợ lý chỉ gợi ý chuyên khoa nên khám, không chẩn đoán hay kê thuốc. '
              'Khi khó thở, đau ngực dữ dội, co giật… hãy gọi 115 ngay.',
              style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 13),
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
    return Align(
      alignment: laNguoiDung ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: laNguoiDung ? AppTheme.mauChinh : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(laNguoiDung ? 18 : 4),
            bottomRight: Radius.circular(laNguoiDung ? 4 : 18),
          ),
          boxShadow: laNguoiDung
              ? null
              : [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: laNguoiDung ? Colors.white : AppTheme.mauChuDam, fontSize: 15, height: 1.4),
          child: child,
        ),
      ),
    );
  }
}

class _TinNhanWidget extends StatelessWidget {
  final TinNhan tin;
  final ValueChanged<GoiYKhoa> onDatLich;
  final VoidCallback onGoi115;

  const _TinNhanWidget({required this.tin, required this.onDatLich, required this.onGoi115});

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
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(tin.anh!, width: 200, fit: BoxFit.cover),
              ),
            ),
          if (tin.noiDung.isNotEmpty) Text(tin.noiDung),
          if (kq != null && kq.mucDo == MucDo.capCuu) ...[
            const SizedBox(height: 10),
            _TheCapCuu(onGoi115: onGoi115),
          ] else if (kq != null && kq.goiYKhoa.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final k in kq.goiYKhoa) ...[
              _TheGoiYKhoa(khoa: k, mucDo: kq.mucDo, onDatLich: () => onDatLich(k)),
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

  const _TheGoiYKhoa({required this.khoa, required this.mucDo, required this.onDatLich});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.mauChinhNhat,
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('GỢI Ý CHUYÊN KHOA',
                style: TextStyle(color: AppTheme.mauChinh, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const Spacer(),
            if (mucDo == MucDo.nenKhamSom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const ShapeDecoration(color: Color(0xFFFFEDD5), shape: StadiumBorder()),
                child: const Text('Nên khám sớm',
                    style: TextStyle(color: Color(0xFFC2410C), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 4),
          Text(khoa.ten,
              style: const TextStyle(color: AppTheme.mauChuDam, fontSize: 18, fontWeight: FontWeight.w800)),
          if (khoa.lyDo.isNotEmpty)
            Text(khoa.lyDo, style: const TextStyle(color: AppTheme.mauChuNhat, fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDatLich,
              icon: const Icon(Icons.event_available, size: 18),
              label: Text('Đặt lịch khoa ${khoa.ten} gần bạn'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TheCapCuu extends StatelessWidget {
  final VoidCallback onGoi115;

  const _TheCapCuu({required this.onGoi115});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
            SizedBox(width: 6),
            Expanded(
              child: Text('Dấu hiệu nguy hiểm — cần cấp cứu ngay',
                  style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGoi115,
              icon: const Icon(Icons.call),
              label: const Text('Gọi 115'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangGo extends StatefulWidget {
  const _DangGo();

  @override
  State<_DangGo> createState() => _DangGoState();
}

class _DangGoState extends State<_DangGo> with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

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
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.mauChinh.withValues(
                    alpha: ((_ac.value * 3 - i) % 3) < 1 ? 1 : 0.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ONhap extends StatelessWidget {
  final TextEditingController oNhap;
  final Uint8List? anh;
  final bool dangCho;
  final VoidCallback onBoAnh;
  final VoidCallback onChonAnh;
  final VoidCallback onGui;

  const _ONhap({
    required this.oNhap,
    required this.anh,
    required this.dangCho,
    required this.onBoAnh,
    required this.onChonAnh,
    required this.onGui,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.mauVien)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (anh != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(anh!, width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: GestureDetector(
                        onTap: onBoAnh,
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.mauChuDam,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Ảnh sẽ được gửi kèm tin nhắn. Bạn có thể mô tả thêm vị trí, thời gian xuất hiện.',
                      style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 12)),
                ),
              ]),
            ),
          Row(
            children: [
              IconButton(
                onPressed: dangCho ? null : onChonAnh,
                icon: const Icon(Icons.photo_camera_outlined, color: AppTheme.mauChinh),
              ),
              Expanded(
                child: TextField(
                  controller: oNhap,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Mô tả triệu chứng…',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => onGui(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: dangCho ? null : onGui,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: AppTheme.mauChinh, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
