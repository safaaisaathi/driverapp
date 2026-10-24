import 'package:driverapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Phase 0 placeholder renders', (tester) async {
    await tester.pumpWidget(const DriverApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
