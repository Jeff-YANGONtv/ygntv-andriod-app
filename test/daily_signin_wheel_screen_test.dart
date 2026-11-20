import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/screens/daily_signin_wheel_screen.dart';

class _WheelService extends AuthService {
  _WheelService({
    required this.items,
    bool failFirstOptionsLoad = false,
    this.optionsFailureStatusCode,
    this.spinGate,
    this.initialCanSpin = false,
    this.spinResults = const [],
    this.failSpin = false,
    this.includeExistingReward = true,
    this.existingRewardCode = 'one_movie',
    this.spinFailureMessage = 'server unavailable',
  }) : _failNext = failFirstOptionsLoad,
       super(client: MockClient((_) async => http.Response('{}', 200)));

  final List<Map<String, dynamic>> items;
  final bool initialCanSpin;
  final List<Map<String, dynamic>> spinResults;
  final bool failSpin;
  final bool includeExistingReward;
  final String existingRewardCode;
  final String spinFailureMessage;
  final int? optionsFailureStatusCode;
  final Completer<void>? spinGate;
  bool _failNext;
  int spinCalls = 0;
  int optionsCalls = 0;
  String? selectedSpinId;
  String? selectedType;
  List<int> selectedContentIds = const [];

  @override
  Future<Map<String, dynamic>> getDailySignInWheelOverview() async => {
    'can_spin': spinCalls == 0
        ? initialCanSpin
        : spinCalls <= spinResults.length &&
              spinResults[spinCalls - 1]['reward_code'] == 'roll_again',
    'next_spin_at': DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String(),
    'rewards': includeExistingReward
        ? [
            {
              'id': 'spin-1',
              'reward_code': existingRewardCode,
              'selection_status': 'pending',
              'expires_at': DateTime.now()
                  .add(const Duration(hours: 12))
                  .toIso8601String(),
            },
          ]
        : <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> spinDailySignInWheel({
    required String spinKey,
  }) async {
    spinCalls++;
    if (spinGate != null) await spinGate!.future;
    if (failSpin) throw AuthException(spinFailureMessage);
    final spin = spinResults[spinCalls - 1];
    return {
      'spin': spin,
      'overview': {
        'can_spin': spin['reward_code'] == 'roll_again',
        'rewards': [spin],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getDailyWheelOptions({
    required String spinId,
    required String type,
    required int page,
    String search = '',
  }) async {
    optionsCalls++;
    if (_failNext) {
      _failNext = false;
      throw AuthException(
        'temporary network failure',
        statusCode: optionsFailureStatusCode,
      );
    }
    return {'items': items, 'has_more': false};
  }

  @override
  Future<Map<String, dynamic>> commitDailyWheelSelection({
    required String spinId,
    required String type,
    List<int> contentIds = const [],
    int? seasonId,
  }) async {
    selectedSpinId = spinId;
    selectedType = type;
    selectedContentIds = List<int>.of(contentIds);
    return {
      'spin': {
        'id': spinId,
        'reward_code': 'one_movie',
        'selection_status': 'selected',
        'selection': {'title': 'Chosen movie'},
      },
      'overview': {'can_spin': false, 'rewards': <Map<String, dynamic>>[]},
    };
  }
}

Widget _app(_WheelService service) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: DailySignInWheelScreen(service: service),
);

Future<void> _openMoviePicker(WidgetTester tester) async {
  await tester.tap(find.text('Choose reward content'));
  await tester.pumpAndSettle();
}

void _expectEnglishVisibleCopy(WidgetTester tester) {
  final myanmar = RegExp(r'[\u1000-\u109F\uAA60-\uAA7F]');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final value = text.data ?? text.textSpan?.toPlainText() ?? '';
    expect(myanmar.hasMatch(value), isFalse, reason: value);
  }
}

void main() {
  test('Lucky Box keeps the approved server reward-code order', () {
    expect(dailyBonusOutcomeOrder, const [
      'one_episode',
      'one_movie',
      'good_luck_next_round',
      'two_movies',
      'two_episodes',
      'roll_again',
      'three_movies',
      'thanks_for_choosing_us',
    ]);
  });

  testWidgets('Lucky Box hides odds card but preserves history and weights', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(
      items: const [],
      includeExistingReward: false,
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Daily Sign In Bonus (Lucky Box)'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-lucky-box-art')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-wheel-rotating')), findsNothing);
    expect(find.text('Lucky Box odds'), findsNothing);
    expect(find.text('25%'), findsNothing);
    expect(find.text('5%'), findsNothing);
    expect(dailyBonusRewardWeights, const {
      'one_episode': 5,
      'one_movie': 5,
      'good_luck_next_round': 25,
      'two_movies': 5,
      'two_episodes': 5,
      'roll_again': 25,
      'three_movies': 5,
      'thanks_for_choosing_us': 25,
    });

    final scrollable = find.byType(ListView).first;
    await tester.dragUntilVisible(
      find.text('Bonus history'),
      scrollable,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonus history'), findsOneWidget);
    expect(find.text('No bonus boxes opened yet'), findsOneWidget);
    expect(find.text('A whole season'), findsNothing);
    service.dispose();
  });

  testWidgets('one-episode picker uses concise singular English labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(
      items: const [],
      existingRewardCode: 'one_episode',
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _openMoviePicker(tester);

    expect(find.text('Choose exactly 1 episode'), findsOneWidget);
    expect(find.text('Choose exactly 1 episode(s)'), findsNothing);
    expect(find.text('0 of 1 selected'), findsOneWidget);
    _expectEnglishVisibleCopy(tester);
    service.dispose();
  });

  testWidgets(
    'server result opens the Lucky Box before the bonus reward is revealed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _WheelService(
        items: const [],
        initialCanSpin: true,
        spinResults: const [
          {
            'id': 'box-again-1',
            'reward_code': 'roll_again',
            'selection_status': 'not_required',
          },
        ],
        includeExistingReward: false,
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      final art = find.byKey(const ValueKey('daily-lucky-box-art'));
      final closedPainter = tester.widget<CustomPaint>(art).painter!;
      expect(find.text('Lucky Box reward'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Open Lucky Box'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Opening your Lucky Box…'), findsOneWidget);
      expect(find.text('Lucky Box reward'), findsNothing);
      expect(
        tester.widget<CustomPaint>(art).painter!.shouldRepaint(closedPainter),
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump();
      expect(find.text('Lucky Box reward'), findsOneWidget);
      final rewardOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Lucky Box reward'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(rewardOpacity.opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(service.spinCalls, 1);
      expect(find.text('Lucky Box reward'), findsOneWidget);
      expect(
        find.text('The server has made another box available.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Open Lucky Box'),
            )
            .onPressed,
        isNotNull,
      );
      service.dispose();
    },
  );

