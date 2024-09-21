import 'package:flutter/material.dart';

class OMark extends StatelessWidget {
  final Color color;

  OMark({required this.color});  // カスタム色を受け取る

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.7;  // マス目の70%にする
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _OMarkPainter(color: color),  // カスタム色を渡す
          ),
        );
      },
    );
  }
}

class _OMarkPainter extends CustomPainter {
  final Color color;

  _OMarkPainter({required this.color});  // カスタム色を受け取る

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color  // カスタム色を設定
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;  // 線の太さを設定

    final radius = size.width / 2;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
