import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../widgets/ygntv_brand.dart';
import 'daily_signin_wheel_screen.dart';
import 'follow_us_screen.dart';
import 'referral_wallet_screen.dart';
import 'subscription_screen.dart';
import 'support_chat_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.service,
    required this.session,
    required this.onSignOut,
    this.onCheckForUpdates,
    super.key,
  });

  final AuthService service;
  final AuthSession session;
  final Future<void> Function() onSignOut;
  final Future<void> Function()? onCheckForUpdates;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<TvProfileData> _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.service.getProfile();
  }

  Future<void> _reload() async {
    final next = widget.service.getProfile();
    setState(() {
      _profile = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _revoke(TvDevice device) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ygntvPanel,
        title: const Text('Remove this device?'),
        content: Text(
          '“${device.name}” will be signed out of YGNTV. You can sign in again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove device'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.revokeDevice(device.id);
      if (mounted) {
        await _reload();
        if (mounted) _message('Device removed.');
      }
    } catch (error) {
      if (mounted) {
        _message(
          _englishAccountError(
            error,
            'Could not remove the device. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _copyUid() async {
    final uid = widget.session.userId.trim();
    if (uid.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: uid));
      if (mounted) _message('UID copied.');
    } catch (_) {
      if (mounted) _message('Could not copy UID.');
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ygntvBackground,
    child: RefreshIndicator(
      color: ygntvRed,
      onRefresh: _reload,
      child: ListView(
        key: const PageStorageKey<String>('account-profile-scroll'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          14,
          7,
          14,
          28 + 67 + MediaQuery.of(context).viewPadding.bottom,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 0, 2, 7),
            child: Text(
              'Account',
              style: TextStyle(
                color: ygntvGold,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          FutureBuilder<TvProfileData>(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _ProfileCard(
                  session: widget.session,
                  onCopyUid: _copyUid,
                  isLoading: true,
                );
              }
              if (snapshot.hasError) {
                return _ProfileCard(
                  session: widget.session,
                  errorMessage: 'Could not refresh account details. Showing your signed-in account info.',
                  onRetry: _reload,
                  onCopyUid: _copyUid,
                );
              }
              return _ProfileCard(
                profile: snapshot.data!,
                session: widget.session,
                onCopyUid: _copyUid,
              );
            },
          ),
          const SizedBox(height: 10),
          const _AccountSectionHeading(title: 'QUICK ACTIONS'),
          const SizedBox(height: 7),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _GridActionTile(
                    icon: Icons.workspace_premium_rounded,
                    key: const ValueKey('account-action-subscription'),
                    title: 'Subscription',
                    subtitle: 'Plans & membership codes.',
                    onTap: () =>
                        _open(SubscriptionScreen(service: widget.service)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GridActionTile(
                    icon: Icons.system_update_rounded,
                    key: const ValueKey('account-action-update'),
                    title: 'App Update',
                    subtitle: 'Check the latest app version.',
                    onTap: () => widget.onCheckForUpdates?.call(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _GridActionTile(
                    icon: Icons.redeem_rounded,
                    key: const ValueKey('account-action-referral'),
                    title: 'Refer & Earn',
                    subtitle: '500 Ks/month per invited Premium member.',
                    onTap: () =>
                        _open(ReferralWalletScreen(service: widget.service)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GridActionTile(
                    icon: Icons.card_giftcard_rounded,
                    key: const ValueKey('account-action-lucky-box'),
                    title: 'Daily Sign In Bonus (Lucky Box)',
                    subtitle: 'Choose your reward within 24 hours.',
                    onTap: () =>
                        _open(DailySignInWheelScreen(service: widget.service)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          _AccountMenuGroup(
            key: const ValueKey('account-menu-group-support'),
            title: 'SUPPORT & CONTACT',
            children: [
              _AccountMenuRow(
                key: const ValueKey('account-menu-help'),
                icon: Icons.support_agent_outlined,
                title: '24/7 Help',
                subtitle: 'Chat with YGNTV customer care anytime.',
                highlighted: true,
                onTap: () => _open(SupportChatScreen(service: widget.service)),
              ),
              _AccountMenuRow(
                key: const ValueKey('account-menu-connect'),
                icon: Icons.public_outlined,
                title: 'Connect With Us',
                subtitle: 'Official YGNTV social links',
                onTap: () => _open(FollowUsScreen(service: widget.service)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<TvProfileData>(
            future: _profile,
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const _AccountMenuGroup(
                  key: ValueKey('account-menu-group-activity'),
                  title: 'ACCOUNT ACTIVITY',
                  children: [SizedBox(height: 54), SizedBox(height: 54)],
                );
              }
              if (!snapshot.hasData) return const SizedBox.shrink();
              final profile = snapshot.data!;
              final minutes = profile.screenTimeLast30DaysSeconds ~/ 60;
              final duration = minutes >= 60
                  ? '${minutes ~/ 60} hr ${minutes % 60} min'
                  : '$minutes min';
              final devices = profile.devices;
              return _AccountMenuGroup(
                key: const ValueKey('account-menu-group-activity'),
                title: 'ACCOUNT ACTIVITY',
                children: [
                  KeyedSubtree(
                    key: const ValueKey('account-screen-time-card'),
                    child: _AccountMenuRow(
                      key: const ValueKey('account-menu-screen-time'),
                      icon: Icons.schedule_outlined,
                      title: 'Screen Time',
                      subtitle: 'Last 30 days · YGNTV only; other apps are not tracked.',
                      trailing: Text(
                        duration,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: ygntvGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  ExpansionTile(
                    key: const PageStorageKey<String>(
                      'account-signed-in-devices',
                    ),
                    expansionAnimationStyle: AnimationStyle.noAnimation,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    collapsedShape: const Border(),
                    shape: const Border(),
                    leading: const _AccountMenuIcon(
                      icon: Icons.devices_outlined,
                    ),
                    title: const Text(
                      'Logged In Device',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${devices.length} of ${profile.deviceLimit} allowed devices signed in',
                      style: const TextStyle(color: ygntvMuted, fontSize: 9.5),
                    ),
                    children: devices.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                'No active device records.',
                                style: TextStyle(
                                  color: ygntvMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ]
                        : devices
                              .map(
                                (device) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  leading: const Icon(
                                    Icons.smartphone_outlined,
                                    color: ygntvGold,
                                    size: 20,
                                  ),
                                  title: Text(
                                    device.name,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      device.platform,
                                      device.appVersion,
                                      if (device.lastSeenAt.isNotEmpty)
                                        'Seen ${_formatDate(device.lastSeenAt)}',
                                    ].where((part) => part.isNotEmpty).join(' · '),
                                    style: const TextStyle(
                                      color: ygntvMuted,
                                      fontSize: 8.5,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Revoke device',
                                    onPressed: _busy
                                        ? null
                                        : () => _revoke(device),
                                    icon: const Icon(
                                      Icons.phonelink_erase_rounded,
                                      color: Color(0xFFFFA6AC),
                                      size: 19,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _SignOutAction(onTap: () => widget.onSignOut()),
          const SizedBox(height: 9),
          const Text(
            'TEST BUILD · Private Android customer app · YGNTV.org',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF74717B), fontSize: 9),
          ),
        ],
      ),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.session,
    this.profile,
    this.errorMessage,
    this.onRetry,
    this.onCopyUid,
    this.isLoading = false,
  });
  final TvProfileData? profile;
  final AuthSession session;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCopyUid;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final profileDisplayName = profile?.displayName.trim() ?? '';
    final profileName = profile?.name.trim() ?? '';
    final sessionName = session.name.trim();
    final name = [profileDisplayName, profileName, sessionName].firstWhere(
      (value) => value.isNotEmpty && value != 'Yangon TV viewer',
      orElse: () => '',
    );
    final profileEmail = profile?.email.trim();
    final email = profileEmail != null && profileEmail.isNotEmpty
        ? profileEmail
        : session.email.trim();
    final heading = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email : 'Your Account');
    final initialSource = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email : 'U');
    final uid = session.userId.trim();
    final isPremium = profile?.entitlement.active == true;
    final plan = profile?.entitlement.planLabel?.trim() ?? '';
    final status = profile == null
        ? 'ACCOUNT DETAILS'
        : isPremium
        ? 'ACTIVE · ${plan.isEmpty ? 'PREMIUM' : plan.toUpperCase()}'
        : 'FREE MEMBER';

    return ClipPath(
      key: const ValueKey('account-profile-card'),
      clipper: _ProfileHeaderClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1A20), Color(0xFF151217), Color(0xFF261116)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -86,
              right: -62,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ygntvRed.withValues(alpha: .22),
                      ygntvRed.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 31),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ACCOUNT PROFILE',
                        style: TextStyle(
                          color: ygntvGold,
                          fontSize: 9,
                          letterSpacing: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (isLoading)
                        const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            color: ygntvRed,
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ygntvGold, ygntvRed],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ygntvRed.withValues(alpha: .24),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      key: const ValueKey('account-profile-avatar'),
                      backgroundColor: const Color(0xFF19191F),
                      child: Text(
                        initialSource.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ygntvMuted, fontSize: 10),
                    ),
                  ],
                  if (uid.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'UID: $uid',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ygntvGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy UID',
                          onPressed: onCopyUid,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.only(left: 4),
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 24,
                          ),
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: ygntvGold,
                            size: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 245),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? ygntvGold.withValues(alpha: .12)
                          : const Color(0xFF24232A),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: (isPremium ? ygntvGold : ygntvMuted).withValues(
                          alpha: .38,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPremium
                              ? Icons.verified_rounded
                              : Icons.person_outline_rounded,
                          color: isPremium ? ygntvGold : ygntvMuted,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPremium ? ygntvGold : Colors.white70,
                              fontSize: 9,
                              letterSpacing: .4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ygntvMuted, fontSize: 10),
                    ),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final curve = 20.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - curve)
      ..cubicTo(
        size.width * .78,
        size.height - 3,
        size.width * .68,
        size.height,
        size.width * .5,
        size.height,
      )
      ..cubicTo(
        size.width * .32,
        size.height,
        size.width * .22,
        size.height - 3,
        0,
        size.height - curve,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _GridActionTile extends StatelessWidget {
  const _GridActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ygntvPanel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: ygntvGold.withValues(alpha: .16)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              _AccountIconBadge(icon: icon, size: 33),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ygntvMuted,
                        fontSize: 9.5,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: ygntvRed,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccountIconBadge extends StatelessWidget {
  const _AccountIconBadge({required this.icon, this.size = 36});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .32),
      color: const Color(0xFF2A1D17),
      border: Border.all(color: ygntvGold.withValues(alpha: .3)),
    ),
    child: Icon(icon, color: ygntvGold, size: size * .58),
  );
}

class _AccountSectionHeading extends StatelessWidget {
  const _AccountSectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: const TextStyle(
        color: ygntvGold,
        fontSize: 9,
        letterSpacing: 1.15,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AccountMenuGroup extends StatelessWidget {
  const _AccountMenuGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _AccountSectionHeading(title: title),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: ygntvPanel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: ygntvGold.withValues(alpha: .13)),
          boxShadow: [
            BoxShadow(
              color: ygntvRed.withValues(alpha: .035),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 57, right: 12),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: .065),
                    ),
                  ),
                children[index],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _AccountMenuRow extends StatelessWidget {
  const _AccountMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.highlighted = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: [
          _AccountMenuIcon(icon: icon, highlighted: highlighted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ygntvMuted,
                      fontSize: 9.5,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right_rounded, color: ygntvRed, size: 19),
          ],
        ],
      ),
    );

    return Material(
      color: highlighted ? const Color(0xFF28171D) : Colors.transparent,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class _AccountMenuIcon extends StatelessWidget {
  const _AccountMenuIcon({required this.icon, this.highlighted = false});

  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      color: highlighted
          ? ygntvRed.withValues(alpha: .15)
          : const Color(0xFF24232A),
      border: Border.all(
        color: (highlighted ? ygntvRed : ygntvGold).withValues(alpha: .28),
      ),
    ),
    child: Icon(
      icon,
      color: highlighted ? const Color(0xFFFF9BA2) : ygntvGold,
      size: 18,
    ),
  );
}

class _SignOutAction extends StatelessWidget {
  const _SignOutAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF231317),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: ygntvRed.withValues(alpha: .34)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const ValueKey('account-sign-out-action'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.logout_rounded,
              color: Color(0xFFFF9BA2),
              size: 20,
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: Color(0xFFFFA3AA),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: ygntvRed.withValues(alpha: .9),
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _englishAccountError(Object error, String fallback) {
  final message = error is AuthException ? error.message : '$error';
  final clean = message.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  return clean.isEmpty ||
          RegExp(r'[\u1000-\u109F\uAA60-\uAA7F]').hasMatch(clean)
      ? fallback
      : clean;
}
