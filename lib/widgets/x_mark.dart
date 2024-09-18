import 'package:flutter/material.dart';

class XMark extends StatelessWidget {
  final Color color;

  XMark({required this.color});  // カスタム色を受け取る

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.65;  // マス目の65%にする
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _XMarkPainter(color: color),  // カスタム色を渡す
          ),
        );
      },
    );
  }
}

class _XMarkPainter extends CustomPainter {
  final Color color;

  _XMarkPainter({required this.color});  // カスタム色を受け取る

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color  // カスタム色を設定
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round  // 丸みを持たせる設定
      ..strokeWidth = 8.0;  // 線の太さを設定

    // バツを描画
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
