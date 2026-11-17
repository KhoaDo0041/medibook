import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Sơ đồ bệnh viện và thuật toán tìm đường ngắn nhất (Dijkstra).
///
/// Mỗi khu (phòng khám, X-quang, thang máy…) là một NÚT đặt tại cửa ra hành lang;
/// các ngã rẽ trên hành lang cũng là nút. Mỗi LỐI ĐI là một cạnh có độ dài (mét).
/// Thang máy nối các tầng với nhau. Toạ độ theo lưới 100 x 140 (1 ô = 0,5 m).

class KhuVuc {
  final String ma;
  final String ten;
  final String moTa;
  final String loai;
  final int tang;
  final Offset cua; // điểm cửa (vị trí nút trên đồ thị)
  final Rect? khung; // khung chữ nhật để vẽ; null với ngã rẽ hành lang

  const KhuVuc({
    required this.ma,
    required this.ten,
    required this.moTa,
    required this.loai,
    required this.tang,
    required this.cua,
    this.khung,
  });

  bool get laHanhLang => loai == 'hanh_lang';
  bool get laThangMay => loai == 'thang_may';

  factory KhuVuc.tuJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final coKhung = j['hx'] != null;
    return KhuVuc(
      ma: j['ma'] as String,
      ten: (j['ten'] as String?) ?? '',
      moTa: (j['mo_ta'] as String?) ?? '',
      loai: (j['loai'] as String?) ?? 'khac',
      tang: (j['tang'] as num?)?.toInt() ?? 1,
      cua: Offset(d('x'), d('y')),
      khung: coKhung ? Rect.fromLTWH(d('hx'), d('hy'), d('hw'), d('hh')) : null,
    );
  }
}

/// Kết quả tìm đường: danh sách nút đi qua và tổng quãng đường.
class DuongDi {
  final List<String> nut;
  final double tongMet;

  const DuongDi(this.nut, this.tongMet);

  /// Đi bộ trong bệnh viện khoảng 40 m/phút (thang máy đã quy đổi ra mét).
  int get soPhut => max(1, (tongMet / 40).round());
}

class SoDoBenhVien {
  final Map<String, KhuVuc> khu;
  final Map<String, List<(String, double)>> _ke; // danh sách kề: nút → [(nút kề, độ dài)]

  SoDoBenhVien(this.khu, this._ke);

  factory SoDoBenhVien.tuJson(Map<String, dynamic> j) {
    final khu = <String, KhuVuc>{
      for (final k in (j['khu'] as List? ?? const []))
        (k as Map)['ma'] as String: KhuVuc.tuJson(Map<String, dynamic>.from(k)),
    };
    final ke = <String, List<(String, double)>>{};
    for (final c in (j['loi_di'] as List? ?? const [])) {
      final m = c as Map;
      final tu = m['tu'] as String, den = m['den'] as String;
      final dai = (m['do_dai'] as num).toDouble();
      (ke[tu] ??= []).add((den, dai)); // lối đi hai chiều
      (ke[den] ??= []).add((tu, dai));
    }
    return SoDoBenhVien(khu, ke);
  }

  List<int> get cacTang => (khu.values.map((k) => k.tang).toSet().toList())..sort();

  List<KhuVuc> khuCuaTang(int tang) =>
      khu.values.where((k) => k.tang == tang && !k.laHanhLang).toList();

  /// Thuật toán Dijkstra: đường ngắn nhất từ [tu] tới [den].
  /// Đồ thị nhỏ (vài chục nút) nên chọn nút gần nhất bằng cách duyệt tuyến tính.
  DuongDi? timDuong(String tu, String den) {
    if (!khu.containsKey(tu) || !khu.containsKey(den)) return null;
    if (tu == den) return DuongDi([tu], 0);

    final khoangCach = <String, double>{for (final m in khu.keys) m: double.infinity};
    final truoc = <String, String>{};
    final daXet = <String>{};
    khoangCach[tu] = 0;

    while (true) {
      // 1. Lấy nút chưa xét có khoảng cách tạm nhỏ nhất
      String? u;
      for (final m in khu.keys) {
        if (daXet.contains(m) || khoangCach[m] == double.infinity) continue;
        if (u == null || khoangCach[m]! < khoangCach[u]!) u = m;
      }
      if (u == null) return null; // không còn đường
      if (u == den) break;
      daXet.add(u);

      // 2. Cập nhật các nút kề (nới lỏng cạnh)
      for (final (v, dai) in _ke[u] ?? const <(String, double)>[]) {
        final moi = khoangCach[u]! + dai;
        if (moi < khoangCach[v]!) {
          khoangCach[v] = moi;
          truoc[v] = u;
        }
      }
    }

    // 3. Lần ngược từ đích về nguồn để có đường đi
    final duong = <String>[den];
    while (duong.last != tu) {
      duong.add(truoc[duong.last]!);
    }
    return DuongDi(duong.reversed.toList(), khoangCach[den]!);
  }

