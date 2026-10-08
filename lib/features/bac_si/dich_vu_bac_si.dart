import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'mo_hinh.dart';

class LoiBacSi implements Exception {
  final String thongBao;
  const LoiBacSi(this.thongBao);
  @override
  String toString() => thongBao;
}

/// Mọi truy vấn phía bác sĩ. RLS đảm bảo bác sĩ chỉ thấy ca và bệnh nhân của mình.
class DichVuBacSi {
  String get _uid => supabase.auth.currentUser!.id;

  /// "Khoa Nội tổng quát · Bệnh viện Nhân dân 115"
  Future<String?> layNoiCongTac() async {
    final rows = await _chay(() => supabase
        .from('bac_si')
        .select('chuyen_khoa(ten_khoa), benh_vien(ten_benh_vien)')
        .eq('id', _uid)
        .limit(1));
    if (rows.isEmpty) return null;
    final khoa = rows.first['chuyen_khoa']?['ten_khoa'];
    final bv = rows.first['benh_vien']?['ten_benh_vien'];
    if (khoa == null && bv == null) return null;
    return [if (khoa != null) 'Khoa $khoa', if (bv != null) bv].join(' · ');
  }

  /// Các ngày (trong khoảng) bác sĩ có ca — để đánh dấu trên thanh chọn ngày.
  Future<Set<DateTime>> layNgayCoCa(DateTime tu, DateTime den) async {
    final rows = await _chay(() => supabase
        .from('ca_kham')
        .select('ngay_kham')
        .eq('bac_si_id', _uid)
        .gte('ngay_kham', _ngay(tu))
        .lte('ngay_kham', _ngay(den)));
    return rows.map((r) => DateTime.parse(r['ngay_kham'] as String)).toSet();
  }

