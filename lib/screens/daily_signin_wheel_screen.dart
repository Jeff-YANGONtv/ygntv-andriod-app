import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_service.dart';

const _ink = Color(0xFF09090B),
    _panel = Color(0xFF19171D),
    _gold = Color(0xFFFFC857),
    _muted = Color(0xFFAAA6B0);

class _BonusOutcome {
  const _BonusOutcome(this.code, this.label, this.weight, this.color);

  final String code;
  final String label;
  final int weight;
  final Color color;
}

const _bonusOutcomes = <_BonusOutcome>[
  _BonusOutcome('one_episode', 'WATCH FREE 1 EPISODE', 5, Color(0xFFAA171D)),
  _BonusOutcome('one_movie', 'WATCH FREE 1 MOVIE', 5, Color(0xFF19191D)),
  _BonusOutcome(
    'good_luck_next_round',
    'GOOD LUCK IN NEXT ROUND',
    25,
    Color(0xFFC5222A),
  ),
  _BonusOutcome('two_movies', 'WATCH FREE 2 MOVIES', 5, Color(0xFF202024)),
  _BonusOutcome('two_episodes', 'WATCH FREE 2 EPISODES', 5, Color(0xFFD0A13C)),
  _BonusOutcome('roll_again', 'ROLL AGAIN', 25, Color(0xFFAE171E)),
  _BonusOutcome('three_movies', 'WATCH FREE 3 MOVIES', 5, Color(0xFF19191D)),
  _BonusOutcome('thanks_for_choosing_us', 'THANK YOU', 25, Color(0xFFC5222A)),
];

List<String> get dailyBonusOutcomeOrder =>
    List.unmodifiable(_bonusOutcomes.map((outcome) => outcome.code));

Map<String, int> get dailyBonusRewardWeights => Map.unmodifiable({
  for (final outcome in _bonusOutcomes) outcome.code: outcome.weight,
});

final _rewardLabels = {
  for (final outcome in _bonusOutcomes) outcome.code: outcome.label,
};

class DailySignInWheelScreen extends StatefulWidget {
  const DailySignInWheelScreen({super.key, required this.service});
  final AuthService service;
  @override
  State<DailySignInWheelScreen> createState() => _DailySignInWheelScreenState();
}

