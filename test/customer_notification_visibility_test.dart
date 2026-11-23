import 'package:flutter_test/flutter_test.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

TvNotificationEntry _entry(
  String id,
  String type, {
  String? readAt,
  String? title,
}) => TvNotificationEntry(
  id: id,
  title: title ?? type,
  message: '',
  type: type,
  linkUrl: null,
  createdAt: null,
  readAt: readAt,
);

void main() {
  test(
    'feed exposes only the four requested customer notification categories',
    () {
      final feed = TvNotificationFeed(
        notifications: [
          _entry('blog', 'new_blog_post'),
          _entry('blog-category', 'blog_post'),
          _entry('purchase', 'subscription_purchase_completed', readAt: 'seen'),
          _entry('expired', 'subscription_expired'),
          _entry('download', 'download_completed'),
          _entry('support', 'support_reply'),
          _entry('old-blog', 'blog_post_updated'),
          _entry('pending', 'subscription_payment_pending'),
          _entry('failed', 'download_failed'),
          _entry('lookalike', 'support_reply', title: 'New blog post'),
        ],
        unreadCount: 7,
      );

      expect(feed.visibleNotifications.map((item) => item.id), [
        'blog',
        'blog-category',
        'purchase',
        'expired',
        'download',
        'failed',
      ]);
      expect(feed.visibleNotifications.map((item) => item.customerCategory), [
        CustomerNotificationCategory.newBlogPost,
        CustomerNotificationCategory.newBlogPost,
        CustomerNotificationCategory.purchaseCompleted,
        CustomerNotificationCategory.subscriptionExpired,
        CustomerNotificationCategory.downloadStatus,
        CustomerNotificationCategory.downloadStatus,
      ]);
      expect(feed.visibleUnreadCount, 5);
    },
  );

  test('title fallback recognizes allowed events only when type is absent', () {
    final allowed = TvNotificationEntry(
      id: 'local-1',
      title: 'Download completed',
      message: 'Your video is ready.',
      type: null,
      linkUrl: null,
      createdAt: null,
      readAt: null,
      isLocal: true,
    );
    final unrelated = TvNotificationEntry(
      id: 'local-2',
      title: 'Subscription payment failed',
      message: 'Please retry.',
      type: null,
      linkUrl: null,
      createdAt: null,
      readAt: null,
      isLocal: true,
    );

    expect(allowed.isCustomerVisible, isTrue);
    expect(unrelated.isCustomerVisible, isFalse);
  });
}
