import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/referral_wallet_screen.dart';

const _overview = <String, dynamic>{
  'referral_code': 'YGNTEST1234',
  'referral_link': 'https://ygntv.org/?ref=YGNTEST1234',
  'attributed': true,
  'earned_total_ks': 10000,
  'withdrawable_balance_ks': 5000,
  'registered_invitees': 3,
  'paid_invitees': 2,
  'leaderboard': [
    {'name': 'Top member', 'successful_invites': 2},
  ],
  'withdrawal_requests': [
    {
      'amount_ks': 1500,
      'payment_method': 'wavepay',
      'payout_address_masked': '09******567',
      'status': 'pending',
    },
    {
      'amount_ks': 500,
      'payment_method': 'kpay',
      'payout_address_masked': '09*****789',
      'status': 'paid',
    },
  ],
};

class _ReferralScreenService extends AuthService {
  _ReferralScreenService({this.withdrawalError})
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  final Object? withdrawalError;
  final requests = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> getReferralOverview() async => _overview;

  @override
  Future<Map<String, dynamic>> requestReferralWithdrawal({
    required int amountKs,
    required String paymentMethod,
    required String payoutAddress,
    required String requestKey,
  }) async {
    requests.add({
      'amount_ks': amountKs,
      'payment_method': paymentMethod,
      'payout_address': payoutAddress,
      'request_key': requestKey,
    });
    if (withdrawalError != null) throw withdrawalError!;
    return {'status': 'pending'};
  }
}

Widget _app(_ReferralScreenService service) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: ReferralWalletScreen(service: service),
);

bool _hasMyanmar(String text) =>
    RegExp(r'[\u1000-\u109F\uAA60-\uAA7F]').hasMatch(text);

void _expectEnglishVisibleCopy(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final value = text.data ?? text.textSpan?.toPlainText() ?? '';
    expect(
      _hasMyanmar(value),
      isFalse,
      reason: 'Unexpected non-English UI: $value',
    );
  }
}

Future<void> _openWithdrawalDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Request withdrawal'));
  await tester.pumpAndSettle();
  expect(find.text('Available balance: 5,000 Ks'), findsOneWidget);
  expect(find.text('Withdrawal amount (Ks)'), findsOneWidget);
  expect(find.text('Payout method'), findsOneWidget);
  expect(find.text('Payout phone number or account address'), findsOneWidget);
}

Future<void> _fillWithdrawal(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '1500');
  await tester.enterText(fields.at(1), '09-1234-5678');
}

void main() {
  testWidgets('referral policy, counts, leaderboard and statuses are English', (
    tester,
  ) async {
    final service = _ReferralScreenService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Refer & Earn'), findsOneWidget);
    expect(find.text('Your referral code'), findsOneWidget);
    expect(find.text('YGNTEST1234'), findsOneWidget);
    expect(
      find.text(
        'Earn 500 Ks for each month an invited member’s Premium subscription is approved. Withdrawable balance follows the referral ledger.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'New accounts opened through your link will have your code prefilled at sign-up. A referral is assigned once, during sign-up, and cannot be added or changed later.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This account’s referral was set at sign-up and cannot be changed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Registered: 3 · Premium: 2'), findsOneWidget);
    expect(
      find.text(
        'Top referrers · ranked by invited members with an approved Premium payment.',
      ),
      findsOneWidget,
    );
    expect(find.text('2 Premium members'), findsOneWidget);
    final withdrawalTitle = find.text('Withdrawal requests');
    final listView = find.byType(ListView).first;
    for (
      var attempt = 0;
      attempt < 12 && withdrawalTitle.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(listView, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(withdrawalTitle);
    await tester.pumpAndSettle();
    expect(find.text('Withdrawal requests'), findsOneWidget);
    expect(find.text('Pending'), findsAtLeastNWidgets(1));
    expect(find.text('Paid'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('Copy referral code'), findsOneWidget);
    expect(find.text('Copy referral link'), findsOneWidget);
    _expectEnglishVisibleCopy(tester);
  });

  testWidgets(
    'withdrawal dialog preserves the three payout rails and manual payout',
    (tester) async {
      final service = _ReferralScreenService();
      addTearDown(service.dispose);
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await _openWithdrawalDialog(tester);
      expect(
        find.text(
          'YGNTV admins review requests and send payouts manually. The app does not transfer money automatically.',
        ),
        findsOneWidget,
      );
      _expectEnglishVisibleCopy(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('WavePay'), findsAtLeastNWidgets(1));
      expect(find.text('KPay'), findsOneWidget);
      expect(find.text('AYA Pay'), findsOneWidget);
      await tester.tap(find.text('KPay'));
      await tester.pumpAndSettle();

      await _fillWithdrawal(tester);
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(service.requests, hasLength(1));
      expect(service.requests.single['amount_ks'], 1500);
      expect(service.requests.single['payment_method'], 'kpay');
      expect(service.requests.single['payout_address'], '09-1234-5678');
    },
  );

  testWidgets('Burmese server errors are shown with an English fallback', (
    tester,
  ) async {
    final service = _ReferralScreenService(
      withdrawalError: const AuthException('\u1000\u1019\u103a'),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await _openWithdrawalDialog(tester);
    await _fillWithdrawal(tester);
    await tester.tap(find.text('Submit request'));
    await tester.pump();

    expect(
      find.text(
        'Could not submit your withdrawal request. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    _expectEnglishVisibleCopy(tester);
  });
}
