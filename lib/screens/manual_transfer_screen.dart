import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';
import '../widgets/ygntv_brand.dart';

class ManualTransferScreen extends StatefulWidget {
  const ManualTransferScreen({
    required this.service,
    required this.plan,
    super.key,
  });

  final AuthService service;
  final TvPremiumPlan plan;

  @override
  State<ManualTransferScreen> createState() => _ManualTransferScreenState();
}

class _ManualTransferScreenState extends State<ManualTransferScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _referenceController = TextEditingController();
  late Future<List<PaymentAccount>> _accounts;

  PaymentAccount? _account;
  TvPaymentOrder? _order;
  Uint8List? _receiptBytes;
  String? _receiptName;
  String? _receiptMimeType;
  bool _busy = false;
  bool _scanning = false;
  bool _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accounts = widget.service.getPaymentAccounts();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _reloadAccounts() async {
    final request = widget.service.getPaymentAccounts();
    setState(() {
      _accounts = request;
      _error = null;
    });
    try {
      await request;
    } catch (_) {
      // The FutureBuilder displays the live API error and retry control.
    }
  }

  Future<void> _chooseAccount(PaymentAccount account) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await widget.service.createPaymentOrder(
        paymentAccountId: account.id,
        planKey: widget.plan.key,
      );
      if (order.status != 'awaiting_receipt') {
        throw const AuthException(
          'YGNTV did not return an order that can accept a receipt.',
        );
      }
      if (!mounted) return;
      setState(() {
        _account = account;
        _order = order;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickReceipt() async {
    if (_busy || _scanning) return;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          setState(() => _error = 'Receipt images must be 5 MB or smaller.');
        }
        return;
      }

      final mimeType = _mimeTypeFor(file);
      if (mimeType == null) {
        if (mounted) {
          setState(() => _error = 'Upload a JPG, PNG, or WebP receipt image.');
        }
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _receiptBytes = bytes;
        _receiptName = file.name.isEmpty ? 'transfer-receipt' : file.name;
        _receiptMimeType = mimeType;
        _referenceController.text = receiptCandidate(file.name);
        _error = null;
        _scanning = true;
      });
      await _scanReceipt(file);
    } catch (error) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = 'Could not read that receipt image. Please choose another.';
        });
      }
    }
  }

  Future<void> _scanReceipt(XFile file) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(file.path);
      final result = await recognizer.processImage(image);
      final suggestion = receiptCandidate(result.text);
      if (mounted && suggestion.isNotEmpty) {
        _referenceController.text = suggestion;
      }
    } catch (_) {
      // The filename suggestion remains editable if local OCR is unavailable.
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _submitReceipt() async {
    final order = _order;
    final bytes = _receiptBytes;
    final mimeType = _receiptMimeType;
    if (_busy ||
        _scanning ||
        order == null ||
        bytes == null ||
        mimeType == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final submitted = await widget.service.submitOrderReceipt(
        orderId: order.id,
        receiptBytes: bytes,
        fileName: _receiptName ?? 'transfer-receipt',
        mimeType: mimeType,
        receiptReference: _referenceController.text,
      );
      if (submitted.status != 'submitted') {
        throw const AuthException(
          'YGNTV did not confirm that the receipt was submitted for review.',
        );
      }
      if (!mounted) return;
      setState(() {
        _order = submitted;
        _confirmed = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _mimeTypeFor(XFile file) {
    final provided = file.mimeType?.toLowerCase();
    if (provided == 'image/jpeg' ||
        provided == 'image/png' ||
        provided == 'image/webp') {
      return provided;
    }
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    appBar: AppBar(
      title: const Text('Premium Subscription'),
      backgroundColor: ygntvBackground,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(17, 10, 17, 28),
        children: [
          const YgntvBrandLockup(compact: true),
          const SizedBox(height: 17),
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
          Text(
            _confirmed ? 'Receipt submitted' : 'Complete your transfer',
            style: const TextStyle(
              fontSize: 24,
              height: 1.12,
              letterSpacing: -.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _progress(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorCard(_error!),
          ],
          const SizedBox(height: 17),
          if (_confirmed)
            _confirmation()
          else if (_order != null && _account != null)
            _receiptStep(_account!, _order!)
          else
            _paymentMethodStep(),
        ],
      ),
    ),
  );

  Widget _progress() {
    final receiptActive = _order != null || _confirmed;
    return Row(
      children: [
        _progressItem('1', 'Plan', done: true),
        _progressLine(done: true),
        _progressItem(
          '2',
          'Payment',
          done: _order != null || _confirmed,
          active: !receiptActive,
        ),
        _progressLine(done: _confirmed),
        _progressItem('3', 'Receipt', done: _confirmed, active: receiptActive),
      ],
    );
  }

  Widget _progressItem(
    String number,
    String label, {
    bool active = false,
    bool done = false,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 11,
        backgroundColor: active || done
            ? ygntvRed.withValues(alpha: .22)
            : ygntvPanel,
        child: Icon(
          done ? Icons.check_rounded : Icons.circle,
          color: active || done ? ygntvGold : ygntvMuted,
          size: done ? 13 : 6,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: active || done ? Colors.white : ygntvMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _progressLine({required bool done}) => Expanded(
    child: Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: done ? ygntvRed : Colors.white12,
    ),
  );

  Widget _paymentMethodStep() => FutureBuilder<List<PaymentAccount>>(
    future: _accounts,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator(color: ygntvRed)),
        );
      }
      if (snapshot.hasError) {
        return _stateCard(
          icon: Icons.wifi_off_rounded,
          title: 'Payment methods could not be loaded',
          copy: snapshot.error.toString(),
          action: TextButton.icon(
            onPressed: _reloadAccounts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        );
      }
      final accounts = snapshot.data ?? const <PaymentAccount>[];
      if (accounts.isEmpty) {
        return _stateCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment methods coming soon',
          copy: 'Active payment accounts added by YGNTV will appear here automatically.',
          action: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to plans'),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stageHeading(
            eyebrow: 'Step 2 of 3',
            title: 'Choose a payment method',
            subtitle:
                '${widget.plan.label} · ${_formatKs(widget.plan.amountKs)} Ks',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 13),
          for (final account in accounts) ...[
            _methodCard(account),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Choose another plan'),
          ),
        ],
      );
    },
  );

  Widget _methodCard(PaymentAccount account) => Material(
    color: ygntvPanel,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: _busy ? null : () => _chooseAccount(account),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ygntvRed.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: ygntvGold,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (account.accountName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      account.accountName,
                      style: const TextStyle(color: ygntvMuted, fontSize: 11),
                    ),
                  ],
                  if (account.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      account.description,
                      style: const TextStyle(color: ygntvMuted, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ygntvRed,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: ygntvMuted),
          ],
        ),
      ),
    ),
  );

  Widget _receiptStep(PaymentAccount account, TvPaymentOrder order) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stageHeading(
        eyebrow: 'Step 3 of 3 · Transfer details',
        title: 'Send the exact amount',
        subtitle: 'Use the selected account, then upload your transfer slip.',
        icon: Icons.verified_user_outlined,
      ),
      const SizedBox(height: 12),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: ygntvGold,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _infoRow('Transfer amount', '${_formatKs(order.amountKs)} Ks'),
            if (order.reference.isNotEmpty)
              _detailRow('Order reference', order.reference),
            _detailRow(
              'Account name',
              account.accountName.isEmpty
                  ? 'Not supplied'
                  : account.accountName,
            ),
            _detailRow(
              'Phone / account number',
              account.accountNumber.isEmpty
                  ? 'Not supplied'
                  : account.accountNumber,
            ),
            if (account.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .035),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  account.description,
                  style: const TextStyle(
                    color: Color(0xFFD0CDD3),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (_validQrUrl(account.qrImageUrl) != null) ...[
              const SizedBox(height: 13),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.white,
                    constraints: const BoxConstraints(
                      maxWidth: 260,
                      maxHeight: 260,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.network(
                      _validQrUrl(account.qrImageUrl)!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 210,
                        height: 110,
                        child: Center(
                          child: Text(
                            'QR image could not be loaded',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: ygntvGold, size: 16),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Premium activates only after an admin verifies this receipt.',
                    style: TextStyle(
                      color: ygntvMuted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 13),
      _stageHeading(
        eyebrow: 'Proof of transfer',
        title: 'Upload your slip',
        subtitle: 'JPG, PNG or WebP · maximum 5 MB',
        icon: Icons.image_outlined,
      ),
      const SizedBox(height: 10),
      _receiptPicker(),
      const SizedBox(height: 11),
      _referenceField(),
      const SizedBox(height: 13),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _receiptBytes == null || _busy || _scanning
              ? null
              : _submitReceipt,
          icon: _busy
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(_busy ? 'Submitting…' : 'Done — submit for review'),
        ),
      ),
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _order = null;
                  _account = null;
                  _receiptBytes = null;
                  _receiptName = null;
                  _receiptMimeType = null;
                  _referenceController.clear();
                  _error = null;
                }),
          icon: const Icon(Icons.arrow_back_rounded, size: 15),
          label: const Text('Choose another payment method'),
        ),
      ),
    ],
  );

  Widget _receiptPicker() => Material(
    color: ygntvPanel,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: _busy || _scanning ? null : _pickReceipt,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 130),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _receiptBytes == null
                ? Colors.white24
                : ygntvGold.withValues(alpha: .5),
          ),
        ),
        child: _receiptBytes == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, color: ygntvGold, size: 29),
                  SizedBox(height: 7),
                  Text(
                    'Select receipt image',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap to browse your device',
                    style: TextStyle(color: ygntvMuted, fontSize: 10),
                  ),
                ],
              )
            : Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _receiptBytes!,
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: ygntvMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: ygntvGold,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _scanning
                              ? 'Scanning receipt…'
                              : 'Replace receipt · ${_receiptName ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ygntvGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _referenceField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Icon(Icons.document_scanner_outlined, size: 15, color: ygntvGold),
          SizedBox(width: 6),
          Text(
            'TxID / Receipt reference',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 7),
      TextField(
        controller: _referenceController,
        autocorrect: false,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: _scanning ? 'Scanning receipt…' : 'Suggested after upload',
          filled: true,
          fillColor: ygntvPanel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 13,
          ),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        _scanning ? 'Reading the receipt image locally…' : 'Check the suggested value against your slip. You can edit it before submission.',
        style: const TextStyle(color: ygntvMuted, fontSize: 9, height: 1.4),
      ),
    ],
  );

  Widget _confirmation() => _panel(
    child: Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: const Color(0x2236A86B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF8FD3A1),
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Thanks — your request is under review.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'The Yangon TV admin team will verify your payment. Premium activates automatically after approval.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ygntvMuted, fontSize: 11, height: 1.5),
        ),
        if (_order?.reference.isNotEmpty == true) ...[
          const SizedBox(height: 15),
          _detailRow('Order reference', _order!.reference),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Return to account'),
          ),
        ),
      ],
    ),
  );

  Widget _stageHeading({
    required String eyebrow,
    required String title,
    required String subtitle,
    required IconData icon,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: const TextStyle(
                color: ygntvGold,
                fontSize: 8,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: ygntvMuted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 9),
      Icon(icon, color: ygntvGold, size: 21),
    ],
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: ygntvMuted, fontSize: 10),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: ygntvMuted, fontSize: 9)),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: child,
  );

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String copy,
    Widget? action,
  }) => _panel(
    child: Column(
      children: [
        const SizedBox(height: 12),
        Icon(icon, color: ygntvGold, size: 31),
        const SizedBox(height: 11),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          copy,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ygntvMuted, fontSize: 10, height: 1.45),
        ),
        if (action != null) ...[const SizedBox(height: 9), action],
        const SizedBox(height: 7),
      ],
    ),
  );

  Widget _errorCard(String text) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0x22E5454F),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ygntvRed.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFFFA6AC),
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFFFC2C5),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

String? _validQrUrl(String value) {
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  return uri?.scheme == 'https' ? uri.toString() : null;
}

String receiptCandidate(String text) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  final match = RegExp(
    r'(?:TX\s*(?:ID|NO)?|TRANSACTION\s*(?:ID|NO)?|REFERENCE\s*(?:ID|NO)?|REF\s*(?:ID|NO)?)[\s:#-]*([A-Z0-9-]{6,32})',
    caseSensitive: false,
  ).firstMatch(value);
  if (match?.group(1) != null) return match!.group(1)!;
  for (final candidate in RegExp(
    r'\b[A-Z0-9-]{9,24}\b',
  ).allMatches(value).map((match) => match.group(0)!)) {
    if (RegExp(r'[A-Z]').hasMatch(candidate) &&
        !RegExp(r'^\d{8,}$').hasMatch(candidate)) {
      return candidate;
    }
  }
  return '';
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
