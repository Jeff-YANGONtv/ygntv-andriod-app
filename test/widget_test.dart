import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/auth/support_models.dart';
import 'package:ygntv_customer/screens/account_screen.dart';
import 'package:ygntv_customer/screens/customer_home_screen.dart';
import 'package:ygntv_customer/screens/media_detail_screen.dart';
import 'package:ygntv_customer/screens/notifications_screen.dart';
import 'package:ygntv_customer/screens/sign_in_screen.dart';
import 'package:ygntv_customer/screens/subscription_screen.dart';
import 'package:ygntv_customer/widgets/resilient_network_image.dart';

Widget _testScreen() => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: SignInScreen(
    busy: false,
    onSignIn: (_, _) async => null,
    onSignUp: (_, _, _) async => null,
    onGoogle: () async => null,
    onTelegram: () async => null,
  ),
);

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.detail)
    : super(client: MockClient((_) async => http.Response('{}', 200)));
  final CatalogItem detail;

  @override
  Future<CatalogItem> loadDetail(CatalogItem item) async => detail;
}

class _FakeCustomerService extends AuthService {
  _FakeCustomerService({
    this.paymentAccounts = const [],
    this.notificationFeed = const TvNotificationFeed(
      notifications: [],
      unreadCount: 0,
    ),
    this.marqueeEntries = const [],
  }) : super(client: MockClient((_) async => http.Response('{}', 200)));

  final List<PaymentAccount> paymentAccounts;
  final TvNotificationFeed notificationFeed;
  final List<TvHomeMarqueeEntry> marqueeEntries;
  int supportStarts = 0;
  int supportSends = 0;
  int paymentAccountCalls = 0;
  int paymentOrderCalls = 0;
  int? createdPaymentAccountId;
  String? createdPlanKey;
  String? redeemedCode;

  @override
  Future<List<TvPremiumPlan>> getPremiumPlans() async => const [
    TvPremiumPlan(
      key: '12_months',
      label: '12 Months',
      amountKs: 30000,
      accessMonths: 12,
    ),
    TvPremiumPlan(
      key: '1_month',
      label: '1 Month',
      amountKs: 2500,
      accessMonths: 1,
    ),
  ];

  @override
  Future<Map<String, dynamic>> redeemMembership(String code) async {
    redeemedCode = code;
    return {'valid_until': '2027-05-10'};
  }

  @override
  Future<List<PaymentAccount>> getPaymentAccounts() async {
    paymentAccountCalls++;
    return paymentAccounts;
  }

  @override
  Future<TvPaymentOrder> createPaymentOrder({
    required int paymentAccountId,
    required String planKey,
  }) async {
    paymentOrderCalls++;
    createdPaymentAccountId = paymentAccountId;
    createdPlanKey = planKey;
    return TvPaymentOrder(
      id: '501',
      reference: 'YTV-TEST-123456',
      planKey: planKey,
      amountKs: planKey == '1_month' ? 2500 : 30000,
      status: 'awaiting_receipt',
    );
  }

  @override
  Future<List<CatalogItem>> loadCatalog(
    String kind, {
    int page = 1,
    int perPage = 48,
  }) async => const [];

  @override
  Future<List<TvLibraryEntry>> getContinueWatching() async => const [];

  @override
  Future<TvNotificationFeed> getNotifications() async => notificationFeed;

  @override
  Future<List<TvHomeMarqueeEntry>> getHomeMarqueeEntries() async =>
      marqueeEntries;

  @override
  Future<TvNotificationFeed> markNotificationRead(String id) async =>
      notificationFeed;

  @override
  Future<TvNotificationFeed> markAllNotificationsRead() async =>
      notificationFeed;

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
  Future<List<SupportConversationSummary>> getSupportConversations() async =>
      const [];

  @override
  Future<SupportMessagesPage> getSupportMessages(
    String publicToken, {
    int afterId = 0,
  }) async => SupportMessagesPage(
    publicToken: publicToken,
    status: 'open',
    messages: const [],
    nextAfterId: afterId,
  );

