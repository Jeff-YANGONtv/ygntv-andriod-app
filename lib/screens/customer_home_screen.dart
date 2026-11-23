import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../services/customer_app_update_service.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/resilient_network_image.dart';
import '../widgets/ygntv_home_banner_fallback.dart';
import '../widgets/ygntv_brand.dart';
import 'account_screen.dart';
import 'blog_screen.dart';
import 'catalog_browser_screen.dart';
import 'daily_signin_wheel_screen.dart';
import 'library_screen.dart';
import 'media_actions.dart';
import 'media_detail_screen.dart';
import 'manual_transfer_screen.dart';
import 'notifications_screen.dart';
import 'referral_wallet_screen.dart';
import 'subscription_screen.dart';
import 'support_chat_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    required this.session,
    required this.authService,
    required this.onSignOut,
    this.deepLinkEvent,
    super.key,
  });

  final AuthSession session;
  final AuthService authService;
  final Future<void> Function() onSignOut;
  final ValueNotifier<AppDeepLink?>? deepLinkEvent;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _quickMenuOpen = false;
  late Future<List<CatalogItem>> _movies;
  late Future<List<CatalogItem>> _series;
  late Future<List<TvLibraryEntry>> _continueWatching;
  late Future<List<TvHomeBanner>> _topAdBanners;
  late Future<List<TvBlogPost>> _homeBlogPosts;
  final PageController _bannerController = PageController();
  final PageController _blogController = PageController();
  int _bannerIndex = 0;
  int _blogIndex = 0;
  TvNotificationFeed? _notificationFeed;
  List<TvHomeMarqueeEntry> _homeMarquee = const [];
  bool _refreshingNotifications = false;
  Timer? _notificationTimer;
  Timer? _marqueeTimer;
  Timer? _bannerTimer;
  Timer? _blogTimer;
  Timer? _appUpdateTimer;
  final CustomerAppUpdateService _appUpdateService = CustomerAppUpdateService();
  DateTime? _lastUpdateCheckAt;
  bool _checkingAppUpdate = false;
  bool _installingDownloadedUpdate = false;
  int? _pendingInstallerDownloadId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.deepLinkEvent?.addListener(_consumeDeepLinkEvent);
    _refreshCatalog();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumeDeepLinkEvent(),
    );
    unawaited(_refreshNotifications());
    unawaited(_refreshHomeMarquee());
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshNotifications(),
    );
    _marqueeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshHomeMarquee(),
    );
    _bannerTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _advanceBanner(),
    );
    _blogTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _advanceBlogHero(),
    );
    _appUpdateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) unawaited(_checkForAppUpdate());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.deepLinkEvent?.removeListener(_consumeDeepLinkEvent);
    _notificationTimer?.cancel();
    _marqueeTimer?.cancel();
    _bannerTimer?.cancel();
    _blogTimer?.cancel();
    _appUpdateTimer?.cancel();
    _bannerController.dispose();
    _blogController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deepLinkEvent != widget.deepLinkEvent) {
      oldWidget.deepLinkEvent?.removeListener(_consumeDeepLinkEvent);
      widget.deepLinkEvent?.addListener(_consumeDeepLinkEvent);
      _consumeDeepLinkEvent();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotifications());
      unawaited(_refreshHomeMarquee());
      unawaited(_onAppResumed());
    }
  }

  Future<void> _onAppResumed() async {
    if (_pendingInstallerDownloadId != null) {
      await _installPendingUpdateIfAllowed();
      return;
    }
    final lastCheck = _lastUpdateCheckAt;
    if (lastCheck == null ||
        DateTime.now().difference(lastCheck) >= const Duration(hours: 6)) {
      await _checkForAppUpdate();
    }
  }

  Future<void> _checkForAppUpdate({bool manual = false}) async {
    if (_checkingAppUpdate) return;
    _checkingAppUpdate = true;
    _lastUpdateCheckAt = DateTime.now();
    try {
      final release = await _appUpdateService.findAvailableUpdate();
      if (!mounted) return;
      if (release == null) {
        if (manual) {
          _showAppUpdateMessage(
            'No new YGNTV updates are available for this app.',
          );
        }
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: ygntvPanel,
          title: const Text('YGNTV update available'),
          content: Text(
            'Version ${release.versionName} · build ${release.versionCode}'
            '${release.releaseNotes.isEmpty ? '' : '\n\n${release.releaseNotes}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download & install'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) await _downloadAndInstallUpdate(release);
    } catch (error) {
      if (manual && mounted) _showAppUpdateMessage(error.toString());
    } finally {
      _checkingAppUpdate = false;
    }
  }

  Future<void> _downloadAndInstallUpdate(AppUpdateRelease release) async {
    final id = await _appUpdateService.startApkDownload(release);
    if (!mounted) return;
    final progress = ValueNotifier<AppUpdateDownloadStatus>(
      const AppUpdateDownloadStatus(status: 'pending'),
    );
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<AppUpdateDownloadStatus>(
        valueListenable: progress,
        builder: (context, status, _) => AlertDialog(
          backgroundColor: ygntvPanel,
          title: const Text('Downloading YGNTV update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: status.progress, color: ygntvRed),
              const SizedBox(height: 12),
              Text(
                status.progress == null
                    ? 'Download is running in the background.'
                    : '${(status.progress! * 100).round()}% downloaded',
                style: const TextStyle(color: ygntvMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    var dialogClosed = false;
    try {
      while (mounted) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final status = await _appUpdateService.downloadStatus(id);
        progress.value = status;
        if (status.status == 'complete' && status.checksumValid == true) {
          if (mounted && !dialogClosed) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogClosed = true;
          }
          await progressDialog;
          if (await _appUpdateService.canInstallPackages()) {
            _pendingInstallerDownloadId = null;
            await _appUpdateService.installDownloadedApk(id);
          } else {
            await _requestInstallPermission(id);
          }
          return;
        }
        if (status.isFinished) {
          throw FormatException(
            status.message ??
                'The YGNTV update download could not be verified.',
          );
        }
      }
    } catch (error) {
      if (mounted && !dialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogClosed = true;
        await progressDialog;
      }
      if (mounted) _showAppUpdateMessage(error.toString());
    } finally {
      progress.dispose();
    }
  }

  Future<void> _requestInstallPermission(int id) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ygntvPanel,
        title: const Text('Allow YGNTV updates'),
        content: const Text(
          'Android needs your permission to install this private TEST update. '
          'Allow “Install unknown apps” for YGNTV, then return here. Android '
          'will still ask you to confirm the update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      _pendingInstallerDownloadId = id;
      await _appUpdateService.openInstallPermissionSettings();
    }
  }

  Future<void> _installPendingUpdateIfAllowed() async {
    final id = _pendingInstallerDownloadId;
    if (id == null || _installingDownloadedUpdate) return;
    _installingDownloadedUpdate = true;
    try {
      if (await _appUpdateService.canInstallPackages()) {
        _pendingInstallerDownloadId = null;
        await _appUpdateService.installDownloadedApk(id);
      }
    } catch (error) {
      if (mounted) _showAppUpdateMessage(error.toString());
    } finally {
      _installingDownloadedUpdate = false;
    }
  }

  void _showAppUpdateMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshNotifications() async {
    if (_refreshingNotifications) return;
    _refreshingNotifications = true;
    try {
      try {
        final feed = await widget.authService.getNotifications();
        if (mounted) setState(() => _notificationFeed = feed);
      } catch (_) {
        // Keep the last confirmed feed; the download poll below still runs.
      }
      try {
        await widget.authService.getAndroidDownloads();
      } catch (_) {
        // Completion polling is best-effort.
      }
    } finally {
      _refreshingNotifications = false;
    }
  }

  Future<void> _refreshHomeMarquee() async {
    try {
      final entries = await widget.authService.getHomeMarqueeEntries();
      if (mounted &&
          _marqueeSignature(entries) != _marqueeSignature(_homeMarquee)) {
        setState(() => _homeMarquee = entries);
      }
    } catch (_) {
      // Keep the last Admin-provided copy, or hide the ticker if none was loaded.
    }
  }

  void _advanceBanner() {
    if (!mounted ||
        _selectedTab != 0 ||
        !_bannerController.hasClients ||
        _bannerController.position.viewportDimension <= 0 ||
        _bannerController.position.maxScrollExtent <= 0) {
      return;
    }
    final position = _bannerController.position;
    final pageCount =
        (position.maxScrollExtent / position.viewportDimension).round() + 1;
    if (pageCount < 2) return;
    final currentPage = _bannerController.page?.round() ?? 0;
    unawaited(
      _bannerController.animateToPage(
        (currentPage + 1) % pageCount,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _advanceBlogHero() {
    if (!mounted ||
        _selectedTab != 0 ||
        !_blogController.hasClients ||
        _blogController.position.viewportDimension <= 0 ||
        _blogController.position.maxScrollExtent <= 0) {
      return;
    }
    final position = _blogController.position;
    final pageCount =
        (position.maxScrollExtent / position.viewportDimension).round() + 1;
    if (pageCount < 2) return;
    final currentPage = _blogController.page?.round() ?? 0;
    unawaited(
      _blogController.animateToPage(
        (currentPage + 1) % pageCount,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _refreshCatalog() {
    _movies = widget.authService.loadCatalog('movie');
    _series = widget.authService.loadCatalog('series');
    _continueWatching = widget.authService.getContinueWatching();
    _topAdBanners = widget.authService.getTopAdBanners();
    _homeBlogPosts = widget.authService.getBlogPosts();
    _bannerIndex = 0;
    _blogIndex = 0;
    if (_bannerController.hasClients) _bannerController.jumpToPage(0);
    if (_blogController.hasClients) _blogController.jumpToPage(0);
  }

  Future<void> _refresh() async {
    setState(_refreshCatalog);
    unawaited(_refreshNotifications());
    unawaited(_refreshHomeMarquee());
    try {
      await Future.wait([
        _movies,
        _series,
        _continueWatching,
        _topAdBanners,
        _homeBlogPosts,
      ]);
    } catch (_) {
      // Each shelf displays its own live API error state.
    }
  }

  void _openItem(CatalogItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MediaDetailScreen(item: item, service: widget.authService),
      ),
    );
  }

  void _selectTab(int tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _openShortcut(Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  void _consumeDeepLinkEvent() {
    final event = widget.deepLinkEvent;
    final link = event?.value;
    if (event == null || link == null) return;
    event.value = null;
    unawaited(_openDeepLink(link));
  }

  Future<void> _openDeepLink(AppDeepLink link) async {
    switch (link.destination) {
      case AppDeepLinkDestination.movies:
        setState(() => _selectedTab = 1);
        return;
      case AppDeepLinkDestination.series:
        setState(() => _selectedTab = 2);
        return;
      case AppDeepLinkDestination.home:
        setState(() => _selectedTab = 0);
        return;
      case AppDeepLinkDestination.search:
        // Keep legacy links working; Search now lives inside each catalog tab.
        setState(() => _selectedTab = 1);
        return;
      case AppDeepLinkDestination.blog:
        setState(() => _selectedTab = 0);
        if (link.slug != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BlogDetailScreen(
                service: widget.authService,
                slug: link.slug!,
              ),
            ),
          );
        }
        return;
      case AppDeepLinkDestination.account:
        setState(() => _selectedTab = 3);
        return;
      case AppDeepLinkDestination.library:
        const libraryTabs = {
          'continue': 0,
          'history': 1,
          'list': 2,
          'offline': 3,
        };
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => LibraryScreen(
              service: widget.authService,
              initialTab: libraryTabs[link.tab] ?? 0,
            ),
          ),
        );
        return;
      case AppDeepLinkDestination.notifications:
        await _openNotifications();
        return;
      case AppDeepLinkDestination.subscription:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SubscriptionScreen(
              service: widget.authService,
              initialTab: link.tab == 'redeem' ? 1 : 0,
            ),
          ),
        );
        return;
      case AppDeepLinkDestination.support:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(service: widget.authService),
          ),
        );
        return;
      case AppDeepLinkDestination.manualTransfer:
        try {
          final planKey = link.planKey;
          if (planKey == null) return;
          final plans = await widget.authService.getPremiumPlans();
          final plan = plans
              .where((candidate) => candidate.key == planKey)
              .firstOrNull;
          if (plan == null) {
            if (mounted) {
              _showAppUpdateMessage(
                'This membership plan is no longer available.',
              );
            }
            return;
          }
          if (!mounted) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  ManualTransferScreen(service: widget.authService, plan: plan),
            ),
          );
        } catch (error) {
          if (mounted) _showAppUpdateMessage(error.toString());
        }
        return;
      case AppDeepLinkDestination.videoPlayback:
        final contentType = link.contentType;
        final contentId = link.contentId;
        if (contentType == null || contentId == null) return;
        await runMediaAction(
          context,
          widget.authService,
          contentType: contentType,
          contentId: contentId,
          title: contentType == 'episode' ? 'YGNTV episode' : 'YGNTV movie',
          posterUrl: '',
          action: 'watch',
        );
        return;
      case AppDeepLinkDestination.movieDetail:
      case AppDeepLinkDestination.seriesDetail:
        final isMovie = link.destination == AppDeepLinkDestination.movieDetail;
        final kind = isMovie ? 'movie' : 'series';
        final slug = link.slug;
        if (slug == null) return;
        setState(() => _selectedTab = isMovie ? 1 : 2);
        try {
          final item = await widget.authService.loadDetail(
            CatalogItem(title: '', posterUrl: '', kind: kind, slug: slug),
          );
          if (!mounted) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailScreen(item: item, service: widget.authService),
            ),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This title could not be opened from the link.'),
              ),
            );
          }
        }
        return;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(service: widget.authService),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshNotifications());
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Scaffold(
        backgroundColor: ygntvBackground,
        appBar: AppBar(
          key: const ValueKey('customer-app-sticky-header'),
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          toolbarHeight: 62,
          surfaceTintColor: Colors.transparent,
          title: const YgntvBrandLockup(compact: true),
          actions: [
            AppPageLinkButton(uri: AppDeepLink.linkFor('home')),
            IconButton(
              tooltip: 'Updates',
              onPressed: _openNotifications,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 42, height: 42),
              icon: Badge(
                isLabelVisible:
                    (_notificationFeed?.visibleUnreadCount ?? 0) > 0,
                label: Text(
                  (_notificationFeed?.visibleUnreadCount ?? 0) > 99
                      ? '99+'
                      : '${_notificationFeed?.visibleUnreadCount ?? 0}',
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: ygntvGold,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(top: false, child: _selectedView()),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
      if (_quickMenuOpen) _buildQuickMenuOverlay(context),
    ],
  );

  Widget _selectedView() => switch (_selectedTab) {
    0 => _homeView(),
    1 => CatalogBrowserScreen(
      service: widget.authService,
      kind: 'movie',
      title: 'Movie',
      catalogFuture: _movies,
      onOpenItem: _openItem,
      onRefresh: _refresh,
    ),
    2 => CatalogBrowserScreen(
      service: widget.authService,
      kind: 'series',
      title: 'Series',
      catalogFuture: _series,
      onOpenItem: _openItem,
      onRefresh: _refresh,
    ),
    _ => AccountScreen(
      service: widget.authService,
      session: widget.session,
      onSignOut: widget.onSignOut,
      onCheckForUpdates: () => _checkForAppUpdate(manual: true),
    ),
  };

  Widget _buildBottomNavigationBar() => SafeArea(
    top: false,
    child: SizedBox(
      height: 72,
      child: Stack(
        key: const ValueKey('customer-bottom-nav'),
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF111116),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(
                  top: BorderSide(color: Color(0x22FFFFFF), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _bottomNavItem(
                      title: 'Home',
                      keyName: 'home',
                      icon: Icons.home_outlined,
                      destination: 0,
                    ),
                  ),
                  Expanded(
                    child: _bottomNavItem(
                      title: 'Movies',
                      keyName: 'movie',
                      icon: Icons.local_movies_outlined,
                      destination: 1,
                    ),
                  ),
                  const SizedBox(width: 66),
                  Expanded(
                    child: _bottomNavItem(
                      title: 'Series',
                      keyName: 'series',
                      icon: Icons.tv_outlined,
                      destination: 2,
                    ),
                  ),
                  Expanded(
                    child: _bottomNavItem(
                      title: 'Account',
                      keyName: 'account',
                      icon: Icons.person_outline_rounded,
                      destination: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -18,
            child: Center(
              child: _quickMenuToggle(
                open: false,
                keyName: 'customer-nav-quick-actions',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bottomNavItem({
    required String title,
    required String keyName,
    required IconData icon,
    required int destination,
  }) {
    final selected = _selectedTab == destination;
    final color = selected ? ygntvRed : const Color(0xFF9697A1);
    return Tooltip(
      message: title,
      child: Semantics(
        label: title,
        button: true,
        selected: selected,
        child: InkWell(
          key: ValueKey('customer-nav-$keyName'),
          onTap: () => _selectTab(destination),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1,
                    letterSpacing: .1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMenuOverlay(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('customer-quick-menu-backdrop'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _quickMenuOpen = false),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                builder: (context, opacity, _) => ColoredBox(
                  color: Colors.black.withValues(alpha: .58 * opacity),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: safeBottom + 72,
            height: 144,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _quickMenuAction(
                    keyName: 'subscription',
                    label: 'Subscription',
                    accessibilityLabel: 'Premium Subscription',
                    icon: Icons.workspace_premium_outlined,
                    onTap: () {
                      setState(() => _quickMenuOpen = false);
                      _openShortcut(
                        SubscriptionScreen(service: widget.authService),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Center(
                    child: _quickMenuAction(
                      keyName: 'daily-bonus',
                      label: 'Daily Bonus',
                      accessibilityLabel: 'Daily Sign In Bonus',
                      icon: Icons.card_giftcard_outlined,
                      onTap: () {
                        setState(() => _quickMenuOpen = false);
                        _openShortcut(
                          DailySignInWheelScreen(service: widget.authService),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _quickMenuAction(
                    keyName: 'referral',
                    label: 'Refer & Earn',
                    accessibilityLabel: 'Referral',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () {
                      setState(() => _quickMenuOpen = false);
                      _openShortcut(
                        ReferralWalletScreen(service: widget.authService),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: safeBottom + 36,
            child: Center(
              child: _quickMenuToggle(
                open: true,
                keyName: 'customer-nav-quick-actions-close',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickMenuToggle({required bool open, required String keyName}) =>
      Semantics(
        label: open ? 'Close quick menu' : 'Open quick menu',
        button: true,
        child: Material(
          color: ygntvRed,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: .3),
          child: InkWell(
            key: ValueKey(keyName),
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _quickMenuOpen = !_quickMenuOpen),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    open ? Icons.close_rounded : Icons.add_rounded,
                    key: ValueKey(open),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _quickMenuAction({
    required String keyName,
    required String label,
    required String accessibilityLabel,
    required IconData icon,
    required VoidCallback onTap,
  }) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .82, end: 1),
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: Tooltip(
      message: accessibilityLabel,
      child: Semantics(
        label: accessibilityLabel,
        button: true,
        child: SizedBox(
          width: 110,
          height: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: const Color(0xFF17171C),
                shape: CircleBorder(
                  side: BorderSide(
                    color: ygntvRed.withValues(alpha: .42),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  key: ValueKey('customer-quick-menu-$keyName'),
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: Icon(icon, color: ygntvRed, size: 25),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    inherit: false,
                    fontFamily: 'Roboto',
                    color: Colors.white,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _homeView() {
    final displayName = widget.session.name.trim().isEmpty
        ? 'there'
        : widget.session.name.trim().split(RegExp(r'\s+')).first;
    return RefreshIndicator(
      color: ygntvRed,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_homeMarquee.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(19, 3, 19, 0),
                child: _HomeMarquee(
                  key: const ValueKey('customer-home-marquee'),
                  entries: _homeMarquee,
                ),
              ),
            ),
          SliverToBoxAdapter(child: _topAdSlider()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR YGNTV HOME',
                    style: TextStyle(
                      color: ygntvGold,
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Welcome back, $displayName.',
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.12,
                      letterSpacing: -.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Stories worth staying up for.',
                    style: TextStyle(color: ygntvMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _blogHeroSlider()),
          SliverToBoxAdapter(child: _continueRail()),
          SliverToBoxAdapter(
            child: _catalogRail(title: 'Movie', future: _movies, kind: 'movie'),
          ),
          SliverToBoxAdapter(
            child: _catalogRail(
              title: 'Series',
              future: _series,
              kind: 'series',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
        ],
      ),
    );
  }

  Widget _topAdSlider() => FutureBuilder<List<TvHomeBanner>>(
    future: _topAdBanners,
    builder: (context, snapshot) {
      final banners = snapshot.data ?? const <TvHomeBanner>[];
      if (banners.isEmpty) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _HomeServiceState(
            message: 'Loading featured banners…',
            loading: true,
          );
        }
        if (snapshot.hasError) {
          return _HomeServiceState(
            message: 'Featured banners are temporarily unavailable.',
            onRetry: () => unawaited(_refresh()),
          );
        }
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AspectRatio(
          key: const ValueKey('home-top-banner-aspect-ratio'),
          aspectRatio: 728 / 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    key: const ValueKey('home-top-banner-slider'),
                    controller: _bannerController,
                    itemCount: banners.length,
                    onPageChanged: (index) =>
                        setState(() => _bannerIndex = index),
                    itemBuilder: (context, index) =>
                        _bannerCard(banners[index]),
                  ),
                  if (banners.length > 1)
                    Positioned(
                      right: 8,
                      bottom: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(
                          banners.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == _bannerIndex ? 12 : 5,
                            height: 5,
                            margin: const EdgeInsets.only(left: 3),
                            decoration: BoxDecoration(
                              color: index == _bannerIndex
                                  ? ygntvGold
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _blogHeroSlider() => FutureBuilder<List<TvBlogPost>>(
    future: _homeBlogPosts,
    builder: (context, snapshot) {
      final posts = snapshot.data ?? const <TvBlogPost>[];
      if (posts.isEmpty) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _HomeServiceState(
            message: 'Loading YGNTV updates…',
            loading: true,
          );
        }
        if (snapshot.hasError) {
          return _HomeServiceState(
            message: 'YGNTV updates are temporarily unavailable.',
            onRetry: () => unawaited(_refresh()),
          );
        }
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: SizedBox(
            key: const ValueKey('home-blog-hero-slider'),
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _blogController,
                  itemCount: posts.length,
                  onPageChanged: (index) => setState(() => _blogIndex = index),
                  itemBuilder: (context, index) => _blogHeroCard(posts[index]),
                ),
                if (posts.length > 1)
                  Positioned(
                    right: 15,
                    bottom: 15,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(
                        posts.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == _blogIndex ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: index == _blogIndex
                                ? ygntvGold
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _blogHeroCard(TvBlogPost post) => GestureDetector(
    onTap: () => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            BlogDetailScreen(service: widget.authService, slug: post.slug),
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (post.image.isNotEmpty)
          ResilientNetworkImage(
            url: post.image,
            fit: BoxFit.cover,
            cacheWidth: 780,
            fallback: const _FeatureBackdrop(),
          )
        else
          const _FeatureBackdrop(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x11000000), Color(0xEE09090D)],
            ),
          ),
        ),
        Positioned(
          left: 17,
          right: 17,
          bottom: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.category.isNotEmpty)
                Text(
                  post.category.toUpperCase(),
                  style: const TextStyle(
                    color: ygntvGold,
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 7),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              if (post.excerpt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD0CDD3),
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _bannerCard(TvHomeBanner banner) => GestureDetector(
    onTap: banner.linkUrl == null
        ? null
        : () => _openBannerLink(banner.linkUrl),
    child: ResilientNetworkImage(
      url: banner.imageUrl,
      fit: BoxFit.contain,
      cacheWidth: 1456,
      fallback: YgntvHomeBannerFallback(
        title: banner.name,
        actionLabel: banner.buttonName,
      ),
    ),
  );

  Future<void> _openBannerLink(String? value) async {
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return;
    final appLink = AppDeepLink.tryParse(uri);
    if (appLink != null) {
      await _openDeepLink(appLink);
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This banner link could not be opened.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This banner link could not be opened.'),
          ),
        );
      }
    }
  }

  Widget _continueRail() => Padding(
    padding: const EdgeInsets.only(bottom: 21),
    child: FutureBuilder<List<TvLibraryEntry>>(
      future: _continueWatching,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <TvLibraryEntry>[];
        if (entries.isEmpty && snapshot.hasError) {
          return _HomeServiceState(
            message: 'Continue watching is temporarily unavailable.',
            onRetry: () => unawaited(_refresh()),
          );
        }
        if (entries.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'Continue watching'),
            const SizedBox(height: 11),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                scrollDirection: Axis.horizontal,
                itemCount: entries.length.clamp(0, 8),
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) => _ContinueCard(
                  key: ValueKey(
                    '${entries[index].contentType}:${entries[index].contentId}',
                  ),
                  entry: entries[index],
                  onTap: () => runMediaAction(
                    context,
                    widget.authService,
                    contentType: entries[index].contentType,
                    contentId: entries[index].contentId,
                    title: entries[index].title,
                    posterUrl: entries[index].posterUrl,
                    action: 'watch',
                    initialPosition: entries[index].positionSeconds,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _catalogRail({
    required String title,
    required Future<List<CatalogItem>> future,
    required String kind,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: FutureBuilder<List<CatalogItem>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CatalogItem>[];
        void onSeeAll() {
          setState(() => _selectedTab = kind == 'movie' ? 1 : 2);
        }

        if (items.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: title, onSeeAll: onSeeAll),
              const SizedBox(height: 10),
              const SizedBox(
                height: 105,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ygntvRed,
                  ),
                ),
              ),
            ],
          );
        }
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: title, onSeeAll: onSeeAll),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  snapshot.hasError
                      ? 'The live catalog is temporarily unavailable.'
                      : 'New titles are on the way.',
                  style: const TextStyle(color: ygntvMuted, fontSize: 11),
                ),
              ),
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: TextButton.icon(
                    onPressed: () => unawaited(_refresh()),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Try again'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title, onSeeAll: onSeeAll),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) => _PosterCard(
                  key: ValueKey('${items[index].kind}:${items[index].id}'),
                  item: items[index],
                  onTap: () => _openItem(items[index]),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _HomeServiceState extends StatelessWidget {
  const _HomeServiceState({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: Row(
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: ygntvRed, strokeWidth: 2),
          )
        else
          const Icon(Icons.wifi_off_rounded, color: ygntvGold, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ygntvMuted,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Retry'),
          ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 19),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('See all', style: TextStyle(fontSize: 11)),
          ),
      ],
    ),
  );
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.item, required this.onTap, super.key});
  final CatalogItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 113,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                child: item.posterUrl.isEmpty
                    ? const _PosterFallback()
                    : ResilientNetworkImage(
                        url: item.posterUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 185,
                        tmdbMaxWidth: 500,
                        fallback: const _PosterFallback(),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              item.year,
              item.kind == 'movie' ? 'Movie' : 'Series',
            ].where((part) => part.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ygntvMuted, fontSize: 9),
          ),
        ],
      ),
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap, super.key});
  final TvLibraryEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final duration = entry.durationSeconds ?? 0;
    final progress = duration > 0
        ? (entry.positionSeconds / duration).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return SizedBox(
      width: 245,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey(
            'continue-card-${entry.contentType}-${entry.contentId}',
          ),
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Container(
              decoration: BoxDecoration(
                color: ygntvPanel,
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  entry.posterUrl.isEmpty
                      ? const _PosterFallback()
                      : ResilientNetworkImage(
                          url: entry.posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 500,
                          tmdbMaxWidth: 500,
                          fallback: const _PosterFallback(),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x16000000),
                          Color(0xE6000000),
                        ],
                        stops: [0, .43, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .74),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        entry.contentType == 'episode' ? 'SERIES' : 'MOVIE',
                        style: const TextStyle(
                          color: ygntvGold,
                          fontSize: 9,
                          letterSpacing: .7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ygntvRed.withValues(alpha: .94),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (entry.year.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            entry.year,
                            style: const TextStyle(
                              color: Color(0xFFC7C3CD),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      key: ValueKey(
                        'continue-progress-${entry.contentType}-${entry.contentId}',
                      ),
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(ygntvRed),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF25222B),
    child: Center(
      child: Icon(Icons.movie_outlined, color: Color(0x66FFFFFF), size: 28),
    ),
  );
}

class _FeatureBackdrop extends StatelessWidget {
  const _FeatureBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF643136), Color(0xFF24202A), Color(0xFF0D0C12)],
      ),
    ),
  );
}

String _marqueeSignature(Iterable<TvHomeMarqueeEntry> entries) => entries
    .map((entry) => '${entry.content}\u0000${entry.textColor}')
    .join('\u0001');

Color _marqueeColor(String value) {
  final hex = value.startsWith('#') ? value.substring(1) : value;
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return ygntvGold;
  return Color(int.parse('FF$hex', radix: 16));
}

class _HomeMarquee extends StatefulWidget {
  const _HomeMarquee({required this.entries, super.key});

  final List<TvHomeMarqueeEntry> entries;

  @override
  State<_HomeMarquee> createState() => _HomeMarqueeState();
}

class _HomeMarqueeState extends State<_HomeMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _HomeMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_marqueeSignature(oldWidget.entries) !=
        _marqueeSignature(widget.entries)) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextSpan marqueeSpan({required bool outlined}) {
      final outline = Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      final children = <InlineSpan>[];
      for (var index = 0; index < widget.entries.length; index++) {
        if (index > 0) {
          children.add(
            TextSpan(
              text: '  •  ',
              style: outlined
                  ? TextStyle(
                      foreground: outline,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    )
                  : const TextStyle(
                      color: ygntvGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
            ),
          );
        }
        final entry = widget.entries[index];
        children.add(
          TextSpan(
            text: '${entry.content}     ',
            style: outlined
                ? TextStyle(
                    foreground: outline,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )
                : TextStyle(
                    color: _marqueeColor(entry.textColor),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        );
      }
      return TextSpan(children: children);
    }

    final fillTextPainter = TextPainter(
      text: marqueeSpan(outlined: false),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final itemWidthWithGap = fillTextPainter.width + 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final repeatCount =
            (constraints.maxWidth / itemWidthWithGap).ceil() + 2;
        return SizedBox(
          height: 34,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final outlineTextPainter = TextPainter(
                  text: marqueeSpan(outlined: true),
                  textDirection: Directionality.of(context),
                  maxLines: 1,
                )..layout();
                return OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: SizedBox(
                    width: itemWidthWithGap * repeatCount,
                    height: 34,
                    child: CustomPaint(
                      painter: _HomeMarqueePainter(
                        outlineTextPainter: outlineTextPainter,
                        fillTextPainter: fillTextPainter,
                        itemWidth: itemWidthWithGap,
                        repeatCount: repeatCount,
                        progress: _controller.value,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _HomeMarqueePainter extends CustomPainter {
  const _HomeMarqueePainter({
    required this.outlineTextPainter,
    required this.fillTextPainter,
    required this.itemWidth,
    required this.repeatCount,
    required this.progress,
  });

  final TextPainter outlineTextPainter;
  final TextPainter fillTextPainter;
  final double itemWidth;
  final int repeatCount;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - fillTextPainter.height) / 2;
    final start = 12 - itemWidth * progress;
    for (var index = 0; index < repeatCount; index++) {
      final offset = Offset(start + itemWidth * index, top);
      outlineTextPainter.paint(canvas, offset);
      fillTextPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeMarqueePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      itemWidth != oldDelegate.itemWidth ||
      repeatCount != oldDelegate.repeatCount ||
      outlineTextPainter.text != oldDelegate.outlineTextPainter.text ||
      fillTextPainter.text != oldDelegate.fillTextPainter.text;
}
