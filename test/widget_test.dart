import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zero_trust_tasks/main.dart';

void main() {
  testWidgets('first launch asks the user to create a master password', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Zero-Trust Tasks'), findsOneWidget);
    expect(find.text('Create your master password'), findsOneWidget);
    expect(find.text('Enter your master password'), findsNothing);
  });

  testWidgets('after setup the app opens locked on the unlock screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'is_setup': true});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Enter your master password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Unlock'), findsOneWidget);
    expect(find.text('Create your master password'), findsNothing);
  });
}
