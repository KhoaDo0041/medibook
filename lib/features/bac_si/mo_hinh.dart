import '../../core/dinh_dang.dart';

// Dữ liệu hiển thị phía bác sĩ (lấy từ Supabase qua DichVuBacSi).

enum TrangThaiLuotKham { choKham, dangKham, tamHoan, daKham, daHuy, vangMat }

TrangThaiLuotKham docTrangThaiLuot(String? s) => switch (s) {
  'dang_kham' => TrangThaiLuotKham.dangKham,
  'tam_hoan' => TrangThaiLuotKham.tamHoan,
  'da_kham' => TrangThaiLuotKham.daKham,
  'da_huy' => TrangThaiLuotKham.daHuy,
  'vang_mat' => TrangThaiLuotKham.vangMat,
  _ => TrangThaiLuotKham.choKham,
};

/// Một bệnh nhân đã lấy số trong một ca.
class LuotKhamTrongCa {
  final int id;
  final int soThuTu;
  final String benhNhanId;
  final String tenBenhNhan;
  final String? gioiTinh;
  final DateTime? ngaySinh;
  final String trieuChung;
  final String? chanDoan;
  final String? loiDan;
  final DateTime? ngayDat;
  final TrangThaiLuotKham trangThai;

  /// Phiếu tiền khám AI tổng hợp (null nếu bệnh nhân không gửi).
  final Map<String, dynamic>? phieuTienKham;

  const LuotKhamTrongCa({
    required this.id,
    required this.soThuTu,
    required this.benhNhanId,
    required this.tenBenhNhan,
    required this.trieuChung,
    required this.trangThai,
    this.gioiTinh,
    this.ngaySinh,
    this.chanDoan,
    this.loiDan,
    this.ngayDat,
    this.phieuTienKham,
  });

  /// AI đánh giá nên khám sớm (hoặc có dấu hiệu nguy hiểm).
  bool get nenKhamSom {
    final m = phieuTienKham?['muc_do'];
    return m == 'nen_kham_som' || m == 'cap_cuu';
  }

  /// Một dòng mô tả cho danh sách: ưu tiên phiếu tiền khám, không có thì lời bệnh nhân ghi.
  String get tomTatKhai {
    final tc = (phieuTienKham?['trieu_chung_chinh'] as String?)?.trim() ?? '';
    final bd = (phieuTienKham?['bat_dau_tu'] as String?)?.trim() ?? '';
    if (tc.isEmpty) return trieuChung;
    return bd.isEmpty ? tc : '$tc · $bd';
  }

  int? get tuoi {
    final ns = ngaySinh;
    if (ns == null) return null;
    final nay = DateTime.now();
    var t = nay.year - ns.year;
    if (nay.month < ns.month || (nay.month == ns.month && nay.day < ns.day))
      t--;
    return t;
  }
}

/// Một ca làm việc của bác sĩ trong ngày, kèm danh sách bệnh nhân.
class CaKhamTrongNgay {
  final int id;
  final DateTime ngay;
  final Duration gioBatDau;
  final Duration gioKetThuc;
  final String? phong; // "Phòng 204 · Tầng 2"
  final int soToiDa;
  final List<LuotKhamTrongCa> danhSach;

  const CaKhamTrongNgay({
    required this.id,
    required this.ngay,
    required this.gioBatDau,
    required this.gioKetThuc,
    required this.soToiDa,
    required this.danhSach,
    this.phong,
  });

  bool get laCaSang => gioBatDau.inHours < 12;
  String get tenCa => laCaSang ? 'Ca sáng' : 'Ca chiều';
  String get khungGio =>
      '${gioCuaKhoang(gioBatDau)} – ${gioCuaKhoang(gioKetThuc)}';

  bool get laHomNay {
    final n = DateTime.now();
    return n.year == ngay.year && n.month == ngay.month && n.day == ngay.day;
  }

  bool get daKetThuc => DateTime.now().isAfter(ngay.add(gioKetThuc));

  /// Hôm nay và chưa hết giờ: được gọi số, mời vào khám, tạm hoãn.
  bool get dangDienRa => laHomNay && !daKetThuc;

  /// Số chỗ đã có người lấy (không tính lượt đã huỷ).
  int get soDaDangKy =>
      danhSach.where((l) => l.trangThai != TrangThaiLuotKham.daHuy).length;

  List<LuotKhamTrongCa> get dangCho =>
      danhSach.where((l) => l.trangThai == TrangThaiLuotKham.choKham).toList()
        ..sort((a, b) => a.soThuTu.compareTo(b.soThuTu));

  LuotKhamTrongCa? get dangKham {
    for (final l in danhSach) {
      if (l.trangThai == TrangThaiLuotKham.dangKham) return l;
    }
    return null;
  }
}

/// Lần khám trước của cùng bệnh nhân với bác sĩ này.
class LanKhamTruoc {
  final DateTime ngay;
  final String chanDoan;

  const LanKhamTruoc({required this.ngay, required this.chanDoan});
}

/// Một lần đến khám (đã khám hoặc vắng mặt) của bệnh nhân với bác sĩ này.
class LanKham {
  final int luotId;
  final DateTime ngay;
  final Duration gioBatDau;
  final TrangThaiLuotKham trangThai;
  final String trieuChung;
  final String? chanDoan;
  final String? loiDan;

  const LanKham({
    required this.luotId,
    required this.ngay,
    required this.gioBatDau,
    required this.trangThai,
    required this.trieuChung,
    this.chanDoan,
    this.loiDan,
  });

  String get tenCa => gioBatDau.inHours < 12 ? 'Ca sáng' : 'Ca chiều';
  bool get daKham => trangThai == TrangThaiLuotKham.daKham;
}

/// Một bệnh nhân bác sĩ đã từng khám, kèm toàn bộ các lần khám (mới nhất trước).
class BenhNhanCuaToi {
  final String id;
  final String hoTen;
  final String? gioiTinh;
  final DateTime? ngaySinh;
  final List<LanKham> cacLan;

  const BenhNhanCuaToi({
    required this.id,
    required this.hoTen,
    required this.cacLan,
    this.gioiTinh,
    this.ngaySinh,
  });

  List<LanKham> get cacLanDaKham => cacLan.where((l) => l.daKham).toList();
  int get soLanKham => cacLanDaKham.length;
  LanKham? get lanGanNhat => cacLanDaKham.isEmpty ? null : cacLanDaKham.first;
  LanKham? get lanDauTien => cacLanDaKham.isEmpty ? null : cacLanDaKham.last;

  int? get tuoi {
    final ns = ngaySinh;
    if (ns == null) return null;
    final nay = DateTime.now();
    var t = nay.year - ns.year;
    if (nay.month < ns.month || (nay.month == ns.month && nay.day < ns.day))
      t--;
    return t;
  }
}
