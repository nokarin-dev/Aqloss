import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/theme/material3_theme.dart';
import 'package:aqloss/theme/standalone_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M3 Light title chrome is light, not the dark fallback', () {
    final theme = buildMaterial3Theme(brightness: Brightness.light);
    final tokens = theme.extension<AqlossTokens>();
    expect(tokens, isNotNull);
    expect(theme.appBarTheme.backgroundColor, tokens!.surface);
    expect(tokens.surface.computeLuminance(), greaterThan(0.5));
    expect(tokens.surfaceVariant.computeLuminance(), greaterThan(0.5));
    expect(tokens.onSurface.computeLuminance(), lessThan(0.5));
    expect(tokens.surface, isNot(AqlossTokens.dark.surface));
    expect(tokens.surfaceVariant, isNot(AqlossTokens.dark.surfaceVariant));
  });

  test('M3 Dark title chrome stays dark', () {
    final theme = buildMaterial3Theme(brightness: Brightness.dark);
    final tokens = theme.extension<AqlossTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.surface.computeLuminance(), lessThan(0.5));
    expect(tokens.onSurface.computeLuminance(), greaterThan(0.5));
  });

  test('Default Light still uses standalone light tokens', () {
    final theme = buildStandaloneTheme(brightness: Brightness.light);
    expect(
      theme.extension<AqlossTokens>()!.surfaceVariant,
      AqlossTokens.light.surfaceVariant,
    );
    expect(theme.useMaterial3, isFalse);
  });
}
