import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.24),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: CustomPaint(painter: _MarkPainter()),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lime = Paint()..color = AppTheme.lime;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.27, 0)
      ..lineTo(size.width * 0.27, size.height * 0.73)
      ..lineTo(size.width, size.height * 0.73)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, lime);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.63,
        0,
        size.width * 0.37,
        size.height * 0.37,
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
