import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Thẻ nền trắng bo góc, đổ bóng nhẹ — dùng chung cho các khối trên dashboard.
class TheTrang extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color mauNen;
  final VoidCallback? onTap;

  const TheTrang({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.mauNen = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boGoc = BorderRadius.circular(AppTheme.boGocThe);
    return Container(
      decoration: BoxDecoration(
        color: mauNen,
        borderRadius: boGoc,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: boGoc,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
