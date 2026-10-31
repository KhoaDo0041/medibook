import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/supabase_client.dart';
import '../../core/dinh_dang.dart';
import 'mo_hinh.dart';

class LoiDatLich implements Exception {
  final String thongBao;
  const LoiDatLich(this.thongBao);
  @override
  String toString() => thongBao;
}

/// Mọi truy vấn của luồng đặt lịch, gọi qua MediBook Web API. Màn hình chỉ gọi các hàm ở đây.
class DichVuDatLich {
  /// Danh sách bệnh viện; nếu có vị trí thì sắp theo khoảng cách gần nhất.
  Future<List<BenhVien>> layBenhVien({double? viDo, double? kinhDo}) async {
    final rows = await _danhSach(() => Api.get('/api/benh-vien'));
    var ds = rows.map(BenhVien.tuJson).toList();
    if (viDo != null && kinhDo != null) {
      ds =
          ds
              .map((b) => b.voiKhoangCach(b.tinhKhoangCach(viDo, kinhDo)))
              .toList()
            ..sort(
              (a, b) => (a.khoangCachKm ?? double.infinity).compareTo(
                b.khoangCachKm ?? double.infinity,
              ),
            );
    }
    return ds;
  }

  /// Id các bệnh viện có chuyên khoa này (dùng khi AI gợi ý khoa).
  Future<Set<int>> layBenhVienCoKhoa(int chuyenKhoaId) async {
    final kq = await _goi(() => Api.get('/api/chuyen-khoa/$chuyenKhoaId/benh-vien'));
    return (kq as List).map((e) => e as int).toSet();
  }

  /// Các khoa của một bệnh viện.
  Future<List<KhoaBenhVien>> layKhoa(int benhVienId) async {
    final rows = await _danhSach(() => Api.get('/api/benh-vien/$benhVienId/khoa'));
    return rows
        .map(
          (r) => KhoaBenhVien(
            id: r['id'] as int,
            chuyenKhoaId: r['chuyen_khoa_id'] as int,
            ten: (r['ten_khoa'] as String?) ?? 'Khoa',
          ),
        )
        .toList()
      ..sort((a, b) => a.ten.compareTo(b.ten));
  }

  /// Bác sĩ đang làm việc của một bệnh viện (kèm họ tên và tên khoa).
  Future<List<BacSi>> layBacSi(int benhVienId) async {
    final rows = await _danhSach(() => Api.get('/api/benh-vien/$benhVienId/bac-si'));
    return rows
        .map(
          (r) => BacSi(
            id: r['id'] as String,
            hoTen: (r['ho_ten'] as String?) ?? 'Bác sĩ',
            hocVi: (r['hoc_vi'] as String?) ?? '',
            soNamKinhNghiem: (r['so_nam_kinh_nghiem'] as int?) ?? 0,
            gioiThieu: (r['gioi_thieu'] as String?) ?? '',
            chuyenKhoaId: r['chuyen_khoa_id'] as int,
            tenKhoa: (r['ten_khoa'] as String?) ?? '',
            benhVienId: r['benh_vien_id'] as int,
          ),
        )
        .toList()
      ..sort((a, b) => a.hoTen.compareTo(b.hoTen));
  }

  /// Ca khám của các bác sĩ trong khoảng ngày [tuNgay, denNgay].
  Future<List<CaKham>> layCaKham(
    List<String> bacSiIds,
    DateTime tuNgay,
    DateTime denNgay,
  ) async {
    if (bacSiIds.isEmpty) return [];
    final rows = await _danhSach(
      () => Api.get(
        '/api/ca-kham',
        thamSo: {
          'bacSiIds': bacSiIds.join(','),
          'tuNgay': ngayISO(tuNgay),
          'denNgay': ngayISO(denNgay),
        },
      ),
    );
    return rows.map(CaKham.tuJson).toList();
  }

  /// Đặt lượt khám: database tự cấp số thứ tự (xem hàm dat_luot_kham).
  Future<LuotKhamMoi> datLuotKham(
    int caKhamId, {
    String? trieuChung,
    Map<String, dynamic>? phieuTienKham,
  }) async {
    final kq = await _goi(
      () => Api.post('/api/luot-kham', {
        'caKhamId': caKhamId,
        'trieuChung': trieuChung,
        'phieuTienKham': phieuTienKham,
      }),
    );
    return LuotKhamMoi.tuJson(Map<String, dynamic>.from(kq as Map));
  }

