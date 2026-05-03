import 'package:aqloss/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqloss/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await AqlossCore.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    await tester.pumpWidget(const AqlossApp());
  });
}
