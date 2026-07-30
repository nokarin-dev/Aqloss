import 'package:aqloss_installer/widgets/app_brand_icon.dart';
import 'package:flutter/material.dart';

class SideAccent extends StatelessWidget {
  const SideAccent({super.key, this.highlight = false});

  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF080809),
        border: Border(right: BorderSide(color: Color(0xFF1A1A22))),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4F8EF7).withValues(alpha: 0.03),
                    Colors.transparent,
                    const Color(0xFF4F8EF7).withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: highlight ? 1.0 : 0.85,
                  child: const AppBrandIcon(size: 36),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aqloss',
                  style: TextStyle(
                    color: Color(0xFF3A3A4A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Text(
                  'Audio, uncompromised.',
                  style: TextStyle(
                    color: Color(0xFF2A2A38),
                    fontSize: 10.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