  Future<void> huyLuotKham(int luotKhamId) =>
      _goi(() => Api.post('/api/luot-kham/$luotKhamId/huy'));

  /// Toàn bộ lượt khám của bệnh nhân đang đăng nhập, mới nhất trước
  /// (API đã ghép sẵn ca khám, bệnh viện, khoa, bác sĩ).
  Future<List<LuotKhamCuaToi>> layLichHenCuaToi() async {
    if (supabase.auth.currentUser == null) return [];
    final rows = await _danhSach(() => Api.get('/api/luot-kham/cua-toi'));

    final ds = <LuotKhamCuaToi>[];
    for (final l in rows) {
      final ca = CaKham.tuJson(Map<String, dynamic>.from(l['ca'] as Map));
      final bvRaw = l['benh_vien'] as Map?;
      final hv = (l['hoc_vi'] as String?) ?? '';
      final ten = (l['ten_bac_si'] as String?) ?? 'Bác sĩ';
      ds.add(
        LuotKhamCuaToi(
          id: l['id'] as int,
          soThuTu: l['so_thu_tu'] as int,
          trangThai: docTrangThai(l['trang_thai'] as String?),
          trieuChung: l['trieu_chung'] as String?,
          chanDoan: l['chan_doan'] as String?,
          ghiChuBacSi: l['ghi_chu_bac_si'] as String?,
          lyDoHuy: l['ly_do_huy'] as String?,
          ca: ca,
          benhVien: bvRaw == null
              ? const BenhVien(id: 0, ten: 'Bệnh viện', diaChi: '')
              : BenhVien.tuJson(Map<String, dynamic>.from(bvRaw)),
          tenKhoa: 'Khoa ${l['ten_khoa'] ?? ''}',
          tenBacSi: hv.isEmpty ? 'BS. $ten' : '$hv $ten',
          ngayTaiKham: l['ngay_tai_kham'] == null
              ? null
              : DateTime.tryParse(l['ngay_tai_kham'] as String),
          phieuTienKham: l['phieu_tien_kham'] is Map
              ? Map<String, dynamic>.from(l['phieu_tien_kham'] as Map)
              : null,
        ),
      );
    }
    ds.sort((a, b) => b.ca.thoiDiemBatDau.compareTo(a.ca.thoiDiemBatDau));
    return ds;
  }

  // ---------- Theo dõi hàng chờ theo thời gian thực ----------

  /// Số đang khám và số người còn chờ trước lượt của mình.
  Future<HangCho?> layHangCho(int luotKhamId) async {
    final kq = await _goi(() => Api.get('/api/luot-kham/$luotKhamId/hang-cho'));
    if (kq is! Map) return null;
    return HangCho.tuJson(Map<String, dynamic>.from(kq));
  }

  /// Nghe Supabase Realtime (chỉ để nhận TÍN HIỆU có thay đổi): mỗi khi dòng ca khám
  /// đổi (bác sĩ gọi số, hoàn tất, tạm hoãn, có người huỷ…) thì gọi [khiThayDoi];
  /// dữ liệu mới vẫn lấy qua Web API.
  RealtimeChannel theoDoiCaKham(int caKhamId, void Function() khiThayDoi) {
    return supabase
        .channel('hang_cho_$caKhamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ca_kham',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: caKhamId,
          ),
          callback: (_) => khiThayDoi(),
        )
        .subscribe();
  }

  Future<void> boTheoDoi(RealtimeChannel kenh) => supabase.removeChannel(kenh);

  // ---------- tiện ích ----------

  Future<List<Map<String, dynamic>>> _danhSach(
    Future<dynamic> Function() goi,
  ) async {
    final kq = await _goi(goi);
    return [for (final r in (kq as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
  }

  Future<dynamic> _goi(Future<dynamic> Function() goi) async {
    try {
      return await goi();
    } on LoiApi catch (e) {
      throw LoiDatLich(e.thongBao);
    } catch (_) {
      throw const LoiDatLich('Không tải được dữ liệu. Kiểm tra kết nối mạng.');
    }
  }
}
