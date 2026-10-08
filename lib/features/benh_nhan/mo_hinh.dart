// Dữ liệu hiển thị trên dashboard bệnh nhân.
// Hiện chưa có dữ liệu thật (sẽ lấy từ Supabase ở nhánh feature/dat-lich).

class LichKhamSapToi {
  final String tenBenhVien;
  final String tenKhoa;
  final String tenBacSi;
  final String tenCa; // VD: "Ca sáng 7:00–11:00"
  final DateTime ngayKham;
  final int soThuTu;
  final String? phongKham; // VD: "Phòng 204 · Tầng 2"

  const LichKhamSapToi({
    required this.tenBenhVien,
    required this.tenKhoa,
    required this.tenBacSi,
    required this.tenCa,
    required this.ngayKham,
    required this.soThuTu,
    this.phongKham,
  });
}

class BacSiDaKham {
  final String id;
  final String hoTen;
  final String tenKhoa;
  final String tenBenhVien;

  const BacSiDaKham({
    required this.id,
    required this.hoTen,
    required this.tenKhoa,
    required this.tenBenhVien,
  });
}
