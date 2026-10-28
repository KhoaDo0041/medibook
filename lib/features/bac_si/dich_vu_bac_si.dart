import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/dinh_dang.dart';
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
    final rows = await _chay(
      () => supabase
          .from('bac_si')
          .select('chuyen_khoa(ten_khoa), benh_vien(ten_benh_vien)')
          .eq('id', _uid)
          .limit(1),
    );
    if (rows.isEmpty) return null;
    final khoa = rows.first['chuyen_khoa']?['ten_khoa'];
    final bv = rows.first['benh_vien']?['ten_benh_vien'];
    if (khoa == null && bv == null) return null;
    return [if (khoa != null) 'Khoa $khoa', if (bv != null) bv].join(' · ');
  }

  /// Các ca của bác sĩ trong một ngày, kèm bệnh nhân từng ca.
  Future<List<CaKhamTrongNgay>> layCaTrongNgay(DateTime ngay) async {
    // Ca nào đã hết giờ thì người còn chờ / tạm hoãn chuyển thành vắng mặt
    try {
      await supabase.rpc('chot_ca_qua_han');
    } catch (_) {}

    final caRows = await _chay(
      () => supabase
          .from('ca_kham')
          .select(
            'id, ngay_kham, gio_bat_dau, gio_ket_thuc, so_luong_toi_da, so_phong, tang',
          )
          .eq('bac_si_id', _uid)
          .eq('ngay_kham', ngayISO(ngay))
          .order('gio_bat_dau'),
    );
    if (caRows.isEmpty) return [];

    final luotRows = await _chay(
      () => supabase
          .from('luot_kham')
          .select(
            'id, ca_kham_id, benh_nhan_id, so_thu_tu, trang_thai, trieu_chung, chan_doan, ghi_chu_bac_si, ngay_tao',
          )
          .inFilter('ca_kham_id', caRows.map((c) => c['id']).toList()),
    );

    final bnIds = luotRows
        .map((l) => l['benh_nhan_id'] as String)
        .toSet()
        .toList();
    final hoSoRows = bnIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _chay(
            () => supabase
                .from('ho_so')
                .select('id, ho_ten, gioi_tinh, ngay_sinh')
                .inFilter('id', bnIds),
          );
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
  Future<List<LanKhamTruoc>> layLichSuVoiBenhNhan(
    String benhNhanId, {
    int? boQuaLuotId,
  }) async {
    final rows = await _chay(
      () => supabase
          .from('luot_kham')
          .select('id, ca_kham_id, chan_doan')
          .eq('benh_nhan_id', benhNhanId)
          .eq('trang_thai', 'da_kham'),
    );
    final cacLuot = rows.where((r) => r['id'] != boQuaLuotId).toList();
    if (cacLuot.isEmpty) return [];

    final caRows = await _chay(
      () => supabase
          .from('ca_kham')
          .select('id, ngay_kham')
          .inFilter('id', cacLuot.map((r) => r['ca_kham_id']).toSet().toList()),
    );
    final ngayTheoCa = {
      for (final c in caRows)
        c['id'] as int: DateTime.parse(c['ngay_kham'] as String),
    };

    return [
      for (final r in cacLuot)
        if (ngayTheoCa[r['ca_kham_id']] != null)
          LanKhamTruoc(
            ngay: ngayTheoCa[r['ca_kham_id']]!,
            chanDoan: (r['chan_doan'] as String?) ?? '',
          ),
    ]..sort((a, b) => b.ngay.compareTo(a.ngay));
  }

  /// Bệnh nhân đã từng khám (hoặc vắng mặt) với bác sĩ đang đăng nhập.
  /// RLS chỉ trả về lượt khám thuộc ca của bác sĩ này.
  Future<List<BenhNhanCuaToi>> layBenhNhanCuaToi() async {
    final luotRows = await _chay(
      () => supabase
          .from('luot_kham')
          .select(
            'id, ca_kham_id, benh_nhan_id, trang_thai, trieu_chung, chan_doan, ghi_chu_bac_si',
          )
          .inFilter('trang_thai', ['da_kham', 'vang_mat']),
    );
    if (luotRows.isEmpty) return [];

    final caRows = await _chay(
      () => supabase
          .from('ca_kham')
          .select('id, ngay_kham, gio_bat_dau')
          .eq('bac_si_id', _uid)
          .inFilter(
            'id',
            luotRows.map((l) => l['ca_kham_id']).toSet().toList(),
          ),
    );
    final caTheoId = {for (final c in caRows) c['id'] as int: c};

    final bnIds = luotRows
        .map((l) => l['benh_nhan_id'] as String)
        .toSet()
        .toList();
    final hoSoRows = await _chay(
      () => supabase
          .from('ho_so')
          .select('id, ho_ten, gioi_tinh, ngay_sinh')
          .inFilter('id', bnIds),
    );
    final hoSo = {for (final h in hoSoRows) h['id'] as String: h};

    final nhom = <String, List<LanKham>>{};
    for (final l in luotRows) {
      final ca = caTheoId[l['ca_kham_id']];
      if (ca == null) continue;
      nhom
          .putIfAbsent(l['benh_nhan_id'] as String, () => [])
          .add(
            LanKham(
              luotId: l['id'] as int,
              ngay: DateTime.parse(ca['ngay_kham'] as String),
              gioBatDau: _docGio(ca['gio_bat_dau'] as String),
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
    final kq = await _rpc('goi_so_tiep_theo', {'p_ca_kham_id': caKhamId});
    return (kq as Map)['id'] as int;
  }

  Future<void> hoanTatKham(int luotKhamId, String chanDoan, String loiDan) =>
      _rpc('hoan_tat_kham', {
        'p_luot_kham_id': luotKhamId,
        'p_chan_doan': chanDoan,
        'p_loi_dan': loiDan,
      });

  /// Mời một bệnh nhân cụ thể vào khám (người tạm hoãn vừa đến, hoặc gọi vượt số).
  Future<void> batDauKham(int luotKhamId) =>
      _rpc('bat_dau_kham', {'p_luot_kham_id': luotKhamId});

  /// Bệnh nhân chưa có mặt: tạm hoãn, vẫn giữ số đến hết ca.
  Future<void> tamHoan(int luotKhamId) =>
      _rpc('tam_hoan_kham', {'p_luot_kham_id': luotKhamId});

  /// Nghe Supabase Realtime trên các ca của bác sĩ: có người đặt / huỷ lịch,
  /// gọi số, hoàn tất… (trigger trong file SQL 11 cập nhật dòng ca_kham) → gọi [khiThayDoi].
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

  static LuotKhamTrongCa _docLuot(
    Map<String, dynamic> l,
    Map<String, dynamic>? hs,
  ) => LuotKhamTrongCa(
    id: l['id'] as int,
    soThuTu: l['so_thu_tu'] as int,
    benhNhanId: l['benh_nhan_id'] as String,
    tenBenhNhan: ((hs?['ho_ten'] as String?)?.trim().isNotEmpty ?? false)
        ? hs!['ho_ten'] as String
        : 'Bệnh nhân',
    gioiTinh: hs?['gioi_tinh'] as String?,
    ngaySinh: hs?['ngay_sinh'] == null
        ? null
        : DateTime.tryParse(hs!['ngay_sinh'] as String),
    trieuChung: (l['trieu_chung'] as String?) ?? '',
    chanDoan: l['chan_doan'] as String?,
    loiDan: l['ghi_chu_bac_si'] as String?,
    ngayDat: l['ngay_tao'] == null
        ? null
        : DateTime.tryParse(l['ngay_tao'] as String)?.toLocal(),
    trangThai: docTrangThaiLuot(l['trang_thai'] as String?),
  );

  static Duration _docGio(String s) {
    final p = s.split(':');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]));
  }

  Future<List<Map<String, dynamic>>> _chay(
    Future<List<Map<String, dynamic>>> Function() truyVan,
  ) async {
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
    // In lỗi gốc ra Logcat để dễ tìm nguyên nhân (lọc: MediBook)
    debugPrint(
      '[MediBook][SUPABASE] code=${e.code} message=${e.message} details=${e.details}',
    );
    if (RegExp(r'[À-ỹ]').hasMatch(e.message))
      return e.message; // thông báo tiếng Việt từ hàm SQL
    if (e.message.contains('check constraint'))
      return 'Database chưa cập nhật trạng thái mới (chạy lại file SQL 07)';
    if (e.message.contains('Could not find the function'))
      return 'Database chưa có hàm này (chạy lại file SQL 07)';
    return 'Có lỗi xảy ra (${e.code ?? 'không rõ mã'}), vui lòng thử lại';
  }
}
