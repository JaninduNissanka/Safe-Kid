import 'package:flutter/material.dart';

// 1. SILHOUETTE LOGO (Warning sign style - parent on right, child on left)
class SafeKidLogo extends StatelessWidget {
  final double size;
  const SafeKidLogo({super.key, this.size = 110.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: SilhouetteLogoPainter(),
    );
  }
}

// 2. CARTOON VECTOR LOGO (Friendly father & son)
class SafeKidCartoonLogo extends StatelessWidget {
  final double size;
  const SafeKidCartoonLogo({super.key, this.size = 180.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: CartoonLogoPainter(),
    );
  }
}

class SilhouetteLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    // Draw dark blue circle background
    final paint = Paint()
      ..color = const Color(0xFF0074BC) // Warning sign blue
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), w * 0.46, paint);

    // Draw white figures
    paint.color = Colors.white;

    // --- Parent (Right) ---
    // Parent Head
    canvas.drawCircle(Offset(cx + w * 0.14, cy - h * 0.16), w * 0.085, paint);

    // Parent Body & Limbs
    final parentPath = Path()
      ..moveTo(cx + w * 0.04, cy - h * 0.06) // Left shoulder
      ..lineTo(cx + w * 0.24, cy - h * 0.06) // Right shoulder
      ..lineTo(cx + w * 0.36, cy + h * 0.10) // Right arm end
      ..lineTo(cx + w * 0.32, cy + h * 0.12)
      ..lineTo(cx + w * 0.21, cy - h * 0.01) // Under-arm right
      // Right leg
      ..lineTo(cx + w * 0.25, cy + h * 0.32)
      ..lineTo(cx + w * 0.20, cy + h * 0.32)
      ..lineTo(cx + w * 0.14, cy + h * 0.06) // Crotch center
      // Left leg
      ..lineTo(cx + w * 0.08, cy + h * 0.32)
      ..lineTo(cx + w * 0.03, cy + h * 0.32)
      ..lineTo(cx + w * 0.08, cy - h * 0.01) // Under-arm left
      // Left arm (holds hand)
      ..lineTo(cx - w * 0.04, cy + h * 0.06)
      ..lineTo(cx - w * 0.06, cy + h * 0.03)
      ..lineTo(cx + w * 0.04, cy - h * 0.06)
      ..close();
    canvas.drawPath(parentPath, paint);

    // --- Child (Left) ---
    // Child Head
    canvas.drawCircle(Offset(cx - w * 0.20, cy + h * 0.03), w * 0.06, paint);

    // Child Body & Limbs
    final childPath = Path()
      ..moveTo(cx - w * 0.27, cy + h * 0.11) // Left shoulder
      ..lineTo(cx - w * 0.13, cy + h * 0.11) // Right shoulder
      // Right arm (goes up to meet parent's hand)
      ..lineTo(cx - w * 0.06, cy + h * 0.03)
      ..lineTo(cx - w * 0.04, cy + h * 0.06)
      ..lineTo(cx - w * 0.15, cy + h * 0.15) // Under-arm right
      // Right leg
      ..lineTo(cx - w * 0.12, cy + h * 0.31)
      ..lineTo(cx - w * 0.16, cy + h * 0.31)
      ..lineTo(cx - w * 0.20, cy + h * 0.20) // Crotch
      // Left leg
      ..lineTo(cx - w * 0.24, cy + h * 0.31)
      ..lineTo(cx - w * 0.28, cy + h * 0.31)
      ..lineTo(cx - w * 0.25, cy + h * 0.15) // Under-arm left
      // Left arm
      ..lineTo(cx - w * 0.35, cy + h * 0.20)
      ..lineTo(cx - w * 0.37, cy + h * 0.17)
      ..lineTo(cx - w * 0.27, cy + h * 0.11)
      ..close();
    canvas.drawPath(childPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CartoonLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    // --- Color Palette ---
    const hairColor = Color(0xFF807A8A); // Purple-grey hair
    const skinColor = Color(0xFFFBD6B5); // Soft beige skin
    const skinShadow = Color(0xFFE5B995); // Darker skin shade for shadows/neck
    const vestColor = Color(0xFF4A89DC); // Royal blue vest
    const sleeveColor = Color(0xFF5ED3FF); // Bright light blue sleeves
    const shirtColor = Color(0xFFE6F5FC); // Soft white-blue child shirt
    const featureColor = Color(0xFF8E6053); // Friendly brown for eyes & smile

    final Paint paint = Paint()..isAntiAlias = true;

    // Torso Left Sleeve
    final Path leftSleeve = Path()
      ..moveTo(cx - w * 0.25, cy + h * 0.05)
      ..lineTo(cx - w * 0.40, cy + h * 0.05)
      ..quadraticBezierTo(cx - w * 0.46, cy + h * 0.15, cx - w * 0.35, cy + h * 0.42)
      ..lineTo(cx - w * 0.25, cy + h * 0.42)
      ..close();
    paint.color = sleeveColor;
    canvas.drawPath(leftSleeve, paint);

    // Torso Right Sleeve
    final Path rightSleeve = Path()
      ..moveTo(cx + w * 0.25, cy + h * 0.05)
      ..lineTo(cx + w * 0.40, cy + h * 0.05)
      ..quadraticBezierTo(cx + w * 0.46, cy + h * 0.15, cx + w * 0.35, cy + h * 0.42)
      ..lineTo(cx + w * 0.25, cy + h * 0.42)
      ..close();
    canvas.drawPath(rightSleeve, paint);

    // Vest Body
    final Path vestBody = Path()
      ..moveTo(cx - w * 0.30, cy + h * 0.05)
      ..lineTo(cx + w * 0.30, cy + h * 0.05)
      ..lineTo(cx + w * 0.26, cy + h * 0.50)
      ..lineTo(cx - w * 0.26, cy + h * 0.50)
      ..close();
    paint.color = vestColor;
    canvas.drawPath(vestBody, paint);

    // Parent Neck
    final Path parentNeck = Path()
      ..moveTo(cx - w * 0.06, cy - h * 0.10)
      ..lineTo(cx + w * 0.06, cy - h * 0.10)
      ..lineTo(cx + w * 0.06, cy + h * 0.05)
      ..lineTo(cx - w * 0.06, cy + h * 0.05)
      ..close();
    paint.color = skinShadow;
    canvas.drawPath(parentNeck, paint);

    // Vest V-Neck Cutout
    final Path vNeckCut = Path()
      ..moveTo(cx - w * 0.08, cy + h * 0.05)
      ..lineTo(cx + w * 0.08, cy + h * 0.05)
      ..lineTo(cx, cy + h * 0.18)
      ..close();
    paint.color = skinColor;
    canvas.drawPath(vNeckCut, paint);

    // Parent Ears
    paint.color = skinColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.20, cy - h * 0.22), width: w * 0.07, height: h * 0.09),
        Radius.circular(w * 0.035),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.20, cy - h * 0.22), width: w * 0.07, height: h * 0.09),
        Radius.circular(w * 0.035),
      ),
      paint,
    );

    // Parent Head
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - h * 0.22), width: w * 0.32, height: h * 0.26),
        Radius.circular(w * 0.08),
      ),
      paint,
    );

    // Parent Hair
    final Path parentHair = Path()
      ..moveTo(cx - w * 0.16, cy - h * 0.31)
      ..quadraticBezierTo(cx - w * 0.15, cy - h * 0.44, cx - w * 0.06, cy - h * 0.44)
      ..quadraticBezierTo(cx + w * 0.08, cy - h * 0.46, cx + w * 0.14, cy - h * 0.42)
      ..quadraticBezierTo(cx + w * 0.17, cy - h * 0.38, cx + w * 0.16, cy - h * 0.31)
      ..lineTo(cx + w * 0.18, cy - h * 0.31)
      ..quadraticBezierTo(cx + w * 0.17, cy - h * 0.26, cx + w * 0.15, cy - h * 0.24)
      ..lineTo(cx + w * 0.13, cy - h * 0.24)
      ..lineTo(cx + w * 0.14, cy - h * 0.31)
      ..lineTo(cx - w * 0.14, cy - h * 0.31)
      ..lineTo(cx - w * 0.13, cy - h * 0.24)
      ..lineTo(cx - w * 0.15, cy - h * 0.24)
      ..quadraticBezierTo(cx - w * 0.17, cy - h * 0.26, cx - w * 0.18, cy - h * 0.31)
      ..close();
    paint.color = hairColor;
    canvas.drawPath(parentHair, paint);

    // Parent Eyes
    paint.color = featureColor;
    canvas.drawCircle(Offset(cx - w * 0.065, cy - h * 0.23), w * 0.016, paint);
    canvas.drawCircle(Offset(cx + w * 0.065, cy - h * 0.23), w * 0.016, paint);
    
    // Parent Smile
    final Paint strokePaint = Paint()
      ..color = featureColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.016
      ..strokeCap = StrokeCap.round;
    final Path parentSmile = Path()
      ..moveTo(cx - w * 0.04, cy - h * 0.17)
      ..quadraticBezierTo(cx, cy - h * 0.14, cx + w * 0.04, cy - h * 0.17);
    canvas.drawPath(parentSmile, strokePaint);

    // Child Torso
    final Path childShirt = Path()
      ..moveTo(cx - w * 0.16, cy + h * 0.38)
      ..lineTo(cx + w * 0.16, cy + h * 0.38)
      ..lineTo(cx + w * 0.16, cy + h * 0.50)
      ..lineTo(cx - w * 0.16, cy + h * 0.50)
      ..close();
    paint.color = shirtColor;
    canvas.drawPath(childShirt, paint);

    // Child Neck
    final Path childNeck = Path()
      ..moveTo(cx - w * 0.04, cy + h * 0.28)
      ..lineTo(cx + w * 0.04, cy + h * 0.28)
      ..lineTo(cx + w * 0.04, cy + h * 0.38)
      ..lineTo(cx - w * 0.04, cy + h * 0.38)
      ..close();
    paint.color = skinShadow;
    canvas.drawPath(childNeck, paint);

    // Child Ears
    paint.color = skinColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.13, cy + h * 0.21), width: w * 0.05, height: h * 0.06),
        Radius.circular(w * 0.025),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.13, cy + h * 0.21), width: w * 0.05, height: h * 0.06),
        Radius.circular(w * 0.025),
      ),
      paint,
    );

    // Child Face
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + h * 0.21), width: w * 0.21, height: h * 0.18),
        Radius.circular(w * 0.065),
      ),
      paint,
    );

    // Child Hair
    final Path childHair = Path()
      ..moveTo(cx - w * 0.11, cy + h * 0.15)
      ..quadraticBezierTo(cx - w * 0.10, cy + h * 0.07, cx - w * 0.04, cy + h * 0.07)
      ..quadraticBezierTo(cx + w * 0.06, cy + h * 0.06, cx + w * 0.10, cy + h * 0.10)
      ..quadraticBezierTo(cx + w * 0.12, cy + h * 0.13, cx + w * 0.11, cy + h * 0.15)
      ..lineTo(cx + w * 0.12, cy + h * 0.15)
      ..quadraticBezierTo(cx + w * 0.11, cy + h * 0.18, cx + w * 0.09, cy + h * 0.20)
      ..lineTo(cx + w * 0.08, cy + h * 0.19)
      ..lineTo(cx + w * 0.09, cy + h * 0.15)
      ..lineTo(cx - w * 0.09, cy + h * 0.15)
      ..lineTo(cx - w * 0.08, cy + h * 0.19)
      ..lineTo(cx - w * 0.09, cy + h * 0.20)
      ..quadraticBezierTo(cx - w * 0.11, cy + h * 0.18, cx - w * 0.12, cy + h * 0.15)
      ..close();
    paint.color = hairColor;
    canvas.drawPath(childHair, paint);

    // Child Eyes
    paint.color = featureColor;
    canvas.drawCircle(Offset(cx - w * 0.045, cy + h * 0.20), w * 0.012, paint);
    canvas.drawCircle(Offset(cx + w * 0.045, cy + h * 0.20), w * 0.012, paint);
    
    // Child Smile
    final Path childSmile = Path()
      ..moveTo(cx - w * 0.03, cy + h * 0.24)
      ..quadraticBezierTo(cx, cy + h * 0.26, cx + w * 0.03, cy + h * 0.24);
    canvas.drawPath(childSmile, strokePaint);

    // Parent's Hands
    paint.color = skinColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.15, cy + h * 0.38), width: w * 0.08, height: h * 0.06),
        Radius.circular(w * 0.03),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.15, cy + h * 0.38), width: w * 0.08, height: h * 0.06),
        Radius.circular(w * 0.03),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
