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
                _MiniLogo(glowing: highlight),
                const SizedBox(height: 8),
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
                  'Lossless everywhere.',
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

class _MiniLogo extends StatelessWidget {
  const _MiniLogo({this.glowing = false});

  final bool glowing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final heights = [8.0, 12.0, 16.0, 12.0, 8.0];
        final opacities = [0.2, 0.4, glowing ? 0.9 : 0.7, 0.4, 0.2];
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 2.0 : 0),
          child: Container(
            width: 3,
            height: heights[i],
            decoration: BoxDecoration(
              color: const Color(0xFF4F8EF7).withValues(alpha: opacities[i]),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }
}
