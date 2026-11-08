import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('loads active HTTPS top-slot banners in the API display order', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 2,
              'name': 'Second banner',
              'type': 'banner',
              'content': 'https://poster.ygntv.org/banners/second.webp',
              'link_url': 'https://ygntv.org/movies/second',
              'button_name': 'Watch now',
              'position': 'top',
              'display_order': 2,
              'is_active': true,
            },
            {
              'id': 1,
              'name': 'First banner',
              'type': 'banner',
              'content': '/storage/banners/first.webp',
              'position': 'top',
              'display_order': 1,
              'is_active': true,
            },
            {
              'id': 3,
              'name': 'Inactive banner',
              'type': 'banner',
              'content': 'https://poster.ygntv.org/banners/inactive.webp',
              'position': 'top',
              'display_order': 0,
              'is_active': false,
            },
            {
              'id': 4,
              'name': 'Non-banner ad',
              'type': 'link',
              'content': 'https://poster.ygntv.org/banners/not-a-banner.webp',
              'position': 'top',
              'display_order': 0,
              'is_active': true,
            },
            {
              'id': 5,
              'name': 'Insecure image',
              'type': 'banner',
              'content': 'http://example.test/banner.webp',
              'position': 'top',
              'display_order': 3,
              'is_active': true,
            },
          ],
        }),
        200,
      );
    });
    final service = AuthService(client: client, tokenReader: () async => null);
    addTearDown(service.dispose);

    final banners = await service.getTopAdBanners();

    expect(banners.map((banner) => banner.id), [1, 2]);
    expect(
      banners.first.imageUrl,
      'https://api.ygntv.org/storage/banners/first.webp',
    );
    expect(banners.first.buttonName, isNull);
    expect(banners.last.name, 'Second banner');
    expect(banners.last.linkUrl, 'https://ygntv.org/movies/second');
    expect(banners.last.buttonName, 'Watch now');
    expect(requests.single.url.path, '/api/public/ads');
    expect(requests.single.url.queryParameters, {'position': 'top'});
  });

  test(
    'notification unread count and read state come from the API response',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final isReadRequest = request.method == 'POST';
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'notifications': [
                {
                  'id': 42,
                  'title': 'Support replied',
                  'message': 'Please check your support chat.',
                  'type': 'support',
                  'link_url': null,
                  'created_at': '2026-11-07T00:00:00Z',
                  'read_at': isReadRequest ? '2026-11-07T00:01:00Z' : null,
                },
              ],
              'unread_count': isReadRequest ? 0 : 1,
            },
          }),
          200,
        );
      });
      final service = AuthService(
        client: client,
        tokenReader: () async => 'notification-test-token',
      );
      addTearDown(service.dispose);

      final before = await service.getNotifications();
      expect(before.unreadCount, 1);
      expect(before.notifications.single.isRead, isFalse);
      final after = await service.markNotificationRead('42');

      expect(after.unreadCount, 0);
      expect(after.notifications.single.isRead, isTrue);
      expect(requests.map((request) => request.url.path), [
        '/api/tv/notifications',
        '/api/tv/notifications/42/read',
      ]);
      expect(requests.last.method, 'POST');
      expect(
        requests.last.headers['authorization'],
        'Bearer notification-test-token',
      );
    },
  );
}
