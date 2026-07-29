import 'package:flutter/material.dart';

@immutable
class AqlossTokens extends ThemeExtension<AqlossTokens> {
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color border;
  final Color indicator;
  final Color primary;

  const AqlossTokens({
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.border,
    required this.indicator,
    required this.primary,
  });

  static const dark = AqlossTokens(
    surface: Color(0xFF060608),
    surfaceVariant: Color(0xFF0C0C10),
    card: Color(0xFF101014),
    onSurface: Colors.white,
    onSurfaceMuted: Color(0x70FFFFFF),
    border: Color(0x10FFFFFF),
    indicator: Color(0x14FFFFFF),
    primary: Color(0xFF8AB4FF),
  );

  static const light = AqlossTokens(
    surface: Color(0xFFF2F2F4),
    surfaceVariant: Color(0xFFE8E8EC),
    card: Colors.white,
    onSurface: Colors.black,
    onSurfaceMuted: Color(0x70000000),
    border: Color(0x10000000),
    indicator: Color(0x10000000),
    primary: Color(0xFF3B5BDB),
  );

  @override
  AqlossTokens copyWith({
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? border,
    Color? indicator,
    Color? primary,
  }) {
    return AqlossTokens(
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      border: border ?? this.border,
      indicator: indicator ?? this.indicator,
      primary: primary ?? this.primary,
    );
  }

  @override
  AqlossTokens lerp(ThemeExtension<AqlossTokens>? other, double t) {
    if (other is! AqlossTokens) return this;
    return AqlossTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      indicator: Color.lerp(indicator, other.indicator, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }
}

extension AqlossTokensX on BuildContext {
  AqlossTokens get aq =>
      Theme.of(this).extension<AqlossTokens>() ?? AqlossTokens.dark;

  bool get isMaterial3Ui => Theme.of(this).useMaterial3;
}
