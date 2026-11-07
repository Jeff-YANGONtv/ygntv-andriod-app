import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/account_screen.dart';

class _FollowUsService extends AuthService {
  _FollowUsService()
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  @override
  Future<TvProfileData> getProfile() async => const TvProfileData(
    name: 'Test Viewer',
    email: 'viewer@example.com',
    displayName: 'Test Viewer',
    entitlement: TvEntitlement(
      active: false,
      planKey: null,
      planLabel: null,
      validFrom: null,
      validUntil: null,
    ),
    devices: [],
  );

  @override
  Future<List<TvSocialLink>> getSocialLinks() async => const [
    TvSocialLink(
      id: 1,
      name: 'Telegram',
      icon: 'telegram',
      url: 'https://t.me/yangontv',
      displayOrder: 1,
      isActive: true,
    ),
  ];
}

void main() {
  testWidgets('Account menu opens Follow Us with configured social links', (
    tester,
  ) async {
    final service = _FollowUsService();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AccountScreen(
          service: service,
          session: const AuthSession(
            token: 'test-token',
            userId: '1',
            name: 'Test Viewer',
            email: 'viewer@example.com',
          ),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Follow Us'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Follow Us'), findsOneWidget);
    await tester.tap(find.text('Follow Us'));
    await tester.pumpAndSettle();

    expect(find.text('Official YGNTV channels'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('https://t.me/yangontv'), findsOneWidget);
  });
}
