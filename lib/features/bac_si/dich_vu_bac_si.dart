import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/supabase_client.dart';
import '../../core/dinh_dang.dart';
import '../../core/don_thuoc.dart';
import 'mo_hinh.dart';

class LoiBacSi implements Exception {
  final String thongBao;
  const LoiBacSi(this.thongBao);
  @override
  String toString() => thongBao;
}

/// Mọi nghiệp vụ phía bác sĩ, gọi qua MediBook Web API.
/// API chạy truy vấn bằng quyền của bác sĩ nên RLS vẫn đảm bảo bác sĩ chỉ thấy ca và bệnh nhân của mình.
class DichVuBacSi {
  String get _uid => supabase.auth.currentUser!.id;

  /// "Khoa Nội tổng quát · Bệnh viện Nhân dân 115"
  Future<String?> layNoiCongTac() async {
    final kq = await _goi(() => Api.get('/api/bac-si/noi-cong-tac'));
    if (kq is! Map) return null;
    final khoa = kq['ten_khoa'];
    final bv = kq['ten_benh_vien'];
    if (khoa == null && bv == null) return null;
    return [if (khoa != null) 'Khoa $khoa', if (bv != null) bv].join(' · ');
  }

  /// Các ca của bác sĩ trong một ngày, kèm bệnh nhân từng ca
  /// (API tự chốt "vắng mặt" cho các ca đã hết giờ trước khi trả về).
  Future<List<CaKhamTrongNgay>> layCaTrongNgay(DateTime ngay) async {
    final caRows = await _danhSach(
      () => Api.get('/api/bac-si/ca', thamSo: {'ngay': ngayISO(ngay)}),
    );
    return [
      for (final c in caRows)
        CaKhamTrongNgay(
          id: c['id'] as int,
          ngay: DateTime.parse(c['ngay_kham'] as String),
          gioBatDau: _docGio(c['gio_bat_dau'] as String),
          gioKetThuc: _docGio(c['gio_ket_thuc'] as String),
          soToiDa: (c['so_luong_toi_da'] as int?) ?? 0,
          phong: c['so_phong'] == null
              ? null
              : c['tang'] == null
              ? 'Phòng ${c['so_phong']}'
              : 'Phòng ${c['so_phong']} · Tầng ${c['tang']}',
          danhSach: [
            for (final l in (c['luot'] as List? ?? const []))
              _docLuot(Map<String, dynamic>.from(l as Map)),
          ],
        ),
    ];
  }

  /// Những lần đã khám xong của bệnh nhân này với bác sĩ.
  Future<List<LanKhamTruoc>> layLichSuVoiBenhNhan(
    String benhNhanId, {
    int? boQuaLuotId,
  }) async {
    final rows = await _danhSach(
      () => Api.get(
        '/api/bac-si/benh-nhan/$benhNhanId/lich-su',
        thamSo: {if (boQuaLuotId != null) 'boQua': '$boQuaLuotId'},
      ),
    );
    return [
      for (final r in rows)
        LanKhamTruoc(
          ngay: DateTime.parse(r['ngay_kham'] as String),
          chanDoan: (r['chan_doan'] as String?) ?? '',
        ),
    ]..sort((a, b) => b.ngay.compareTo(a.ngay));
  }

  /// Bệnh nhân đã từng khám (hoặc vắng mặt) với bác sĩ đang đăng nhập.
  Future<List<BenhNhanCuaToi>> layBenhNhanCuaToi() async {
    final rows = await _danhSach(() => Api.get('/api/bac-si/benh-nhan'));
    if (rows.isEmpty) return [];

    final nhom = <String, List<LanKham>>{};
    final hoSo = <String, Map<String, dynamic>>{};
    for (final l in rows) {
      final id = l['benh_nhan_id'] as String;
      hoSo[id] = l;
      nhom
          .putIfAbsent(id, () => [])
          .add(
            LanKham(
              luotId: l['id'] as int,
              ngay: DateTime.parse(l['ngay_kham'] as String),
              gioBatDau: _docGio(l['gio_bat_dau'] as String),
              trangThai: docTrangThaiLuot(l['trang_thai'] as String?),
              trieuChung: (l['trieu_chung'] as String?) ?? '',
              chanDoan: l['chan_doan'] as String?,
              loiDan: l['ghi_chu_bac_si'] as String?,
            ),
          );
    }

    final ds = <BenhNhanCuaToi>[];
    nhom.forEach((id, cacLan) {
      cacLan.sort(
        (a, b) => b.ngay.add(b.gioBatDau).compareTo(a.ngay.add(a.gioBatDau)),
      );
      final h = hoSo[id];
      final ten = (h?['ho_ten'] as String?)?.trim() ?? '';
      ds.add(
        BenhNhanCuaToi(
          id: id,
          hoTen: ten.isEmpty ? 'Bệnh nhân' : ten,
          gioiTinh: h?['gioi_tinh'] as String?,
          ngaySinh: h?['ngay_sinh'] == null
              ? null
              : DateTime.tryParse(h!['ngay_sinh'] as String),
          cacLan: cacLan,
        ),
      );
    });
    // Ai khám gần đây nhất lên trước; người chỉ có lượt vắng mặt xuống cuối
    ds.sort((a, b) {
      final ta = a.lanGanNhat, tb = b.lanGanNhat;
      if (ta == null && tb == null) return a.hoTen.compareTo(b.hoTen);
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.ngay.add(tb.gioBatDau).compareTo(ta.ngay.add(ta.gioBatDau));
    });
    return ds;
  }

