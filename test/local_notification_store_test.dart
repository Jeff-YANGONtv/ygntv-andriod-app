import 'package:flutter_test/flutter_test.dart';
import 'package:ygntv_customer/auth/local_notification_store.dart';

void main() {
  test('local notices remain unread until individually marked read', () async {
    String? value;
    final store = LocalNotificationStore(
      readValue: () async => value,
      writeValue: (next) async => value = next,
    );

    await store.addNotification(
      title: 'Saved to My List',
      message: 'Movie was added.',
      type: 'library_saved',
    );
    final unread = await store.getNotifications();
    expect(unread, hasLength(1));
    expect(unread.single['read_at'], isNull);
    expect(unread.single['is_local'], isTrue);

    await store.markRead('${unread.single['id']}');
    final read = await store.getNotifications();
    expect(read.single['read_at'], isNotNull);
  });

  test('parallel local events are serialized without losing records', () async {
    String? value;
    final store = LocalNotificationStore(
      readValue: () async => value,
      writeValue: (next) async => value = next,
    );

    await Future.wait([
      store.addNotification(
        title: 'Download started',
        message: 'One',
        type: 'download_started',
      ),
      store.addNotification(
        title: 'Saved to My List',
        message: 'Two',
        type: 'library_saved',
      ),
      store.addNotification(
        title: 'Started watching',
        message: 'Three',
        type: 'watch_started',
      ),
    ]);

    expect(await store.getNotifications(), hasLength(3));
  });

  test(
    'tracked downloads create a single completion notice only after finish',
    () async {
      String? value;
      final store = LocalNotificationStore(
        readValue: () async => value,
        writeValue: (next) async => value = next,
      );
      await store.trackDownload(42);

      await store.recordFinishedDownloads(const [
        LocalDownloadResult(id: 42, title: 'Test movie', status: 'downloading'),
      ]);
      expect(await store.getNotifications(), isEmpty);

      const finished = LocalDownloadResult(
        id: 42,
        title: 'Test movie',
        status: 'complete',
      );
      await store.recordFinishedDownloads(const [finished]);
      await store.recordFinishedDownloads(const [finished]);

      final notifications = await store.getNotifications();
      expect(notifications, hasLength(1));
      expect(notifications.single['title'], 'Download complete');
      expect(notifications.single['read_at'], isNull);
    },
  );
}
