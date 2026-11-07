import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ygntv_customer/widgets/resilient_network_image.dart';
import 'package:ygntv_customer/widgets/ygntv_text_splash.dart';

void main() {
  testWidgets(
    'startup splash shows animated YGN TV text instead of a spinner',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: YgntvTextSplash()));

      expect(find.text('YGN TV'), findsOneWidget);
      expect(find.text('LOADING YGNTV'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 800));
    },
  );

  testWidgets('failed poster requests retry twice and retain a fallback', (
    tester,
  ) async {
    final retryAttempts = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 180,
            child: ResilientNetworkImage(
              url: 'https://example.invalid/t/p/w342/poster.jpg',
              fallback: const Text('Poster unavailable'),
              retryDelays: const [
                Duration(milliseconds: 30),
                Duration(milliseconds: 30),
              ],
              onRetry: retryAttempts.add,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Poster unavailable'), findsOneWidget);
    expect(retryAttempts, [1, 2]);
  });
}
