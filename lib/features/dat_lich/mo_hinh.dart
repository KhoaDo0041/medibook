import 'dart:math';

/// Các mô hình dữ liệu cho luồng đặt lịch khám.

class BenhVien {
  final int id;
  final String ten;
  final String diaChi;
  final double? viDo;
  final double? kinhDo;

  /// Khoảng cách (km) từ vị trí người dùng; null nếu chưa có vị trí.
  final double? khoangCachKm;

  const BenhVien({
    required this.id,
    required this.ten,
    required this.diaChi,
    this.viDo,
    this.kinhDo,
    this.khoangCachKm,
  });

  factory BenhVien.tuJson(Map<String, dynamic> j) => BenhVien(
        id: j['id'] as int,
        ten: j['ten_benh_vien'] as String,
        diaChi: (j['dia_chi'] as String?) ?? '',
        viDo: (j['vi_do'] as num?)?.toDouble(),
        kinhDo: (j['kinh_do'] as num?)?.toDouble(),
      );

  BenhVien voiKhoangCach(double? km) => BenhVien(
        id: id, ten: ten, diaChi: diaChi, viDo: viDo, kinhDo: kinhDo, khoangCachKm: km);

  /// Khoảng cách đường chim bay (Haversine), đơn vị km.
  double? tinhKhoangCach(double viDoToi, double kinhDoToi) {
    if (viDo == null || kinhDo == null) return null;
    const banKinhTraiDat = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(viDo! - viDoToi);
    final dLon = rad(kinhDo! - kinhDoToi);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(viDoToi)) * cos(rad(viDo!)) * sin(dLon / 2) * sin(dLon / 2);
    return banKinhTraiDat * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

class KhoaBenhVien {
  final int id;
  final int chuyenKhoaId;
  final String ten;

  const KhoaBenhVien({required this.id, required this.chuyenKhoaId, required this.ten});
}

class BacSi {
  final String id;
  final String hoTen;
  final String hocVi;
  final int soNamKinhNghiem;
  final String gioiThieu;
  final int chuyenKhoaId;
  final String tenKhoa;
  final int benhVienId;

  const BacSi({
    required this.id,
    required this.hoTen,
    required this.hocVi,
    required this.soNamKinhNghiem,
    required this.gioiThieu,
    required this.chuyenKhoaId,
    required this.tenKhoa,
    required this.benhVienId,
  });

  /// VD: "BS.CKII Lê Minh Châu"
  String get tenDayDu => hocVi.isEmpty ? 'BS. $hoTen' : '$hocVi $hoTen';
}

class CaKham {
  final int id;
  final String bacSiId;
  final DateTime ngay; // chỉ phần ngày
  final Duration gioBatDau; // tính từ 00:00
  final Duration gioKetThuc;
  final int soToiDa;
  final int soDaDangKy;
  final String? soPhong;
  final int? tang;

  const CaKham({
    required this.id,
    required this.bacSiId,
    required this.ngay,
    required this.gioBatDau,
    required this.gioKetThuc,
    required this.soToiDa,
    required this.soDaDangKy,
    this.soPhong,
    this.tang,
  });

  factory CaKham.tuJson(Map<String, dynamic> j) => CaKham(
        id: j['id'] as int,
        bacSiId: j['bac_si_id'] as String,
        ngay: DateTime.parse(j['ngay_kham'] as String),
        gioBatDau: _docGio(j['gio_bat_dau'] as String),
        gioKetThuc: _docGio(j['gio_ket_thuc'] as String),
        soToiDa: (j['so_luong_toi_da'] as int?) ?? 0,
        soDaDangKy: (j['so_da_dang_ky'] as int?) ?? 0,
        soPhong: j['so_phong'] as String?,
        tang: j['tang'] as int?,
      );

  /// VD: "Phòng 204 · Tầng 2"; null nếu chưa có phòng.
  String? get viTriPhong {
    if (soPhong == null || soPhong!.trim().isEmpty) return null;
    return tang == null ? 'Phòng $soPhong' : 'Phòng $soPhong · Tầng $tang';
  }

  static Duration _docGio(String s) {
    final p = s.split(':');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]));
  }

  int get soConLai => max(0, soToiDa - soDaDangKy);
  bool get hetCho => soConLai == 0;
  bool get laCaSang => gioBatDau.inHours < 12;
  String get tenCa => laCaSang ? 'Ca sáng' : 'Ca chiều';

  DateTime get thoiDiemBatDau => ngay.add(gioBatDau);
  DateTime get thoiDiemKetThuc => ngay.add(gioKetThuc);
  bool get daKetThuc => DateTime.now().isAfter(thoiDiemKetThuc);
  bool get datDuoc => !hetCho && !daKetThuc;

  /// VD: "07:30 – 11:30"
  String get khungGio => '${_inGio(gioBatDau)} – ${_inGio(gioKetThuc)}';

  static String _inGio(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
}

/// Kết quả sau khi đặt thành công.
class LuotKhamMoi {
  final int id;
  final int soThuTu;
  final int caKhamId;

  const LuotKhamMoi({required this.id, required this.soThuTu, required this.caKhamId});

  factory LuotKhamMoi.tuJson(Map<String, dynamic> j) => LuotKhamMoi(
        id: j['id'] as int,
        soThuTu: j['so_thu_tu'] as int,
        caKhamId: j['ca_kham_id'] as int,
      );
}

enum TrangThaiLuot { choKham, dangKham, tamHoan, daKham, daHuy, vangMat }

TrangThaiLuot docTrangThai(String? s) => switch (s) {
      'dang_kham' => TrangThaiLuot.dangKham,
      'tam_hoan' => TrangThaiLuot.tamHoan,
      'da_kham' => TrangThaiLuot.daKham,
      'da_huy' => TrangThaiLuot.daHuy,
      'vang_mat' => TrangThaiLuot.vangMat,
      _ => TrangThaiLuot.choKham,
    };

/// Một lượt khám của bệnh nhân, kèm đủ thông tin để hiển thị tab Lịch hẹn.
class LuotKhamCuaToi {
  final int id;
  final int soThuTu;
  final TrangThaiLuot trangThai;
  final String? trieuChung;
  final String? chanDoan;
  final String? ghiChuBacSi;
  final CaKham ca;
  final BenhVien benhVien;
  final String tenKhoa;
  final String tenBacSi; // VD: "BS.CKII Lê Minh Châu"

  const LuotKhamCuaToi({
    required this.id,
    required this.soThuTu,
    required this.trangThai,
    required this.trieuChung,
    required this.chanDoan,
    required this.ghiChuBacSi,
    required this.ca,
    required this.benhVien,
    required this.tenKhoa,
    required this.tenBacSi,
  });

  /// Còn hiệu lực: chưa huỷ, chưa khám xong, ca chưa kết thúc.
  bool get sapToi =>
      (trangThai == TrangThaiLuot.choKham ||
          trangThai == TrangThaiLuot.dangKham ||
          trangThai == TrangThaiLuot.tamHoan) &&
      !ca.daKetThuc;

  /// Chỉ huỷ được khi đang chờ và ca chưa bắt đầu (giống luật trong database).
  bool get huyDuoc =>
      trangThai == TrangThaiLuot.choKham && DateTime.now().isBefore(ca.thoiDiemBatDau);

  /// Bác sĩ đánh dấu vắng mặt, hoặc ca đã qua mà không khám, không huỷ.
  bool get vangMat =>
      trangThai == TrangThaiLuot.vangMat ||
      (ca.daKetThuc && (trangThai == TrangThaiLuot.choKham || trangThai == TrangThaiLuot.tamHoan));
}