  /// Các ca của bác sĩ trong một ngày, kèm bệnh nhân từng ca.
  Future<List<CaKhamTrongNgay>> layCaTrongNgay(DateTime ngay) async {
    // Ca nào đã hết giờ thì người còn chờ / tạm hoãn chuyển thành vắng mặt
    try {
      await supabase.rpc('chot_ca_qua_han');
    } catch (_) {}

    final caRows = await _chay(() => supabase
        .from('ca_kham')
        .select('id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, so_phong, tang')
        .eq('bac_si_id', _uid)
        .eq('ngay_kham', _ngay(ngay))
        .order('gio_bat_dau'));
    if (caRows.isEmpty) return [];

    final luotRows = await _chay(() => supabase
        .from('luot_kham')
        .select('id, ca_kham_id, benh_nhan_id, so_thu_tu, trang_thai, trieu_chung, chan_doan, ghi_chu_bac_si, ngay_tao')
        .inFilter('ca_kham_id', caRows.map((c) => c['id']).toList()));

    final bnIds = luotRows.map((l) => l['benh_nhan_id'] as String).toSet().toList();
    final hoSoRows = bnIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _chay(() => supabase
            .from('ho_so')
            .select('id, ho_ten, gioi_tinh, ngay_sinh')
            .inFilter('id', bnIds));
    final hoSo = {for (final h in hoSoRows) h['id'] as String: h};

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
            for (final l in luotRows.where((l) => l['ca_kham_id'] == c['id']))
              _docLuot(l, hoSo[l['benh_nhan_id']]),
          ],
        ),
    ];
  }

  /// Những lần đã khám xong của bệnh nhân này với bác sĩ (RLS chỉ trả về ca của bác sĩ).
  Future<List<LanKhamTruoc>> layLichSuVoiBenhNhan(String benhNhanId, {int? boQuaLuotId}) async {
    final rows = await _chay(() => supabase
        .from('luot_kham')
        .select('id, ca_kham_id, chan_doan')
        .eq('benh_nhan_id', benhNhanId)
        .eq('trang_thai', 'da_kham'));
    final cacLuot = rows.where((r) => r['id'] != boQuaLuotId).toList();
    if (cacLuot.isEmpty) return [];

    final caRows = await _chay(() => supabase
        .from('ca_kham')
        .select('id, ngay_kham')
        .inFilter('id', cacLuot.map((r) => r['ca_kham_id']).toSet().toList()));
    final ngayTheoCa = {for (final c in caRows) c['id'] as int: DateTime.parse(c['ngay_kham'] as String)};

    return [
      for (final r in cacLuot)
        if (ngayTheoCa[r['ca_kham_id']] != null)
          LanKhamTruoc(ngay: ngayTheoCa[r['ca_kham_id']]!, chanDoan: (r['chan_doan'] as String?) ?? ''),
    ]..sort((a, b) => b.ngay.compareTo(a.ngay));
  }

  Future<int> goiSoTiepTheo(int caKhamId) async {
    final kq = await _rpc('goi_so_tiep_theo', {'p_ca_kham_id': caKhamId});
    return (kq as Map)['id'] as int;
  }

  Future<void> hoanTatKham(int luotKhamId, String chanDoan, String loiDan) =>
      _rpc('hoan_tat_kham', {'p_luot_kham_id': luotKhamId, 'p_chan_doan': chanDoan, 'p_loi_dan': loiDan});

  /// Mời một bệnh nhân cụ thể vào khám (người tạm hoãn vừa đến, hoặc gọi vượt số).
  Future<void> batDauKham(int luotKhamId) => _rpc('bat_dau_kham', {'p_luot_kham_id': luotKhamId});

  /// Bệnh nhân chưa có mặt: tạm hoãn, vẫn giữ số đến hết ca.
  Future<void> tamHoan(int luotKhamId) => _rpc('tam_hoan_kham', {'p_luot_kham_id': luotKhamId});

  // ---------- tiện ích ----------

  static LuotKhamTrongCa _docLuot(Map<String, dynamic> l, Map<String, dynamic>? hs) => LuotKhamTrongCa(
        id: l['id'] as int,
        soThuTu: l['so_thu_tu'] as int,
        benhNhanId: l['benh_nhan_id'] as String,
        tenBenhNhan: ((hs?['ho_ten'] as String?)?.trim().isNotEmpty ?? false)
            ? hs!['ho_ten'] as String
            : 'Bệnh nhân',
        gioiTinh: hs?['gioi_tinh'] as String?,
        ngaySinh: hs?['ngay_sinh'] == null ? null : DateTime.tryParse(hs!['ngay_sinh'] as String),
        trieuChung: (l['trieu_chung'] as String?) ?? '',
        chanDoan: l['chan_doan'] as String?,
        loiDan: l['ghi_chu_bac_si'] as String?,
        ngayDat: l['ngay_tao'] == null ? null : DateTime.tryParse(l['ngay_tao'] as String)?.toLocal(),
        trangThai: docTrangThaiLuot(l['trang_thai'] as String?),
      );

  static Duration _docGio(String s) {
    final p = s.split(':');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]));
  }

  static String _ngay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> _chay(Future<List<Map<String, dynamic>>> Function() truyVan) async {
    try {
      return await truyVan();
    } on PostgrestException catch (e) {
      throw LoiBacSi(_dichLoi(e));
    } catch (_) {
      throw const LoiBacSi('Không tải được dữ liệu. Kiểm tra kết nối mạng.');
    }
  }

  Future<dynamic> _rpc(String ham, Map<String, dynamic> thamSo) async {
    try {
      return await supabase.rpc(ham, params: thamSo);
    } on PostgrestException catch (e) {
      throw LoiBacSi(_dichLoi(e));
    } catch (_) {
      throw const LoiBacSi('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }

  String _dichLoi(PostgrestException e) {
    if (RegExp(r'[À-ỹ]').hasMatch(e.message)) return e.message; // thông báo tiếng Việt từ hàm SQL
    return 'Có lỗi xảy ra, vui lòng thử lại';
  }
}
