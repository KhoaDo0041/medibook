import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'ghi_log.dart';

class TuyenDuong {
  final List<LatLng> cacDiem;
  final double quangDuongMet;
  final double thoiGianGiay;

  const TuyenDuong(this.cacDiem, this.quangDuongMet, this.thoiGianGiay);

  String get moTa =>
      '${(quangDuongMet / 1000).toStringAsFixed(1).replaceAll('.', ',')} km · ${(thoiGianGiay / 60).round()} phút';
}

/// Hỏi máy chủ OSRM (OpenStreetMap) đường đi thật bằng xe máy/ô tô.
/// OSRM tìm đường bằng Contraction Hierarchies (biến thể nhanh của Dijkstra).
/// Lấy cả các tuyến thay thế rồi sắp theo QUÃNG ĐƯỜNG tăng dần → phần tử đầu là đường ngắn nhất.
Future<List<TuyenDuong>> timDuongOsrm(LatLng tu, LatLng den) async {
  final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
      '${tu.longitude},${tu.latitude};${den.longitude},${den.latitude}'
      '?overview=full&geometries=geojson&alternatives=true');
  final res = await http.get(url, headers: {'User-Agent': 'MediBook student project'}).timeout(
        const Duration(seconds: 12),
      );
  if (res.statusCode != 200) throw Exception('OSRM trả về mã ${res.statusCode}');

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  if (json['code'] != 'Ok') throw Exception('OSRM: ${json['code']}');

  final ds = <TuyenDuong>[
    for (final r in json['routes'] as List)
      TuyenDuong(
        [
          for (final c in (r['geometry']['coordinates'] as List))
            LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ],
        (r['distance'] as num).toDouble(),
        (r['duration'] as num).toDouble(),
      ),
  ]..sort((a, b) => a.quangDuongMet.compareTo(b.quangDuongMet));

  for (var i = 0; i < ds.length; i++) {
    ghiLog('OSRM', 'Tuyến ${i + 1}: ${ds[i].moTa}${i == 0 ? ' ← ngắn nhất' : ''}');
  }
  return ds;
}
