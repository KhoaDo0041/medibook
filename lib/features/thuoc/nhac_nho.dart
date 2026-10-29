import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'lich_uong.dart';
import 'thoi_quen.dart';

/// Thông báo nhắc uống thuốc và nhắc tái khám (thông báo cục bộ trên điện thoại,
/// không cần máy chủ). Không có nút "Đã uống": chỉ nhắc khi đến giờ.
class NhacNho {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _daKhoiTao = false;

  /// Chỉ đặt trước 14 ngày (Android giới hạn số báo thức mỗi app);
  /// mỗi lần mở app sẽ đặt tiếp (hàm lamMoi).
  static const _soNgayDatTruoc = 14;

  static const _kenhThuoc = AndroidNotificationDetails(
    'nhac_uong_thuoc',
    'Nhắc uống thuốc',
    channelDescription: 'Nhắc giờ uống thuốc theo đơn bác sĩ',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _kenhTaiKham = AndroidNotificationDetails(
    'nhac_tai_kham',
    'Nhắc tái khám',
    channelDescription: 'Nhắc lịch tái khám bác sĩ đã hẹn',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> khoiTao() async {
    if (_daKhoiTao || kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _daKhoiTao = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Xin quyền thông báo (Android 13+) và quyền báo thức chính xác (Android 12+).
  /// Trả về false nếu người dùng không cho phép thông báo.
  static Future<bool> xinQuyen() async {
    if (kIsWeb) return false;
    await khoiTao();
    final ok = await _android?.requestNotificationsPermission() ?? true;
    if ((await _android?.canScheduleExactNotifications()) == false) {
      await _android?.requestExactAlarmsPermission();
    }
    return ok;
  }

  static Future<AndroidScheduleMode> _cheDo() async =>
      (await _android?.canScheduleExactNotifications()) == true
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  // Mỗi lượt khám một dải id riêng: [goc, goc + 2000)
  static int _goc(int luotKhamId) => (luotKhamId % 100000) * 2000;

  static Future<void> _huyDai(int luotKhamId, {bool caTaiKham = false}) async {
    final goc = _goc(luotKhamId);
    final den = caTaiKham ? goc + 2000 : goc + 1990;
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= goc && p.id < den) await _plugin.cancel(id: p.id);
    }
  }

  /// Đặt (lại) toàn bộ nhắc uống thuốc của một lịch.
  static Future<int> datNhacUongThuoc(LichUong lich) async {
    if (kIsWeb) return 0;
    await khoiTao();
    await _huyDai(lich.luotKhamId);
    if (!lich.batNhac) return 0;

    final cheDo = await _cheDo();
    final bayGio = tz.TZDateTime.now(tz.local);
    final homNay = DateTime(bayGio.year, bayGio.month, bayGio.day);
    var dem = 0;
    for (var ngay = 0; ngay < _soNgayDatTruoc; ngay++) {
      final d = homNay.add(Duration(days: ngay));
      final cacCu = lich.cacCu(d);
      for (var s = 0; s < cacCu.length && s < 20; s++) {
        final (gio, ds) = cacCu[s];
        final luc = tz.TZDateTime(tz.local, d.year, d.month, d.day, gio ~/ 60, gio % 60);
        if (!luc.isAfter(bayGio)) continue;
        final ngayThu = d.difference(lich.batDau).inDays; // 0-based, < 90
        final noiDung = ds
            .map((t) => '${t.dong.thuoc.ten} ${t.dong.lieuChu} ${t.dong.thuoc.donVi}')
            .join(', ');
        final thoiDiem = ds.first.dong.thoiDiem.nhan.toLowerCase();
        try {
          await _plugin.zonedSchedule(
            id: _goc(lich.luotKhamId) + ngayThu * 20 + s,
            title: '💊 Đến giờ uống thuốc (${chuPhut(gio)})',
            body: '$noiDung · $thoiDiem',
            scheduledDate: luc,
            notificationDetails: const NotificationDetails(android: _kenhThuoc),
            androidScheduleMode: cheDo,
          );
          dem++;
        } catch (e) {
          debugPrint('[MediBook][Nhắc] không đặt được: $e');
        }
      }
    }
    return dem;
  }

  static Future<void> huyNhacUongThuoc(int luotKhamId) async {
    if (kIsWeb) return;
    await khoiTao();
    await _huyDai(luotKhamId);
  }

  /// Nhắc tái khám: 19:00 hôm trước và 07:00 sáng hôm đó.
  static Future<void> datNhacTaiKham(int luotKhamId, DateTime ngay, String noiKham) async {
    if (kIsWeb) return;
    await khoiTao();
    final goc = _goc(luotKhamId);
    await _plugin.cancel(id: goc + 1990);
    await _plugin.cancel(id: goc + 1991);
    final cheDo = await _cheDo();
    final bayGio = tz.TZDateTime.now(tz.local);
    final cac = [
      (goc + 1990, tz.TZDateTime(tz.local, ngay.year, ngay.month, ngay.day - 1, 19), 'Ngày mai'),
      (goc + 1991, tz.TZDateTime(tz.local, ngay.year, ngay.month, ngay.day, 7), 'Hôm nay'),
    ];
    for (final (id, luc, khi) in cac) {
      if (!luc.isAfter(bayGio)) continue;
      await _plugin.zonedSchedule(
        id: id,
        title: '📅 Nhắc tái khám',
        body: '$khi bạn có lịch tái khám: $noiKham. Nhớ đặt lịch trên MediBook nhé.',
        scheduledDate: luc,
        notificationDetails: const NotificationDetails(android: _kenhTaiKham),
        androidScheduleMode: cheDo,
      );
    }
  }

  /// Mở app: đặt tiếp nhắc cho các lịch còn hiệu lực (vì chỉ đặt trước 14 ngày).
  static Future<void> lamMoi() async {
    if (kIsWeb) return;
    try {
      await khoiTao();
      final homNay = DateTime.now();
      for (final l in await KhoLichUong.danhSach()) {
        if (l.batNhac && !l.ketThuc.isBefore(DateTime(homNay.year, homNay.month, homNay.day))) {
          await datNhacUongThuoc(l);
        }
      }
    } catch (e) {
      debugPrint('[MediBook][Nhắc] làm mới lỗi: $e');
    }
  }

  /// Dùng khi demo: hiện thử một thông báo sau [giay] giây.
  static Future<void> guiThu(LichUong lich, {int giay = 10}) async {
    if (kIsWeb) return;
    await khoiTao();
    final cu = lich.cacCu(DateTime.now());
    final ds = cu.isNotEmpty ? cu.first.$2 : lich.thuoc;
    await _plugin.zonedSchedule(
      id: 1999999999,
      title: '💊 Đến giờ uống thuốc (thử)',
      body: ds
          .map((t) => '${t.dong.thuoc.ten} ${t.dong.lieuChu} ${t.dong.thuoc.donVi}')
          .join(', '),
      scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(seconds: giay)),
      notificationDetails: const NotificationDetails(android: _kenhThuoc),
      androidScheduleMode: await _cheDo(),
    );
  }
}
