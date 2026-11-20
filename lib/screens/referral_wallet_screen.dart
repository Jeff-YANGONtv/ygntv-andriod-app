import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_service.dart';

const _ink = Color(0xFF09090B);
const _panel = Color(0xFF17171B);
const _red = Color(0xFFE5454F);
const _gold = Color(0xFFFFC857);
const _muted = Color(0xFFAAA7B0);

class ReferralWalletScreen extends StatefulWidget {
  const ReferralWalletScreen({required this.service, super.key});

  final AuthService service;

  @override
  State<ReferralWalletScreen> createState() => _ReferralWalletScreenState();
}

class _ReferralWalletScreenState extends State<ReferralWalletScreen> {
  late Future<Map<String, dynamic>> _overview;

  @override
  void initState() {
    super.initState();
    _overview = widget.service.getReferralOverview();
  }

  Future<void> _reload() async {
    final next = widget.service.getReferralOverview();
    setState(() {
      _overview = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied.')));
  }

  Future<void> _withdraw(int balance) async {
    final requested = await showDialog<bool>(
      context: context,
      builder: (_) => _WithdrawalRequestDialog(
        balance: balance,
        onSubmit:
            ({
              required int amountKs,
              required String paymentMethod,
              required String payoutAddress,
            }) => widget.service.requestReferralWithdrawal(
              amountKs: amountKs,
              paymentMethod: paymentMethod,
              payoutAddress: payoutAddress,
              requestKey: const Uuid().v4(),
            ),
      ),
    );
    if (requested == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    appBar: AppBar(backgroundColor: _ink, title: const Text('Refer & Earn')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _red));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load referral details.'),
                TextButton(onPressed: _reload, child: const Text('Try again')),
              ],
            ),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final code = '${data['referral_code'] ?? ''}';
        final link = '${data['referral_link'] ?? ''}';
        final earned = _intValue(data['earned_total_ks']);
        final balance = _intValue(data['withdrawable_balance_ks']);
        final leaderboard = _rows(data['leaderboard']);
        final withdrawals = _rows(data['withdrawal_requests']);
        final attributed = data['attributed'] == true;
        return RefreshIndicator(
          color: _red,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              _referralPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total referral earnings',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ks(earned),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Withdrawable balance',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ks(balance),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Earn 500 Ks for each month an invited member’s Premium subscription is approved. Withdrawable balance follows the referral ledger.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: balance > 0
                            ? () => _withdraw(balance)
                            : null,
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Request withdrawal'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _referralPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your referral code',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            code,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy referral code',
                          onPressed: code.isEmpty
                              ? null
                              : () => _copy(code, 'Referral code'),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    if (link.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SelectableText(
                        link,
                        style: const TextStyle(color: _muted, fontSize: 10.5),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _copy(link, 'Referral link'),
                          icon: const Icon(Icons.link),
                          label: const Text('Copy referral link'),
                        ),
                      ),
                    ],
                    const Text(
                      'New accounts opened through your link will have your code prefilled at sign-up. A referral is assigned once, during sign-up, and cannot be added or changed later.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                    if (attributed) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'This account’s referral was set at sign-up and cannot be changed.',
                        style: TextStyle(color: _gold, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _referralPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registered: ${_intValue(data['registered_invitees'] ?? data['total_registered_invitees'])} · Premium: ${_intValue(data['paid_invitees'] ?? data['distinct_paid_premium_invitees'] ?? data['successful_invites'])}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Top referrers · ranked by invited members with an approved Premium payment.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (leaderboard.isEmpty)
                      const Text(
                        'No approved referrals yet.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      )
                    else
                      for (var index = 0; index < leaderboard.length; index++)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: _red.withValues(alpha: .18),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            '${leaderboard[index]['name'] ?? 'YGNTV user'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '${_intValue(leaderboard[index]['successful_invites'])} Premium members',
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _referralPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Withdrawal requests',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (withdrawals.isEmpty)
                      const Text(
                        'No withdrawal requests yet.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      )
                    else
                      for (final row in withdrawals)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.payments_outlined,
                            color: _gold,
                          ),
                          title: Text(
                            '${_ks(_intValue(row['amount_ks']))} · ${_methodLabel('${row['payment_method'] ?? ''}')}',
                          ),
                          subtitle: Text(
                            '${row['payout_address_masked'] ?? ''} · ${_statusLabel('${row['status'] ?? ''}')}',
                          ),
                          trailing: TextButton(
                            onPressed: null,
                            child: Text(_statusLabel('${row['status'] ?? ''}')),
                          ),
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

class _WithdrawalRequestDialog extends StatefulWidget {
  const _WithdrawalRequestDialog({
    required this.balance,
    required this.onSubmit,
  });

  final int balance;
  final Future<void> Function({
    required int amountKs,
    required String paymentMethod,
    required String payoutAddress,
  })
  onSubmit;

  @override
  State<_WithdrawalRequestDialog> createState() =>
      _WithdrawalRequestDialogState();
}

class _WithdrawalRequestDialogState extends State<_WithdrawalRequestDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _addressController;
  String _method = 'wavepay';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim());
    final address = _addressController.text.trim();
    if (amount == null || amount < 1 || amount > widget.balance) {
      _message('Enter an amount from 1 Ks up to your available balance.');
      return;
    }
    if (address.length < 3) {
      _message('Enter a valid payout address.');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        amountKs: amount,
        paymentMethod: _method,
        payoutAddress: address,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(
        _englishError(
          error,
          'Could not submit your withdrawal request. Check your connection and try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: const Text('Request withdrawal'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available balance: ${_ks(widget.balance)}'),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Withdrawal amount (Ks)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Payout method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'wavepay', child: Text('WavePay')),
                DropdownMenuItem(value: 'kpay', child: Text('KPay')),
                DropdownMenuItem(value: 'aya_pay', child: Text('AYA Pay')),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _method = value);
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              keyboardType: TextInputType.phone,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Payout phone number or account address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'YGNTV admins review requests and send payouts manually. The app does not transfer money automatically.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Submit request'),
      ),
    ],
  );
}

Widget _referralPanel({required Widget child}) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: _panel,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: Colors.white.withValues(alpha: .07)),
  ),
  child: child,
);

int _intValue(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

List<Map<String, dynamic>> _rows(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];

String _ks(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} Ks';

String _methodLabel(String value) => switch (value) {
  'wavepay' => 'WavePay',
  'kpay' => 'KPay',
  'aya_pay' => 'AYA Pay',
  _ => value,
};

String _statusLabel(String value) => switch (value) {
  'pending' => 'Pending',
  'paid' => 'Paid',
  'rejected' => 'Rejected',
  _ => value.replaceAll('_', ' '),
};

String _englishError(Object error, String fallback) {
  final message = error is AuthException ? error.message : '$error';
  final clean = message.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  return clean.isEmpty ||
          RegExp(r'[\u1000-\u109F\uAA60-\uAA7F]').hasMatch(clean)
      ? fallback
      : clean;
}
