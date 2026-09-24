import 'package:aqloss/app_channel.dart';
import 'package:aqloss/util/notices.dart';
import 'package:aqloss/widgets/nightly_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('local and release builds are not nightly', () {
    expect(kIsNightly, isFalse);
    expect(kAppChannel, 'release');
  });

  test('version label only tags nightly', () {
    expect(appVersionLabel('1.1.0'), '1.1.0');
    expect(appVersionLabel('1.1.0', nightly: false), '1.1.0');
    expect(appVersionLabel('1.1.0', nightly: true), '1.1.0 (nightly)');
  });

  test('notice shows until the nightly warning is acked', () {
    expect(shouldShowNightlyNotice(isNightly: false, acked: false), isFalse);
    expect(shouldShowNightlyNotice(isNightly: false, acked: true), isFalse);
    expect(shouldShowNightlyNotice(isNightly: true, acked: true), isFalse);
    expect(shouldShowNightlyNotice(isNightly: true, acked: false), isTrue);
  });

  testWidgets('release builds do not open the warning', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => maybeShowNightlyNotice(context, isNightly: false),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text(kNightlyBuildTitle), findsNothing);
  });

  testWidgets('nightly warning shows once then stays dismissed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => maybeShowNightlyNotice(context, isNightly: true),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text(kNightlyBuildTitle), findsOneWidget);
    expect(find.text(kNightlyBuildMessage), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(kNightlyBuildTitle), findsNothing);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text(kNightlyBuildTitle), findsNothing);
  });
}