  @override
  Future<SupportMessagesPage> startSupportConversation({
    String? publicToken,
    String pageUrl = 'yangontv://account/help',
  }) async {
    supportStarts++;
    return const SupportMessagesPage(
      publicToken: 'supportToken123456789012345678901',
      status: 'open',
      messages: [],
      nextAfterId: 0,
    );
  }

  @override
  Future<SupportChatMessage> sendSupportMessage(
    String publicToken,
    String body,
  ) async {
    supportSends++;
    return SupportChatMessage(
      id: supportSends,
      senderType: 'visitor',
      body: body,
    );
  }
}

void main() {
  testWidgets('launch screen opens on Sign In with Sign Up available', (
    tester,
  ) async {
    await tester.pumpWidget(_testScreen());
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Telegram'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('Sign Up switches to the account creation form', (tester) async {
    await tester.pumpWidget(_testScreen());
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Join Yangon TV.'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  test('TMDB poster paths resolve directly to image.tmdb.org', () {
    final item = CatalogItem.fromJson({
      'id': 31,
      'name': 'Sample Movie',
      'poster_path': '/sample-poster.jpg',
    }, 'movie');
    expect(item.posterUrl, 'https://image.tmdb.org/t/p/w500/sample-poster.jpg');
  });

  test('absolute TMDB poster and backdrop URLs use direct image sizes', () {
    final item = CatalogItem.fromJson({
      'id': 32,
      'name': 'Absolute URL sample',
      'poster_url': 'https://image.tmdb.org/t/p/w500/poster.jpg',
      'backdrop_url': 'https://image.tmdb.org/t/p/w1280/backdrop.jpg',
    }, 'movie');
    expect(item.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
    expect(item.backdropUrl, 'https://image.tmdb.org/t/p/w780/backdrop.jpg');
  });

  test('poster sizes stay on direct TMDB and leave other hosts alone', () {
    expect(
      directTmdbImageUrlForWidth(
        'https://image.tmdb.org/t/p/w342/poster.jpg',
        185,
      ),
      'https://image.tmdb.org/t/p/w185/poster.jpg',
    );
    expect(
      directTmdbImageUrlForWidth(
        'https://image.tmdb.org/t/p/w342/poster.jpg',
        500,
      ),
      'https://image.tmdb.org/t/p/w500/poster.jpg',
    );
    const otherHost = 'https://cdn.example.test/poster.jpg';
    expect(directTmdbImageUrlForWidth(otherHost, 185), otherHost);
  });

  testWidgets(
    'multi-season series shows seasons first, then selected episodes',
    (tester) async {
      const item = CatalogItem(
        id: 17,
        slug: 'sample-series',
        title: 'Sample Series',
        posterUrl: '',
        kind: 'series',
      );
      const detail = CatalogItem(
        id: 17,
        slug: 'sample-series',
        title: 'Sample Series',
        posterUrl: '',
        kind: 'series',
        synopsis: 'A real API-backed series detail shape.',
        seasons: [
          CatalogSeason(
            id: 101,
            number: 1,
            title: 'Season 1',
            episodes: [
              CatalogEpisode(id: 1001, number: 1, title: 'Opening Chapter'),
            ],
          ),
          CatalogSeason(
            id: 102,
            number: 2,
            title: 'Season 2',
            episodes: [
              CatalogEpisode(id: 2001, number: 1, title: 'The Return'),
            ],
          ),
        ],
      );
      final service = _FakeAuthService(detail);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: MediaDetailScreen(item: item, service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsNWidgets(2));
      expect(find.text('Watch'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a season to view its episodes.'),
        findsOneWidget,
      );
      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('Season 2'), findsOneWidget);
      expect(find.text('EPISODE 1'), findsNothing);
      expect(find.text('Opening Chapter'), findsNothing);

      await tester.ensureVisible(find.text('Season 2').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Season 2').first);
      await tester.pumpAndSettle();
      expect(find.text('The Return'), findsOneWidget);
      expect(find.text('All seasons'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription matches website benefits and keeps live plans selectable',
    (tester) async {
      final service = _FakeCustomerService();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: SubscriptionScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose your access'), findsOneWidget);
      expect(
        find.text(
          'Unlock new releases, Myanmar subtitles, and a smoother way to watch.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 Month'), findsOneWidget);
      expect(find.text('2,500 Ks'), findsOneWidget);
      expect(find.text('Desktop · Mobile'), findsOneWidget);
      expect(find.text('All Contents From ygntv.org'), findsOneWidget);

      final planButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Select plan').first,
      );
      expect(planButton.onPressed, isNotNull);
      expect(service.paymentAccountCalls, 0);

      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promo code redeem'));
      await tester.pumpAndSettle();
      expect(find.text('Redeem your membership code'), findsOneWidget);
      expect(find.text('Enter promo code'), findsOneWidget);
      expect(find.text('Redeem code'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'YGNTV2026');
      await tester.tap(find.text('Redeem code'));
      await tester.pumpAndSettle();
      expect(service.redeemedCode, 'YGNTV2026');
      expect(find.textContaining('Promo code activated'), findsOneWidget);
      expect(service.paymentAccountCalls, 0);
    },
  );

  testWidgets('plan selection opens the live manual-transfer flow', (
    tester,
  ) async {
    final service = _FakeCustomerService(
      paymentAccounts: const [
        PaymentAccount(
          id: 52,
          name: 'KBZPay',
          accountName: 'YGNTV Premium',
          accountNumber: 'TEST-TRANSFER-123',
          description: 'Transfer the exact plan price.',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: SubscriptionScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Select plan').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Select plan').first);
    await tester.pumpAndSettle();
    expect(find.text('Choose a payment method'), findsOneWidget);
    expect(find.text('KBZPay'), findsOneWidget);

    await tester.tap(find.text('KBZPay').first);
    await tester.pumpAndSettle();
    expect(find.text('Send the exact amount'), findsOneWidget);
    expect(find.text('2,500 Ks'), findsOneWidget);
    expect(find.text('YTV-TEST-123456'), findsOneWidget);
    expect(find.text('Phone / account number'), findsOneWidget);
    expect(find.text('TEST-TRANSFER-123'), findsOneWidget);
    expect(service.paymentOrderCalls, 1);
    expect(service.createdPaymentAccountId, 52);
    expect(service.createdPlanKey, '1_month');
  });

  test(
    'admin-managed payment fields and API unread-count presence are parsed',
    () {
      final account = PaymentAccount.fromJson({
        'id': 8,
        'name': 'Live wallet',
        'account_name': 'YGNTV',
        'account_number': 'API-TRANSFER-TEST',
        'description': 'Admin-provided transfer note',
        'qr_image_url': 'https://example.org/live-qr.png',
        'is_active': true,
      });
      expect(account.description, 'Admin-provided transfer note');
      expect(account.accountNumber, 'API-TRANSFER-TEST');
      expect(account.qrImageUrl, 'https://example.org/live-qr.png');
      expect(account.isActive, isTrue);

      final noServerCount = TvNotificationFeed.fromJson({
        'notifications': [
          {'id': 1, 'title': 'Update', 'message': 'Message', 'read_at': null},
        ],
      });
      expect(noServerCount.hasServerUnreadCount, isFalse);
      expect(noServerCount.unreadCount, 1);

      final serverCount = TvNotificationFeed.fromJson({
        'notifications': [],
        'unread_count': 4,
      });
      expect(serverCount.hasServerUnreadCount, isTrue);
      expect(serverCount.unreadCount, 4);
    },
  );

  test('download progress includes percentage and local offline path', () {
    final download = TvDownloadProgress.fromMap({
      'id': 17,
      'title': 'Offline movie',
      'status': 'downloading',
      'bytes_downloaded': 25,
      'total_bytes': 100,
      'local_uri': 'file:///data/user/0/org.ygntv/files/Movies/movie.mp4',
    });
    expect(download.progress, .25);
    expect(download.isActive, isTrue);
    expect(
      download.localFilePath,
      '/data/user/0/org.ygntv/files/Movies/movie.mp4',
    );
  });

  testWidgets('support reply notification opens Help & Support chat', (
    tester,
  ) async {
    final service = _FakeCustomerService(
      notificationFeed: const TvNotificationFeed(
        notifications: [
          TvNotificationEntry(
            id: 'support-1',
            title: 'Customer support reply',
            message: 'We have replied to your message.',
            type: 'support',
            linkUrl: '/subscription',
            createdAt: null,
            readAt: null,
          ),
        ],
        unreadCount: 1,
        hasServerUnreadCount: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: NotificationsScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customer support reply'));
    await tester.pumpAndSettle();

    expect(find.text('Help & Support'), findsOneWidget);
    expect(
      find.text('How can we help with your subscription?'),
      findsOneWidget,
    );
  });

  testWidgets('home notification bell opens live Updates and shows API count', (
    tester,
  ) async {
    final service = _FakeCustomerService(
      notificationFeed: const TvNotificationFeed(
        notifications: [
          TvNotificationEntry(
            id: '8',
            title: 'New YGNTV update',
            message: 'A real update from the API.',
            type: null,
            linkUrl: null,
            createdAt: null,
            readAt: null,
          ),
        ],
        unreadCount: 2,
        hasServerUnreadCount: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: CustomerHomeScreen(
          session: const AuthSession(
            token: 'test',
            userId: '1',
            name: 'Test Viewer',
            email: 'viewer@example.com',
          ),
          authService: service,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.isLabelVisible, isTrue);

    await tester.tap(find.byTooltip('Updates'));
    await tester.pumpAndSettle();
    expect(find.text('YGNTV Updates'), findsOneWidget);
    expect(find.text('New YGNTV update'), findsOneWidget);
  });

  testWidgets('home marquee is hidden when empty and shown for Admin text', (
    tester,
  ) async {
    const session = AuthSession(
      token: 'test',
      userId: '1',
      name: 'Test Viewer',
      email: 'viewer@example.com',
    );
    Widget home(_FakeCustomerService service) => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: CustomerHomeScreen(
        session: session,
        authService: service,
        onSignOut: () async {},
      ),
    );

    await tester.pumpWidget(home(_FakeCustomerService()));
    await tester.pump();
    expect(find.byKey(const ValueKey('customer-home-marquee')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      home(
        _FakeCustomerService(
          marqueeEntries: const [
            TvHomeMarqueeEntry(
              content: 'Admin announcement',
              textColor: '#73C9FF',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('customer-home-marquee')), findsOneWidget);
  });

  testWidgets(
    'shared app header and bottom navigation stay fixed across tabs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: CustomerHomeScreen(
            session: const AuthSession(
              token: 'test',
              userId: '1',
              name: 'Test Viewer',
              email: 'viewer@example.com',
            ),
            authService: _FakeCustomerService(),
            onSignOut: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('customer-app-sticky-header')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customer-app-sticky-header')),
        findsOneWidget,
      );

      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customer-app-sticky-header')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('home bell hides the number when API omits unread_count', (
    tester,
  ) async {
    final service = _FakeCustomerService(
      notificationFeed: const TvNotificationFeed(
        notifications: [],
        unreadCount: 3,
        hasServerUnreadCount: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: CustomerHomeScreen(
          session: const AuthSession(
            token: 'test',
            userId: '1',
            name: 'Test Viewer',
            email: 'viewer@example.com',
          ),
          authService: service,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets(
    'Help & Support is in the customer Account menu and sends through the real service API',
    (tester) async {
      final service = _FakeCustomerService();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: AccountScreen(
              service: service,
              session: const AuthSession(
                token: 'test',
                userId: '1',
                name: 'Test Viewer',
                email: 'viewer@example.com',
              ),
              onSignOut: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);

      final helpEntry = find.text('Help & Support').first;
      await tester.scrollUntilVisible(
        helpEntry,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(helpEntry);
      await tester.pumpAndSettle();
      expect(find.text('Help & Support'), findsOneWidget);
      expect(
        find.text('How can we help with your subscription?'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Need help with Premium?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Need help with Premium?'), findsOneWidget);
      expect(service.supportStarts, 1);
      expect(service.supportSends, 1);
    },
  );
}
