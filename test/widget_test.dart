import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_tasks/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MyApp), findsOneWidget);
  });
}
