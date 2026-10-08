import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../benh_nhan/mo_hinh.dart' show LichKhamSapToi;
import 'mo_hinh.dart';

class LoiDatLich implements Exception {
  final String thongBao;
  const LoiDatLich(this.thongBao);
  @override
  String toString() => thongBao;
}

/// Mọi truy vấn của luồng đặt lịch. Màn hình chỉ gọi các hàm ở đây.
class DichVuDatLich {
  /// Danh sách bệnh viện; nếu có vị trí thì sắp theo khoảng cách gần nhất.
  Future<List<BenhVien>> layBenhVien({double? viDo, double? kinhDo}) async {
    final rows = await _chay(() => supabase.from('benh_vien').select().order('ten_benh_vien'));
    var ds = rows.map(BenhVien.tuJson).toList();
    if (viDo != null && kinhDo != null) {
      ds = ds.map((b) => b.voiKhoangCach(b.tinhKhoangCach(viDo, kinhDo))).toList()
        ..sort((a, b) => (a.khoangCachKm ?? double.infinity)
            .compareTo(b.khoangCachKm ?? double.infinity));
    }
    return ds;
  }

  /// Các khoa của một bệnh viện.
  Future<List<KhoaBenhVien>> layKhoa(int benhVienId) async {
    final rows = await _chay(() => supabase
        .from('khoa_benh_vien')
        .select('id, chuyen_khoa_id, chuyen_khoa(ten_khoa)')
        .eq('benh_vien_id', benhVienId));
    final ds = rows
        .map((r) => KhoaBenhVien(
              id: r['id'] as int,
              chuyenKhoaId: r['chuyen_khoa_id'] as int,
              ten: (r['chuyen_khoa']?['ten_khoa'] as String?) ?? 'Khoa',
            ))
        .toList()
      ..sort((a, b) => a.ten.compareTo(b.ten));
    return ds;
  }

  /// Bác sĩ đã duyệt của một bệnh viện (kèm họ tên và tên khoa).
  Future<List<BacSi>> layBacSi(int benhVienId) async {
    final rows = await _chay(() => supabase
        .from('bac_si')
        .select('id, hoc_vi, so_nam_kinh_nghiem, gioi_thieu, chuyen_khoa_id, benh_vien_id, chuyen_khoa(ten_khoa)')
        .eq('benh_vien_id', benhVienId)
        .eq('trang_thai', 'da_duyet'));
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();
    final hoSo = await _chay(() => supabase.from('ho_so').select('id, ho_ten').inFilter('id', ids));
    final tenTheoId = {for (final h in hoSo) h['id'] as String: (h['ho_ten'] as String?) ?? ''};

    return rows
        .map((r) => BacSi(
              id: r['id'] as String,
              hoTen: tenTheoId[r['id']] ?? 'Bác sĩ',
              hocVi: (r['hoc_vi'] as String?) ?? '',
              soNamKinhNghiem: (r['so_nam_kinh_nghiem'] as int?) ?? 0,
              gioiThieu: (r['gioi_thieu'] as String?) ?? '',
              chuyenKhoaId: r['chuyen_khoa_id'] as int,
              tenKhoa: (r['chuyen_khoa']?['ten_khoa'] as String?) ?? '',
              benhVienId: r['benh_vien_id'] as int,
            ))
        .toList()
      ..sort((a, b) => a.hoTen.compareTo(b.hoTen));
  }

  /// Ca khám của các bác sĩ trong khoảng ngày [tuNgay, denNgay].
  Future<List<CaKham>> layCaKham(List<String> bacSiIds, DateTime tuNgay, DateTime denNgay) async {
    if (bacSiIds.isEmpty) return [];
    final rows = await _chay(() => supabase
        .from('ca_kham')
        .select('id, bac_si_id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, so_da_dang_ky, so_phong, tang')
        .inFilter('bac_si_id', bacSiIds)
        .gte('ngay_kham', _ngay(tuNgay))
        .lte('ngay_kham', _ngay(denNgay))
        .order('ngay_kham')
        .order('gio_bat_dau'));
    return rows.map(CaKham.tuJson).toList();
  }

