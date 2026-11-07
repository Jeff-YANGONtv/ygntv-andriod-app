import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_service.dart';
import 'deep_links/app_deep_link.dart';
import 'screens/customer_home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'widgets/ygntv_text_splash.dart';

const _brandRed = Color(0xFFE5454F);
const _appBackground = Color(0xFF09090D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: _appBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final service = AuthService();
  final controller = AuthController(service);
  runApp(YgntvCustomerApp(controller: controller));
  await controller.restore();
}

class YgntvCustomerApp extends StatefulWidget {
  const YgntvCustomerApp({required this.controller, super.key});

  final AuthController controller;

  @override
  State<YgntvCustomerApp> createState() => _YgntvCustomerAppState();
}

class _YgntvCustomerAppState extends State<YgntvCustomerApp> {
  final AppLinks _appLinks = AppLinks();
  final ValueNotifier<AppDeepLink?> _deepLinkEvent =
      ValueNotifier<AppDeepLink?>(null);
  StreamSubscription<Uri>? _linkSubscription;
  AppDeepLink? _pendingLink;
  String? _lastUri;
  DateTime? _lastUriAt;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_dispatchPendingLink);
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _receiveUri,
      onError: (_) {},
    );
    unawaited(_receiveInitialUri());
  }

  @override
  void didUpdateWidget(covariant YgntvCustomerApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_dispatchPendingLink);
      widget.controller.addListener(_dispatchPendingLink);
      _dispatchPendingLink();
    }
  }

  Future<void> _receiveInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _receiveUri(uri);
    } catch (_) {
      // The app still opens normally if Android supplies no launch URI.
    }
  }

  void _receiveUri(Uri uri) {
    final link = AppDeepLink.tryParse(uri);
    if (link == null) return;

    final now = DateTime.now();
    final serializedUri = uri.toString();
    if (_lastUri == serializedUri &&
        _lastUriAt != null &&
        now.difference(_lastUriAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastUri = serializedUri;
    _lastUriAt = now;
    _pendingLink = link;
    _dispatchPendingLink();
  }

  void _dispatchPendingLink() {
    final link = _pendingLink;
    if (link == null ||
        !widget.controller.ready ||
        widget.controller.session == null) {
      return;
    }
    _pendingLink = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.controller.ready || widget.controller.session == null) {
        _pendingLink = link;
        return;
      }
      _deepLinkEvent.value = link;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_dispatchPendingLink);
    final subscription = _linkSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _deepLinkEvent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandRed,
      brightness: Brightness.dark,
    ).copyWith(primary: _brandRed, surface: const Color(0xFF17171E));
    return MaterialApp(
      title: 'Yangon TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _appBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: _appBackground,
          foregroundColor: Colors.white,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2B2023),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 10,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? _brandRed
                  : const Color(0xFFA4A1AA),
            ),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (!widget.controller.ready) {
            return const YgntvTextSplash();
          }
          final session = widget.controller.session;
          if (session == null) {
            return SignInScreen(
              busy: widget.controller.busy,
              onSignIn: widget.controller.signIn,
              onSignUp: widget.controller.signUp,
              onGoogle: widget.controller.signInWithGoogle,
              onTelegram: widget.controller.signInWithTelegram,
            );
          }
          return CustomerHomeScreen(
            session: session,
            authService: widget.controller.service,
            onSignOut: widget.controller.signOut,
            deepLinkEvent: _deepLinkEvent,
          );
        },
      ),
    );
  }
}
