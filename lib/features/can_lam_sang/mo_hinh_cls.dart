/// Dữ liệu cận lâm sàng (X-quang, xét nghiệm…) lấy từ Web API.
library;

/// "120.000đ"
String tienVnd(int dong) {
  final s = dong.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${b.toString()}đ';
}

/// Một dịch vụ trong danh mục (bảng dich_vu_cls).
class DichVuClsMuc {
  final int id;
  final String ten;
  final int gia;
  final int thoiGianPhut;
  final bool canNhinAn;
  final String mucDich;
  final String chuanBi;
  final String maKhu;
  final String tenKhu;
  final int tang;

  const DichVuClsMuc({
    required this.id,
    required this.ten,
    required this.gia,
    required this.thoiGianPhut,
    required this.canNhinAn,
    required this.mucDich,
    required this.chuanBi,
    required this.maKhu,
    required this.tenKhu,
    required this.tang,
  });

  factory DichVuClsMuc.tuJson(Map<String, dynamic> j) => DichVuClsMuc(
    id: j['id'] as int,
    ten: j['ten'] as String,
    gia: (j['gia'] as num?)?.toInt() ?? 0,
    thoiGianPhut: (j['thoi_gian_phut'] as num?)?.toInt() ?? 15,
    canNhinAn: (j['can_nhin_an'] as bool?) ?? false,
    mucDich: (j['muc_dich'] as String?) ?? '',
    chuanBi: (j['chuan_bi'] as String?) ?? '',
    maKhu: j['ma_khu'] as String,
    tenKhu: (j['ten_khu'] as String?) ?? '',
    tang: (j['tang'] as num?)?.toInt() ?? 1,
  );
}

/// Một chỉ định của lượt khám (bảng chi_dinh_cls, đã ghép dịch vụ và khu).
class ChiDinhCls {
  final int id;
  final int thuTu;
  final bool xong;
  final String? ketQua;
  final DichVuClsMuc dichVu;

  const ChiDinhCls({
    required this.id,
    required this.thuTu,
    required this.xong,
    required this.dichVu,
    this.ketQua,
  });

  factory ChiDinhCls.tuJson(Map<String, dynamic> j) => ChiDinhCls(
    id: (j['id'] as num).toInt(),
    thuTu: (j['thu_tu'] as num).toInt(),
    xong: j['trang_thai'] == 'xong',
    ketQua: j['ket_qua'] as String?,
    dichVu: DichVuClsMuc.tuJson({
      ...j,
      'id': j['dich_vu_id'],
      'tang': j['tang_khu'],
    }),
  );
}

/// Lộ trình cận lâm sàng của một lượt khám.
class LoTrinhCls {
  final int luotKhamId;
  final String trangThai; // lam_cls, cho_doc_kq, dang_kham, da_kham…
  final int soThuTu;
  final bool daThanhToan;
  final String? soPhong;
  final int? tang;
  final String tenBacSi;
  final int tongTien;
  final List<ChiDinhCls> chiDinh;

  const LoTrinhCls({
    required this.luotKhamId,
    required this.trangThai,
    required this.soThuTu,
    required this.daThanhToan,
    required this.tenBacSi,
    required this.tongTien,
    required this.chiDinh,
    this.soPhong,
    this.tang,
  });

  factory LoTrinhCls.tuJson(Map<String, dynamic> j) => LoTrinhCls(
    luotKhamId: j['luot_kham_id'] as int,
    trangThai: (j['trang_thai'] as String?) ?? '',
    soThuTu: (j['so_thu_tu'] as num?)?.toInt() ?? 0,
    daThanhToan: (j['da_thanh_toan_cls'] as bool?) ?? false,
    soPhong: j['so_phong'] as String?,
    tang: (j['tang'] as num?)?.toInt(),
    tenBacSi: (j['ten_bac_si'] as String?) ?? 'Bác sĩ',
    tongTien: (j['tong_tien'] as num?)?.toInt() ?? 0,
    chiDinh: [
      for (final c in (j['chi_dinh'] as List? ?? const []))
        ChiDinhCls.tuJson(Map<String, dynamic>.from(c as Map)),
    ],
  );

  bool get coChiDinh => chiDinh.isNotEmpty;
  int get soXong => chiDinh.where((c) => c.xong).length;
  bool get xongHet => chiDinh.every((c) => c.xong);

  /// Chỉ định cần làm tiếp theo (null khi đã làm hết).
  ChiDinhCls? get tiepTheo {
    for (final c in chiDinh) {
      if (!c.xong) return c;
    }
    return null;
  }

  /// Nút của phòng khám trên sơ đồ (khu phòng khám theo tầng).
  String get maPhongKham => 'PK_${(tang ?? 1).clamp(1, 4)}';
  String get tenPhong => soPhong == null ? 'phòng khám' : 'Phòng $soPhong';
}
