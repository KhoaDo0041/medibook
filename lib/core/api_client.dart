import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'supabase_client.dart';

/// Lỗi khi gọi Web API, đã có thông báo tiếng Việt để hiện cho người dùng.
class LoiApi implements Exception {
  final String thongBao;
  final int? maHttp;
  const LoiApi(this.thongBao, {this.maHttp});
  @override
  String toString() => thongBao;
}

/// Gọi MediBook Web API (ASP.NET Core, deploy trên Render).
///
/// Mỗi yêu cầu gửi kèm access token của Supabase Auth trong header
/// `Authorization: Bearer ...`; API kiểm tra token rồi mới truy vấn database.
class Api {
  Api._();

  /// Render bản miễn phí "ngủ" sau 15 phút không dùng, lần gọi đầu có thể mất ~50 giây.
  static const _thoiGianCho = Duration(seconds: 60);

  static Map<String, String> _header() {
    final token = supabase.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String duong, [Map<String, String>? thamSo]) =>
      Uri.parse('${ApiConfig.baseUrl}$duong').replace(queryParameters: thamSo);

  static Future<dynamic> get(String duong, {Map<String, String>? thamSo}) =>
      _gui(() => http.get(_uri(duong, thamSo), headers: _header()));

  static Future<dynamic> post(String duong, [Object? body]) => _gui(
    () => http.post(
      _uri(duong),
      headers: _header(),
      body: body == null ? null : jsonEncode(body),
    ),
  );

  static Future<dynamic> _gui(Future<http.Response> Function() yeuCau) async {
    final http.Response res;
    try {
      res = await yeuCau().timeout(_thoiGianCho);
    } on TimeoutException {
      throw const LoiApi('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } catch (_) {
      throw const LoiApi('Không kết nối được máy chủ. Kiểm tra kết nối mạng.');
    }

    final noiDung = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (noiDung.isEmpty) return null;
      return jsonDecode(noiDung);
    }
    if (res.statusCode == 401) {
      throw const LoiApi(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        maHttp: 401,
      );
    }
    String thongBao = 'Có lỗi xảy ra (mã ${res.statusCode}), vui lòng thử lại';
    try {
      final j = jsonDecode(noiDung);
      if (j is Map && j['message'] is String) thongBao = j['message'] as String;
    } catch (_) {}
    throw LoiApi(thongBao, maHttp: res.statusCode);
  }
}
