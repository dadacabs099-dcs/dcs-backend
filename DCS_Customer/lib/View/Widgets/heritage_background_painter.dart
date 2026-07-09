import 'package:flutter/material.dart';
import 'dart:math';
import '../Themes/indian_heritage_theme.dart';

/// Indian Heritage Background Painter - Creates beautiful patterns programmatically
class HeritageBackgroundPainter extends CustomPainter {
  final String patternType;
  final Color? primaryColor;
  final Color? secondaryColor;

  HeritageBackgroundPainter({
    this.patternType = 'mandala',
    this.primaryColor,
    this.secondaryColor,
  });

  Color get _primary => primaryColor == null || primaryColor == Colors.transparent 
      ? IndianHeritageColors.saffron.withOpacity(0.15) 
      : primaryColor!;
  
  Color get _secondary => secondaryColor == null || secondaryColor == Colors.transparent 
      ? IndianHeritageColors.oceanBlue.withOpacity(0.1) 
      : secondaryColor!;

  @override
  void paint(Canvas canvas, Size size) {
    switch (patternType) {
      case 'mandala':
        _drawMandala(canvas, size);
        break;
      case 'lotus':
        _drawLotusPattern(canvas, size);
        break;
      case 'paisley':
        _drawPaisleyPattern(canvas, size);
        break;
      case 'block':
        _drawBlockPrint(canvas, size);
        break;
      case 'heritage':
        _drawHeritageBlend(canvas, size);
        break;
      default:
        _drawMandala(canvas, size);
    }
  }

  void _drawMandala(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.8;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _primary;

    // Draw concentric circles
    for (double radius = 30; radius <= maxRadius; radius += 40) {
      canvas.drawCircle(center, radius, paint);
    }

    // Draw radial lines (24 spokes like Ashoka Chakra)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _secondary;

    for (int i = 0; i < 24; i++) {
      final angle = (i * 15) * (pi / 180);
      final start = Offset(
        center.dx + 30 * cos(angle),
        center.dy + 30 * sin(angle),
      );
      final end = Offset(
        center.dx + maxRadius * cos(angle),
        center.dy + maxRadius * sin(angle),
      );
      canvas.drawLine(start, end, linePaint);
    }

    // Draw decorative dots at intersections
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = IndianHeritageColors.marigold.withOpacity(0.2);

    for (int i = 0; i < 24; i++) {
      for (double radius = 70; radius <= maxRadius; radius += 80) {
        final angle = (i * 15) * (pi / 180);
        final position = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        canvas.drawCircle(position, 4, dotPaint);
      }
    }
  }

  void _drawLotusPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = _primary;

    final petalCount = 8;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < petalCount; i++) {
      final angle = (i * (360 / petalCount)) * (pi / 180);
      
      final path = Path();
      final petalLength = min(size.width, size.height) * 0.35;
      final petalWidth = 40.0;
      
      final tipX = centerX + petalLength * cos(angle);
      final tipY = centerY + petalLength * sin(angle);
      
      final baseAngle1 = angle - 0.3;
      final baseAngle2 = angle + 0.3;
      
      final base1X = centerX + 60 * cos(baseAngle1);
      final base1Y = centerY + 60 * sin(baseAngle1);
      final base2X = centerX + 60 * cos(baseAngle2);
      final base2Y = centerY + 60 * sin(baseAngle2);
      
      path.moveTo(centerX, centerY);
      path.quadraticBezierTo(base1X, base1Y, tipX, tipY);
      path.quadraticBezierTo(base2X, base2Y, centerX, centerY);
      path.close();
      
      canvas.drawPath(path, paint);
    }

    // Center circle
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = IndianHeritageColors.marigold.withOpacity(0.25);
    canvas.drawCircle(Offset(centerX, centerY), 50, centerPaint);
  }

  void _drawPaisleyPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _secondary;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _primary;

    // Draw paisley shapes in grid
    for (double x = 60; x < size.width; x += 150) {
      for (double y = 60; y < size.height; y += 150) {
        _drawPaisley(canvas, Offset(x, y), 30, paint, fillPaint);
      }
    }
  }

  void _drawPaisley(Canvas canvas, Offset center, double size, Paint strokePaint, Paint fillPaint) {
    final path = Path();
    
    // Paisley teardrop shape
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(
      center.dx + size * 0.8, center.dy - size * 0.3,
      center.dx + size * 0.5, center.dy + size * 0.5,
    );
    path.quadraticBezierTo(
      center.dx, center.dy + size * 0.8,
      center.dx - size * 0.5, center.dy + size * 0.5,
    );
    path.quadraticBezierTo(
      center.dx - size * 0.8, center.dy - size * 0.3,
      center.dx, center.dy - size,
    );
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Inner dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = IndianHeritageColors.saffron.withOpacity(0.35);
    canvas.drawCircle(center, size * 0.25, dotPaint);
  }

  void _drawBlockPrint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _secondary;

    // Draw diamond pattern grid
    final spacing = 80.0;
    
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final path = Path();
        final half = spacing / 2;
        
        path.moveTo(x + half, y);
        path.lineTo(x + spacing, y + half);
        path.lineTo(x + half, y + spacing);
        path.lineTo(x, y + half);
        path.close();
        
        canvas.drawPath(path, paint);
        
        // Fill every other diamond
        if (((x ~/ spacing) + (y ~/ spacing)) % 2 == 0) {
          final fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..color = _primary;
          canvas.drawPath(path, fillPaint);
        }
      }
    }
  }

  void _drawHeritageBlend(Canvas canvas, Size size) {
    // Gradient background effect
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        IndianHeritageColors.saffron.withOpacity(0.08),
        IndianHeritageColors.marigold.withOpacity(0.05),
        IndianHeritageColors.oceanBlue.withOpacity(0.03),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect);
    
    canvas.drawRect(rect, paint);

    // Overlay subtle mandala
    _drawMandala(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Heritage Background Widget
class HeritageBackground extends StatelessWidget {
  final Widget child;
  final String patternType;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool useGradient;

  const HeritageBackground({
    Key? key,
    required this.child,
    this.patternType = 'heritage',
    this.primaryColor,
    this.secondaryColor,
    this.useGradient = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: useGradient ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IndianHeritageColors.darkBackground,
            IndianHeritageColors.darkSurface,
            IndianHeritageColors.darkCard.withOpacity(0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ) : null,
        color: useGradient ? null : IndianHeritageColors.darkBackground,
      ),
      child: Stack(
        children: [
          // Pattern overlay
          CustomPaint(
            size: Size.infinite,
            painter: HeritageBackgroundPainter(
              patternType: patternType,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }
}

/// Heritage App Background - Use this as the main app background
class HeritageAppBackground extends StatelessWidget {
  final Widget child;

  const HeritageAppBackground({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HeritageBackground(
      patternType: 'heritage',
      useGradient: true,
      child: child,
    );
  }
}
