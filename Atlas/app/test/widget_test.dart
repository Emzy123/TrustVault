import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:atlas/main.dart' show AtlasApp;

void main() {
  testWidgets('Atlas app renders', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Atlas')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(AtlasApp(router: router));
    expect(find.text('Atlas'), findsOneWidget);
  });
}
