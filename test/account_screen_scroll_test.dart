import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/account_screen.dart';
import 'package:ygntv_customer/screens/customer_home_screen.dart';

class _ProfileScrollService extends AuthService {
  _ProfileScrollService()
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  @override
  Future<TvProfileData> getProfile() async => TvProfileData(
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
      5,
      (index) => TvDevice(
        id: index + 1,
        name: 'Test device ${index + 1}',
        platform: 'Android',
        appVersion: '1.1.10',
        lastSeenAt: '2026-11-10T12:00:00Z',
      ),
    ),
  );

  @override
  Future<Map<String, dynamic>> getReferralOverview() async => {
    'referral_code': 'YGNTEST1234',
    'earned_total_ks': 0,
    'withdrawable_balance_ks': 0,
    'leaderboard': <Map<String, dynamic>>[],
    'withdrawal_requests': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> getDailySignInWheelOverview() async => {
    'can_spin': false,
    'next_spin_at': '2026-11-16T00:00:00Z',
    'rewards': <Map<String, dynamic>>[],
  };
}

class _FailingProfileService extends _ProfileScrollService {
  @override
  Future<TvProfileData> getProfile() async =>
      throw const AuthException('Profile refresh failed');
}

class _CountingProfileService extends _ProfileScrollService {
  int profileLoads = 0;

  @override
  Future<TvProfileData> getProfile() {
    profileLoads++;
    return super.getProfile();
  }
}

class _HomeShellScrollService extends _ProfileScrollService {
  int profileLoads = 0;

  @override
  Future<TvProfileData> getProfile() async {
    profileLoads++;
    return TvProfileData(
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
          appVersion: '1.1.10-TEST',
          lastSeenAt: '2026-11-10T12:00:00Z',
        ),
      ),
      screenTimeLast30DaysSeconds: 37 * 60,
      deviceLimit: 2,
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
  Future<List<TvHomeBanner>> getTopAdBanners() async => const [];

  @override
  Future<List<TvBlogPost>> getBlogPosts({int page = 1}) async => const [];

  @override
  Future<List<TvHomeMarqueeEntry>> getHomeMarqueeEntries() async => const [];

  @override
  Future<TvNotificationFeed> getNotifications() async =>
      const TvNotificationFeed(notifications: [], unreadCount: 0);

  @override
  Future<List<TvDownloadProgress>> getAndroidDownloads() async => const [];
}

const _session = AuthSession(
  token: 'test-token',
  userId: '1',
  name: 'Test Viewer',
  email: 'viewer@example.com',
);

Widget _accountApp({required Widget home}) =>
    MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: home);

