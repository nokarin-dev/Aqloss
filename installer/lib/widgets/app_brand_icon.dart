import 'package:flutter/material.dart';

class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/icons/icon_128.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, error, stackTrace) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1A22),
          alignment: Alignment.center,
          child: Text(
            'A',
            style: TextStyle(
              color: const Color(0xFF4F8EF7),
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
