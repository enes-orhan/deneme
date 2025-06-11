// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiyafet_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiyafet_app/services/storage_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);
    
    await tester.pumpWidget(MyApp(storageService: storageService));
    await tester.pumpAndSettle();

    // Verify that the app title is displayed
    expect(find.text('Kıyafet Envanteri'), findsOneWidget);
  });
}