  Future<int> goiSoTiepTheo(int caKhamId) async {
    final kq = await _goi(
      () => Api.post('/api/bac-si/ca/$caKhamId/goi-so-tiep-theo'),
    );
    return (kq as Map)['id'] as int;
  }

  /// Chốt kết quả khám, kèm đơn thuốc (thuốc mẫu) và ngày tái khám nếu có.
  Future<void> hoanTatKham(
    int luotKhamId,
    String chanDoan,
    String loiDan, {
    List<DongDonThuoc> donThuoc = const [],
    DateTime? ngayTaiKham,
  }) => _goi(
    () => Api.post('/api/bac-si/luot-kham/$luotKhamId/hoan-tat', {
      'chanDoan': chanDoan,
      'loiDan': loiDan,
      'donThuoc': [for (final d in donThuoc) d.toJson()],
      'ngayTaiKham': ngayTaiKham == null ? null : ngayISO(ngayTaiKham),
    }),
  );

  /// Mời một bệnh nhân cụ thể vào khám (người tạm hoãn vừa đến, hoặc gọi vượt số).
  Future<void> batDauKham(int luotKhamId) =>
      _goi(() => Api.post('/api/bac-si/luot-kham/$luotKhamId/bat-dau'));

  /// Bệnh nhân chưa có mặt: tạm hoãn, vẫn giữ số đến hết ca.
  Future<void> tamHoan(int luotKhamId) =>
      _goi(() => Api.post('/api/bac-si/luot-kham/$luotKhamId/tam-hoan'));

  /// Nghe Supabase Realtime trên các ca của bác sĩ (chỉ để nhận tín hiệu có thay đổi:
  /// có người đặt / huỷ lịch, gọi số…) → gọi [khiThayDoi]; dữ liệu mới lấy lại qua Web API.
  RealtimeChannel theoDoiCacCa(void Function() khiThayDoi) {
    return supabase
        .channel('ca_bac_si_$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ca_kham',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bac_si_id',
            value: _uid,
          ),
          callback: (_) => khiThayDoi(),
        )
        .subscribe();
  }

  Future<void> boTheoDoi(RealtimeChannel kenh) => supabase.removeChannel(kenh);

  // ---------- tiện ích ----------

  static LuotKhamTrongCa _docLuot(Map<String, dynamic> l) => LuotKhamTrongCa(
    id: l['id'] as int,
    soThuTu: l['so_thu_tu'] as int,
    benhNhanId: l['benh_nhan_id'] as String,
    tenBenhNhan: ((l['ho_ten'] as String?)?.trim().isNotEmpty ?? false)
        ? l['ho_ten'] as String
        : 'Bệnh nhân',
    gioiTinh: l['gioi_tinh'] as String?,
    ngaySinh: l['ngay_sinh'] == null
        ? null
        : DateTime.tryParse(l['ngay_sinh'] as String),
    trieuChung: (l['trieu_chung'] as String?) ?? '',
    chanDoan: l['chan_doan'] as String?,
    loiDan: l['ghi_chu_bac_si'] as String?,
    ngayDat: l['ngay_tao'] == null
        ? null
        : DateTime.tryParse(l['ngay_tao'] as String)?.toLocal(),
    trangThai: docTrangThaiLuot(l['trang_thai'] as String?),
    phieuTienKham: l['phieu_tien_kham'] is Map
        ? Map<String, dynamic>.from(l['phieu_tien_kham'] as Map)
        : null,
  );

  static Duration _docGio(String s) {
    final p = s.split(':');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]));
  }

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
      debugPrint('[MediBook][API] ${e.maHttp} ${e.thongBao}');
      throw LoiBacSi(e.thongBao);
    } catch (e) {
      debugPrint('[MediBook][API] $e');
      throw const LoiBacSi('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }
}
