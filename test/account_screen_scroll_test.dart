import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/account_screen.dart';
import 'package:ygntv_customer/screens/customer_home_screen.dart';

class _CustomerUiService extends AuthService {
  _CustomerUiService({
    TvProfileData? profile,
    this.blogPosts = const [],
    this.watchHistory = const [],
    this.watchHistoryPages = const {},
    this.bonusHistory = const [],
  }) : profile = profile ?? _defaultProfile(),
       super(client: MockClient((_) async => http.Response('{}', 200)));

  final TvProfileData profile;
  final List<TvBlogPost> blogPosts;
  final List<TvLibraryEntry> watchHistory;
  final Map<int, List<TvLibraryEntry>> watchHistoryPages;
  final List<Map<String, dynamic>> bonusHistory;

  @override
  Future<TvProfileData> getProfile() async => profile;

  @override
  Future<List<CatalogItem>> loadCatalog(
    String kind, {
    int page = 1,
    int perPage = 48,
  }) async => const [];

  @override
  Future<List<TvLibraryEntry>> getContinueWatching() async => const [];

  @override
  Future<List<TvLibraryEntry>> getWatchHistory({int page = 1}) async =>
      watchHistoryPages[page] ?? watchHistory;

  @override
  Future<List<TvLibraryEntry>> getSavedContent({int page = 1}) async =>
      const [];

  @override
  Future<List<TvDownloadProgress>> getAndroidDownloads() async => const [];

  @override
  Future<List<TvHomeBanner>> getTopAdBanners() async => const [];

  @override
  Future<List<TvBlogPost>> getBlogPosts({int page = 1}) async => blogPosts;

  @override
  Future<List<TvHomeMarqueeEntry>> getHomeMarqueeEntries() async => const [];

  @override
  Future<TvNotificationFeed> getNotifications() async =>
      const TvNotificationFeed(notifications: [], unreadCount: 0);

  @override
  Future<Map<String, dynamic>> getDailySignInWheelOverview() async => {
    'can_spin': false,
    'next_spin_at': '2026-11-16T00:00:00Z',
    'rewards': bonusHistory,
  };
}

TvProfileData _defaultProfile() => TvProfileData(
  name: 'Test Viewer',
  email: 'viewer@example.com',
  displayName: 'Test Viewer',
  entitlement: const TvEntitlement(
    active: false,
    planKey: null,
    planLabel: null,
    validFrom: null,
    validUntil: null,
  ),
  devices: List.generate(
    2,
    (index) => TvDevice(
      id: index + 1,
      name: 'Test phone ${index + 1}',
      platform: 'Android',
      appVersion: '1.1.8-TEST',
      lastSeenAt: '2026-11-10T12:00:00Z',
    ),
  ),
  deviceLimit: 2,
);

const _session = AuthSession(
  token: 'test-token',
  userId: '12345',
  name: 'Test Viewer',
  email: 'viewer@example.com',
);

Widget _home(_CustomerUiService service) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: CustomerHomeScreen(
    session: _session,
    authService: service,
    onSignOut: () async {},
  ),
);

