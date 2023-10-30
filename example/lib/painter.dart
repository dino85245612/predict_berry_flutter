import 'package:flutter/material.dart';

class WhiteBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Define the coordinates for the white box (left, top, right, bottom)
    final left = 50.0;
    final top = 50.0;
    final right = 150.0;
    final bottom = 150.0;

    // Create a rectangle with the specified coordinates and draw it on the canvas
    final rect = Rect.fromLTRB(left, top, right, bottom);
    return canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
