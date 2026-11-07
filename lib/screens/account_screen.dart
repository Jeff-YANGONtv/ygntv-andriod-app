import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/ygntv_brand.dart';
import 'library_screen.dart';
import 'follow_us_screen.dart';
import 'notifications_screen.dart';
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
    setState(() => _profile = next);
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
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  void _open(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: ygntvRed,
    onRefresh: _reload,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Row(
          children: [
            const YgntvBrandLockup(compact: true),
            const Spacer(),
            AppPageLinkButton(uri: AppDeepLink.linkFor('account')),
          ],
        ),
        const SizedBox(height: 22),
        FutureBuilder<TvProfileData>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Panel(
                child: SizedBox(
                  height: 112,
                  child: Center(
                    child: CircularProgressIndicator(color: ygntvRed),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return _Panel(
                child: Column(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: ygntvGold,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    const Text('Account details are unavailable.'),
                    const SizedBox(height: 6),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ygntvMuted, fontSize: 10),
                    ),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }
            return _ProfileCard(
              profile: snapshot.data!,
              session: widget.session,
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<TvProfileData>(
          future: _profile,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            return _MembershipCard(entitlement: snapshot.data!.entitlement);
          },
        ),
        const SizedBox(height: 15),
        const Text(
          'YOUR YGNTV',
          style: TextStyle(
            color: ygntvMuted,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        _ActionTile(
          icon: Icons.video_library_outlined,
          title: 'My Library',
          subtitle: 'Continue watching, history, and My List',
          onTap: () => _open(LibraryScreen(service: widget.service)),
        ),
        _ActionTile(
          icon: Icons.notifications_none_rounded,
          title: 'YGNTV Updates',
          subtitle: 'Announcements and account notifications',
          onTap: () => _open(NotificationsScreen(service: widget.service)),
        ),
        _ActionTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Premium membership',
          subtitle: 'Current plans, prices, and code redemption',
          onTap: () => _open(SubscriptionScreen(service: widget.service)),
        ),
        if (widget.onCheckForUpdates != null) ...[
          const SizedBox(height: 9),
          const Text(
            'APP',
            style: TextStyle(
              color: ygntvMuted,
              fontSize: 9,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _ActionTile(
            icon: Icons.system_update_alt_rounded,
            title: 'Check for app updates',
            subtitle: 'Check for the latest YGNTV app release',
            onTap: () {
              widget.onCheckForUpdates?.call();
            },
          ),
        ],
        const SizedBox(height: 9),
        const Text(
          'HELP & SUPPORT',
          style: TextStyle(
            color: ygntvMuted,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        _ActionTile(
          icon: Icons.support_agent_rounded,
          title: 'Help & Support',
          subtitle: 'Chat with the YGNTV customer care team',
          onTap: () => _open(SupportChatScreen(service: widget.service)),
        ),
        const SizedBox(height: 15),
        const Text(
          'CONNECT',
          style: TextStyle(
            color: ygntvMuted,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        _ActionTile(
          icon: Icons.share_rounded,
          title: 'Follow Us',
          subtitle: 'Official YGNTV social links',
          onTap: () => _open(FollowUsScreen(service: widget.service)),
        ),
        const SizedBox(height: 15),
        FutureBuilder<TvProfileData>(
          future: _profile,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final devices = snapshot.data!.devices;
            return _Panel(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 15),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                leading: const Icon(Icons.devices_rounded, color: ygntvGold),
                title: const Text(
                  'Signed-in devices',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${devices.length} active ${devices.length == 1 ? 'device' : 'devices'}',
                  style: const TextStyle(color: ygntvMuted, fontSize: 10),
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
                              leading: const Icon(
                                Icons.smartphone_rounded,
                                size: 19,
                                color: ygntvMuted,
                              ),
                              title: Text(
                                device.name,
                                style: const TextStyle(
                                  fontSize: 11,
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
                                  fontSize: 9,
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Revoke device',
                                onPressed: _busy ? null : () => _revoke(device),
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
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
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => widget.onSignOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFA6AC),
            side: const BorderSide(color: Color(0x66E5454F)),
            minimumSize: const Size.fromHeight(49),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'UNOFFICIAL V1 · YGNTV.org · Android',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF74717B), fontSize: 9),
        ),
      ],
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.session});
  final TvProfileData profile;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : session.name;
    final email = profile.email.isNotEmpty ? profile.email : session.email;
    return _Panel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: ygntvRed.withValues(alpha: .18),
            child: Text(
              name.trim().isEmpty
                  ? 'Y'
                  : name.trim().characters.first.toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ygntvMuted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.entitlement});
  final TvEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final active = entitlement.active;
    return _Panel(
      child: Row(
        children: [
          Icon(
            active
                ? Icons.workspace_premium_rounded
                : Icons.lock_outline_rounded,
            color: active ? ygntvGold : ygntvMuted,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? (entitlement.planLabel ?? 'Premium active')
                      : 'No active Premium membership',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active && entitlement.validUntil != null
                      ? 'Valid through ${_formatDate(entitlement.validUntil!)}'
                      : active
                      ? 'Your account can stream protected titles.'
                      : 'Premium titles require an active entitlement.',
                  style: const TextStyle(
                    color: ygntvMuted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF81D398),
              size: 18,
            ),
        ],
      ),
    );
  }
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
    margin: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: ygntvGold),
        title: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: ygntvMuted, fontSize: 9),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: ygntvMuted),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: ygntvPanel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: BorderSide(color: Colors.white.withValues(alpha: .06)),
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