  double _doDai(String a, String b) {
    for (final (v, d) in _ke[a] ?? const <(String, double)>[]) {
      if (v == b) return d;
    }
    return 0;
  }

  /// Hướng dẫn bằng lời: tách theo tầng, chèn bước đi thang máy.
  List<String> huongDan(DuongDi d) {
    if (d.nut.length < 2) return ['Bạn đang ở ngay khu này.'];
    final buoc = <String>[];
    var met = 0.0;
    for (var i = 1; i < d.nut.length; i++) {
      final a = khu[d.nut[i - 1]]!, b = khu[d.nut[i]]!;
      if (a.tang != b.tang) {
        // đi hết đoạn trên tầng cũ tới thang máy
        if (met > 0) buoc.add('Đi khoảng ${met.round()} m đến thang máy.');
        met = 0;
        // gộp các tầng liên tiếp thành một lần đi thang máy
        var j = i;
        while (j + 1 < d.nut.length && khu[d.nut[j + 1]]!.laThangMay) {
          j++;
        }
        final tangDen = khu[d.nut[j]]!.tang;
        buoc.add('Đi thang máy ${tangDen > a.tang ? 'lên' : 'xuống'} tầng $tangDen.');
        i = j;
        continue;
      }
      met += _doDai(a.ma, b.ma);
    }
    final dich = khu[d.nut.last]!;
    buoc.add(met > 0
        ? 'Đi tiếp khoảng ${met.round()} m đến ${dich.ten}.'
        : 'Đến ${dich.ten}.');
    return buoc;
  }

  /// Khu (không phải hành lang) chứa điểm chạm trên tầng đang xem.
  KhuVuc? khuTaiDiem(int tang, Offset diem) {
    for (final k in khuCuaTang(tang)) {
      if (k.khung != null && k.khung!.contains(diem)) return k;
    }
    return null;
  }
}

/// Vẽ một tầng của sơ đồ, tô đường đi, điểm "Bạn đang ở đây" và ghim điểm đến.
class BanDoTang extends StatelessWidget {
  final SoDoBenhVien soDo;
  final int tang;
  final DuongDi? duong;
  final String? maTu;
  final String? maDen;
  final String? nhanDen; // VD "Phòng 215" thay cho tên khu phòng khám
  final ValueChanged<KhuVuc>? onChamKhu;

  const BanDoTang({
    super.key,
    required this.soDo,
    required this.tang,
    this.duong,
    this.maTu,
    this.maDen,
    this.nhanDen,
    this.onChamKhu,
  });

