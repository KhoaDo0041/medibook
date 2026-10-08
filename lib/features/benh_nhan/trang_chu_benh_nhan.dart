import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/anh_dai_dien.dart';
import '../../core/widgets/man_hinh_sap_co.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/tab_ho_so.dart';
import '../dat_lich/dich_vu_dat_lich.dart';
import '../dat_lich/man_hinh_chon_benh_vien.dart';
import '../dat_lich/tab_lich_hen.dart';
import 'mo_hinh.dart';
import 'widgets/o_chuc_nang.dart';
import 'widgets/the_bac_si_da_kham.dart';
import 'widgets/the_lich_kham_sap_toi.dart';
import 'widgets/the_tro_ly_ai.dart';

/// Dashboard bệnh nhân: 4 tab ở thanh dưới.
class TrangChuBenhNhan extends StatefulWidget {
  final HoSo hoSo;

  const TrangChuBenhNhan({super.key, required this.hoSo});

  @override
  State<TrangChuBenhNhan> createState() => _TrangChuBenhNhanState();
}

class _TrangChuBenhNhanState extends State<TrangChuBenhNhan> {
  int _tabDangChon = 0;

  // Tăng mỗi lần mở lại tab để tab đó tải lại dữ liệu mới nhất
  int _phienBanTrangChu = 0;
  int _phienBanLichHen = 0;
  bool _moDaQua = false;

  void _chuyenTab(int i, {bool daQua = false}) {
    setState(() {
      _tabDangChon = i;
      if (i == 0) _phienBanTrangChu++;
      if (i == 1) {
        _phienBanLichHen++;
        _moDaQua = daQua;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cacTab = [
      _TabTrangChu(
        key: ValueKey('trang_chu_$_phienBanTrangChu'),
        hoSo: widget.hoSo,
        moTab: _chuyenTab,
        moLichSu: () => _chuyenTab(1, daQua: true),
      ),
      TabLichHen(
        key: ValueKey('lich_hen_$_phienBanLichHen'),
        hoSo: widget.hoSo,
        moDaQua: _moDaQua,
        moTab: _chuyenTab,
      ),
      const ManHinhSapCo(
        icon: Icons.smart_toy_outlined,
        tieuDe: 'Trợ lý AI',
        moTa: 'Trò chuyện về triệu chứng và chụp ảnh để nhận định sơ bộ.',
      ),
      TabHoSo(hoSo: widget.hoSo),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tabDangChon, children: cacTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabDangChon,
        onDestinationSelected: _chuyenTab,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.mauChinhNhat,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.mauChinh),
              label: 'Trang chủ'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today, color: AppTheme.mauChinh),
              label: 'Lịch hẹn'),
          NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy, color: AppTheme.mauChinh),
              label: 'Trợ lý AI'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.mauChinh),
              label: 'Hồ sơ'),
        ],
      ),
    );
  }
}

// ============================ TAB TRANG CHỦ ============================

class _TabTrangChu extends StatefulWidget {
  final HoSo hoSo;
  final ValueChanged<int> moTab;
  final VoidCallback moLichSu;

  const _TabTrangChu({super.key, required this.hoSo, required this.moTab, required this.moLichSu});

  @override
  State<_TabTrangChu> createState() => _TabTrangChuState();
}

class _TabTrangChuState extends State<_TabTrangChu> {
  LichKhamSapToi? _lichSapToi;

  @override
  void initState() {
    super.initState();
    _taiLich();
  }

  Future<void> _taiLich() async {
    try {
      final lich = await DichVuDatLich().layLichSapToi();
      if (mounted) setState(() => _lichSapToi = lich);
    } on LoiDatLich {
      // Lỗi mạng: giữ nguyên thẻ hiện tại, kéo xuống để thử lại
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final hoSo = widget.hoSo;
    final moTab = widget.moTab;

    final lichSapToi = _lichSapToi;
    const List<BacSiDaKham> bacSiDaKham = []; // làm ở phần lịch sử khám

    Future<void> datLich() async {
      final kq = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => ManHinhChonBenhVien(hoSo: hoSo)),
      );
      if (kq == 'mo_ai') moTab(2);
      _taiLich();
    }

    return RefreshIndicator(
      onRefresh: _taiLich,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // 1. Lời chào + chuông + ảnh đại diện
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xin chào,',
                      style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat)),
                  Text(
                    hoSo.hoTen.isEmpty ? 'Bạn' : hoSo.hoTen,
                    style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            _NutTron(
              icon: Icons.notifications_none,
              onTap: () => baoSapCo(context, 'Thông báo'),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => moTab(3),
              child: AnhDaiDien(hoTen: hoSo.hoTen),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Lịch khám sắp tới
        TheLichKhamSapToi(
          lich: lichSapToi,
          onDatLich: datLich,
          onChiDuong: () => baoSapCo(context, 'Chỉ đường'),
        ),
        const SizedBox(height: 16),

        // 3. Trợ lý AI
        TheTroLyAi(
          onTroChuyen: () => moTab(2),
          onChupAnh: () => baoSapCo(context, 'Chụp ảnh nhận định'),
        ),
        const SizedBox(height: 16),

        // 4. Hai ô chức năng
        Row(
          children: [
            Expanded(
              child: OChucNang(
                icon: Icons.event_available_outlined,
                tieuDe: 'Đặt lịch khám',
                moTa: 'Khám nhanh',
                onTap: datLich,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OChucNang(
                icon: Icons.medical_information_outlined,
                tieuDe: 'Lịch sử khám',
                moTa: 'Xem lại hồ sơ',
                onTap: widget.moLichSu,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 5. Bác sĩ đã khám
        Row(
          children: [
            Expanded(
              child: Text('Bác sĩ bạn đã khám',
                  style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (bacSiDaKham.isNotEmpty)
              TextButton(
                onPressed: () => baoSapCo(context, 'Danh sách bác sĩ'),
                child: const Text('Xem tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (bacSiDaKham.isEmpty)
          TheTrang(
            child: Row(
              children: [
                const Icon(Icons.person_search_outlined, color: AppTheme.mauChuNhat),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sau mỗi lần khám, bác sĩ sẽ xuất hiện ở đây để bạn đặt lại nhanh.',
                    style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bacSiDaKham.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => TheBacSiDaKham(
                bacSi: bacSiDaKham[i],
                onDatLai: () => baoSapCo(context, 'Đặt lại với bác sĩ'),
              ),
            ),
          ),
        const SizedBox(height: 24),

        // 6. Lưu ý về AI
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppTheme.boGoc),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppTheme.mauChuNhat),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thông tin từ AI chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ.',
                  style: chu.bodySmall?.copyWith(
                      color: AppTheme.mauChuNhat, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _NutTron extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NutTron({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.boGoc)),
      elevation: 1,
      shadowColor: const Color(0x1A0F172A),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppTheme.mauChuDam),
        ),
      ),
    );
  }
}
