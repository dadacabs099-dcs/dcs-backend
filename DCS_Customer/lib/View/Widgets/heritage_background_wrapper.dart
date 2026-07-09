import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';

final heritageImageProvider = StateProvider<String>((ref) {
  final images = [
    'https://images.unsplash.com/photo-1605282470397-f7ca4798c362?q=60&w=500&auto=format&fit=crop', // Premier Padmini
    'https://images.unsplash.com/photo-1527247043589-98e6ac08f56c?q=60&w=500&auto=format&fit=crop', // Vintage Luxury Car
    'https://images.unsplash.com/photo-1565193994326-f77e909247f0?q=60&w=500&auto=format&fit=crop', // Classic Indian Street Car
    'https://images.unsplash.com/photo-1590059392257-2e1d7168d189?q=60&w=500&auto=format&fit=crop', // Iconic Ambassador
    'https://images.unsplash.com/photo-1589417103248-2b83a0670868?q=60&w=500&auto=format&fit=crop', // Antique Rolls Royce India
    'https://images.unsplash.com/photo-1533560232123-7034433963f2?q=60&w=500&auto=format&fit=crop', // Vintage Car Detail
  ];
  return images[math.Random().nextInt(images.length)];
});

class HeritageBackgroundWrapper extends ConsumerWidget {
  final Widget child;
  final String pageName;
  final bool enableBackground;

  const HeritageBackgroundWrapper({
    super.key,
    required this.child,
    required this.pageName,
    this.enableBackground = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enableBackground) return child;
    
    final imageUrl = ref.watch(heritageImageProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 400,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(color: isDark ? Colors.black : IndianHeritageCarColors.platinum);
            },
            errorBuilder: (context, error, stackTrace) => Container(color: isDark ? Colors.black : IndianHeritageCarColors.platinum),
          ),
        ),
        
        // Dynamic Overlay & Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
                    ]
                  : [
                      Colors.white.withOpacity(0.4),
                      IndianHeritageCarColors.platinum.withOpacity(0.9),
                    ],
              ),
            ),
          ),
        ),
        
        // Pattern Overlay (Optional, keeping it subtle)
        Positioned.fill(
          child: CustomPaint(
            painter: HeritagePatternPainter(),
            size: Size.infinite,
          ),
        ),
        
        // Content
        child,
      ],
    );
  }
}

class HeritagePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = IndianHeritageColors.saffron.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Draw traditional Indian pattern elements
    _drawMandalaPattern(canvas, size, paint);
    _drawDiagonalLines(canvas, size, paint);
    _drawCornerMotifs(canvas, size, paint);
  }

  void _drawMandalaPattern(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.15;

    // Central mandala circles
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        radius * (1 - i * 0.3),
        paint,
      );
    }
  }

  void _drawDiagonalLines(Canvas canvas, Size size, Paint paint) {
    final linePaint = Paint()
      ..color = IndianHeritageColors.marigold.withOpacity(0.02)
      ..strokeWidth = 1;

    // Diagonal lines creating geometric pattern
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final start = Offset(
        size.width / 2,
        size.height / 2,
      );
      final end = Offset(
        size.width / 2 + size.width * 0.4 * math.cos(angle),
        size.height / 2 + size.height * 0.4 * math.sin(angle),
      );
      canvas.drawLine(start, end, linePaint);
    }
  }

  void _drawCornerMotifs(Canvas canvas, Size size, Paint paint) {
    final motifPaint = Paint()
      ..color = IndianHeritageColors.oceanBlue.withOpacity(0.02)
      ..strokeWidth = 2;

    // Corner motifs
    final corners = [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    for (final corner in corners) {
      _drawCornerMotif(canvas, corner, motifPaint);
    }
  }

  void _drawCornerMotif(Canvas canvas, Offset corner, Paint paint) {
    final path = Path();
    path.moveTo(corner.dx, corner.dy);
    path.lineTo(corner.dx + 50, corner.dy);
    path.lineTo(corner.dx, corner.dy + 50);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Dadacabs Logo Widget
class DadacabsLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const DadacabsLogo({
    super.key,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/imgs/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// Modern Card with Heritage Theme
class HeritageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const HeritageCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? IndianHeritageColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: IndianHeritageColors.saffron.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: IndianHeritageColors.saffron.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      ),
    );
  }
}

// Heritage Button with Modern Styling
class HeritageButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const HeritageButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: IndianHeritageColors.saffron, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: _buildButtonContent(),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? IndianHeritageColors.saffron,
        foregroundColor: textColor ?? IndianHeritageColors.charcoal,
        elevation: 8,
        shadowColor: IndianHeritageColors.saffron.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(IndianHeritageColors.charcoal),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}
