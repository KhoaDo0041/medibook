/// Dữ liệu hiển thị trên dashboard bác sĩ.
/// Hiện chưa có dữ liệu thật (sẽ lấy từ Supabase ở nhánh feature/bac-si).

enum TrangThaiLuotKham { choKham, dangKham, daKham, daHuy }

/// Một bệnh nhân đã lấy số trong một ca.
class LuotKhamTrongCa {
  final String id;
  final int soThuTu;
  final String tenBenhNhan;
  final String trieuChung;
  final TrangThaiLuotKham trangThai;

  const LuotKhamTrongCa({
    required this.id,
    required this.soThuTu,
    required this.tenBenhNhan,
    required this.trieuChung,
    required this.trangThai,
  });
}

/// Một ca làm việc của bác sĩ trong ngày, kèm danh sách bệnh nhân.
class CaKhamTrongNgay {
  final String tenCa; // "Ca sáng"
  final String khungGio; // "07:00 – 11:00"
  final bool laCaSang;
  final int soToiDa;
  final List<LuotKhamTrongCa> danhSach;

  const CaKhamTrongNgay({
    required this.tenCa,
    required this.khungGio,
    required this.laCaSang,
    required this.soToiDa,
    required this.danhSach,
  });

  /// Số chỗ đã có người lấy (không tính lượt đã huỷ).
  int get soDaDangKy =>
      danhSach.where((l) => l.trangThai != TrangThaiLuotKham.daHuy).length;
}
