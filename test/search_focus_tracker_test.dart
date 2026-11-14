import 'package:aqloss/util/search_focus_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    SearchFocusTracker.instance.setCapturingShortcut(false);
  });

  testWidgets('a focused text field counts as search focus', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField())),
    );
    expect(SearchFocusTracker.instance.hasFocus, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    expect(SearchFocusTracker.instance.hasFocus, isTrue);
  });
}