  testWidgets(
    'server-selected ROLL AGAIN permits consecutive opens until another outcome',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _WheelService(
        items: const [],
        initialCanSpin: true,
        spinResults: const [
          {
            'id': 'box-again-1',
            'reward_code': 'roll_again',
            'selection_status': 'not_required',
          },
          {
            'id': 'box-again-2',
            'reward_code': 'roll_again',
            'selection_status': 'not_required',
          },
          {
            'id': 'box-again-3',
            'reward_code': 'roll_again',
            'selection_status': 'not_required',
          },
          {
            'id': 'box-good-luck',
            'reward_code': 'good_luck_next_round',
            'selection_status': 'not_required',
          },
        ],
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      Future<void> openBoxAndWait() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Open Lucky Box'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }

      for (var expectedCalls = 1; expectedCalls <= 3; expectedCalls++) {
        await openBoxAndWait();
        expect(service.spinCalls, expectedCalls);
        expect(
          find.text('The server has made another box available.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Open Lucky Box'),
              )
              .onPressed,
          isNotNull,
        );
      }

      await openBoxAndWait();
      expect(service.spinCalls, 4);
      expect(
        find.text(
          'Your next bonus box is available after the 24-hour cooldown.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Open Lucky Box'), findsNothing);
      service.dispose();
    },
  );

  testWidgets(
    'rapid repeat tap while server spin is pending sends only one request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gate = Completer<void>();
      final service = _WheelService(
        items: const [],
        initialCanSpin: true,
        spinGate: gate,
        spinResults: const [
          {
            'id': 'spin-after-double-tap',
            'reward_code': 'roll_again',
            'selection_status': 'not_required',
          },
        ],
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Open Lucky Box'));
      await tester.pump();
      expect(service.spinCalls, 1);
      final pendingButton = find.widgetWithText(
        FilledButton,
        'Checking bonus…',
      );
      expect(pendingButton, findsOneWidget);
      expect(tester.widget<FilledButton>(pendingButton).onPressed, isNull);

      await tester.tap(pendingButton);
      await tester.pump();
      expect(service.spinCalls, 1);

      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(service.spinCalls, 1);
      expect(
        find.text('The server has made another box available.'),
        findsOneWidget,
      );
      service.dispose();
    },
  );

  testWidgets(
    'spin API failure does not animate or show an unconfirmed reward',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _WheelService(
        items: const [],
        initialCanSpin: true,
        failSpin: true,
        includeExistingReward: false,
      );
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Open Lucky Box'));
      await tester.pumpAndSettle();
      expect(find.text('server unavailable'), findsOneWidget);
      expect(find.text('Lucky Box reward'), findsNothing);
      expect(find.text('Opening your Lucky Box…'), findsNothing);
      expect(find.byKey(const ValueKey('daily-wheel-rotating')), findsNothing);
      expect(tester.takeException(), isNull);
      service.dispose();
    },
  );

  testWidgets('Burmese spin errors are shown using an English fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(
      items: const [],
      initialCanSpin: true,
      failSpin: true,
      spinFailureMessage: '\u1000\u1019\u103a',
      includeExistingReward: false,
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Open Lucky Box'));
    await tester.pumpAndSettle();
    expect(
      find.text('Lucky Box request failed. Please try again.'),
      findsOneWidget,
    );
    _expectEnglishVisibleCopy(tester);
    service.dispose();
  });

  testWidgets('empty movie options show a clear eligible-content message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(items: const []);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _openMoviePicker(tester);

    expect(
      find.text('No eligible movies are available right now.'),
      findsOneWidget,
    );
    expect(service.optionsCalls, 1);
    service.dispose();
  });

  testWidgets('an options error is visible and retry can show movie choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(
      items: const [
        {'id': 41, 'title': 'Moonlit River'},
      ],
      failFirstOptionsLoad: true,
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _openMoviePicker(tester);

    expect(
      find.text(
        'Could not load reward options. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Moonlit River'), findsOneWidget);
    expect(service.optionsCalls, 2);
    service.dispose();
  });

  testWidgets('HTTP options failure shows the server status code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(
      items: const [],
      failFirstOptionsLoad: true,
      optionsFailureStatusCode: 503,
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    await _openMoviePicker(tester);

    expect(
      find.text(
        'YGNTV reward service error (HTTP 503). Please try again later.',
      ),
      findsOneWidget,
    );
    expect(service.optionsCalls, 1);
    service.dispose();
  });

  testWidgets('movie options remain selectable and commit the chosen ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _WheelService(
      items: const [
        {'id': 73, 'title': 'Lanterns at Dawn', 'subtitle': 'Movie'},
      ],
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.text('Lucky Box odds'), findsNothing);
    final scrollable = find.byType(ListView).first;
    await tester.dragUntilVisible(
      find.text('Bonus history'),
      scrollable,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bonus history'), findsOneWidget);
    expect(find.textContaining('Selection: Pending'), findsOneWidget);
    await tester.ensureVisible(find.text('Choose reward content'));
    await tester.pumpAndSettle();
    await _openMoviePicker(tester);

    expect(find.text('Lanterns at Dawn'), findsOneWidget);
    await tester.tap(find.text('Lanterns at Dawn'));
    await tester.pump();
    await tester.tap(find.text('Confirm selection'));
    await tester.pumpAndSettle();

    expect(service.selectedSpinId, 'spin-1');
    expect(service.selectedType, 'movie');
    expect(service.selectedContentIds, [73]);
    expect(find.textContaining('Selected: Chosen movie'), findsOneWidget);
    service.dispose();
  });
}
