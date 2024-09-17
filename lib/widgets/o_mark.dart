import 'package:flutter/material.dart';

class OMark extends StatelessWidget {
  const OMark({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OMarkPainter(),
    );
  }
}

class _OMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
