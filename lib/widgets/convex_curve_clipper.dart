import 'package:flutter/material.dart';

class ConvexCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start 24 pixels down from the top on the left
    path.moveTo(0, 24);
    // Draw a smooth quadratic Bezier curve to the top-center (x: width/2, y: 0)
    // and back down to the right (x: width, y: 24)
    path.quadraticBezierTo(size.width / 2, 0, size.width, 24);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
