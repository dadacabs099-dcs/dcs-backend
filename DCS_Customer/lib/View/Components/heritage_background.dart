import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final heritageImageProvider = StateProvider<String>((ref) {
  final images = [
    'https://images.unsplash.com/photo-1548013146-72479768bbaa?q=80&w=2073&auto=format&fit=crop', // Taj Mahal
    'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?q=80&w=2071&auto=format&fit=crop', // Red Fort
    'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?q=80&w=1932&auto=format&fit=crop', // Varanasi
    'https://images.unsplash.com/photo-1590766948510-da0d95947493?q=80&w=2015&auto=format&fit=crop', // Hampi
    'https://images.unsplash.com/photo-1598333105741-628f32192131?q=80&w=1974&auto=format&fit=crop', // Mysore Palace
    'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?q=80&w=1974&auto=format&fit=crop', // Amer Fort
  ];
  return images[Random().nextInt(images.length)];
});

class HeritageBackground extends ConsumerWidget {
  final Widget child;
  final double opacity;

  const HeritageBackground({
    super.key,
    required this.child,
    this.opacity = 0.4,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = ref.watch(heritageImageProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(color: Colors.black);
            },
            errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(1 - opacity),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
