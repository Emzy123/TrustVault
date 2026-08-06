import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trustvault/main.dart' show TrustVaultApp;

void main() {
  testWidgets('TrustVault app renders', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('TrustVault')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(TrustVaultApp(router: router));
    expect(find.text('TrustVault'), findsOneWidget);
  });
}
