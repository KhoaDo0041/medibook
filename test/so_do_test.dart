import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook_flutter/features/can_lam_sang/so_do.dart';

/// Kiểm thử thuật toán Dijkstra trên sơ đồ mẫu (test/so_do.json lấy từ API /api/so-do).
void main() {
  final soDo = SoDoBenhVien.tuJson(
    jsonDecode(File('test/so_do.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('Cùng tầng: đi thẳng theo hành lang', () {
    final d = soDo.timDuong('THU_NGAN', 'NHA_THUOC')!;
    expect(d.nut.first, 'THU_NGAN');
    expect(d.nut.last, 'NHA_THUOC');
    expect(d.nut.any((m) => m.startsWith('TM_')), isFalse);
    expect(d.tongMet, closeTo(49.5, 0.01));
  });

  test('Khác tầng: phải đi qua thang máy', () {
    final d = soDo.timDuong('KHU_A', 'KHU_B')!;
    expect(d.nut, containsAllInOrder(['KHU_A', 'TM_1', 'TM_3', 'KHU_B']));
    expect(soDo.huongDan(d), contains('Đi thang máy lên tầng 3.'));
  });

  test('Đường ngắn nhất không dài hơn đi vòng qua khu khác', () {
    final thang = soDo.timDuong('CONG', 'KHU_A')!.tongMet;
    final vong = soDo.timDuong('CONG', 'NHA_THUOC')!.tongMet +
        soDo.timDuong('NHA_THUOC', 'KHU_A')!.tongMet;
    expect(thang, lessThanOrEqualTo(vong));
  });

  test('Đang ở ngay khu đích', () {
    final d = soDo.timDuong('PK_2', 'PK_2')!;
    expect(d.tongMet, 0);
    expect(d.nut, ['PK_2']);
  });

  test('Mã khu không tồn tại', () {
    expect(soDo.timDuong('KHONG_CO', 'KHU_A'), isNull);
  });
}
