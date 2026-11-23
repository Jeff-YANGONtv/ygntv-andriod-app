import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ygntv_customer/widgets/ygntv_home_banner_fallback.dart';

void main() {
  testWidgets(
    'shows YGNTV branding, banner title, and action without overflow',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 328,
              height: 40,
              child: YgntvHomeBannerFallback(
                title: 'New series premieres this week',
                actionLabel: 'Watch now',
              ),
            ),
          ),
        ),
      );

      expect(find.text('YANGON TV'), findsOneWidget);
      expect(find.text('New series premieres this week'), findsOneWidget);
      expect(find.text('WATCH NOW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
