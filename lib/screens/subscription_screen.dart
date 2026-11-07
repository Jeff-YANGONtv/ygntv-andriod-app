import 'package:flutter/material.dart';

import '../deep_links/app_deep_link.dart';
import '../auth/auth_service.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/ygntv_brand.dart';
import 'manual_transfer_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    required this.service,
    this.initialTab = 0,
    super.key,
  });

  final AuthService service;
  final int initialTab;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Future<List<TvPremiumPlan>> _plans;
  final _codeController = TextEditingController();
  final _pageController = PageController();
  int _page = 0;
  late int _selectedTab;
  bool _redeeming = false;
  String? _redeemMessage;
  bool _redeemSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1).toInt();
    _plans = widget.service.getPremiumPlans();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _page = 0;
      _plans = widget.service.getPremiumPlans();
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  void _selectPlan(TvPremiumPlan plan) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ManualTransferScreen(service: widget.service, plan: plan),
      ),
    );
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _redeeming) return;
    setState(() {
      _redeeming = true;
      _redeemMessage = null;
    });
    try {
      final result = await widget.service.redeemMembership(code);
      if (!mounted) return;
      final until = result['valid_until'];
      setState(() {
        _redeemSuccess = true;
        _redeemMessage = until is String && until.isNotEmpty
            ? 'Promo code activated · Premium valid until ${_formatDate(until)}.'
            : 'Promo code activated.';
        _codeController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _redeemSuccess = false;
        _redeemMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    appBar: AppBar(
      title: const Text('Premium Subscription'),
      actions: [
        AppPageLinkButton(
          uri: AppDeepLink.linkFor('subscription/plans'),
          uriBuilder: () => AppDeepLink.linkFor(
            _selectedTab == 1 ? 'subscription/redeem' : 'subscription/plans',
          ),
        ),
      ],
    ),
    body: RefreshIndicator(
      color: ygntvRed,
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const YgntvBrandLockup(compact: true),
          const SizedBox(height: 19),
          const Text(
            'YANGON TV MEMBERSHIP',
            style: TextStyle(
              color: ygntvGold,
              fontSize: 9,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Premium Subscription',
            style: TextStyle(
              fontSize: 25,
              height: 1.1,
              letterSpacing: -.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 17),
          _subscriptionTabs(),
          const SizedBox(height: 18),
          if (_selectedTab == 0) _plansTab() else _promoTab(),
        ],
      ),
    ),
  );

  Widget _subscriptionTabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        _tabButton(0, Icons.workspace_premium_outlined, 'Membership plans'),
        _tabButton(1, Icons.card_giftcard_outlined, 'Promo code redeem'),
      ],
    ),
  );

  Widget _tabButton(int index, IconData icon, String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: () => setState(() => _selectedTab = index),
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        style: TextButton.styleFrom(
          foregroundColor: _selectedTab == index
              ? const Color(0xFFFFD4D6)
              : ygntvMuted,
          backgroundColor: _selectedTab == index
              ? ygntvRed.withValues(alpha: .18)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
  );

  Widget _plansTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose your access',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      const Text(
        'Unlock new releases, Myanmar subtitles, and a smoother way to watch.',
        style: TextStyle(color: ygntvMuted, fontSize: 11, height: 1.45),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<TvPremiumPlan>>(
        future: _plans,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 330,
              child: Center(child: CircularProgressIndicator(color: ygntvRed)),
            );
          }
          if (snapshot.hasError) {
            return _stateCard(
              icon: Icons.wifi_off_rounded,
              title: 'Plans could not be loaded',
              copy:
                  'Current prices come from YGNTV and are not guessed offline.',
              action: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            );
          }
          final plans =
              List<TvPremiumPlan>.of(snapshot.data ?? const <TvPremiumPlan>[])
                ..sort((a, b) {
                  final term = a.accessMonths.compareTo(b.accessMonths);
                  return term == 0 ? a.amountKs.compareTo(b.amountKs) : term;
                });
          if (plans.isEmpty) {
            return _stateCard(
              icon: Icons.hourglass_empty_rounded,
              title: 'No Premium plans are available right now.',
              copy: 'Please check back shortly for current membership options.',
            );
          }
          final selectedPage = _page.clamp(0, plans.length - 1);
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Plan ${selectedPage + 1} of ${plans.length}',
                      style: const TextStyle(
                        color: ygntvMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (plans.length > 1) ...[
                    IconButton(
                      tooltip: 'Previous plan',
                      visualDensity: VisualDensity.compact,
                      onPressed: selectedPage == 0
                          ? null
                          : () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      tooltip: 'Next plan',
                      visualDensity: VisualDensity.compact,
                      onPressed: selectedPage == plans.length - 1
                          ? null
                          : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            ),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ],
              ),
              SizedBox(
                height: 375,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: plans.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => _PlanCard(
                    plan: plans[index],
                    isBestValue: index == plans.length - 1,
                    onSelect: () => _selectPlan(plans[index]),
                  ),
                ),
              ),
              if (plans.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    plans.length,
                    (index) => Semantics(
                      button: true,
                      label: 'Show plan ${index + 1}: ${plans[index].label}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 7,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: selectedPage == index ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: selectedPage == index
                                  ? ygntvRed
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Swipe to compare plans',
                  style: TextStyle(color: ygntvMuted, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          );
        },
      ),
    ],
  );

  Widget _promoTab() => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ygntvRed.withValues(alpha: .13),
          Colors.white.withValues(alpha: .035),
        ],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ygntvRed.withValues(alpha: .3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Have a promo code?',
                    style: TextStyle(
                      color: ygntvMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Redeem your membership code',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Enter a code from Yangon TV to activate Premium access instantly.',
                    style: TextStyle(
                      color: ygntvMuted,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF9DA2)),
          ],
        ),
        const SizedBox(height: 17),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _redeem(),
          decoration: InputDecoration(
            hintText: 'Enter promo code',
            filled: true,
            fillColor: const Color(0xFF101015),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: FilledButton(
            onPressed: _redeeming ? null : _redeem,
            child: _redeeming
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Redeem code'),
          ),
        ),
        if (_redeemMessage != null) ...[
          const SizedBox(height: 11),
          Text(
            _redeemMessage!,
            style: TextStyle(
              color: _redeemSuccess
                  ? const Color(0xFF90D4A2)
                  : const Color(0xFFFFA6AC),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String copy,
    Widget? action,
  }) => Container(
    height: 280,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: ygntvGold, size: 32),
        const SizedBox(height: 13),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          copy,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ygntvMuted, fontSize: 11, height: 1.45),
        ),
        if (action != null) ...[const SizedBox(height: 10), action],
      ],
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isBestValue,
    required this.onSelect,
  });

  final TvPremiumPlan plan;
  final bool isBestValue;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${plan.label}, ${_formatKs(plan.amountKs)} Ks, ${plan.accessMonths} month${plan.accessMonths == 1 ? '' : 's'} access. Select plan to continue with manual transfer.',
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF302126), Color(0xFF19181F), Color(0xFF111116)],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .15),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: Color(0xFFFFC2C5),
                  size: 20,
                ),
              ),
              const Spacer(),
              if (isBestValue)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x26F0C778),
                    border: Border.all(color: const Color(0x66F0C778)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: ygntvGold,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Best value',
                        style: TextStyle(
                          color: Color(0xFFFFE0C5),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'YGNTV MEMBERSHIP',
            style: TextStyle(
              color: Color(0xFFFFADB1),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'PLAN PRICE',
            style: TextStyle(
              color: ygntvMuted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_formatKs(plan.amountKs)} Ks',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .055),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: ygntvGold, size: 14),
                const SizedBox(width: 7),
                Text(
                  '${plan.accessMonths} month${plan.accessMonths == 1 ? '' : 's'} access',
                  style: const TextStyle(
                    color: Color(0xFFDED7D4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          const Divider(color: Color(0x22FFFFFF), height: 1),
          const SizedBox(height: 10),
          const _BenefitRow(
            icon: Icons.devices_rounded,
            text: 'Desktop · Mobile',
          ),
          const SizedBox(height: 8),
          const _BenefitRow(
            icon: Icons.movie_outlined,
            text: 'All Contents From ygntv.org',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Select plan'),
              style: FilledButton.styleFrom(
                backgroundColor: ygntvRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFFFFB7BC), size: 15),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFD9D1D2),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

String _formatKs(int amount) {
  final digits = amount.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return output.toString();
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
