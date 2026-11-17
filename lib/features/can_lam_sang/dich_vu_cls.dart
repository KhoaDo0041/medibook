import '../../core/api_client.dart';
import 'mo_hinh_cls.dart';
import 'so_do.dart';

class LoiCls implements Exception {
  final String thongBao;
  const LoiCls(this.thongBao);
  @override
  String toString() => thongBao;
}

/// Gọi Web API cho phần cận lâm sàng và sơ đồ bệnh viện (dùng chung bác sĩ và bệnh nhân).
class DichVuCls {
  DichVuCls._();

  static List<DichVuClsMuc>? _danhMuc;
  static SoDoBenhVien? _soDo;

  /// Danh mục dịch vụ cận lâm sàng (bác sĩ chọn khi chỉ định).
  static Future<List<DichVuClsMuc>> danhMuc() async {
    final daCo = _danhMuc;
    if (daCo != null) return daCo;
    final rows = await _goi(() => Api.get('/api/dich-vu-cls')) as List;
    return _danhMuc = [
      for (final r in rows) DichVuClsMuc.tuJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Sơ đồ bệnh viện (tải một lần rồi giữ trong bộ nhớ).
  static Future<SoDoBenhVien> soDo() async {
    final daCo = _soDo;
    if (daCo != null) return daCo;
    final j = await _goi(() => Api.get('/api/so-do')) as Map;
    return _soDo = SoDoBenhVien.tuJson(Map<String, dynamic>.from(j));
  }

  static Future<LoTrinhCls> loTrinh(int luotKhamId) async {
    final j = await _goi(() => Api.get('/api/luot-kham/$luotKhamId/lo-trinh'));
    if (j is! Map) throw const LoiCls('Không tìm thấy lượt khám');
    return LoTrinhCls.tuJson(Map<String, dynamic>.from(j));
  }

  /// Bác sĩ gửi chỉ định cho bệnh nhân đang khám.
  static Future<void> guiChiDinh(int luotKhamId, List<int> dichVuIds) => _goi(
    () => Api.post('/api/bac-si/luot-kham/$luotKhamId/chi-dinh', {
      'dichVuIds': dichVuIds,
    }),
  );

  /// Bệnh nhân thanh toán (mô phỏng). Trả về số tiền đã thanh toán.
  static Future<int> thanhToan(int luotKhamId) async {
    final j = await _goi(
      () => Api.post('/api/luot-kham/$luotKhamId/thanh-toan-cls'),
    );
    return ((j as Map?)?['so_tien'] as num?)?.toInt() ?? 0;
  }

  /// Bệnh nhân đã đến khu và làm xong một chỉ định.
  static Future<void> hoanThanh(int chiDinhId) =>
      _goi(() => Api.post('/api/chi-dinh/$chiDinhId/hoan-thanh'));

  /// Bệnh nhân quay lại phòng khám sau khi làm hết chỉ định.
  static Future<void> quayLai(int luotKhamId) =>
      _goi(() => Api.post('/api/luot-kham/$luotKhamId/quay-lai'));

  static Future<dynamic> _goi(Future<dynamic> Function() goi) async {
    try {
      return await goi();
    } on LoiApi catch (e) {
      throw LoiCls(e.thongBao);
    } catch (_) {
      throw const LoiCls('Không kết nối được máy chủ. Vui lòng thử lại.');
    }
  }
}
