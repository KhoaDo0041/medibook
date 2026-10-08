import 'package:flutter/foundation.dart';

/// In log ra Logcat. Lọc trong Android Studio bằng: MediBook
/// VD: [MediBook][GPS] Điểm #3: 10.776500, 106.666400
void ghiLog(String nhom, String noiDung) => debugPrint('[MediBook][$nhom] $noiDung');
