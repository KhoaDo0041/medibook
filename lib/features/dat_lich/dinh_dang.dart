// Các hàm định dạng ngày, giờ, khoảng cách theo kiểu Việt Nam.

const _thuDai = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
const _thuNgan = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String haiSo(int n) => n.toString().padLeft(2, '0');

/// "T5"
String thuNgan(DateTime d) => _thuNgan[d.weekday - 1];

/// "Thứ Năm, 09/10/2026"
String ngayDayDu(DateTime d) => '${_thuDai[d.weekday - 1]}, ${haiSo(d.day)}/${haiSo(d.month)}/${d.year}';

/// "07:15"
String gioPhut(DateTime d) => '${haiSo(d.hour)}:${haiSo(d.minute)}';

/// "850 m" hoặc "1,2 km"
String khoangCach(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

DateTime chiNgay(DateTime d) => DateTime(d.year, d.month, d.day);

bool cungNgay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
