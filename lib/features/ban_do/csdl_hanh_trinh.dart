import 'package:latlong2/latlong.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'ghi_log.dart';

/// Một hành trình đã/đang ghi.
class HanhTrinh {
  final String ma; // VD: HT_1728400000000
  final String tenDich;
  final double? viDoDich;
  final double? kinhDoDich;
  final DateTime batDau;
  final DateTime? ketThuc; // null = đang ghi dở
  final int soDiem;

  const HanhTrinh({
    required this.ma,
    required this.tenDich,
    required this.batDau,
    this.viDoDich,
    this.kinhDoDich,
    this.ketThuc,
    this.soDiem = 0,
  });

  LatLng? get dich => viDoDich == null || kinhDoDich == null ? null : LatLng(viDoDich!, kinhDoDich!);

  factory HanhTrinh.tuDong(Map<String, Object?> d) => HanhTrinh(
        ma: d['ma'] as String,
        tenDich: (d['ten_dich'] as String?) ?? '',
        viDoDich: d['vi_do_dich'] as double?,
        kinhDoDich: d['kinh_do_dich'] as double?,
        batDau: DateTime.fromMillisecondsSinceEpoch(d['bat_dau'] as int),
        ketThuc: d['ket_thuc'] == null ? null : DateTime.fromMillisecondsSinceEpoch(d['ket_thuc'] as int),
        soDiem: (d['so_diem'] as int?) ?? 0,
      );
}

/// Lưu vết trên máy bằng SQLite (thay cho Room ở bản Java).
/// File: medibook_local.db — xem bằng App Inspection > Database Inspector.
class CsdlHanhTrinh {
  static Database? _db;

  static Future<Database> _moDb() async {
    if (_db != null) return _db!;
    final duongDan = join(await getDatabasesPath(), 'medibook_local.db');
    _db = await openDatabase(
      duongDan,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE hanh_trinh (
            ma TEXT PRIMARY KEY,
            ten_dich TEXT,
            vi_do_dich REAL,
            kinh_do_dich REAL,
            bat_dau INTEGER NOT NULL,
            ket_thuc INTEGER
          )''');
        await db.execute('''
          CREATE TABLE diem_toa_do (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ma_hanh_trinh TEXT NOT NULL,
            vi_do REAL NOT NULL,
            kinh_do REAL NOT NULL,
            thoi_gian INTEGER NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_diem_hanh_trinh ON diem_toa_do (ma_hanh_trinh)');
        ghiLog('SQLITE', 'Tạo bảng hanh_trinh, diem_toa_do');
      },
    );
    ghiLog('SQLITE', 'Đã mở $duongDan');
    return _db!;
  }

  static Future<void> moSan() => _moDb();

  static Future<void> taoHanhTrinh(HanhTrinh h) async {
    final db = await _moDb();
    await db.insert('hanh_trinh', {
      'ma': h.ma,
      'ten_dich': h.tenDich,
      'vi_do_dich': h.viDoDich,
      'kinh_do_dich': h.kinhDoDich,
      'bat_dau': h.batDau.millisecondsSinceEpoch,
    });
    ghiLog('SQLITE', 'INSERT hanh_trinh ${h.ma} → ${h.tenDich}');
  }

  static Future<void> themDiem(String ma, LatLng p, {required int thuTu, bool offline = false}) async {
    final db = await _moDb();
    await db.insert('diem_toa_do', {
      'ma_hanh_trinh': ma,
      'vi_do': p.latitude,
      'kinh_do': p.longitude,
      'thoi_gian': DateTime.now().millisecondsSinceEpoch,
    });
    ghiLog('SQLITE', 'INSERT điểm #$thuTu vào diem_toa_do${offline ? ' (đang OFFLINE)' : ''}');
  }

  static Future<void> ketThuc(String ma) async {
    final db = await _moDb();
    await db.update('hanh_trinh', {'ket_thuc': DateTime.now().millisecondsSinceEpoch},
        where: 'ma = ?', whereArgs: [ma]);
    ghiLog('SQLITE', 'UPDATE hanh_trinh $ma: đã kết thúc');
  }

  static Future<List<LatLng>> layDiem(String ma) async {
    final db = await _moDb();
    final rows = await db.query('diem_toa_do',
        where: 'ma_hanh_trinh = ?', whereArgs: [ma], orderBy: 'thoi_gian');
    ghiLog('SQLITE', 'SELECT ${rows.length} điểm của $ma để vẽ lại');
    return [for (final r in rows) LatLng(r['vi_do'] as double, r['kinh_do'] as double)];
  }

  /// Hành trình bị ngắt giữa chừng (app tắt khi đang ghi).
  static Future<HanhTrinh?> layDangGhiDo() async {
    final ds = await layDanhSach(chiDangGhiDo: true);
    return ds.isEmpty ? null : ds.first;
  }

  static Future<List<HanhTrinh>> layDanhSach({bool chiDangGhiDo = false}) async {
    final db = await _moDb();
    final rows = await db.rawQuery('''
      SELECT h.*, (SELECT COUNT(*) FROM diem_toa_do d WHERE d.ma_hanh_trinh = h.ma) AS so_diem
      FROM hanh_trinh h
      ${chiDangGhiDo ? 'WHERE h.ket_thuc IS NULL' : ''}
      ORDER BY h.bat_dau DESC''');
    return rows.map(HanhTrinh.tuDong).toList();
  }

  static Future<void> xoa(String ma) async {
    final db = await _moDb();
    await db.delete('diem_toa_do', where: 'ma_hanh_trinh = ?', whereArgs: [ma]);
    await db.delete('hanh_trinh', where: 'ma = ?', whereArgs: [ma]);
    ghiLog('SQLITE', 'DELETE hành trình $ma');
  }
}
