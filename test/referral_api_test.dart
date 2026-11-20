import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('loads referral overview using the signed-in customer token', () async {
    late http.Request captured;
    final service = AuthService(
      tokenReader: () async => 'customer-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'referral_code': 'YGNABCDEFGH',
              'withdrawable_balance_ks': 1000,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.getReferralOverview();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/tv/referrals');
    expect(captured.headers['authorization'], 'Bearer customer-token');
    expect(result['referral_code'], 'YGNABCDEFGH');
    expect(result['withdrawable_balance_ks'], 1000);
    service.dispose();
  });

  test('submits the selected payout rail, amount, address and idempotency key', () async {
    late http.Request captured;
    final service = AuthService(
      tokenReader: () async => 'customer-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'success': true, 'data': {'status': 'pending'}}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.requestReferralWithdrawal(
      amountKs: 1500,
      paymentMethod: 'kpay',
      payoutAddress: ' 09-1234-5678 ',
      requestKey: 'fa8eb71a-4da0-4c09-9b8f-123456789012',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/tv/referrals/withdrawals');
    expect(captured.headers['authorization'], 'Bearer customer-token');
    expect(jsonDecode(captured.body), {
      'amount_ks': 1500,
      'payment_method': 'kpay',
      'payout_address': '09-1234-5678',
      'request_key': 'fa8eb71a-4da0-4c09-9b8f-123456789012',
    });
    expect(result['status'], 'pending');
    service.dispose();
  });
}
