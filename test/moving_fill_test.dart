import 'package:aqloss/ui/shell/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection fill moves between items', (tester) async {
    final first = GlobalKey();
    final second = GlobalKey();
    final host = GlobalKey<_HostState>();

    await tester.pumpWidget(
      MaterialApp(
        home: _Host(key: host, first: first, second: second),
      ),
    );
    await tester.pump();

    expect(fill(tester).top, closeTo(box(tester, first).top, 0.5));
    expect(fill(tester).width, closeTo(box(tester, first).width, 0.5));

    host.currentState!.select(second);
    await tester.pump();
    final start = fill(tester).top;
    await tester.pump(const Duration(milliseconds: 140));
    final mid = fill(tester).top;
    await tester.pump(motionDuration);
    final end = fill(tester);

    expect(start, closeTo(box(tester, first).top, 1));
    expect(mid, greaterThan(start + 4));
    expect(mid, lessThan(box(tester, second).top));
    expect(end.top, closeTo(box(tester, second).top, 0.5));
    expect(end.width, closeTo(box(tester, second).width, 0.5));
  });

  testWidgets('fill lays out in an unbounded row', (tester) async {
    final first = GlobalKey();
    final second = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 40,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: MovingFill(
                selectedKey: second,
                color: const Color(0x24FFFFFF),
                radius: 999,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(key: first, width: 48, height: 30),
                    SizedBox(key: second, width: 72, height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(fill(tester).left, closeTo(box(tester, second).left, 0.5));
    expect(fill(tester).width, closeTo(72, 0.5));
  });
}

Rect fill(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color == const Color(0x24FFFFFF),
  );
  return tester.getRect(finder);
}

Rect box(WidgetTester tester, GlobalKey key) {
  return tester.getRect(find.byKey(key));
}

class _Host extends StatefulWidget {
  final GlobalKey first;
  final GlobalKey second;

  const _Host({super.key, required this.first, required this.second});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late GlobalKey _selected = widget.first;

  void select(GlobalKey key) => setState(() => _selected = key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MovingFill(
        selectedKey: _selected,
        color: const Color(0x24FFFFFF),
        radius: 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(key: widget.first, width: 80, height: 36),
            const SizedBox(height: 24),
            SizedBox(key: widget.second, width: 120, height: 36),
          ],
        ),
      ),
    );
  }
}
