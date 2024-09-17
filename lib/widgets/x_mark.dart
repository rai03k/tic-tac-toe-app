import 'package:flutter/material.dart';

class XMark extends StatelessWidget {
  const XMark({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _XMarkPainter(),
    );
  }
}

class _XMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
