import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/app_theme.dart';
import '../dat_lich/chi_duong.dart';
import '../dat_lich/dich_vu_dat_lich.dart';
import '../dat_lich/dinh_dang.dart';
import '../dat_lich/mo_hinh.dart';
import '../dat_lich/vi_tri.dart';
import 'csdl_hanh_trinh.dart';
import 'ghi_log.dart';
import 'tim_duong_osrm.dart';

/// Bản đồ trong app: vị trí hiện tại, đường đi ngắn nhất (OSRM), ghi lại hành trình (SQLite).
/// [dich] có giá trị khi mở từ nút "Chỉ đường" của một bệnh viện cụ thể.
class ManHinhBanDo extends StatefulWidget {
  final BenhVien? dich;

  const ManHinhBanDo({super.key, this.dich});

  @override
  State<ManHinhBanDo> createState() => _ManHinhBanDoState();
}

class _ManHinhBanDoState extends State<ManHinhBanDo> {
  static const _soUngVien = 3; // số bệnh viện gần nhất (chim bay) đem đi so đường thật
  static const _banKinhDenNoiMet = 50.0;
  static const _mauGoiY = AppTheme.mauCam; // đường gợi ý: cam
  static const _mauDaDi = AppTheme.mauChinh; // đường thực tế: xanh
  static const _khoangCach = Distance(calculator: Haversine()); // công thức Haversine

  final _banDo = MapController();
  bool _banDoSanSang = false;

  // Vị trí
  LatLng? _viTri;
  StreamSubscription<Position>? _theoDoiViTri;
  String? _loiViTri;

  // Bệnh viện + đích
  List<BenhVien> _dsBenhVien = [];
  LatLng? _dich;
  String? _tenDich;
  BenhVien? _benhVienDich;
  List<TuyenDuong> _cacTuyen = [];
  bool _dangTimDuong = false;
  bool _daBaoDenNoi = false;

  // Ghi hành trình
  String? _maHanhTrinh;
  final List<LatLng> _vetDaDi = [];
  bool _dangGhi = false;
  DateTime? _batDauLuc;
  String? _dangXemLai; // tên hành trình cũ đang xem lại

  // Mạng
  StreamSubscription<List<ConnectivityResult>>? _theoDoiMang;
  bool _coMang = true;

  String _trangThai = 'Đang lấy vị trí của bạn…';

  @override
  void initState() {
    super.initState();
    ghiLog('APP', 'Mở màn hình Bản đồ & hành trình');
    CsdlHanhTrinh.moSan(); // mở sẵn để Database Inspector thấy ngay
    _dangKyTheoDoiMang();
    _khoiDong();
  }

  @override
  void dispose() {
    _theoDoiViTri?.cancel();
    _theoDoiMang?.cancel();
    _canhBaoGps?.cancel();
    WakelockPlus.disable();
    // Không kết thúc hành trình ở đây: nếu app bị tắt khi đang ghi, lần sau sẽ hỏi tiếp tục.
    super.dispose();
  }

  // ======================= KHỞI ĐỘNG =======================

  Future<void> _khoiDong() async {
    final kq = await layViTri();
    if (!mounted) return;
    if (!kq.co) {
      setState(() {
        _loiViTri = kq.loiNhan;
        _trangThai = 'Chưa có vị trí. Bật định vị và cấp quyền vị trí cho MediBook.';
      });
    } else {
      _capNhatViTri(LatLng(kq.viDo!, kq.kinhDo!), diChuyenBanDo: true);
      _batDauTheoDoiViTri();
    }

    try {
      final ds = await DichVuDatLich().layBenhVien();
      if (mounted) setState(() => _dsBenhVien = ds);
    } catch (_) {
      ghiLog('APP', 'Không tải được danh sách bệnh viện');
    }

    await _hoiTiepTucHanhTrinhDo();

    final bv = widget.dich;
    if (bv != null && _maHanhTrinh == null && bv.viDo != null && bv.kinhDo != null) {
      _benhVienDich = bv;
      await _timDuongDen(LatLng(bv.viDo!, bv.kinhDo!), bv.ten);
    } else if (_maHanhTrinh == null && _viTri != null) {
      setState(() => _trangThai = 'Chạm một bệnh viện, nhấn giữ bản đồ, hoặc bấm "Bệnh viện gần nhất".');
    }
  }

