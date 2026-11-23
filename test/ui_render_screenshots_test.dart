// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as vp;
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/account_screen.dart';
import 'package:ygntv_customer/screens/customer_home_screen.dart';
import 'package:ygntv_customer/screens/daily_signin_wheel_screen.dart';
import 'package:ygntv_customer/screens/search_screen.dart';
import 'package:ygntv_customer/screens/video_player_screen.dart';

const _captureKey = ValueKey<String>('ui-render-capture');

String _findMaterialFontsPath() {
  var directory = Directory(Platform.resolvedExecutable).parent;
  for (var depth = 0; depth < 8; depth++) {
    final candidate = Directory(
      '${directory.path}${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}material_fonts',
    );
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  throw StateError('Flutter SDK Material fonts were not found.');
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}

Future<void> _loadTestFonts() async {
  final materialFontsPath = _findMaterialFontsPath();
  final roboto = FontLoader('Roboto')
    ..addFont(
      _fontData(
        '$materialFontsPath${Platform.pathSeparator}Roboto-Regular.ttf',
      ),
    );
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      _fontData(
        '$materialFontsPath${Platform.pathSeparator}MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

const _session = AuthSession(
  token: 'render-test-token',
  userId: 'demo-1042',
  name: 'Demo Viewer',
  email: 'viewer@example.test',
);

const _catalogItems = <CatalogItem>[
  CatalogItem(
    id: 11,
    title: 'After the Monsoon',
    posterUrl: '',
    kind: 'movie',
    year: '2025',
    genres: ['Drama'],
  ),
  CatalogItem(
    id: 12,
    title: 'Midnight Express',
    posterUrl: '',
    kind: 'movie',
    year: '2024',
    genres: ['Action'],
  ),
  CatalogItem(
    id: 21,
    title: 'The Silent Sea',
    posterUrl: '',
    kind: 'series',
    year: '2025',
    genres: ['Mystery'],
  ),
  CatalogItem(
    id: 22,
    title: 'A River Between Us',
    posterUrl: '',
    kind: 'series',
    year: '2023',
    genres: ['Drama'],
  ),
];

const _watchHistory = <TvLibraryEntry>[
  TvLibraryEntry(
    contentType: 'movie',
    contentId: 11,
    title: 'After the Monsoon',
    posterUrl: '',
    year: '2025',
    positionSeconds: 1600,
    durationSeconds: 7200,
    completed: false,
    lastWatchedAt: '2026-11-22T12:00:00Z',
  ),
  TvLibraryEntry(
    contentType: 'episode',
    contentId: 21,
    title: 'The Silent Sea · Episode 03',
    posterUrl: '',
    year: '2025',
    positionSeconds: 900,
    durationSeconds: 2400,
    completed: false,
    lastWatchedAt: '2026-11-21T12:00:00Z',
  ),
];

class _RenderService extends AuthService {
  _RenderService({
    this.failHomeRequests = false,
    this.failSearch = false,
    this.failHistoryOnce = false,
  }) : super(client: MockClient((_) async => http.Response('{}', 200)));

  final bool failHomeRequests;
  final bool failSearch;
  final bool failHistoryOnce;
  final searchErrorCompleter = Completer<List<CatalogItem>>();
  int _historyCalls = 0;
  int _spinCalls = 0;

  @override
  Future<TvProfileData> getProfile() async => TvProfileData(
    name: 'Demo Viewer',
    email: 'viewer@example.test',
    displayName: 'Demo Viewer',
    entitlement: const TvEntitlement(
      active: false,
      planKey: null,
      planLabel: null,
      validFrom: null,
      validUntil: null,
    ),
    devices: const [
      TvDevice(
        id: 1,
        name: 'Demo phone',
        platform: 'Android',
        appVersion: '1.0',
        lastSeenAt: '2026-11-22T12:00:00Z',
      ),
      TvDevice(
        id: 2,
        name: 'Demo tablet',
        platform: 'Android',
        appVersion: '1.0',
        lastSeenAt: '2026-11-20T12:00:00Z',
      ),
    ],
    screenTimeLast30DaysSeconds: 3660,
    deviceLimit: 2,
  );

  @override
  Future<List<CatalogItem>> loadCatalog(
    String kind, {
    int page = 1,
    int perPage = 48,
  }) async {
    if (failHomeRequests) throw AuthException('HTTP 503 test detail');
    if (page > 1) return const [];
    return _catalogItems.where((item) => item.kind == kind).toList();
  }

  @override
  Future<List<CatalogItem>> searchCatalog(String query) {
    if (failSearch) return searchErrorCompleter.future;
    return Future.value(_catalogItems);
  }

  @override
  Future<List<TvLibraryEntry>> getContinueWatching() async {
    if (failHomeRequests) throw AuthException('HTTP 503 test detail');
    return const [];
  }

  @override
  Future<List<TvLibraryEntry>> getWatchHistory({int page = 1}) async {
    _historyCalls++;
    if (failHistoryOnce && _historyCalls == 1) {
      throw AuthException('HTTP 503 internal test detail');
    }
    return _watchHistory;
  }

  @override
  Future<List<TvLibraryEntry>> getSavedContent({int page = 1}) async =>
      const [];

  @override
  Future<List<TvDownloadProgress>> getAndroidDownloads() async => const [];

  @override
  Future<List<TvHomeBanner>> getTopAdBanners() async {
    if (failHomeRequests) throw AuthException('HTTP 503 test detail');
    return const [
      TvHomeBanner(
        id: 1,
        name: 'YGNTV Featured',
        imageUrl: '',
        displayOrder: 1,
        buttonName: 'Explore',
      ),
    ];
  }

  @override
  Future<List<TvBlogPost>> getBlogPosts({int page = 1}) async {
    if (failHomeRequests) throw AuthException('HTTP 503 test detail');
    return const [
      TvBlogPost(
        id: 'demo-story',
        slug: 'demo-story',
        title: 'Stories worth staying up for',
        excerpt: 'Fresh updates from the YGNTV team.',
        date: '2026-11-22',
        category: 'YGNTV UPDATES',
        author: 'YGNTV',
        image: '',
      ),
    ];
  }

  @override
  Future<List<TvHomeMarqueeEntry>> getHomeMarqueeEntries() async => const [];

  @override
  Future<TvNotificationFeed> getNotifications() async =>
      const TvNotificationFeed(notifications: [], unreadCount: 0);

  @override
  Future<Map<String, dynamic>> getDailySignInWheelOverview() async => {
    'can_spin': _spinCalls == 0,
    'next_spin_at': DateTime.now()
        .add(const Duration(hours: 12))
        .toIso8601String(),
    'rewards': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> spinDailySignInWheel({
    required String spinKey,
  }) async {
    _spinCalls++;
    final spin = <String, dynamic>{
      'id': 'render-spin-1',
      'reward_code': 'two_movies',
      'selection_status': 'pending',
    };
    return {
      'spin': spin,
      'overview': {
        'can_spin': false,
        'rewards': [spin],
      },
    };
  }
}

class _RenderVideoPlatform extends vp.VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<vp.VideoEvent>> _streams = {};
  final Map<int, Duration> _positions = {};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(vp.DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<vp.VideoEvent>();
    _streams[playerId] = stream;
    _positions[playerId] = const Duration(seconds: 145);
    stream.add(
      vp.VideoEvent(
        eventType: vp.VideoEventType.initialized,
        duration: const Duration(seconds: 723),
        size: const Size(1920, 1080),
      ),
    );
    return playerId;
  }

  @override
  Stream<vp.VideoEvent> videoEventsFor(int playerId) =>
      _streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    final stream = _streams.remove(playerId);
    _positions.remove(playerId);
    if (stream != null) await stream.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Widget buildView(int playerId) => const ColoredBox(
    color: Color(0xFF111116),
    child: Center(child: Icon(Icons.movie_outlined, color: Colors.white24)),
  );
}

Widget _captureApp(Widget screen) => RepaintBoundary(
  key: _captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: screen,
  ),
);

Widget _videoPlayerLauncher(Widget player) => RepaintBoundary(
  key: _captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context)
                .push<void>(MaterialPageRoute<void>(builder: (_) => player)),
            child: const Text('Open video'),
          ),
        ),
      ),
    ),
  ),
);

