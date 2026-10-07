import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook_flutter/features/auth/man_hinh_chao_mung.dart';

void main() {
  testWidgets('Màn hình chào mừng có 2 nút chọn vai trò', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ManHinhChaoMung()));

    expect(find.text('MediBook'), findsOneWidget);
    expect(find.text('Tôi là Bệnh nhân'), findsOneWidget);
    expect(find.text('Tôi là Bác sĩ'), findsOneWidget);
  });
}