void main() {
  testWidgets(
    'screen-time card region scrolls in both directions in the screenshot-sized Home shell',
    (tester) async {
      tester.view.physicalSize = const Size(702, 1566);
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _HomeShellScrollService();
      const systemInsets = EdgeInsets.only(top: 27, bottom: 27);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: systemInsets, viewPadding: systemInsets),
              child: CustomerHomeScreen(
                session: _session,
                authService: service,
                onSignOut: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final accountDestination = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Account'),
      );
      await tester.tap(accountDestination);
      await tester.pumpAndSettle();

      final account = find.byType(AccountScreen);
      expect(account, findsOneWidget);
      final scrollable = find.descendant(
        of: account,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      expect(
        find.descendant(of: account, matching: find.byType(RefreshIndicator)),
        findsOneWidget,
      );
      final listViewFinder = find.descendant(
        of: account,
        matching: find.byType(ListView),
      );
      expect(
        tester.widget<ListView>(listViewFinder).physics,
        isA<AlwaysScrollableScrollPhysics>(),
      );

      final screenTimeCard = find.byKey(
        const ValueKey('account-screen-time-card'),
      );
      for (
        var attempt = 0;
        attempt < 20 && screenTimeCard.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(scrollable, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(screenTimeCard, findsOneWidget);
      expect(
        find.descendant(
          of: screenTimeCard,
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: screenTimeCard, matching: find.byType(InkWell)),
        findsNothing,
      );

      final position = tester.state<ScrollableState>(scrollable).position;
      final viewport = tester.getRect(scrollable);
      final cardRect = tester.getRect(screenTimeCard);
      final screenshotCardTop = viewport.top + viewport.height * .77;
      final screenshotOffset =
          (position.pixels + cardRect.top - screenshotCardTop)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
      position.jumpTo(screenshotOffset);
      await tester.pumpAndSettle();

      Offset markedSwipeOrigin() {
        final rect = tester.getRect(screenTimeCard);
        final point = Offset(
          rect.left + rect.width * .62,
          rect.top + rect.height * .75,
        );
        expect(tester.getRect(scrollable).contains(point), isTrue);
        return point;
      }

      final placedCard = tester.getRect(screenTimeCard);
      expect(
        placedCard.top,
        closeTo(tester.getRect(scrollable).top + viewport.height * .77, 4),
      );
      expect(service.profileLoads, 1);

      final beforeUpwardSwipe = position.pixels;
      await tester.dragFrom(markedSwipeOrigin(), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(beforeUpwardSwipe));
      expect(service.profileLoads, 1);
      expect(tester.takeException(), isNull);

      final beforeDownwardSwipe = position.pixels;
      await tester.dragFrom(markedSwipeOrigin(), const Offset(0, 90));
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(beforeDownwardSwipe));
      expect(service.profileLoads, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      service.dispose();
    },
  );

  testWidgets(
    'repeated opposite swipes on the marked card settle without a scroll jump',
    (tester) async {
      tester.view.physicalSize = const Size(702, 1566);
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _HomeShellScrollService();
      const systemInsets = EdgeInsets.only(top: 27, bottom: 27);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: systemInsets, viewPadding: systemInsets),
              child: CustomerHomeScreen(
                session: _session,
                authService: service,
                onSignOut: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Account'),
        ),
      );
      await tester.pumpAndSettle();

      final account = find.byType(AccountScreen);
      final scrollable = find.descendant(
        of: account,
        matching: find.byType(Scrollable),
      );
      final card = find.byKey(const ValueKey('account-screen-time-card'));
      for (
        var attempt = 0;
        attempt < 20 && card.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(scrollable, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(card, findsOneWidget);

      final position = tester.state<ScrollableState>(scrollable).position;
      final viewport = tester.getRect(scrollable);
      final cardRect = tester.getRect(card);
      final desiredTop = viewport.top + viewport.height * .77;
      position.jumpTo(
        (position.pixels + cardRect.top - desiredTop)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      await tester.pumpAndSettle();

      Offset markedOrigin() {
        final rect = tester.getRect(card);
        return Offset(
          rect.left + rect.width * .62,
          rect.top + rect.height * .75,
        );
      }

      final deltas = [
        const Offset(0, 90),
        const Offset(0, -90),
        const Offset(0, 90),
        const Offset(0, -90),
      ];
      for (final delta in deltas) {
        await tester.dragFrom(markedOrigin(), delta);
        await tester.pump(const Duration(milliseconds: 80));
        expect(
          position.pixels,
          inInclusiveRange(position.minScrollExtent, position.maxScrollExtent),
        );
        expect(tester.takeException(), isNull);
      }

      await tester.pumpAndSettle();
      final settledOffset = position.pixels;
      await tester.pump(const Duration(milliseconds: 250));
      expect(position.pixels, closeTo(settledOffset, 1));
      expect(service.profileLoads, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      service.dispose();
    },
  );

  testWidgets(
    'at maxScrollExtent the reverse finger drag decreases Account pixels',
    (tester) async {
      tester.view.physicalSize = const Size(702, 1566);
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _HomeShellScrollService();
      const systemInsets = EdgeInsets.only(top: 27, bottom: 27);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: systemInsets, viewPadding: systemInsets),
              child: CustomerHomeScreen(
                session: _session,
                authService: service,
                onSignOut: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Account'),
        ),
      );
      await tester.pumpAndSettle();

      final account = find.byType(AccountScreen);
      final scrollable = find.descendant(
        of: account,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));

      final viewport = tester.getRect(scrollable);
      final start = Offset(viewport.center.dx, viewport.bottom - 4);
      final maxOffset = position.maxScrollExtent;

      // Finger moves upward (negative Y): this is further forward at the end
      // of a normal ListView and must remain clamped at maxScrollExtent.
      await tester.dragFrom(start, const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(maxOffset, 1));

      // To reverse toward the top, the finger moves downward (positive Y).
      final beforeReverse = position.pixels;
      await tester.dragFrom(start, const Offset(0, 90));
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(beforeReverse));
      expect(service.profileLoads, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      service.dispose();
    },
  );

  testWidgets(
    'reverse drag interrupts a bottom fling across a Home shell rebuild',
    (tester) async {
      tester.view.physicalSize = const Size(702, 1566);
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _HomeShellScrollService();
      const systemInsets = EdgeInsets.only(top: 27, bottom: 27);
      late StateSetter rebuildParent;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(padding: systemInsets, viewPadding: systemInsets),
                child: CustomerHomeScreen(
                  session: _session,
                  authService: service,
                  onSignOut: () async {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Account'),
        ),
      );
      await tester.pumpAndSettle();

      final account = find.byType(AccountScreen);
      final scrollable = find.descendant(
        of: account,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final maxOffset = position.maxScrollExtent;
      expect(position.pixels, closeTo(maxOffset, 1));

      final viewport = tester.getRect(scrollable);
      final start = Offset(viewport.center.dx, viewport.center.dy);
      await tester.flingFrom(start, const Offset(0, 320), 1500);
      await tester.pump(const Duration(milliseconds: 80));
      expect(position.pixels, lessThan(maxOffset));

      final beforeRebuild = position.pixels;
      rebuildParent(() {});
      await tester.pump();
      final rebuiltPosition = tester
          .state<ScrollableState>(scrollable)
          .position;
      expect(rebuiltPosition, same(position));
      expect(rebuiltPosition.pixels, lessThan(maxOffset));

      final beforeInterrupt = rebuiltPosition.pixels;
      await tester.dragFrom(start, const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(rebuiltPosition.pixels, greaterThan(beforeInterrupt));

      final beforeReverse = rebuiltPosition.pixels;
      await tester.dragFrom(start, const Offset(0, 90));
      await tester.pumpAndSettle();
      expect(rebuiltPosition.pixels, lessThan(beforeReverse));
      expect(beforeRebuild, lessThan(maxOffset));
      expect(service.profileLoads, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      service.dispose();
    },
  );

  testWidgets(
    'Home shell tab remount restores Account max offset and reverse scroll',
    (tester) async {
      tester.view.physicalSize = const Size(702, 1566);
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _HomeShellScrollService();
      const systemInsets = EdgeInsets.only(top: 27, bottom: 27);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: systemInsets, viewPadding: systemInsets),
              child: CustomerHomeScreen(
                session: _session,
                authService: service,
                onSignOut: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder destination(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );

      await tester.tap(destination('Account'));
      await tester.pumpAndSettle();
      var scrollable = find.descendant(
        of: find.byType(AccountScreen),
        matching: find.byType(Scrollable),
      );
      var position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final savedMaxOffset = position.maxScrollExtent;
      expect(position.pixels, closeTo(savedMaxOffset, 1));

      await tester.tap(destination('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsNothing);
      await tester.tap(destination('Account'));
      await tester.pumpAndSettle();
      scrollable = find.descendant(
        of: find.byType(AccountScreen),
        matching: find.byType(Scrollable),
      );
      position = tester.state<ScrollableState>(scrollable).position;
      // Profile-backed rows can settle to a slightly different extent after
      // the tab is remounted; require near-end restoration, then test at the
      // exact current max extent.
      expect(position.maxScrollExtent - position.pixels, lessThanOrEqualTo(20));
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, 1));

      final viewport = tester.getRect(scrollable);
      final beforeReverse = position.pixels;
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.bottom - 4),
        const Offset(0, 90),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(beforeReverse));
      expect(service.profileLoads, 2);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      service.dispose();
    },
  );

  testWidgets(
    'collapsing signed-in devices leaves Profile scrolling responsive',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _accountApp(
          home: Scaffold(
            body: AccountScreen(
              service: _ProfileScrollService(),
              session: _session,
              onSignOut: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      final devicesTile = find.text('Logged In Device');
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(devicesTile);
      await tester.pumpAndSettle();
      await tester.tap(devicesTile);
      await tester.pump();
      expect(find.text('Test device 1'), findsOneWidget);

      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await tester.ensureVisible(devicesTile);
      await tester.pumpAndSettle();
      await tester.tap(devicesTile);
      await tester.pump();
      expect(find.text('Test device 1'), findsNothing);

      await tester.dragUntilVisible(
        find.text('Account'),
        scrollable,
        const Offset(0, 240),
      );
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
    },
  );

  testWidgets(
    'pull-to-refresh on Account does not throw during scroll gesture',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _CountingProfileService();
      await tester.pumpWidget(
        _accountApp(
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
      expect(service.profileLoads, 1);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 420));
      await tester.pumpAndSettle();

      expect(service.profileLoads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Profile scroll position is restored after leaving the tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bucket = PageStorageBucket();
    var showProfile = true;
    late StateSetter updateParent;
    await tester.pumpWidget(
      _accountApp(
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateParent = setState;
                return showProfile
                    ? AccountScreen(
                        service: _ProfileScrollService(),
                        session: _session,
                        onSignOut: () async {},
                      )
                    : const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -420));
    await tester.pumpAndSettle();
    final beforeLeave = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(beforeLeave, greaterThan(0));

    updateParent(() => showProfile = false);
    await tester.pumpAndSettle();
    updateParent(() => showProfile = true);
    await tester.pumpAndSettle();

    final restoredScrollable = find.byType(Scrollable).first;
    final restoredPosition = tester
        .state<ScrollableState>(restoredScrollable)
        .position;
    final expectedOffset = beforeLeave
        .clamp(
          restoredPosition.minScrollExtent,
          restoredPosition.maxScrollExtent,
        )
        .toDouble();
    // The compact Account layout changes content above the saved position;
    // allow a small remapping while still requiring a nearby restored offset.
    expect(
      (restoredPosition.pixels - expectedOffset).abs(),
      lessThanOrEqualTo(12),
    );
  });

  testWidgets('Account quick actions are described, paired, and tappable', (
    tester,
  ) async {
    String? copiedUid;
    var updateChecks = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        final arguments = call.arguments;
        if (call.method == 'Clipboard.setData' && arguments is Map) {
          copiedUid = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _accountApp(
        home: Scaffold(
          body: AccountScreen(
            service: _ProfileScrollService(),
            session: _session,
            onSignOut: () async {},
            onCheckForUpdates: () async {
              updateChecks++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Viewer'), findsOneWidget);
    expect(find.text('viewer@example.com'), findsOneWidget);
    expect(find.text('UID: ${_session.userId}'), findsOneWidget);
    expect(find.byTooltip('Copy UID'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-profile-avatar')),
        matching: find.text('T'),
      ),
      findsOneWidget,
    );
    expect(find.text('Plans & membership codes.'), findsOneWidget);
    expect(find.text('Latest private TEST app.'), findsOneWidget);
    expect(
      find.text('500 Ks/month per invited Premium member.'),
      findsOneWidget,
    );
    expect(find.text('Choose reward within 7 days.'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);
    expect(find.byIcon(Icons.redeem_rounded), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);

    final subscriptionCard = find.byKey(
      const ValueKey('account-action-subscription'),
    );
    final updateCard = find.byKey(const ValueKey('account-action-update'));
    final referralCard = find.byKey(const ValueKey('account-action-referral'));
    final luckyBoxCard = find.byKey(const ValueKey('account-action-lucky-box'));
    expect(
      find.descendant(
        of: find.byType(AccountScreen),
        matching: find.byType(AspectRatio),
      ),
      findsNothing,
    );
    for (final card in [
      subscriptionCard,
      updateCard,
      referralCard,
      luckyBoxCard,
    ]) {
      final height = tester.getRect(card).height;
      expect(height, greaterThanOrEqualTo(68));
      expect(height, lessThan(120));
    }
    expect(
      tester.getRect(subscriptionCard).center.dy,
      closeTo(tester.getRect(updateCard).center.dy, 1),
    );
    expect(
      tester.getRect(subscriptionCard).center.dx,
      lessThan(tester.getRect(updateCard).center.dx),
    );
    expect(
      tester.getRect(referralCard).center.dy,
      closeTo(tester.getRect(luckyBoxCard).center.dy, 1),
    );
    expect(
      tester.getRect(referralCard).center.dx,
      lessThan(tester.getRect(luckyBoxCard).center.dx),
    );

    await tester.tap(find.byTooltip('Copy UID'));
    await tester.pumpAndSettle();
    expect(copiedUid, _session.userId);
    expect(find.text('UID copied.'), findsOneWidget);

    await tester.tap(updateCard);
    await tester.pumpAndSettle();
    expect(updateChecks, 1);

    final refer = find.text('Refer & Earn');
    final spin = find.text('Daily Sign In Bonus (Lucky Box)');
    await tester.ensureVisible(refer);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(referralCard).center.dy,
      closeTo(tester.getRect(luckyBoxCard).center.dy, 1),
    );
    expect(
      tester.getRect(referralCard).center.dx,
      lessThan(tester.getRect(luckyBoxCard).center.dx),
    );

    await tester.tap(refer);
    await tester.pumpAndSettle();
    expect(find.text('YGNTEST1234'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('YGNTEST1234'), findsNothing);

    await tester.ensureVisible(spin);
    await tester.pumpAndSettle();
    await tester.tap(spin);
    await tester.pumpAndSettle();
    expect(find.text('Daily Sign In Bonus (Lucky Box)'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Bonus history'),
      find.byType(Scrollable).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonus history'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign Out'));
    expect(find.text('Help & Support (24/7)'), findsOneWidget);
    expect(find.text('Connect With Us'), findsOneWidget);
    expect(find.text('Logged In Device'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets(
    'bottom-edge and reverse drags stay stable with expanded device rows',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in const [Size(320, 640), Size(360, 640)]) {
        tester.view.physicalSize = size;
        final service = _CountingProfileService();
        await tester.pumpWidget(
          _accountApp(
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

        final scrollable = find.byType(Scrollable).first;
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(service.profileLoads, 1);

        Future<void> dragToBottom() async {
          for (
            var attempt = 0;
            attempt < 30 && position.pixels < position.maxScrollExtent - 1;
            attempt++
          ) {
            await tester.drag(scrollable, const Offset(0, -240));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(position.pixels, closeTo(position.maxScrollExtent, 1));
        }

        Future<void> exerciseBottomBoundary() async {
          final bottom = position.maxScrollExtent;
          expect(position.pixels, closeTo(bottom, 1));
          final viewport = tester.getRect(scrollable);
          final edgeStart = Offset(viewport.center.dx, viewport.bottom - 3);

          await tester.dragFrom(edgeStart, const Offset(0, -90));
          await tester.pumpAndSettle();
          expect(position.pixels, closeTo(position.maxScrollExtent, 1));
          expect(service.profileLoads, 1);
          expect(tester.takeException(), isNull);

          final beforeReverse = position.pixels;
          await tester.dragFrom(edgeStart, const Offset(0, 90));
          await tester.pumpAndSettle();
          expect(position.pixels, lessThan(beforeReverse));
          expect(
            position.pixels,
            greaterThanOrEqualTo(position.minScrollExtent),
          );
          expect(service.profileLoads, 1);
          expect(tester.takeException(), isNull);

          await dragToBottom();
        }

        await dragToBottom();
        expect(
          find.text('TEST BUILD · Private Android customer app · YGNTV.org'),
          findsOneWidget,
        );
        await exerciseBottomBoundary();

        final devicesTile = find.text('Logged In Device');
        await tester.ensureVisible(devicesTile);
        await tester.pumpAndSettle();
        await tester.tap(devicesTile);
        await tester.pumpAndSettle();
        expect(find.text('Test device 5'), findsOneWidget);
        expect(service.profileLoads, 1);

        await dragToBottom();
        await exerciseBottomBoundary();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'device card remains tappable near the fixed navigation bar with bottom scroll runway',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _accountApp(
          home: Scaffold(
            appBar: AppBar(toolbarHeight: 62),
            body: SafeArea(
              top: false,
              child: AccountScreen(
                service: _ProfileScrollService(),
                session: _session,
                onSignOut: () async {},
              ),
            ),
            bottomNavigationBar: NavigationBar(
              height: 67,
              selectedIndex: 4,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.movie_rounded),
                  label: 'Movies',
                ),
                NavigationDestination(
                  icon: Icon(Icons.live_tv_rounded),
                  label: 'Series',
                ),
                NavigationDestination(
                  icon: Icon(Icons.article_rounded),
                  label: 'Blog',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_rounded),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final navigationBar = tester.getRect(find.byType(NavigationBar));
      var viewport = tester.getRect(scrollable);
      expect(viewport.bottom, lessThanOrEqualTo(navigationBar.top));

      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final devicesTile = find.text('Logged In Device');
      await tester.ensureVisible(devicesTile);
      await tester.pump();

      viewport = tester.getRect(scrollable);
      var titleRect = tester.getRect(devicesTile);
      final targetY = viewport.bottom - 28;
      final targetOffset = (position.pixels + titleRect.center.dy - targetY)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      position.jumpTo(targetOffset);
      await tester.pump();

      viewport = tester.getRect(scrollable);
      titleRect = tester.getRect(devicesTile);
      expect(titleRect.center.dy, lessThan(viewport.bottom));
      expect(titleRect.bottom, lessThan(viewport.bottom));
      await tester.tap(devicesTile);
      await tester.pump();
      expect(find.text('Test device 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final edgeStart = Offset(viewport.center.dx, viewport.bottom - 4);
      final beforeUpwardDrag = position.pixels;
      await tester.dragFrom(edgeStart, const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(beforeUpwardDrag));
      expect(tester.takeException(), isNull);

      final beforeDownwardDrag = position.pixels;
      await tester.dragFrom(edgeStart, const Offset(0, 55));
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(beforeDownwardDrag));
      expect(tester.takeException(), isNull);

      while (position.pixels < position.maxScrollExtent - 1) {
        await tester.drag(scrollable, const Offset(0, -240));
        await tester.pumpAndSettle();
      }
      final footer = tester.getRect(
        find.text('TEST BUILD · Private Android customer app · YGNTV.org'),
      );
      expect(footer.bottom, lessThanOrEqualTo(navigationBar.top - 90));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile refresh failure keeps signed-in identity visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _accountApp(
        home: Scaffold(
          body: AccountScreen(
            service: _FailingProfileService(),
            session: _session,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Viewer'), findsOneWidget);
    expect(find.text('viewer@example.com'), findsOneWidget);
    expect(find.text('UID: ${_session.userId}'), findsOneWidget);
    expect(
      find.text(
        'Could not refresh account details. Showing your signed-in account info.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('empty profile identity uses a neutral initial and no fake UID', (
    tester,
  ) async {
    await tester.pumpWidget(
      _accountApp(
        home: Scaffold(
          body: AccountScreen(
            service: _FailingProfileService(),
            session: const AuthSession(
              token: 'test-token',
              userId: '',
              name: 'Yangon TV viewer',
              email: '',
            ),
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Account'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-profile-avatar')),
        matching: find.text('U'),
      ),
      findsOneWidget,
    );
    expect(find.text('Yangon TV viewer'), findsNothing);
    expect(find.textContaining('UID:'), findsNothing);
    expect(find.byTooltip('Copy UID'), findsNothing);
  });
}
