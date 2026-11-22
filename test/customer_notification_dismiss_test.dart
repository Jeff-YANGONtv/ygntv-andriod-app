import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/auth/local_notification_store.dart';

void main() {
  test(
    'read notices stay dismissed locally without clearing download tracking',
    () async {
      final requests = <http.Request>[];
      String? stored;
      const response = {
        'success': true,
        'data': {
          'notifications': [
            {
              'id': 'read-blog',
              'title': 'New blog post',
              'message': 'Already read.',
              'type': 'new_blog_post',
              'link_url': null,
              'created_at': '2026-11-20T00:00:00Z',
              'read_at': '2026-11-20T00:01:00Z',
            },
            {
              'id': 'unread-expiry',
              'title': 'Premium expired',
              'message': 'Renew your membership.',
              'type': 'premium_subscription_expired',
              'link_url': null,
              'created_at': '2026-11-21T00:00:00Z',
              'read_at': null,
            },
          ],
          'unread_count': 1,
        },
      };
      final store = LocalNotificationStore(
        readValue: () async => stored,
        writeValue: (value) async => stored = value,
      );
      await store.trackDownload(42);
      final service = AuthService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(response), 200);
        }),
        tokenReader: () async => 'test-token',
        localNotificationStore: store,
      );
      addTearDown(service.dispose);

      final initial = await service.getNotifications();
      expect(initial.visibleNotifications.map((item) => item.id), [
        'unread-expiry',
        'read-blog',
      ]);

      final cleared = await service.dismissReadNotifications(initial);
      expect(cleared.visibleNotifications.map((item) => item.id), [
        'unread-expiry',
      ]);
      final refreshed = await service.getNotifications();
      expect(refreshed.visibleNotifications.map((item) => item.id), [
        'unread-expiry',
      ]);

      final saved = jsonDecode(stored!) as Map<String, dynamic>;
      expect(saved['dismissed_notification_ids'], ['read-blog']);
      expect(saved['tracked_download_ids'], [42]);

      await store.recordFinishedDownloads(const [
        LocalDownloadResult(id: 42, title: 'Test movie', status: 'complete'),
      ]);
      final afterDownload = await service.getNotifications();
      expect(
        afterDownload.visibleNotifications.any(
          (item) => item.title == 'Download complete',
        ),
        isTrue,
      );
      expect(requests, isNotEmpty);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(
        requests.every(
          (request) => request.url.path.endsWith('/tv/notifications'),
        ),
        isTrue,
      );
    },
  );
}