  /// Đặt lượt khám: database tự cấp số thứ tự (xem hàm dat_luot_kham).
  Future<LuotKhamMoi> datLuotKham(int caKhamId, {String? trieuChung}) async {
    try {
      final kq = await supabase.rpc('dat_luot_kham',
          params: {'p_ca_kham_id': caKhamId, 'p_trieu_chung': trieuChung});
      return LuotKhamMoi.tuJson(Map<String, dynamic>.from(kq as Map));
    } on PostgrestException catch (e) {
      throw LoiDatLich(_dichLoi(e));
    } catch (_) {
      throw const LoiDatLich('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }

  Future<void> huyLuotKham(int luotKhamId) async {
    try {
      await supabase.rpc('huy_luot_kham', params: {'p_luot_kham_id': luotKhamId});
    } on PostgrestException catch (e) {
      throw LoiDatLich(_dichLoi(e));
    } catch (_) {
      throw const LoiDatLich('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }

  /// Lượt khám sắp tới gần nhất của bệnh nhân đang đăng nhập (null nếu không có).
  Future<LichKhamSapToi?> layLichSapToi() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final luot = await _chay(() => supabase
        .from('luot_kham')
        .select('id, ca_kham_id, so_thu_tu')
        .eq('benh_nhan_id', uid)
        .inFilter('trang_thai', ['cho_kham', 'dang_kham']));
    if (luot.isEmpty) return null;

    final caRows = await _chay(() => supabase
        .from('ca_kham')
        .select('id, bac_si_id, khoa_benh_vien_id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, so_da_dang_ky, so_phong, tang')
        .inFilter('id', luot.map((l) => l['ca_kham_id']).toList()));
    final caTheoId = {for (final c in caRows) c['id'] as int: c};

    // Chọn lượt có ca chưa kết thúc và bắt đầu sớm nhất
    Map<String, dynamic>? luotChon;
    CaKham? caChon;
    for (final l in luot) {
      final raw = caTheoId[l['ca_kham_id']];
      if (raw == null || raw['bac_si_id'] == null) continue;
      final ca = CaKham.tuJson(raw);
      if (ca.daKetThuc) continue;
      if (caChon == null || ca.thoiDiemBatDau.isBefore(caChon.thoiDiemBatDau)) {
        caChon = ca;
        luotChon = l;
      }
    }
    if (caChon == null || luotChon == null) return null;
    final ca = caChon;

    final khoa = await _chay(() => supabase
        .from('khoa_benh_vien')
        .select('chuyen_khoa(ten_khoa), benh_vien(ten_benh_vien)')
        .eq('id', caTheoId[ca.id]!['khoa_benh_vien_id'] as int)
        .limit(1));
    final bs = await _chay(() => supabase.from('bac_si').select('hoc_vi').eq('id', ca.bacSiId).limit(1));
    final ten = await _chay(() => supabase.from('ho_so').select('ho_ten').eq('id', ca.bacSiId).limit(1));

    final hocVi = bs.isEmpty ? '' : (bs.first['hoc_vi'] as String?) ?? '';
    final hoTen = ten.isEmpty ? 'Bác sĩ' : (ten.first['ho_ten'] as String?) ?? 'Bác sĩ';

    return LichKhamSapToi(
      tenBenhVien: khoa.isEmpty ? '' : (khoa.first['benh_vien']?['ten_benh_vien'] as String?) ?? '',
      tenKhoa: khoa.isEmpty ? '' : 'Khoa ${khoa.first['chuyen_khoa']?['ten_khoa'] ?? ''}',
      tenBacSi: hocVi.isEmpty ? 'BS. $hoTen' : '$hocVi $hoTen',
      tenCa: '${ca.tenCa} ${ca.khungGio}',
      phongKham: ca.viTriPhong,
      ngayKham: ca.ngay,
      soThuTu: luotChon['so_thu_tu'] as int,
    );
  }

  /// Toàn bộ lượt khám của bệnh nhân đang đăng nhập, mới nhất trước.
  Future<List<LuotKhamCuaToi>> layLichHenCuaToi() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final luot = await _chay(() => supabase
        .from('luot_kham')
        .select('id, ca_kham_id, so_thu_tu, trang_thai, trieu_chung, chan_doan, ghi_chu_bac_si')
        .eq('benh_nhan_id', uid));
    if (luot.isEmpty) return [];

    final caRows = await _chay(() => supabase
        .from('ca_kham')
        .select('id, bac_si_id, khoa_benh_vien_id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, so_da_dang_ky, so_phong, tang')
        .inFilter('id', luot.map((l) => l['ca_kham_id']).toSet().toList()));
    final caTheoId = {for (final c in caRows) c['id'] as int: c};

    final khoaIds = caRows.map((c) => c['khoa_benh_vien_id']).toSet().toList();
    final khoaRows = await _chay(() => supabase
        .from('khoa_benh_vien')
        .select('id, chuyen_khoa(ten_khoa), benh_vien(*)')
        .inFilter('id', khoaIds));
    final khoaTheoId = {for (final k in khoaRows) k['id'] as int: k};

    final bacSiIds = caRows.map((c) => c['bac_si_id'] as String).toSet().toList();
    final bsRows = await _chay(() => supabase.from('bac_si').select('id, hoc_vi').inFilter('id', bacSiIds));
    final tenRows = await _chay(() => supabase.from('ho_so').select('id, ho_ten').inFilter('id', bacSiIds));
    final hocVi = {for (final b in bsRows) b['id'] as String: (b['hoc_vi'] as String?) ?? ''};
    final hoTen = {for (final h in tenRows) h['id'] as String: (h['ho_ten'] as String?) ?? 'Bác sĩ'};

    final ds = <LuotKhamCuaToi>[];
    for (final l in luot) {
      final caRaw = caTheoId[l['ca_kham_id']];
      if (caRaw == null) continue;
      final ca = CaKham.tuJson(caRaw);
      final khoa = khoaTheoId[caRaw['khoa_benh_vien_id']];
      final bvRaw = khoa?['benh_vien'] as Map<String, dynamic>?;
      final hv = hocVi[ca.bacSiId] ?? '';
      final ten = hoTen[ca.bacSiId] ?? 'Bác sĩ';
      ds.add(LuotKhamCuaToi(
        id: l['id'] as int,
        soThuTu: l['so_thu_tu'] as int,
        trangThai: docTrangThai(l['trang_thai'] as String?),
        trieuChung: l['trieu_chung'] as String?,
        chanDoan: l['chan_doan'] as String?,
        ghiChuBacSi: l['ghi_chu_bac_si'] as String?,
        ca: ca,
        benhVien: bvRaw == null
            ? const BenhVien(id: 0, ten: 'Bệnh viện', diaChi: '')
            : BenhVien.tuJson(bvRaw),
        tenKhoa: 'Khoa ${khoa?['chuyen_khoa']?['ten_khoa'] ?? ''}',
        tenBacSi: hv.isEmpty ? 'BS. $ten' : '$hv $ten',
      ));
    }
    ds.sort((a, b) => b.ca.thoiDiemBatDau.compareTo(a.ca.thoiDiemBatDau));
    return ds;
  }

  // ---------- tiện ích ----------

  static String _ngay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> _chay(
      Future<List<Map<String, dynamic>>> Function() truyVan) async {
    try {
      return await truyVan();
    } on PostgrestException catch (e) {
      throw LoiDatLich(_dichLoi(e));
    } catch (_) {
      throw const LoiDatLich('Không tải được dữ liệu. Kiểm tra kết nối mạng.');
    }
  }

  /// Lỗi do hàm SQL raise đã là tiếng Việt; lỗi ràng buộc thì dịch lại.
  String _dichLoi(PostgrestException e) {
    final m = e.message;
    if (m.contains('luot_kham_mot_lan_moi_ca')) return 'Bạn đã đặt ca này rồi';
    if (m.contains('luot_kham_stt_duy_nhat')) return 'Có người vừa đặt cùng lúc, vui lòng thử lại';
    if (m.contains('ca_kham_hop_le')) return 'Ca khám đã hết chỗ';
    if (RegExp(r'[À-ỹ]').hasMatch(m)) return m; // thông báo tiếng Việt từ database
    return 'Có lỗi xảy ra, vui lòng thử lại';
  }
}
