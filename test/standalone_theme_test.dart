import 'package:aqloss/theme/aqloss_tokens.dart';
import 'package:aqloss/theme/standalone_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark theme uses the dark surface tokens', () {
    final theme = buildStandaloneTheme(brightness: Brightness.dark);
    expect(
      theme.extension<AqlossTokens>()!.surface,
      AqlossTokens.dark.surface,
    );
    expect(theme.useMaterial3, isFalse);
  });
}