  /// Theo dõi vị trí liên tục (3 giây / 5 mét như bản Java).
  /// Khi đang ghi: chạy dịch vụ nền có thông báo, để vẫn nhận GPS khi chuyển sang app khác
  /// (VD mở Lockito) hoặc tắt màn hình.
  void _batDauTheoDoiViTri({bool chayNen = false}) {
    final caiDat = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: chayNen
          ? const ForegroundNotificationConfig(
              notificationTitle: 'MediBook đang ghi hành trình',
              notificationText: 'Vị trí của bạn đang được lưu vào máy.',
              enableWakeLock: true,
            )
          : null,
    );
    _theoDoiViTri?.cancel();
    _theoDoiViTri = Geolocator.getPositionStream(locationSettings: caiDat).listen(
      (p) => _xuLyViTriMoi(p),
      onError: (e) => ghiLog('GPS', 'Lỗi: $e'),
    );
    ghiLog('GPS', 'Bắt đầu theo dõi vị trí${chayNen ? ' (chạy nền)' : ''}');
  }

  /// Đang ghi mà lâu không có điểm mới thì báo cho người dùng biết.
  Timer? _canhBaoGps;
  DateTime _lanCuoiCoGps = DateTime.now();

  void _batCanhBaoGps() {
    _canhBaoGps?.cancel();
    _canhBaoGps = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_dangGhi || !mounted) return;
      final giay = DateTime.now().difference(_lanCuoiCoGps).inSeconds;
      if (giay >= 20) {
        ghiLog('GPS', 'Đã $giay giây chưa nhận được vị trí mới');
        setState(() => _trangThai = 'Chưa nhận được vị trí mới ($giay giây). '
            'Kiểm tra GPS / Lockito còn đang chạy không.');
      }
    });
  }

  void _capNhatViTri(LatLng p, {bool diChuyenBanDo = false}) {
    setState(() {
      _viTri = p;
      _loiViTri = null;
    });
    if (diChuyenBanDo && _banDoSanSang) _banDo.move(p, 16);
  }

  // ======================= MẠNG =======================

  void _dangKyTheoDoiMang() {
    Connectivity().checkConnectivity().then((kq) {
      if (mounted) setState(() => _coMang = !kq.contains(ConnectivityResult.none));
    });
    _theoDoiMang = Connectivity().onConnectivityChanged.listen((kq) async {
      final coMangMoi = !kq.contains(ConnectivityResult.none);
      if (coMangMoi == _coMang || !mounted) return;
      setState(() => _coMang = coMangMoi);
      if (coMangMoi) {
        ghiLog('MẠNG', 'Có mạng trở lại → vẽ lại hành trình từ SQLite');
        final ma = _maHanhTrinh;
        if (ma != null) {
          final diem = await CsdlHanhTrinh.layDiem(ma);
          if (mounted) {
            setState(() {
              _vetDaDi
                ..clear()
                ..addAll(diem);
              _trangThai = 'Đã có mạng lại, đã vẽ lại hành trình (${diem.length} điểm).';
            });
          }
        }
      } else {
        ghiLog('MẠNG', 'Mất mạng → vẫn tiếp tục ghi GPS vào SQLite');
        setState(() => _trangThai = '[Offline] Mất mạng, vẫn đang lưu vị trí vào máy.');
      }
    });
  }

  // ======================= TÌM ĐƯỜNG =======================

  /// 1. Lọc 3 bệnh viện gần nhất theo đường chim bay (Haversine, không cần mạng)
  /// 2. Hỏi OSRM đường đi thật đến từng bệnh viện
  /// 3. Chọn bệnh viện có QUÃNG ĐƯỜNG THẬT ngắn nhất
  Future<void> _timBenhVienGanNhat() async {
    final viTri = _viTri;
    if (viTri == null) return _bao('Chưa có vị trí GPS, vui lòng đợi một chút.');
    if (_dangTimDuong) return;

    final coToaDo = _dsBenhVien.where((b) => b.viDo != null && b.kinhDo != null).toList();
    if (coToaDo.isEmpty) return _bao('Chưa tải được danh sách bệnh viện.');

    double chimBay(BenhVien b) => _khoangCach.as(LengthUnit.Meter, viTri, LatLng(b.viDo!, b.kinhDo!));
    coToaDo.sort((a, b) => chimBay(a).compareTo(chimBay(b)));
    final ungVien = coToaDo.take(_soUngVien).toList();

    setState(() {
      _dangTimDuong = true;
      _trangThai = 'Đang so sánh đường đi đến ${ungVien.length} bệnh viện gần nhất…';
    });

    BenhVien? tot;
    List<TuyenDuong>? tuyenTot;
    for (final b in ungVien) {
      ghiLog('HAVERSINE', '${b.ten}: chim bay ${(chimBay(b) / 1000).toStringAsFixed(2)} km');
      try {
        final tuyen = await timDuongOsrm(viTri, LatLng(b.viDo!, b.kinhDo!));
        if (tuyen.isEmpty) continue;
        ghiLog('OSRM', '${b.ten}: đường thật ${tuyen.first.moTa}');
        if (tuyenTot == null || tuyen.first.quangDuongMet < tuyenTot.first.quangDuongMet) {
          tot = b;
          tuyenTot = tuyen;
        }
      } catch (e) {
        ghiLog('OSRM', 'Lỗi tìm đường đến ${b.ten}: $e');
      }
    }
    if (!mounted) return;

    if (tot == null || tuyenTot == null) {
      setState(() => _dangTimDuong = false);
      return _baoLoiTimDuong();
    }
    ghiLog('KẾT QUẢ', 'Bệnh viện có đường đi ngắn nhất: ${tot.ten}');
    setState(() {
      _dangTimDuong = false;
      _benhVienDich = tot;
    });
    _hienTuyen(LatLng(tot.viDo!, tot.kinhDo!), tot.ten, tuyenTot);
  }

  Future<void> _timDuongDen(LatLng dich, String ten) async {
    final viTri = _viTri;
    if (viTri == null) {
      setState(() {
        _dich = dich;
        _tenDich = ten;
      });
      return _bao('Chưa có vị trí GPS, vui lòng đợi một chút.');
    }
    if (_dangTimDuong) return;
    setState(() {
      _dangTimDuong = true;
      _trangThai = 'Đang tìm đường đến $ten…';
    });
    try {
      final tuyen = await timDuongOsrm(viTri, dich);
      if (!mounted) return;
      setState(() => _dangTimDuong = false);
      if (tuyen.isEmpty) return _baoLoiTimDuong();
      _hienTuyen(dich, ten, tuyen);
    } catch (e) {
      ghiLog('OSRM', 'Lỗi tìm đường đến $ten: $e');
      if (!mounted) return;
      setState(() {
        _dangTimDuong = false;
        _dich = dich;
        _tenDich = ten;
        _cacTuyen = [];
      });
      _baoLoiTimDuong();
    }
  }

  void _hienTuyen(LatLng dich, String ten, List<TuyenDuong> tuyen) {
    setState(() {
      _dich = dich;
      _tenDich = ten;
      _cacTuyen = tuyen;
      _daBaoDenNoi = false;
      _dangXemLai = null;
      _trangThai = tuyen.length > 1
          ? 'Đã so ${tuyen.length} tuyến, chọn tuyến ngắn nhất. Bấm "Bắt đầu đi" để ghi lại đường bạn thực sự đi.'
          : 'Bấm "Bắt đầu đi" để ghi lại đường bạn thực sự đi.';
    });
    if (!_dangGhi) _vuaKhung([...tuyen.first.cacDiem, if (_viTri != null) _viTri!]);
  }

  void _baoLoiTimDuong() => setState(() => _trangThai = _coMang
      ? 'Không tìm được đường, vui lòng thử lại.'
      : '[Offline] Tìm đường cần có mạng. Việc lưu vết vẫn chạy bình thường.');

  // ======================= GHI HÀNH TRÌNH =======================

  Future<void> _batDauGhi() async {
    if (_viTri == null) return _bao('Chưa có vị trí GPS, chưa thể bắt đầu.');
    final ma = 'HT_${DateTime.now().millisecondsSinceEpoch}';
    await CsdlHanhTrinh.taoHanhTrinh(HanhTrinh(
      ma: ma,
      tenDich: _tenDich ?? 'Không chọn điểm đến',
      viDoDich: _dich?.latitude,
      kinhDoDich: _dich?.longitude,
      batDau: DateTime.now(),
    ));
    await WakelockPlus.enable(); // giữ màn hình sáng khi đang ghi
    setState(() {
      _maHanhTrinh = ma;
      _dangGhi = true;
      _batDauLuc = DateTime.now();
      _dangXemLai = null;
      _vetDaDi.clear(); // ẩn vết cũ khi chạy lại
      _daBaoDenNoi = false;
      _trangThai = '${_coMang ? '' : '[Offline] '}Đang ghi… chờ tín hiệu GPS';
    });
    ghiLog('GHI', 'Bắt đầu hành trình $ma');
    _lanCuoiCoGps = DateTime.now();
    _batDauTheoDoiViTri(chayNen: true);
    _batCanhBaoGps();
    // Điểm xuất phát
    _luuDiem(_viTri!);
  }

  void _xuLyViTriMoi(Position p) {
    if (!mounted) return;
    final diem = LatLng(p.latitude, p.longitude);
    _lanCuoiCoGps = DateTime.now();
    ghiLog('GPS', 'Vị trí: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} '
        '(sai số ${p.accuracy.toStringAsFixed(0)} m)');
    final lanDau = _viTri == null;
    _capNhatViTri(diem, diChuyenBanDo: lanDau);

    if (_dangGhi) {
      _luuDiem(diem);
      if (_banDoSanSang) _banDo.move(diem, _banDo.camera.zoom);
      _kiemTraDenNoi(diem);
    }
  }

  void _luuDiem(LatLng diem) {
    final ma = _maHanhTrinh;
    if (ma == null) return;
    setState(() {
      _vetDaDi.add(diem);
      _trangThai = '${_coMang ? '' : '[Offline] '}Đang ghi… đã lưu ${_vetDaDi.length} điểm';
    });
    CsdlHanhTrinh.themDiem(ma, diem, thuTu: _vetDaDi.length, offline: !_coMang);
  }

  void _kiemTraDenNoi(LatLng diem) {
    final dich = _dich;
    if (dich == null || _daBaoDenNoi) return;
    final conLai = _khoangCach.as(LengthUnit.Meter, diem, dich);
    if (conLai <= _banKinhDenNoiMet) {
      _daBaoDenNoi = true;
      ghiLog('GHI', 'Đã đến $_tenDich (còn ${conLai.toStringAsFixed(0)} m)');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bạn đã đến $_tenDich. Bấm "Kết thúc" để lưu hành trình.'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Future<void> _dungGhi() async {
    final ma = _maHanhTrinh;
    if (ma == null) return;
    await CsdlHanhTrinh.ketThuc(ma);
    await WakelockPlus.disable();
    _canhBaoGps?.cancel();
    _batDauTheoDoiViTri();
    ghiLog('GHI', 'Dừng hành trình $ma, tổng ${_vetDaDi.length} điểm');
    final diem = await CsdlHanhTrinh.layDiem(ma); // vẽ lại từ SQLite cho chắc
    if (!mounted) return;
    setState(() {
      _dangGhi = false;
      _maHanhTrinh = null;
      _vetDaDi
        ..clear()
        ..addAll(diem);
      _trangThai = 'Đã lưu hành trình: ${diem.length} điểm, ${_moTaQuangDuong(_quangDuongDaDi)}.';
    });
    if (diem.length > 1) _vuaKhung(diem);
  }

  /// Mở lại app khi lần trước đang ghi dở (chưa bấm Kết thúc).
  Future<void> _hoiTiepTucHanhTrinhDo() async {
    final h = await CsdlHanhTrinh.layDangGhiDo();
    if (h == null || !mounted) return;
    final diem = await CsdlHanhTrinh.layDiem(h.ma);
    if (!mounted) return;
    ghiLog('GHI', 'Phát hiện hành trình ghi dở ${h.ma} (${diem.length} điểm)');

    final tiepTuc = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Hành trình đang ghi dở'),
        content: Text('Lần trước app bị đóng khi đang ghi hành trình đến "${h.tenDich}" '
            '(${diem.length} điểm). Bạn muốn ghi tiếp?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Kết thúc')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Ghi tiếp'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (tiepTuc == true) {
      await WakelockPlus.enable();
      setState(() {
        _maHanhTrinh = h.ma;
        _dangGhi = true;
        _batDauLuc = h.batDau;
        _vetDaDi
          ..clear()
          ..addAll(diem);
        _dich = h.dich;
        _tenDich = h.tenDich;
        _trangThai = 'Đã khôi phục ${diem.length} điểm từ SQLite, tiếp tục ghi…';
      });
      ghiLog('GHI', 'Tiếp tục hành trình ${h.ma}');
      _lanCuoiCoGps = DateTime.now();
      _batDauTheoDoiViTri(chayNen: true);
      _batCanhBaoGps();
      if (diem.isNotEmpty) _vuaKhung(diem);
      final dich = h.dich;
      if (dich != null && _coMang) {
        try {
          final tuyen = await timDuongOsrm(_viTri ?? diem.last, dich);
          if (mounted && tuyen.isNotEmpty) setState(() => _cacTuyen = tuyen);
        } catch (_) {}
      }
    } else {
      await CsdlHanhTrinh.ketThuc(h.ma);
    }
  }

  // ======================= LỊCH SỬ =======================

  Future<void> _moLichSu() async {
    final ds = await CsdlHanhTrinh.layDanhSach();
    if (!mounted) return;
    final chon = await showModalBottomSheet<HanhTrinh>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BangLichSu(ds: ds),
    );
    if (chon == null || !mounted) return;
    final diem = await CsdlHanhTrinh.layDiem(chon.ma);
    if (!mounted) return;
    setState(() {
      _vetDaDi
        ..clear()
        ..addAll(diem);
      _dangXemLai = chon.tenDich;
      _cacTuyen = [];
      _dich = chon.dich;
      _tenDich = chon.tenDich;
      _trangThai = 'Đang xem lại hành trình ${haiSo(chon.batDau.day)}/${haiSo(chon.batDau.month)} '
          '${gioPhut(chon.batDau)}: ${diem.length} điểm, ${_moTaQuangDuong(_quangDuongDaDi)}.';
    });
    if (diem.length > 1) _vuaKhung(diem);
  }

  void _xoaBanDo() {
    setState(() {
      _vetDaDi.clear();
      _cacTuyen = [];
      _dich = null;
      _tenDich = null;
      _benhVienDich = null;
      _dangXemLai = null;
      _trangThai = 'Đã xoá bản đồ. Dữ liệu hành trình vẫn còn trong máy (xem ở Lịch sử).';
    });
  }

  // ======================= TIỆN ÍCH =======================

  double get _quangDuongDaDi {
    var tong = 0.0;
    for (var i = 1; i < _vetDaDi.length; i++) {
      tong += _khoangCach.as(LengthUnit.Meter, _vetDaDi[i - 1], _vetDaDi[i]);
    }
    return tong;
  }

  String _moTaQuangDuong(double met) =>
      met < 1000 ? '${met.round()} m' : '${(met / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';

  void _vuaKhung(List<LatLng> diem) {
    if (!_banDoSanSang || diem.isEmpty) return;
    if (diem.length == 1) {
      _banDo.move(diem.first, 16);
      return;
    }
    _banDo.fitCamera(CameraFit.coordinates(coordinates: diem, padding: const EdgeInsets.fromLTRB(40, 140, 40, 260)));
  }

  void _bao(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  // ======================= GIAO DIỆN =======================

  @override
  Widget build(BuildContext context) {
    final tuyen = _cacTuyen.isEmpty ? null : _cacTuyen.first;
    final batDau = _batDauLuc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ & hành trình'),
        actions: [
          IconButton(tooltip: 'Lịch sử hành trình', icon: const Icon(Icons.history), onPressed: _dangGhi ? null : _moLichSu),
          IconButton(tooltip: 'Xoá bản đồ', icon: const Icon(Icons.layers_clear_outlined), onPressed: _dangGhi ? null : _xoaBanDo),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _banDo,
            options: MapOptions(
              initialCenter: _viTri ?? const LatLng(10.7769, 106.7009), // TP.HCM
              initialZoom: 14,
              onMapReady: () {
                _banDoSanSang = true;
                if (_viTri != null) _banDo.move(_viTri!, 16);
              },
              onLongPress: (_, p) {
                if (_dangGhi) return;
                _benhVienDich = null;
                _timDuongDen(p, 'điểm đã chọn');
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.medibook.medibook_flutter',
              ),
              PolylineLayer(polylines: [
                // Tuyến thay thế: xám nhạt
                for (final t in _cacTuyen.skip(1))
                  Polyline(points: t.cacDiem, color: Colors.grey.withValues(alpha: 0.6), strokeWidth: 5),
                // Đường ngắn nhất gợi ý: cam (nằm dưới đường thực tế)
                if (tuyen != null) Polyline(points: tuyen.cacDiem, color: _mauGoiY, strokeWidth: 7),
                // Đường thực tế đã đi: xanh
                if (_vetDaDi.length > 1) Polyline(points: _vetDaDi, color: _mauDaDi, strokeWidth: 5),
              ]),
              MarkerLayer(markers: [
                for (final b in _dsBenhVien)
                  if (b.viDo != null && b.kinhDo != null)
                    Marker(
                      point: LatLng(b.viDo!, b.kinhDo!),
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: _dangGhi
                            ? null
                            : () {
                                _benhVienDich = b;
                                _timDuongDen(LatLng(b.viDo!, b.kinhDo!), b.ten);
                              },
                        child: Icon(Icons.local_hospital,
                            size: 34,
                            color: _benhVienDich?.id == b.id ? Colors.red.shade700 : Colors.red.shade300),
                      ),
                    ),
                if (_dich != null && _benhVienDich == null)
                  Marker(
                    point: _dich!,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.place, size: 38, color: Colors.red),
                  ),
                if (_viTri != null)
                  Marker(
                    point: _viTri!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.mauChinh,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                    ),
                  ),
              ]),
              RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),

          // Thanh trạng thái phía trên
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _TheTrangThai(
              trangThai: _loiViTri ?? _trangThai,
              coMang: _coMang,
              dangGhi: _dangGhi,
              dangTai: _dangTimDuong,
            ),
          ),

          // Nút về vị trí của tôi
          Positioned(
            right: 12,
            bottom: 230,
            child: FloatingActionButton.small(
              heroTag: 'vi_tri',
              backgroundColor: Colors.white,
              onPressed: _viTri == null ? null : () => _banDo.move(_viTri!, 17),
              child: const Icon(Icons.my_location, color: AppTheme.mauChinh),
            ),
          ),

          // Bảng điều khiển phía dưới
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BangDieuKhien(
              tenDich: _tenDich,
              tuyen: tuyen,
              soTuyen: _cacTuyen.length,
              dangGhi: _dangGhi,
              dangXemLai: _dangXemLai,
              soDiem: _vetDaDi.length,
              quangDuong: _moTaQuangDuong(_quangDuongDaDi),
              thoiGian: batDau == null ? null : DateTime.now().difference(batDau),
              coGoogleMaps: _benhVienDich != null,
              onGanNhat: _dangGhi || _dangTimDuong ? null : _timBenhVienGanNhat,
              onBatDau: _batDauGhi,
              onKetThuc: _dungGhi,
              onGoogleMaps: () {
                final bv = _benhVienDich;
                if (bv != null) moGoogleMaps(context, bv);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ WIDGET CON ============================

class _TheTrangThai extends StatelessWidget {
  final String trangThai;
  final bool coMang;
  final bool dangGhi;
  final bool dangTai;

  const _TheTrangThai({required this.trangThai, required this.coMang, required this.dangGhi, required this.dangTai});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(AppTheme.boGoc),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (dangTai)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(dangGhi ? Icons.fiber_manual_record : Icons.info_outline,
                  size: 18, color: dangGhi ? Colors.red : AppTheme.mauChinh),
            const SizedBox(width: 10),
            Expanded(child: Text(trangThai, style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: ShapeDecoration(
                color: coMang ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: const StadiumBorder(),
              ),
              child: Text(coMang ? 'Online' : 'Offline',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: coMang ? const Color(0xFF15803D) : const Color(0xFFB91C1C))),
            ),
          ],
        ),
      ),
    );
  }
}

