import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../widgets/ygntv_brand.dart';
import 'follow_us_screen.dart';
import 'library_screen.dart';
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
  late Future<List<TvLibraryEntry>> _recentActivity;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.service.getProfile();
    _recentActivity = widget.service.getWatchHistory();
  }

  Future<void> _reload() async {
    final next = widget.service.getProfile();
    final nextActivity = widget.service.getWatchHistory();
    setState(() {
      _profile = next;
      _recentActivity = nextActivity;
    });
    try {
      await Future.wait<Object?>([next, nextActivity]);
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
        padding: const EdgeInsets.fromLTRB(14, 7, 14, 16),
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
          const SizedBox(height: 8),
          _RecentActivitySection(
            future: _recentActivity,
            onRetry: _reload,
            onViewAll: () =>
                _open(ActivityHistoryScreen(service: widget.service)),
          ),
          const SizedBox(height: 10),
          FutureBuilder<TvProfileData>(
            future: _profile,
            builder: (context, snapshot) => _AccountMenuGroup(
              key: const ValueKey('account-menu-group-screen-time'),
              title: 'SCREEN TIME',
              children: [
                _AccountMenuRow(
                  key: const ValueKey('account-menu-screen-time'),
                  iconName: 'screen_time',
                  title: 'Screen Time',
                  subtitle: snapshot.hasData
                      ? _screenTimeLabel(
                          snapshot.data!.screenTimeLast30DaysSeconds,
                        )
                      : snapshot.hasError
                      ? 'Usage summary is unavailable.'
                      : 'Loading usage summary…',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AccountMenuGroup(
            key: const ValueKey('account-menu-group-support'),
            title: 'SUPPORT & CONTACT',
            children: [
              _AccountMenuRow(
                key: const ValueKey('account-menu-help'),
                iconName: 'help',
                title: '24/7 Support',
                subtitle: 'Chat with YGNTV customer care anytime.',
                highlighted: true,
                onTap: () => _open(SupportChatScreen(service: widget.service)),
              ),
              _AccountMenuRow(
                key: const ValueKey('account-menu-connect'),
                iconName: 'social',
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
                  key: ValueKey('account-menu-group-devices'),
                  title: 'LOGGED IN DEVICES',
                  children: [SizedBox(height: 54)],
                );
              }
              if (!snapshot.hasData) {
                return _AccountMenuGroup(
                  key: const ValueKey('account-menu-group-devices'),
                  title: 'LOGGED IN DEVICES',
                  children: [
                    _AccountMenuRow(
                      key: const ValueKey('account-menu-devices'),
                      iconName: 'devices',
                      title: 'Logged In Devices',
                      subtitle: 'Could not load devices. Tap to retry.',
                      onTap: _reload,
                    ),
                  ],
                );
              }
              final profile = snapshot.data!;
              final devices = profile.devices;
              return _AccountMenuGroup(
                key: const ValueKey('account-menu-group-devices'),
                title: 'LOGGED IN DEVICES',
                children: [
                  ExpansionTile(
                    key: const PageStorageKey<String>(
                      'account-signed-in-devices',
                    ),
                    expansionAnimationStyle: AnimationStyle.noAnimation,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    collapsedShape: const Border(),
                    shape: const Border(),
                    leading: const _AccountMenuIcon(name: 'devices'),
                    title: const Text(
                      'Logged In Devices',
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
                                    Icons.smartphone_rounded,
                                    color: ygntvMuted,
                                    size: 18,
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
          const SizedBox(height: 18),
          _SignOutAction(onTap: () => widget.onSignOut()),
          const SizedBox(height: 9),
        ],
      ),
    ),
  );
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.future,
    required this.onRetry,
    required this.onViewAll,
  });

  final Future<List<TvLibraryEntry>> future;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('account-recent-activity'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: ygntvGold.withValues(alpha: .13)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Activity History',
                style: TextStyle(
                  color: ygntvGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('account-view-all-activity'),
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: ygntvRed,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        FutureBuilder<List<TvLibraryEntry>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Center(
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      color: ygntvRed,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent activity is unavailable.',
                      style: TextStyle(color: ygntvMuted, fontSize: 10),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('Retry'),
                  ),
                ],
              );
            }
            final entries = snapshot.data ?? const <TvLibraryEntry>[];
            if (entries.isEmpty) {
              return const Text(
                'No recent watch activity yet.',
                style: TextStyle(color: ygntvMuted, fontSize: 10),
              );
            }
            return Column(
              children: [
                for (final entry in entries.take(3))
                  _RecentWatchActivityRow(entry: entry),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _RecentWatchActivityRow extends StatelessWidget {
  const _RecentWatchActivityRow({required this.entry});

  final TvLibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final watchedAt = DateTime.tryParse(entry.lastWatchedAt ?? '')?.toLocal();
    final isEpisode = entry.contentType == 'episode';
    final type = isEpisode ? 'Series episode' : 'Movie';
    final icon = isEpisode ? Icons.live_tv_outlined : Icons.movie_outlined;
    final iconColor = isEpisode ? ygntvRed : ygntvGold;
    final subtitle = watchedAt == null
        ? type
        : '$type · ${_formatDate(watchedAt.toIso8601String())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF24232A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              key: ValueKey(
                'recent-activity-icon-${isEpisode ? 'episode' : 'movie'}',
              ),
              color: iconColor,
              size: 19,
              semanticLabel: type,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: ygntvMuted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    final premiumRemaining = _premiumRemainingLabel(profile?.entitlement);

    return ClipPath(
      key: const ValueKey('account-profile-card'),
      clipper: _ProfileHeaderClipper(),
      child: Container(
        key: const ValueKey('account-profile-card-background'),
        width: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFF741B25)),
        child: Stack(
          children: [
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
                      key: const ValueKey('account-profile-uid-row'),
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
                        if (isPremium)
                          const Padding(
                            padding: EdgeInsets.only(left: 3, right: 1),
                            child: Icon(
                              Icons.verified_rounded,
                              key: ValueKey('account-premium-verified'),
                              color: Color(0xFF39A5FF),
                              size: 15,
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
                            Icons.content_copy_rounded,
                            key: ValueKey('account-copy-uid-icon'),
                            color: ygntvGold,
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isPremium)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Premium · $premiumRemaining',
                        key: const ValueKey('account-premium-remaining'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ygntvGold,
                          fontSize: 10,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
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
    required this.iconName,
    required this.title,
    this.subtitle,
    this.highlighted = false,
    this.onTap,
  });

  final String iconName;
  final String title;
  final String? subtitle;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: [
          _AccountMenuIcon(name: iconName, highlighted: highlighted),
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
          if (onTap != null) ...[
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
  const _AccountMenuIcon({required this.name, this.highlighted = false});

  final String name;
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
      _accountMenuIconFor(name),
      color: highlighted ? ygntvRed : ygntvGold,
      size: 19,
      key: ValueKey('account-menu-icon-$name'),
    ),
  );
}

IconData _accountMenuIconFor(String name) => switch (name) {
  'screen_time' => Icons.access_time_rounded,
  'help' => Icons.support_agent_rounded,
  'social' => Icons.public_rounded,
  'devices' => Icons.devices_rounded,
  _ => Icons.info_outline_rounded,
};

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

String _premiumRemainingLabel(TvEntitlement? entitlement) {
  if (entitlement?.active != true) return '';
  final rawExpiry = entitlement?.validUntil?.trim();
  if (rawExpiry == null || rawExpiry.isEmpty) return 'duration unavailable';
  final expiry = DateTime.tryParse(rawExpiry)?.toLocal();
  if (expiry == null) return 'duration unavailable';

  final remaining = expiry.difference(DateTime.now());
  if (remaining.inSeconds <= 0) return 'expired';
  final days = remaining.inDays;
  if (days > 0) return '$days ${days == 1 ? 'day' : 'days'} left';
  final hours = remaining.inHours;
  if (hours > 0) return '$hours ${hours == 1 ? 'hour' : 'hours'} left';
  final minutes = remaining.inMinutes;
  if (minutes > 0) {
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} left';
  }
  return 'Less than a minute left';
}

String _screenTimeLabel(int? seconds) {
  if (seconds == null) return 'Usage data is unavailable.';
  if (seconds <= 0) return '0 min in the last 30 days';
  if (seconds < 60) return '$seconds sec in the last 30 days';
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) return '$minutes min in the last 30 days';
  if (remainingMinutes == 0) return '$hours hr in the last 30 days';
  return '$hours hr $remainingMinutes min in the last 30 days';
}

String _englishAccountError(Object error, String fallback) {
  final message = error is AuthException ? error.message : '$error';
  final clean = message.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  return clean.isEmpty ||
          RegExp(r'[\u1000-\u109F\uAA60-\uAA7F]').hasMatch(clean)
      ? fallback
      : clean;
}
