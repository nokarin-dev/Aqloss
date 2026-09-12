import 'package:aqloss/widgets/q_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required bool reduce}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: const Scaffold(body: Center(child: QSpinner())),
  );
}

void main() {
  testWidgets('spinner stays still when reduce motion is on', (tester) async {
    await tester.pumpWidget(_app(reduce: true));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('spinner runs when motion is allowed', (tester) async {
    await tester.pumpWidget(_app(reduce: false));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('spinner stops after reduce motion turns on', (tester) async {
    await tester.pumpWidget(_app(reduce: false));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(_app(reduce: true));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