CustomerHomeScreen _home(_RenderService service) => CustomerHomeScreen(
  session: _session,
  authService: service,
  onSignOut: () async {},
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(WidgetTester tester, String fileName) async {
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('goldens/$fileName'),
  );
}

void main() {
  setUpAll(_loadTestFonts);

  testWidgets('quick menu labels render without underlines', (tester) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService();
    await tester.pumpWidget(_captureApp(_home(service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-nav-quick-actions')));
    await tester.pumpAndSettle();

    for (final label in ['Subscription', 'Daily Bonus', 'Refer & Earn']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontFamily, 'Roboto');
      expect(text.style?.inherit, isFalse);
      expect(text.style?.decoration, TextDecoration.none);
      expect(text.style?.decorationColor, Colors.transparent);
    }
    await _capture(tester, 'customer_quick_menu.png');
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Account profile/history and bottom Sign Out render cleanly', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService();
    await tester.pumpWidget(_captureApp(_home(service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-nav-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-profile-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recent-activity-icon-movie')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recent-activity-icon-episode')),
      findsOneWidget,
    );
    await _capture(tester, 'account_profile_activity.png');

    final signOut = find.byKey(const ValueKey('account-sign-out-action'));
    await tester.dragUntilVisible(
      signOut,
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final signOutRect = tester.getRect(signOut);
    final navRect = tester.getRect(
      find.byKey(const ValueKey('customer-bottom-nav')),
    );
    final gap = navRect.top - signOutRect.bottom;
    expect(gap, greaterThanOrEqualTo(0));
    expect(gap, lessThanOrEqualTo(36));
    await _capture(tester, 'account_signout_spacing.png');

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Movie and Series catalogs render search before genres', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService();
    await tester.pumpWidget(_captureApp(_home(service)));
    await tester.pumpAndSettle();

    for (final item in [
      ('movie', 'customer-nav-movie', 'customer_movie_catalog.png'),
      ('series', 'customer-nav-series', 'customer_series_catalog.png'),
    ]) {
      await tester.tap(find.byKey(ValueKey(item.$2)));
      await tester.pumpAndSettle();
      final searchRect = tester.getRect(
        find.byKey(const ValueKey('catalog-search-field')),
      );
      final genreRect = tester.getRect(
        find.byKey(const ValueKey('catalog-genre-filters')),
      );
      expect(searchRect.bottom, lessThan(genreRect.top));
      expect(genreRect.top - searchRect.bottom, lessThanOrEqualTo(20));
      expect(find.textContaining('48 movies'), findsNothing);
      expect(find.textContaining('48 series'), findsNothing);
      await _capture(tester, item.$3);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Lucky Box ready and reward-reveal screens render', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService();
    await tester.pumpWidget(
      _captureApp(DailySignInWheelScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Claim Lucky Box'), findsOneWidget);
    await _capture(tester, 'lucky_box_ready.png');

    await tester.tap(find.widgetWithText(FilledButton, 'Claim Lucky Box'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4150));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-reward-dialog-title')),
      findsOneWidget,
    );
    expect(find.text('FREE WATCH 2 MOVIES'), findsWidgets);
    expect(find.text('DAILY REWARD UNLOCKED'), findsOneWidget);
    await _capture(tester, 'lucky_box_reward_reveal.png');

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('video player controls render with a fake platform', (
    tester,
  ) async {
    _setSize(tester, const Size(844, 480));
    final previousPlatform = vp.VideoPlayerPlatform.instance;
    vp.VideoPlayerPlatform.instance = _RenderVideoPlatform();
    addTearDown(() => vp.VideoPlayerPlatform.instance = previousPlatform);

    final service = _RenderService();
    await tester.pumpWidget(
      _videoPlayerLauncher(
        VideoPlayerScreen(
          service: service,
          url: 'https://example.test/demo.mp4',
          headers: const {},
          title: 'The Silent Sea · Episode 03',
          posterUrl: '',
          contentType: 'episode',
          contentId: 21,
          initialPosition: 145,
          saveProgress: false,
        ),
      ),
    );
    await tester.tap(find.text('Open video'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('video-play-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-skip-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-skip-forward')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-progress-slider')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Playback speed'), findsOneWidget);
    expect(
      find.byTooltip('Exit landscape').evaluate().isNotEmpty ||
          find.byTooltip('Landscape fullscreen').evaluate().isNotEmpty,
      isTrue,
    );
    await _capture(tester, 'video_player_controls.png');

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Home loading errors show compact retry states', (tester) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService(failHomeRequests: true);
    await tester.pumpWidget(_captureApp(_home(service)));
    await tester.pumpAndSettle();

    expect(
      find.text('Featured banners are temporarily unavailable.'),
      findsOneWidget,
    );
    expect(
      find.text('YGNTV updates are temporarily unavailable.'),
      findsOneWidget,
    );
    expect(
      find.text('Continue watching is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(
      find.text('The live catalog is temporarily unavailable.'),
      findsNWidgets(2),
    );
    expect(find.textContaining('HTTP 503'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Search errors use non-technical recovery copy', (tester) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService(failSearch: true);
    await tester.pumpWidget(
      _captureApp(
        Scaffold(
          body: SearchScreen(service: service, onOpenItem: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing title');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.searchErrorCompleter.completeError(
      AuthException('HTTP 503 internal test detail'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search is unavailable'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.textContaining('HTTP 503'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Account activity error offers retry and recovers', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final service = _RenderService(failHistoryOnce: true);
    await tester.pumpWidget(
      _captureApp(
        Scaffold(
          body: AccountScreen(
            service: service,
            session: _session,
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent activity is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recent activity is unavailable.'), findsNothing);
    expect(find.text('After the Monsoon'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