class _DailySignInWheelScreenState extends State<DailySignInWheelScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _overview;
  late final AnimationController _boxController;
  Map<String, dynamic>? _prize;
  int _rewardRevealKey = 0;
  bool _opening = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _overview = widget.service.getDailySignInWheelOverview();
    _boxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
  }

  @override
  void dispose() {
    _boxController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final f = widget.service.getDailySignInWheelOverview();
    setState(() {
      _overview = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _spin() async {
    if (_busy) return;
    setState(() => _busy = true);
    _boxController.reset();
    try {
      final r = await widget.service.spinDailySignInWheel(
        spinKey: const Uuid().v4(),
      );
      if (!mounted) return;
      final spin = _map(r['spin']);
      final code = '${spin['reward_code'] ?? spin['code'] ?? ''}';
      if (spin.isEmpty || !_rewardLabels.containsKey(code)) {
        throw const FormatException(
          'The server returned an unknown bonus result.',
        );
      }

      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      _boxController.duration = reducedMotion
          ? const Duration(milliseconds: 450)
          : const Duration(milliseconds: 1900);
      setState(() => _opening = true);
      await _boxController.forward();
      if (!mounted) return;

      final overview = _map(r['overview']);
      setState(() {
        _prize = spin;
        _rewardRevealKey++;
        _opening = false;
        _overview = Future.value(overview);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = false);
      _message(e);
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _kind(String code) => code.contains('episode') ? 'episode' : 'movie';
  int _requiredCount(String code) =>
      code == 'two_movies' || code == 'two_episodes'
      ? 2
      : code == 'three_movies'
      ? 3
      : 1;
  bool _isContentReward(String code) => const {
    'one_movie',
    'two_movies',
    'three_movies',
    'one_episode',
    'two_episodes',
  }.contains(code);
  bool _isSelectable(Map<String, dynamic> p) {
    final code = '${p['reward_code'] ?? p['code'] ?? ''}';
    final status = '${p['selection_status'] ?? ''}';
    final expiry = DateTime.tryParse('${p['expires_at'] ?? ''}');
    return _isContentReward(code) &&
        status != 'selected' &&
        status != 'expired' &&
        (expiry == null || expiry.isAfter(DateTime.now()));
  }

  Future<void> _select(Map<String, dynamic> prize) async {
    if (_busy) return;
    final code = '${prize['reward_code'] ?? prize['code'] ?? ''}';
    final spinId = '${prize['id'] ?? prize['spin_id'] ?? ''}';
    if (spinId.isEmpty) return;
    final picked = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      builder: (context) => _OptionPicker(
        service: widget.service,
        spinId: spinId,
        type: _kind(code),
        requiredCount: _requiredCount(code),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final type = _kind(code);
      final result = await widget.service.commitDailyWheelSelection(
        spinId: spinId,
        type: type,
        contentIds: picked.map((e) => _int(e['id'])).toList(),
      );
      if (!mounted) return;
      final authoritative = _map(result['spin']);
      setState(
        () => _prize = authoritative.isNotEmpty ? authoritative : result,
      );
      final o = _map(result['overview']);
      if (o.isNotEmpty) setState(() => _overview = Future.value(o));
      await _reload();
    } catch (e) {
      _message(e);
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(Object e) {
    final raw = e is AuthException ? e.message : '$e';
    final clean = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final text =
        clean.isEmpty || RegExp(r'[\u1000-\u109F\uAA60-\uAA7F]').hasMatch(clean)
        ? 'Lucky Box request failed. Please try again.'
        : clean;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        title: const Text('Daily Sign In Bonus (Lucky Box)'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _gold));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load Lucky Box details.'),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data ?? <String, dynamic>{};
          final canSpin = data['can_spin'] == true;
          final history = _rows(data['rewards']);
          final prize = _prize ?? _activePrize(history);
          final code = '${prize?['reward_code'] ?? prize?['code'] ?? ''}';
          final selection = _map(prize?['selection']);
          final selectable = prize != null && _isSelectable(prize);
          return RefreshIndicator(
            color: _gold,
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                _card(
                  Column(
                    children: [
                      const Text(
                        'Open a box for a server-selected YGNTV reward.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 280,
                        height: 250,
                        child: AnimatedBuilder(
                          animation: _boxController,
                          builder: (context, _) {
                            final progress = _boxController.value;
                            return Semantics(
                              label: 'Lucky Box',
                              value: progress >= .98
                                  ? 'Open'
                                  : progress > 0
                                  ? 'Opening'
                                  : 'Closed',
                              child: CustomPaint(
                                key: const ValueKey('daily-lucky-box-art'),
                                painter: _LuckyBoxPainter(progress: progress),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_opening) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Opening your Lucky Box…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _gold, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: canSpin && !_busy ? _spin : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _ink,
                          ),
                          child: Text(
                            _busy
                                ? _opening
                                      ? 'Opening…'
                                      : 'Checking bonus…'
                                : canSpin
                                ? 'Open Lucky Box'
                                : 'Next bonus: ${_date(data['next_spin_at'])}',
                          ),
                        ),
                      ),
                      if (!canSpin)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'A non-repeat result starts the 24-hour cooldown.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      if (canSpin)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'ROLL AGAIN can unlock consecutive opens.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (prize != null)
                  TweenAnimationBuilder<double>(
                    key: ValueKey('daily-reward-$_rewardRevealKey'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final progress = value.clamp(0.0, 1.0).toDouble();
                      return Opacity(
                        opacity: progress,
                        child: Transform.translate(
                          offset: Offset(0, 34 * (1 - progress)),
                          child: Transform.scale(
                            scale: .94 + .06 * progress,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lucky Box reward',
                            style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _rewardLabels[code] ??
                                '${prize['reward_label'] ?? 'Reward'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (code == 'roll_again')
                            const Text(
                              'The server has made another box available.',
                              style: TextStyle(color: _muted),
                            ),
                          if (code == 'good_luck_next_round')
                            const Text(
                              'Your next bonus box is available after the 24-hour cooldown.',
                              style: TextStyle(color: _muted),
                            ),
                          if (code == 'thanks_for_choosing_us')
                            const Text(
                              'Thanks for choosing Yangon TV.',
                              style: TextStyle(color: _muted),
                            ),
                          if (_isContentReward(code) &&
                              prize['expires_at'] != null)
                            Text(
                              'Expires: ${_date(prize['expires_at'])}',
                              style: const TextStyle(color: _muted),
                            ),
                          if (_isContentReward(code))
                            Text(
                              'Selection status: ${_selectionStatusLabel(prize['selection_status'])}',
                              style: const TextStyle(color: _muted),
                            ),
                          if (selectable) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Choose before expiry. This selection cannot be changed.',
                              style: TextStyle(color: _muted),
                            ),
                            FilledButton(
                              onPressed: _busy ? null : () => _select(prize),
                              child: const Text('Choose reward content'),
                            ),
                          ],
                          if (selection.isNotEmpty)
                            Text(
                              'Selected: ${selection['title'] ?? selection['name'] ?? selection}',
                              style: const TextStyle(color: _gold),
                            ),
                          if (_isContentReward(code) &&
                              prize['selection_status'] == 'expired')
                            const Text(
                              'This reward has expired.',
                              style: TextStyle(color: _muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bonus history',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (history.isEmpty)
                        const Text(
                          'No bonus boxes opened yet',
                          style: TextStyle(color: _muted),
                        ),
                      for (final row in history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _rewardLabels['${row['reward_code'] ?? row['code']}'] ??
                                '${row['reward_label'] ?? 'Reward'}',
                          ),
                          subtitle: Text(
                            'Selection: ${_selectionStatusLabel(row['selection_status'] ?? 'not_required')} · Expires ${_date(row['expires_at'])}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          trailing: _isSelectable(row)
                              ? TextButton(
                                  onPressed: _busy ? null : () => _select(row),
                                  child: const Text('Select'),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic>? _activePrize(List<Map<String, dynamic>> rewards) {
    final now = DateTime.now();
    for (final row in rewards) {
      final status = '${row['selection_status'] ?? ''}';
      final expiry = DateTime.tryParse('${row['expires_at'] ?? ''}');
      final code = '${row['reward_code'] ?? row['code'] ?? ''}';
      if (_isContentReward(code) &&
          status == 'pending' &&
          (expiry == null || expiry.isAfter(now))) {
        return row;
      }
    }
    return null;
  }
}

class _OptionPicker extends StatefulWidget {
  const _OptionPicker({
    required this.service,
    required this.spinId,
    required this.type,
    required this.requiredCount,
  });
  final AuthService service;
  final String spinId, type;
  final int requiredCount;
  @override
  State<_OptionPicker> createState() => _OptionPickerState();
}

class _OptionPickerState extends State<_OptionPicker> {
  final _search = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  final Set<int> _selected = {};
  int _page = 1;
  bool _hasMore = true, _loading = false;
  String _query = '';
  String? _loadError;
  int _requestGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    final requestedPage = reset ? 1 : _page;
    final requestedQuery = _query;
    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    setState(() {
      _loading = true;
      if (reset) {
        _items.clear();
        _loadError = null;
      }
    });
    try {
      final response = await widget.service.getDailyWheelOptions(
        spinId: widget.spinId,
        type: widget.type,
        page: requestedPage,
        search: requestedQuery,
      );
      final data = _map(response['data'] ?? response);
      final rows = _rows(data['items']);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _items.addAll(rows);
        _hasMore = data['has_more'] == true;
        _page = requestedPage + 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _hasMore = false;
        _loading = false;
        _loadError = _loadFailureMessage(error);
      });
    }
  }

  String _loadFailureMessage(Object error) {
    if (error is AuthException && error.code == 'invalid_reward_options') {
      return 'YGNTV returned an invalid reward-options response. Please retry later.';
    }
    final statusCode = error is AuthException ? error.statusCode : null;
    if (statusCode == 401) {
      return 'Your sign-in session could not be verified. Sign in again, then retry (HTTP 401).';
    }
    if (statusCode == 403) {
      return 'YGNTV denied access to these reward options (HTTP 403).';
    }
    if (statusCode == 404) {
      return 'The reward-options request was not found (HTTP 404).';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'YGNTV reward service error (HTTP $statusCode). Please try again later.';
    }
    if (statusCode != null) {
      return 'Reward options request failed (HTTP $statusCode). Please try again.';
    }
    return 'Could not load reward options. Check your connection and try again.';
  }

  String get _emptyMessage {
    if (_query.trim().isNotEmpty) return 'No results match "$_query".';
    return switch (widget.type) {
      'movie' => 'No eligible movies are available right now.',
      'episode' => 'No eligible series episodes are available right now.',
      _ => 'No eligible options are available right now.',
    };
  }

  Widget _buildOptions() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: _muted, size: 30),
              const SizedBox(height: 10),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _load(reset: true),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator(color: _gold)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
              ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 80) {
          _load();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _items.length + (_hasMore && _loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: _gold),
              ),
            );
          }
          final item = _items[index];
          final id = _int(item['id']);
          final chosen = _selected.contains(id);
          final disabled = !chosen && _selected.length >= _allowedCount;
          return CheckboxListTile(
            value: chosen,
            onChanged: disabled
                ? null
                : (v) => setState(
                    () => v == true ? _selected.add(id) : _selected.remove(id),
                  ),
            title: Text('${item['title'] ?? 'Untitled'}'),
            subtitle: Text('${item['subtitle'] ?? ''}'),
            activeColor: _gold,
            checkColor: _ink,
          );
        },
      ),
    );
  }

  int get _allowedCount => widget.requiredCount;
  String get _contentLabel => widget.type == 'movie' ? 'movie' : 'episode';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose exactly $_allowedCount $_contentLabel${_allowedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search options',
                      ),
                      onChanged: (v) {
                        _query = v;
                        _load(reset: true);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildOptions()),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${_selected.length} of $_allowedCount selected',
                      style: const TextStyle(color: _muted),
                    ),
                    FilledButton(
                      onPressed: _selected.length == _allowedCount
                          ? () => Navigator.pop(
                              context,
                              _items
                                  .where(
                                    (e) => _selected.contains(_int(e['id'])),
                                  )
                                  .toList(),
                            )
                          : null,
                      child: const Text('Confirm selection'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

Widget _card(Widget child) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: _panel,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _gold.withValues(alpha: .16)),
    boxShadow: [BoxShadow(color: _gold.withValues(alpha: .08), blurRadius: 14)],
  ),
  child: child,
);

String _selectionStatusLabel(dynamic value) {
  final status = value?.toString().trim() ?? '';
  return switch (status) {
    'pending' => 'Pending',
    'selected' => 'Selected',
    'expired' => 'Expired',
    'not_required' => 'Not required',
    '' => 'Not available',
    _ => status.replaceAll('_', ' '),
  };
}

class _LuckyBoxPainter extends CustomPainter {
  const _LuckyBoxPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    canvas.save();
    canvas.scale(size.width / 280, size.height / 250);

    _paintLight(canvas, t);
    _paintBox(canvas, t);
    _paintSparkles(canvas, t);

    canvas.restore();
  }

  void _paintLight(Canvas canvas, double t) {
    if (t <= 0) return;
    final beamBounds = const Rect.fromLTWH(28, 0, 224, 126);
    final beamPath = Path()
      ..moveTo(140, 111)
      ..lineTo(45, 5)
      ..lineTo(235, 5)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFFD36B).withValues(alpha: t * .52),
            const Color(0xFFFFC857).withValues(alpha: t * .22),
            const Color(0xFFFFC857).withValues(alpha: 0),
          ],
        ).createShader(beamBounds),
    );

    for (final ray in const [
      (Offset(116, 112), Offset(72, 10), Offset(91, 10)),
      (Offset(164, 112), Offset(189, 10), Offset(208, 10)),
    ]) {
      final path = Path()
        ..moveTo(ray.$1.dx, ray.$1.dy)
        ..lineTo(ray.$2.dx, ray.$2.dy)
        ..lineTo(ray.$3.dx, ray.$3.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFFFFE08A).withValues(alpha: t * .26),
      );
    }

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(140, 111), width: 128, height: 30),
      Paint()
        ..color = const Color(0xFFFFC857).withValues(alpha: t * .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _paintBox(Canvas canvas, double t) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(140, 222), width: 162, height: 25),
      Paint()
        ..color = Colors.black.withValues(alpha: .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    final leftFace = Path()
      ..moveTo(65, 107)
      ..lineTo(140, 128)
      ..lineTo(140, 220)
      ..lineTo(65, 197)
      ..close();
    final rightFace = Path()
      ..moveTo(140, 128)
      ..lineTo(215, 107)
      ..lineTo(215, 197)
      ..lineTo(140, 220)
      ..close();
    canvas.drawPath(
      leftFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE23A42), Color(0xFF8D101A)],
        ).createShader(const Rect.fromLTWH(65, 107, 75, 113)),
    );
    canvas.drawPath(
      rightFace,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF33151B), Color(0xFF100D12)],
        ).createShader(const Rect.fromLTWH(140, 107, 75, 113)),
    );

    final goldEdge = Paint()
      ..color = const Color(0xFFE8B74D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(leftFace, goldEdge);
    canvas.drawPath(rightFace, goldEdge);

    final leftRibbon = Path()
      ..moveTo(112, 120)
      ..lineTo(124, 124)
      ..lineTo(124, 215)
      ..lineTo(112, 211)
      ..close();
    final rightRibbon = Path()
      ..moveTo(156, 124)
      ..lineTo(168, 120)
      ..lineTo(168, 211)
      ..lineTo(156, 215)
      ..close();
    final ribbonPaint = Paint()..color = const Color(0xFFFFC857);
    canvas.drawPath(leftRibbon, ribbonPaint);
    canvas.drawPath(rightRibbon, ribbonPaint);
    canvas.drawPath(
      Path()
        ..moveTo(117, 122)
        ..lineTo(121, 123)
        ..lineTo(121, 214)
        ..lineTo(117, 212)
        ..close(),
      Paint()..color = const Color(0xFFB41420),
    );
    canvas.drawPath(
      Path()
        ..moveTo(159, 123)
        ..lineTo(163, 122)
        ..lineTo(163, 212)
        ..lineTo(159, 214)
        ..close(),
      Paint()..color = const Color(0xFFB41420),
    );

    final opening = Path()
      ..moveTo(65, 107)
      ..lineTo(140, 87)
      ..lineTo(215, 107)
      ..lineTo(140, 129)
      ..close();
    canvas.drawPath(opening, Paint()..color = const Color(0xFF100A0D));
    canvas.drawPath(opening, goldEdge);

    final leftClosed = const [
      Offset(140, 83),
      Offset(54, 105),
      Offset(140, 130),
      Offset(140, 106),
    ];
    final rightClosed = const [
      Offset(140, 83),
      Offset(226, 105),
      Offset(140, 130),
      Offset(140, 106),
    ];
    final leftOpen = const [
      Offset(140, 106),
      Offset(79, 96),
      Offset(34, 57),
      Offset(103, 69),
    ];
    final rightOpen = const [
      Offset(140, 106),
      Offset(201, 96),
      Offset(246, 57),
      Offset(177, 69),
    ];
    final leftFlap = List.generate(
      4,
      (i) => Offset.lerp(leftClosed[i], leftOpen[i], t)!,
    );
    final rightFlap = List.generate(
      4,
      (i) => Offset.lerp(rightClosed[i], rightOpen[i], t)!,
    );
    _drawPolygon(
      canvas,
      leftFlap,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFF1D0), Color(0xFFC21B27)],
        ).createShader(const Rect.fromLTWH(30, 55, 112, 80)),
    );
    _drawPolygon(
      canvas,
      rightFlap,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE3A1), Color(0xFF72121B)],
        ).createShader(const Rect.fromLTWH(138, 55, 112, 80)),
    );
    _drawPolygon(canvas, leftFlap, goldEdge);
    _drawPolygon(canvas, rightFlap, goldEdge);

    final bowAlpha = (1 - t) * .92;
    final bowPaint = Paint()
      ..color = const Color(0xFFE12B36).withValues(alpha: bowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(128, 83), width: 23, height: 13),
      bowPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(152, 83), width: 23, height: 13),
      bowPaint,
    );
    canvas.drawCircle(
      const Offset(140, 84),
      4,
      Paint()..color = const Color(0xFFFFC857).withValues(alpha: bowAlpha),
    );
  }

  void _paintSparkles(Canvas canvas, double t) {
    if (t <= .04) return;
    const stars = [
      (Offset(56, 38), 5.0),
      (Offset(222, 32), 4.0),
      (Offset(39, 74), 3.5),
      (Offset(243, 72), 4.5),
      (Offset(83, 58), 3.0),
      (Offset(197, 56), 3.4),
      (Offset(61, 105), 2.5),
      (Offset(219, 103), 2.6),
    ];
    for (var index = 0; index < stars.length; index++) {
      final (center, radius) = stars[index];
      final shimmer =
          .35 + .65 * ((math.sin(progress * 12 + index * 1.7) + 1) / 2);
      final r = radius * (.72 + shimmer * .28);
      final path = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + r * .23, center.dy - r * .23)
        ..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx + r * .23, center.dy + r * .23)
        ..lineTo(center.dx, center.dy + r)
        ..lineTo(center.dx - r * .23, center.dy + r * .23)
        ..lineTo(center.dx - r, center.dy)
        ..lineTo(center.dx - r * .23, center.dy - r * .23)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFFFFE7A4).withValues(alpha: t * shimmer),
      );
    }
  }

  void _drawPolygon(Canvas canvas, List<Offset> points, Paint paint) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LuckyBoxPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _rows(dynamic v) => v is List
    ? v.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
    : <Map<String, dynamic>>[];
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _date(dynamic v) {
  final d = DateTime.tryParse('$v')?.toLocal();
  return d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
