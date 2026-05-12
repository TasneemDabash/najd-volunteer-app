import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:najd_volunteer/config/theme.dart';

/// Smoke test for the app theme. We avoid bootstrapping the full app because
/// the splash screen has repeating animations that can't be settled cleanly
/// inside flutter_test.
void main() {
  testWidgets('lightTheme produces a usable MaterialApp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('Najd'))),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Najd'), findsOneWidget);
  });
}