void main() {
  testWidgets('bottom navigation uses the reference-style quick menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _CustomerUiService();
    await tester.pumpWidget(_home(service));
    await tester.pumpAndSettle();

    final bottom = find.byKey(const ValueKey('customer-bottom-nav'));
    expect(bottom, findsOneWidget);
    expect(
      find.descendant(of: bottom, matching: find.byType(Image)),
      findsNothing,
    );
    for (final title in ['Home', 'Movies', 'Series', 'Account']) {
      expect(
        find.descendant(of: bottom, matching: find.text(title)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: bottom, matching: find.text('Blog')),
      findsNothing,
    );
    for (final destination in ['home', 'movie', 'series', 'account']) {
      expect(find.byKey(ValueKey('customer-nav-$destination')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('customer-nav-quick-actions')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('customer-nav-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-profile-card')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('customer-nav-quick-actions')));
    await tester.pumpAndSettle();
    for (final label in ['Subscription', 'Daily Bonus', 'Refer & Earn']) {
      expect(find.text(label), findsOneWidget);
      final labelText = tester.widget<Text>(find.text(label));
      expect(labelText.style?.decoration, TextDecoration.none);
      expect(labelText.style?.decorationColor, Colors.transparent);
    }
    for (final destination in ['subscription', 'daily-bonus', 'referral']) {
      expect(
        find.byKey(ValueKey('customer-quick-menu-$destination')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(ValueKey('customer-quick-menu-$destination')),
            )
            .onTap,
        isNotNull,
      );
    }
    expect(
      find.byKey(const ValueKey('customer-nav-quick-actions-close')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('customer-quick-menu-subscription')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Premium Subscription'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Account shows requested actions and honest empty data states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _CustomerUiService();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            service: service,
            session: _session,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final title in [
      'Activity History',
      '24/7 Support',
      'Connect With Us',
      'Logged In Devices',
      'Sign Out',
    ]) {
      expect(
        find.text(title),
        findsOneWidget,
        reason: '$title should be available.',
      );
    }
    expect(find.text('Screen Time'), findsOneWidget);
    expect(find.text('Usage data is unavailable.'), findsOneWidget);
    expect(find.text('No recent watch activity yet.'), findsOneWidget);
    expect(find.textContaining('Daily Lucky Box'), findsNothing);
    expect(find.textContaining('Premium Plan Renewed'), findsNothing);
    expect(find.text('Movie Library'), findsNothing);
    expect(find.text('My Library'), findsNothing);
    expect(find.text('2 of 2 allowed devices signed in'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets(
    'Account preview uses real watch history and profile screen time',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _CustomerUiService(
        profile: TvProfileData(
          name: 'Test Viewer',
          email: 'viewer@example.com',
          displayName: 'Test Viewer',
          entitlement: const TvEntitlement(
            active: false,
            planKey: null,
            planLabel: null,
            validFrom: null,
            validUntil: null,
          ),
          devices: const [],
          screenTimeLast30DaysSeconds: 3660,
        ),
        watchHistory: const [
          TvLibraryEntry(
            contentType: 'movie',
            contentId: 41,
            title: 'Test Movie From History',
            posterUrl: '',
            year: '2026',
            positionSeconds: 120,
            durationSeconds: 7200,
            completed: false,
            lastWatchedAt: '2026-11-22T12:00:00Z',
          ),
          TvLibraryEntry(
            contentType: 'episode',
            contentId: 42,
            title: 'Test Series Episode From History',
            posterUrl: '',
            year: '2026',
            positionSeconds: 90,
            durationSeconds: 2400,
            completed: false,
            lastWatchedAt: '2026-11-21T12:00:00Z',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: AccountScreen(
              service: service,
              session: _session,
              onSignOut: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Movie From History'), findsOneWidget);
      expect(find.text('Test Series Episode From History'), findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('recent-activity-icon-movie')),
            )
            .icon,
        Icons.movie_outlined,
      );
      expect(
        tester
            .widget<Icon>(
              find.byKey(const ValueKey('recent-activity-icon-episode')),
            )
            .icon,
        Icons.live_tv_outlined,
      );
      expect(find.text('1 hr 1 min in the last 30 days'), findsOneWidget);
      expect(find.text('Daily Lucky Box'), findsNothing);
      expect(find.text('Premium Plan Renewed'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets(
    'Activity History shows four requested tabs and no Movie Library',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _CustomerUiService(
        bonusHistory: const [
          {
            'id': 77,
            'reward_code': 'one_movie',
            'selection_status': 'selected',
            'selection': {'title': 'Obsession'},
            'claimed_at': '2026-11-22T12:00:00Z',
          },
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: AccountScreen(
              service: service,
              session: _session,
              onSignOut: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-view-all-activity')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('activity-history-screen')),
        findsOneWidget,
      );
      for (final tab in ['Watch List', 'Watched', 'Downloaded']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('Claimed Bonus'), findsOneWidget);
      final subscriptionTab = find.text('Subscription History');
      await tester.ensureVisible(subscriptionTab);
      expect(subscriptionTab, findsOneWidget);
      expect(find.text('Movie Library'), findsNothing);

      await tester.tap(subscriptionTab);
      await tester.pumpAndSettle();
      expect(find.text('Subscription history is unavailable'), findsOneWidget);

      final claimedBonusTab = find.text('Claimed Bonus');
      await tester.ensureVisible(claimedBonusTab);
      await tester.tap(claimedBonusTab);
      await tester.pumpAndSettle();
      expect(find.text('1 Movie'), findsOneWidget);
      expect(find.text('Selected: Obsession'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets(
    'Premium profile shows only the blue UID check and remaining time',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final expires = DateTime.now().add(const Duration(days: 5, hours: 4));
      final service = _CustomerUiService(
        profile: TvProfileData(
          name: 'Premium Viewer',
          email: 'premium@example.com',
          displayName: 'Premium Viewer',
          entitlement: TvEntitlement(
            active: true,
            planKey: 'welcome_trial',
            planLabel: 'WELCOME_TRIAL',
            validFrom: null,
            validUntil: expires.toUtc().toIso8601String(),
          ),
          devices: const [],
          deviceLimit: 2,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: AccountScreen(
              service: service,
              session: _session,
              onSignOut: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uidRow = find.byKey(const ValueKey('account-profile-uid-row'));
      final uid = find.text('UID: ${_session.userId}');
      final check = find.byKey(const ValueKey('account-premium-verified'));
      expect(find.descendant(of: uidRow, matching: uid), findsOneWidget);
      expect(find.descendant(of: uidRow, matching: check), findsOneWidget);
      expect(tester.widget<Icon>(check).color, const Color(0xFF39A5FF));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('account-premium-remaining')),
            )
            .data,
        'Premium · 5 days left',
      );
      expect(find.textContaining('ACTIVE'), findsNothing);
      expect(find.textContaining('WELCOME_TRIAL'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets('View All loads every available Watch History page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _CustomerUiService(
      watchHistoryPages: const {
        1: [
          TvLibraryEntry(
            contentType: 'movie',
            contentId: 51,
            title: 'Newest History Item',
            posterUrl: '',
            year: '2026',
            positionSeconds: 20,
            durationSeconds: 600,
            completed: false,
            lastWatchedAt: '2026-11-22T12:00:00Z',
          ),
        ],
        2: [
          TvLibraryEntry(
            contentType: 'episode',
            contentId: 52,
            title: 'Older History Item',
            posterUrl: '',
            year: '2025',
            positionSeconds: 20,
            durationSeconds: 600,
            completed: false,
            lastWatchedAt: '2026-11-20T12:00:00Z',
          ),
        ],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: AccountScreen(
            service: service,
            session: _session,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-view-all-activity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watched'));
    await tester.pumpAndSettle();

    expect(find.text('Newest History Item'), findsOneWidget);
    expect(find.text('Older History Item'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('home keeps Blog as a swipeable slider, not a navigation tab', (
    tester,
  ) async {
    const posts = [
      TvBlogPost(
        id: '1',
        slug: 'story-one',
        title: 'Story One',
        excerpt: 'First story.',
        date: '2026-11-20',
        category: 'Updates',
        author: 'YGNTV',
        image: '',
      ),
      TvBlogPost(
        id: '2',
        slug: 'story-two',
        title: 'Story Two',
        excerpt: 'Second story.',
        date: '2026-11-21',
        category: 'Updates',
        author: 'YGNTV',
        image: '',
      ),
    ];
    final service = _CustomerUiService(blogPosts: posts);
    await tester.pumpWidget(_home(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-blog-hero-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-nav-blog')), findsNothing);
    expect(find.text('Story One'), findsOneWidget);
    final slider = find.byKey(const ValueKey('home-blog-hero-slider'));
    await tester.ensureVisible(slider);
    final pageView = find.descendant(
      of: slider,
      matching: find.byType(PageView),
    );
    final controller = tester.widget<PageView>(pageView).controller!;
    await tester.fling(pageView, const Offset(-520, 0), 1200);
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(1, .01));
    expect(find.text('Story Two'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