  static const rongLuoi = 100.0;
  static const caoLuoi = 140.0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: rongLuoi / caoLuoi,
      child: LayoutBuilder(
        builder: (_, kt) {
          final tiLe = kt.maxWidth / rongLuoi;
          return GestureDetector(
            onTapUp: onChamKhu == null
                ? null
                : (e) {
                    final k = soDo.khuTaiDiem(tang, e.localPosition / tiLe);
                    if (k != null) onChamKhu!(k);
                  },
            child: CustomPaint(
              size: Size(kt.maxWidth, kt.maxWidth / rongLuoi * caoLuoi),
              painter: _VeTang(
                soDo: soDo,
                tang: tang,
                duong: duong,
                maTu: maTu,
                maDen: maDen,
                nhanDen: nhanDen,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VeTang extends CustomPainter {
  final SoDoBenhVien soDo;
  final int tang;
  final DuongDi? duong;
  final String? maTu, maDen, nhanDen;

  _VeTang({
    required this.soDo,
    required this.tang,
    this.duong,
    this.maTu,
    this.maDen,
    this.nhanDen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / BanDoTang.rongLuoi;
    Offset p(Offset o) => o * s;

    // Nền lưới
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFAFCFE));
    final luoi = Paint()
      ..color = const Color(0xFFEEF3F8)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= BanDoTang.rongLuoi; x += 10) {
      canvas.drawLine(p(Offset(x, 0)), p(Offset(x, BanDoTang.caoLuoi)), luoi);
    }
    for (var y = 0.0; y <= BanDoTang.caoLuoi; y += 10) {
      canvas.drawLine(p(Offset(0, y)), p(Offset(BanDoTang.rongLuoi, y)), luoi);
    }

    // Hành lang chính
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(46 * s, 6 * s, 54 * s, (tang == 1 ? 128 : 124) * s),
        Radius.circular(3 * s),
      ),
      Paint()..color = const Color(0xFFE9EFF5),
    );

    // Các khu
    for (final k in soDo.khuCuaTang(tang)) {
      final khung = k.khung;
      if (khung == null) continue;
      final laDen = k.ma == maDen, laTu = k.ma == maTu;
      final (nen, vien) = laDen
          ? (AppTheme.mauNhanNhat, AppTheme.mauNhan)
          : laTu
          ? (AppTheme.mauChinhNhat, AppTheme.mauChinh)
          : k.loai == 'cong'
          ? (AppTheme.mauChuDam, AppTheme.mauChuDam)
          : (Colors.white, const Color(0xFFDCE6EF));
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(khung.left * s, khung.top * s, khung.width * s, khung.height * s),
        Radius.circular(3.5 * s),
      );
      canvas.drawRRect(r, Paint()..color = nen);
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = laDen || laTu ? 2 : 1
          ..color = vien,
      );
      final ten = laDen && nhanDen != null ? nhanDen! : k.ten;
      final chu = k.loai == 'cong'
          ? Colors.white
          : laDen
          ? const Color(0xFF8E2160)
          : laTu
          ? AppTheme.mauChinhDam
          : AppTheme.mauChuDam;
      _chu(
        canvas,
        ten,
        Offset(khung.left * s + 2.5 * s, khung.top * s + 2.5 * s),
        khung.width * s - 5 * s,
        TextStyle(fontSize: 3.6 * s, fontWeight: FontWeight.w700, color: chu, height: 1.2),
        dong: khung.height < 16 ? 1 : 2,
      );
      final moTa = laDen && nhanDen != null ? k.ten : k.moTa;
      if (moTa.isNotEmpty && khung.height >= 16) {
        _chu(
          canvas,
          moTa,
          Offset(khung.left * s + 2.5 * s, khung.top * s + 11 * s),
          khung.width * s - 5 * s,
          TextStyle(fontSize: 3 * s, color: chu.withValues(alpha: 0.7), height: 1.2),
        );
      }
    }

    // Đường đi trên tầng này (nét đứt màu hồng)
    final d = duong;
    if (d != null && d.nut.length > 1) {
      final but = Paint()
        ..color = AppTheme.mauNhan
        ..strokeWidth = 1.6 * s
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < d.nut.length; i++) {
        final a = soDo.khu[d.nut[i - 1]]!, b = soDo.khu[d.nut[i]]!;
        if (a.tang != tang || b.tang != tang) continue;
        _netDut(canvas, p(a.cua), p(b.cua), but, 1.4 * s, 3.2 * s);
      }
    }

    // Điểm bắt đầu và ghim điểm đến
    final tu = soDo.khu[maTu];
    if (tu != null && tu.tang == tang) {
      final o = p(tu.cua);
      canvas.drawCircle(o, 5 * s, Paint()..color = AppTheme.mauChinh.withValues(alpha: 0.18));
      canvas.drawCircle(o, 2.6 * s, Paint()..color = AppTheme.mauChinh);
      canvas.drawCircle(
        o,
        2.6 * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * s
          ..color = Colors.white,
      );
    }
    final den = soDo.khu[maDen];
    if (den != null && den.tang == tang && den.ma != maTu) {
      final o = p(den.cua);
      final ghim = Path()
        ..moveTo(o.dx, o.dy)
        ..cubicTo(o.dx - 7 * s, o.dy - 8 * s, o.dx - 5 * s, o.dy - 14 * s, o.dx, o.dy - 14 * s)
        ..cubicTo(o.dx + 5 * s, o.dy - 14 * s, o.dx + 7 * s, o.dy - 8 * s, o.dx, o.dy)
        ..close();
      canvas.drawPath(ghim, Paint()..color = AppTheme.mauNhan);
      canvas.drawCircle(Offset(o.dx, o.dy - 9.5 * s), 1.8 * s, Paint()..color = Colors.white);
    }
  }

  void _netDut(Canvas c, Offset a, Offset b, Paint but, double dai, double cach) {
    final tong = (b - a).distance;
    if (tong == 0) return;
    final huong = (b - a) / tong;
    var t = 0.0;
    while (t < tong) {
      final cuoi = min(t + dai, tong);
      c.drawLine(a + huong * t, a + huong * cuoi, but);
      t += dai + cach;
    }
  }

  void _chu(Canvas c, String text, Offset o, double rong, TextStyle kieu, {int dong = 2}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: kieu),
      textDirection: TextDirection.ltr,
      maxLines: dong,
      ellipsis: '…',
    )..layout(maxWidth: max(0, rong));
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _VeTang old) =>
      old.tang != tang || old.duong != duong || old.maTu != maTu || old.maDen != maDen;
}
