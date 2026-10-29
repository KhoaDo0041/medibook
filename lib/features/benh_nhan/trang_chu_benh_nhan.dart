import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/anh_dai_dien.dart';
import '../../core/widgets/the_trang.dart';
import '../../core/widgets/hieu_ung.dart';
import '../../core/widgets/tuong_tac.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/tab_ho_so.dart';
import '../dat_lich/chi_duong.dart';
import '../dat_lich/dich_vu_dat_lich.dart';
import '../dat_lich/man_hinh_chon_bac_si.dart';
import '../dat_lich/mo_hinh.dart' show LuotKhamCuaToi, TrangThaiLuot;
import '../dat_lich/man_hinh_chon_benh_vien.dart';
import '../dat_lich/tab_lich_hen.dart';
import '../tro_ly_ai/tab_tro_ly_ai.dart';
import 'mo_hinh.dart';
import 'widgets/o_chuc_nang.dart';
import 'widgets/the_bac_si_da_kham.dart';
import 'widgets/the_hang_cho.dart';
import '../thuoc/nhac_nho.dart';
import '../thuoc/the_thuoc_hom_nay.dart';
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
  int _lenhChupAnh = 0; // tăng để tab Trợ lý AI mở camera ngay

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
        chupAnh: () => setState(() {
          _tabDangChon = 2;
          _lenhChupAnh++;
        }),
      ),
      TabLichHen(
        key: ValueKey('lich_hen_$_phienBanLichHen'),
        hoSo: widget.hoSo,
        moDaQua: _moDaQua,
        moTab: _chuyenTab,
      ),
      TabTroLyAi(hoSo: widget.hoSo, lenhChupAnh: _lenhChupAnh),
      TabHoSo(hoSo: widget.hoSo),
    ];

    return Scaffold(
      body: SafeArea(
        child: ChuyenTabMem(index: _tabDangChon, children: cacTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabDangChon,
        onDestinationSelected: _chuyenTab,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.mauChinhNhat,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: IconNay(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: IconNay(Icons.calendar_today),
            label: 'Lịch hẹn',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: IconNay(Icons.smart_toy),
            label: 'Trợ lý AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: IconNay(Icons.person),
            label: 'Hồ sơ',
          ),
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
  final VoidCallback chupAnh;

  const _TabTrangChu({
    super.key,
    required this.hoSo,
    required this.moTab,
    required this.moLichSu,
    required this.chupAnh,
  });

  @override
  State<_TabTrangChu> createState() => _TabTrangChuState();
}

class _TabTrangChuState extends State<_TabTrangChu> {
  LuotKhamCuaToi? _luotSapToi;
  List<LuotKhamCuaToi> _daKham = []; // mỗi bác sĩ một lượt gần nhất

  @override
  void initState() {
    super.initState();
    _taiLich();
    NhacNho.lamMoi(); // đặt tiếp nhắc uống thuốc cho các ngày sắp tới
  }

  Future<void> _taiLich() async {
    try {
      final ds = await DichVuDatLich().layLichHenCuaToi(); // mới nhất trước
      final sapToi = ds.where((l) => l.sapToi).toList()
        ..sort((a, b) => a.ca.thoiDiemBatDau.compareTo(b.ca.thoiDiemBatDau));
      final daGap = <String>{};
      final daKham = [
        for (final l in ds)
          if (l.trangThai == TrangThaiLuot.daKham && daGap.add(l.ca.bacSiId)) l,
      ];
      if (mounted) {
        setState(() {
          _luotSapToi = sapToi.isEmpty ? null : sapToi.first;
          _daKham = daKham;
        });
      }
    } on LoiDatLich {
      // Lỗi mạng: giữ nguyên thẻ hiện tại, kéo xuống để thử lại
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final hoSo = widget.hoSo;
    final moTab = widget.moTab;

    final luot = _luotSapToi;
    final lichSapToi = luot == null
        ? null
        : LichKhamSapToi(
            tenBenhVien: luot.benhVien.ten,
            tenKhoa: luot.tenKhoa,
            tenBacSi: luot.tenBacSi,
            tenCa: '${luot.ca.tenCa} ${luot.ca.khungGio}',
            ngayKham: luot.ca.ngay,
            soThuTu: luot.soThuTu,
            phongKham: luot.ca.viTriPhong,
          );
    final bacSiDaKham = [
      for (final l in _daKham)
        BacSiDaKham(
          id: l.ca.bacSiId,
          hoTen: l.tenBacSi,
          tenKhoa: l.tenKhoa,
          tenBenhVien: l.benhVien.ten,
        ),
    ];

    Future<void> datLai(int i) async {
      final l = _daKham[i];
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManHinhChonBacSi(
            hoSo: hoSo,
            benhVien: l.benhVien,
            bacSiIdBanDau: l.ca.bacSiId,
          ),
        ),
      );
      _taiLich();
    }

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
        children: lanLuot([
          // 1. Lời chào + chuông + ảnh đại diện
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loiChao(),
                      style: chu.bodyLarge?.copyWith(
                        color: AppTheme.mauChuNhat,
                      ),
                    ),
                    Text(
                      hoSo.hoTen.isEmpty ? 'Bạn' : hoSo.hoTen,
                      style: chu.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
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
            onChiDuong: () {
              if (luot != null) moChiDuong(context, luot.benhVien);
            },
          ),
          const SizedBox(height: 16),

          // 2b. Hàng chờ trực tiếp (chỉ trong ngày khám)
          if (luot != null && TheHangCho.nenHien(luot)) ...[
            TheHangCho(
              key: ValueKey(luot.id),
              luot: luot,
              khiKetThuc: _taiLich,
            ),
            const SizedBox(height: 16),
          ],

          // 2c. Uống thuốc hôm nay (chỉ hiện khi có lịch)
          const TheThuocHomNay(),

          // 3. Trợ lý AI
          TheTroLyAi(onTroChuyen: () => moTab(2), onChupAnh: widget.chupAnh),
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
                child: Text(
                  'Bác sĩ bạn đã khám',
                  style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (bacSiDaKham.isNotEmpty)
                TextButton(
                  onPressed: widget.moLichSu,
                  child: const Text('Xem lịch sử'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (bacSiDaKham.isEmpty)
            TheTrang(
              child: Row(
                children: [
                  const Icon(
                    Icons.person_search_outlined,
                    color: AppTheme.mauChuNhat,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sau mỗi lần khám, bác sĩ sẽ xuất hiện ở đây để bạn đặt lại nhanh.',
                      style: chu.bodyMedium?.copyWith(
                        color: AppTheme.mauChuNhat,
                      ),
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
                  onDatLai: () => datLai(i),
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
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppTheme.mauChuNhat,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thông tin từ AI chỉ mang tính tham khảo, không thay thế chẩn đoán của bác sĩ.',
                    style: chu.bodySmall?.copyWith(
                      color: AppTheme.mauChuNhat,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Lời chào đổi theo giờ trong ngày.
String _loiChao() {
  final gio = DateTime.now().hour;
  if (gio < 11) return 'Chào buổi sáng ☀️';
  if (gio < 14) return 'Chào buổi trưa 🌤️';
  if (gio < 18) return 'Chào buổi chiều 🌇';
  return 'Chào buổi tối 🌙';
}