class _BangDieuKhien extends StatelessWidget {
  final String? tenDich;
  final TuyenDuong? tuyen;
  final int soTuyen;
  final bool dangGhi;
  final String? dangXemLai;
  final int soDiem;
  final String quangDuong;
  final Duration? thoiGian;
  final bool coGoogleMaps;
  final VoidCallback? onGanNhat;
  final VoidCallback onBatDau;
  final VoidCallback onKetThuc;
  final VoidCallback onGoogleMaps;

  const _BangDieuKhien({
    required this.tenDich,
    required this.tuyen,
    required this.soTuyen,
    required this.dangGhi,
    required this.dangXemLai,
    required this.soDiem,
    required this.quangDuong,
    required this.thoiGian,
    required this.coGoogleMaps,
    required this.onGanNhat,
    required this.onBatDau,
    required this.onKetThuc,
    required this.onGoogleMaps,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final tg = thoiGian;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Điểm đến + tuyến
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppTheme.mauCam),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenDich ?? 'Chưa chọn điểm đến',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      tuyen == null
                          ? (dangXemLai != null ? 'Đang xem lại hành trình đã lưu' : 'Chạm bệnh viện hoặc nhấn giữ bản đồ')
                          : 'Đường ngắn nhất: ${tuyen!.moTa}${soTuyen > 1 ? ' (so $soTuyen tuyến)' : ''}',
                      style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                    ),
                  ],
                ),
              ),
              if (coGoogleMaps)
                IconButton(
                  tooltip: 'Mở Google Maps',
                  onPressed: onGoogleMaps,
                  icon: const Icon(Icons.open_in_new, color: AppTheme.mauChinh),
                ),
            ],
          ),

          // Thống kê hành trình
          if (dangGhi || dangXemLai != null || soDiem > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _OSo(nhan: 'Đã đi', giaTri: quangDuong),
                _OSo(nhan: 'Số điểm', giaTri: '$soDiem'),
                _OSo(nhan: 'Thời gian', giaTri: tg == null ? '--' : '${tg.inMinutes} phút'),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Nút
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGanNhat,
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('Bệnh viện gần nhất'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: dangGhi
                    ? FilledButton.icon(
                        onPressed: onKetThuc,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Kết thúc'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: onBatDau,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Bắt đầu đi'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OSo extends StatelessWidget {
  final String nhan;
  final String giaTri;

  const _OSo({required this.nhan, required this.giaTri});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.mauChinhNhat,
            borderRadius: BorderRadius.circular(AppTheme.boGoc),
          ),
          child: Column(
            children: [
              Text(giaTri, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.mauChinh)),
              Text(nhan, style: const TextStyle(fontSize: 11, color: AppTheme.mauChuNhat)),
            ],
          ),
        ),
      );
}

class _BangLichSu extends StatelessWidget {
  final List<HanhTrinh> ds;

  const _BangLichSu({required this.ds});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hành trình đã lưu (${ds.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Dữ liệu nằm trong SQLite trên máy, xem được cả khi mất mạng.',
                style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 13)),
            const SizedBox(height: 12),
            if (ds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Chưa có hành trình nào.')),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ds.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final h = ds[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.mauChinhNhat,
                        child: Icon(Icons.route, color: AppTheme.mauChinh),
                      ),
                      title: Text(h.tenDich, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${haiSo(h.batDau.day)}/${haiSo(h.batDau.month)} ${gioPhut(h.batDau)} · '
                          '${h.soDiem} điểm${h.ketThuc == null ? ' · đang ghi dở' : ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, h),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
