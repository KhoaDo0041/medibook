import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/anh_dai_dien.dart';
import '../../core/widgets/man_hinh_sap_co.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/tab_ho_so.dart';
import 'mo_hinh.dart';
import 'widgets/danh_sach_ca.dart';
import 'widgets/o_thong_ke.dart';
import 'widgets/thanh_chon_ngay.dart';
import 'widgets/the_dang_kham.dart';

/// Dashboard bác sĩ: 3 tab ở thanh dưới.
class TrangChuBacSi extends StatefulWidget {
  final HoSo hoSo;

  const TrangChuBacSi({super.key, required this.hoSo});

  @override
  State<TrangChuBacSi> createState() => _TrangChuBacSiState();
}

class _TrangChuBacSiState extends State<TrangChuBacSi> {
  int _tabDangChon = 0;

  @override
  Widget build(BuildContext context) {
    final cacTab = [
      _TabLichKham(hoSo: widget.hoSo),
      const ManHinhSapCo(
        icon: Icons.groups_outlined,
        tieuDe: 'Bệnh nhân',
        moTa: 'Danh sách bệnh nhân bạn đã khám và hồ sơ của họ sẽ hiện ở đây.',
      ),
      TabHoSo(hoSo: widget.hoSo),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tabDangChon, children: cacTab)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabDangChon,
        onDestinationSelected: (i) => setState(() => _tabDangChon = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.mauChinhNhat,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note, color: AppTheme.mauChinh),
              label: 'Lịch khám'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups, color: AppTheme.mauChinh),
              label: 'Bệnh nhân'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.mauChinh),
              label: 'Hồ sơ'),
        ],
      ),
    );
  }
}

// ============================ TAB LỊCH KHÁM ============================

class _TabLichKham extends StatefulWidget {
  final HoSo hoSo;
  const _TabLichKham({required this.hoSo});

  @override
  State<_TabLichKham> createState() => _TabLichKhamState();
}

class _TabLichKhamState extends State<_TabLichKham> {
  DateTime _ngayDangChon = DateTime.now();

  // Chưa có dữ liệu thật: sẽ lấy từ Supabase theo bác sĩ + ngày đang chọn
  List<CaKhamTrongNgay> get _cacCa => const [];

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final cacCa = _cacCa;
    final tatCaLuot = [for (final ca in cacCa) ...ca.danhSach];

    int dem(TrangThaiLuotKham t) => tatCaLuot.where((l) => l.trangThai == t).length;
    final tong = tatCaLuot.where((l) => l.trangThai != TrangThaiLuotKham.daHuy).length;
    final daKham = dem(TrangThaiLuotKham.daKham);
    final dangCho = dem(TrangThaiLuotKham.choKham);

    LuotKhamTrongCa? dangKham;
    String? caDangKham;
    for (final ca in cacCa) {
      for (final l in ca.danhSach) {
        if (l.trangThai == TrangThaiLuotKham.dangKham) {
          dangKham = l;
          caDangKham = ca.tenCa;
        }
      }
    }
    final choKham = tatCaLuot.where((l) => l.trangThai == TrangThaiLuotKham.choKham).toList()
      ..sort((a, b) => a.soThuTu.compareTo(b.soThuTu));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // 1. Lời chào
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xin chào bác sĩ,',
                      style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat)),
                  Text(widget.hoSo.hoTen.isEmpty ? 'Bác sĩ' : widget.hoSo.hoTen,
                      style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 16, color: AppTheme.mauChuNhat),
                    const SizedBox(width: 6),
                    // Khoa và bệnh viện sẽ lấy từ bảng bac_si
                    Text('Chưa gán khoa · bệnh viện',
                        style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                  ]),
                ],
              ),
            ),
            AnhDaiDien(hoTen: widget.hoSo.hoTen, banKinh: 28),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Chọn ngày trong tuần
        ThanhChonNgay(
          ngayDangChon: _ngayDangChon,
          onChon: (ngay) => setState(() => _ngayDangChon = ngay),
        ),
        const SizedBox(height: 16),

        // 3. Thống kê
        Row(
          children: [
            Expanded(
              child: OThongKe(
                  nhan: 'Tổng bệnh nhân',
                  giaTri: tong,
                  donVi: 'hồ sơ',
                  icon: Icons.groups_outlined,
                  mau: AppTheme.mauChinh),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OThongKe(
                  nhan: 'Đã khám',
                  giaTri: daKham,
                  donVi: 'xong',
                  icon: Icons.check_circle_outline,
                  mau: const Color(0xFF15803D)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OThongKe(
                  nhan: 'Đang chờ',
                  giaTri: dangCho,
                  donVi: 'lượt',
                  icon: Icons.schedule,
                  mau: const Color(0xFFB45309)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Đang khám
        TheDangKham(
          dangKham: dangKham,
          tenCa: caDangKham,
          soTiepTheo: choKham.isEmpty ? null : choKham.first.soThuTu,
          onGoiTiep: () => baoSapCo(context, 'Gọi số tiếp theo'),
          onMoBenhAn: () => baoSapCo(context, 'Nhập kết quả khám'),
        ),
        const SizedBox(height: 24),

        // 5. Danh sách theo ca
        if (cacCa.isEmpty)
          TheTrang(
            child: Row(
              children: [
                const Icon(Icons.event_busy_outlined, color: AppTheme.mauChuNhat),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Không có lịch khám trong ngày này.',
                      style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
                ),
              ],
            ),
          )
        else
          for (final ca in cacCa) ...[
            DanhSachCa(
              ca: ca,
              onChonBenhNhan: (_) => baoSapCo(context, 'Hồ sơ bệnh nhân'),
            ),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}
