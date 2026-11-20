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
    color: Colors.black,
    child: RefreshIndicator(
      color: ygntvRed,
      onRefresh: _reload,
      child: ListView(
        key: const PageStorageKey<String>('account-profile-scroll'),
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        // Leave room to scroll the final interactive card clear of the fixed
        // CustomerHome navigation bar and the device's system navigation inset.
        padding: EdgeInsets.fromLTRB(
          14,
          8,
          14,
          28 + 67 + MediaQuery.of(context).viewPadding.bottom,
        ),
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.headset_mic_rounded,
            title: '24/7 Help',
            subtitle: 'Chat with YGNTV customer care anytime.',
            onTap: () => _open(SupportChatScreen(service: widget.service)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Connect With Us',
                style: TextStyle(
                  color: ygntvMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: .16),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ActionTile(
            icon: Icons.public_rounded,
            title: 'Follow Us',
            subtitle: 'Official YGNTV social links',
            onTap: () => _open(FollowUsScreen(service: widget.service)),
          ),
          const SizedBox(height: 8),
          FutureBuilder<TvProfileData>(
            future: _profile,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _Panel(child: SizedBox(height: 40));
                }
                return const SizedBox.shrink();
              }
              final minutes = snapshot.data!.screenTimeLast30DaysSeconds ~/ 60;
              final duration = minutes >= 60
                  ? '${minutes ~/ 60} hr ${minutes % 60} min'
                  : '$minutes min';
              return KeyedSubtree(
                key: const ValueKey('account-screen-time-card'),
                child: _Panel(
                  child: Row(
                    children: [
                      const _AccountIconBadge(
                        icon: Icons.schedule_rounded,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'In-app screen time · last 30 days',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$duration · YGNTV open time only; other apps are not tracked.',
                              style: const TextStyle(
                                color: ygntvMuted,
                                fontSize: 9.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 15),
          FutureBuilder<TvProfileData>(
            future: _profile,
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const _Panel(
                  padding: EdgeInsets.zero,
                  child: SizedBox(height: 72),
                );
              }
              if (!snapshot.hasData) return const SizedBox.shrink();
              final profile = snapshot.data!;
              final devices = profile.devices;
              return _Panel(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: const PageStorageKey<String>(
                    'account-signed-in-devices',
                  ),
                  expansionAnimationStyle: AnimationStyle.noAnimation,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  leading: const _AccountIconBadge(
                    icon: Icons.devices_other_rounded,
                    size: 36,
                  ),
                  title: const Text(
                    'Logged In Device',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
                              style: TextStyle(color: ygntvMuted, fontSize: 11),
                            ),
                          ),
                        ]
                      : devices
                            .map(
                              (device) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                leading: const _AccountIconBadge(
                                  icon: Icons.smartphone_rounded,
                                  size: 30,
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
              );
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => widget.onSignOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFFB81724),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
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

    return ClipRRect(
      key: const ValueKey('account-profile-card'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B1A20), Color(0xFF151217), Color(0xFF241116)],
          ),
          border: Border.all(color: ygntvGold.withValues(alpha: .24)),
          boxShadow: [
            BoxShadow(
              color: ygntvRed.withValues(alpha: .12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: -54,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ygntvRed.withValues(alpha: .20),
                      ygntvRed.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: ygntvRed,
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
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
                              color: ygntvRed.withValues(alpha: .20),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
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
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heading,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ygntvMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                            if (uid.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'UID: $uid',
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
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 27,
                                      height: 25,
                                    ),
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      color: ygntvGold,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: ygntvMuted, fontSize: 11),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ),
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
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: ygntvGold.withValues(alpha: .16)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _AccountIconBadge(icon: icon, size: 36),
              const SizedBox(width: 8),
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
                        fontSize: 12.5,
                        height: 1.15,
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
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                color: ygntvRed,
                size: 18,
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
    child: Icon(icon, color: ygntvGold, size: size * .6),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.zero,
    child: Material(
      color: ygntvPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ygntvGold.withValues(alpha: .15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minVerticalPadding: 7,
        leading: _AccountIconBadge(icon: icon, size: 36),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: ygntvMuted, fontSize: 10),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: ygntvRed,
          size: 20,
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: ygntvPanel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(19),
      side: BorderSide(color: ygntvGold.withValues(alpha: .12)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
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
