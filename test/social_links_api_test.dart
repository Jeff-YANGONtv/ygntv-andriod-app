import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('loads active safe social links in API display order', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 3,
              'name': 'Facebook',
              'icon': 'facebook',
              'url': 'https://facebook.com/yangontvfbpage',
              'display_order': 2,
              'is_active': true,
            },
            {
              'id': 2,
              'name': 'Telegram',
              'icon': 'telegram',
              'url': 'https://t.me/yangontv',
              'display_order': 1,
              'is_active': true,
            },
            {
              'id': 4,
              'name': 'Disabled channel',
              'url': 'https://example.test/disabled',
              'display_order': 3,
              'is_active': false,
            },
            {
              'id': 5,
              'name': 'Unsafe link',
              'url': 'javascript:alert(1)',
              'display_order': 4,
              'is_active': true,
            },
          ],
        }),
        200,
      );
    });
    final service = AuthService(client: client, tokenReader: () async => null);
    addTearDown(service.dispose);

    final links = await service.getSocialLinks();

    expect(links.map((link) => link.name), ['Telegram', 'Facebook']);
    expect(links.first.url, 'https://t.me/yangontv');
    expect(requests.single.url.path, '/api/socials');
    expect(requests.single.method, 'GET');
  });

  test('allows configured email contacts but rejects unknown URL schemes', () {
    final email = TvSocialLink.fromJson({
      'id': 1,
      'name': 'Email',
      'url': 'mailto:hello@ygntv.org',
      'is_active': true,
    });
    final unsafe = TvSocialLink.fromJson({
      'id': 2,
      'name': 'Unsafe',
      'url': 'javascript:alert(1)',
      'is_active': true,
    });

    expect(email.isUsable, isTrue);
    expect(unsafe.isUsable, isFalse);
  });
}
