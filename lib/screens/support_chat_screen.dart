import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../auth/support_models.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/ygntv_brand.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({required this.service, super.key});

  final AuthService service;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  SupportMessagesPage? _conversation;
  List<SupportChatMessage> _messages = const [];
  Timer? _pollTimer;
  String? _token;
  String? _error;
  String _status = 'open';
  int _lastMessageId = 0;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadLatestConversation();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestConversation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversations = await widget.service.getSupportConversations();
      if (!mounted) return;
      if (conversations.isEmpty) {
        setState(() {
          _token = null;
          _conversation = null;
          _messages = const [];
          _status = 'open';
          _lastMessageId = 0;
          _loading = false;
        });
        return;
      }
      final latest = conversations.first;
      final page = await widget.service.getSupportMessages(latest.publicToken);
      if (!mounted) return;
      _applyPage(page, fallbackToken: latest.publicToken);
      setState(() => _loading = false);
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applyPage(SupportMessagesPage page, {String? fallbackToken}) {
    _conversation = page;
    _token = page.publicToken.isNotEmpty ? page.publicToken : fallbackToken;
    _status = page.status;
    _messages = page.messages;
    _lastMessageId = page.nextAfterId;
    if (_lastMessageId == 0 && _messages.isNotEmpty) {
      _lastMessageId = _messages.last.id;
    }
  }

  Future<void> _poll() async {
    final token = _token;
    if (token == null || token.isEmpty || _loading || _sending) return;
    try {
      final page = await widget.service.getSupportMessages(
        token,
        afterId: _lastMessageId,
      );
      if (!mounted) return;
      final existingIds = _messages.map((message) => message.id).toSet();
      final additions = page.messages
          .where((message) => !existingIds.contains(message.id))
          .toList(growable: false);
      if (additions.isEmpty && page.status == _status) return;
      setState(() {
        _status = page.status;
        _messages = [..._messages, ...additions];
        if (page.nextAfterId > _lastMessageId) {
          _lastMessageId = page.nextAfterId;
        } else if (additions.isNotEmpty && additions.last.id > _lastMessageId) {
          _lastMessageId = additions.last.id;
        }
      });
      if (additions.isNotEmpty) _scrollToLatest();
    } catch (_) {
      // The next scheduled poll retries; transient network issues stay quiet.
    }
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      var token = _token;
      if (token == null || token.isEmpty) {
        final started = await widget.service.startSupportConversation();
        token = started.publicToken;
        if (token.isEmpty) {
          throw const AuthException(
            'The support service did not return a conversation token.',
          );
        }
        if (!mounted) return;
        setState(() {
          _applyPage(started);
          _token = token;
        });
      }
      final message = await widget.service.sendSupportMessage(token, body);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages = [..._messages, message];
        }
        if (message.id > _lastMessageId) _lastMessageId = message.id;
        _conversation = SupportMessagesPage(
          publicToken: token!,
          status: _status,
          messages: _messages,
          nextAfterId: _lastMessageId,
        );
        _composer.clear();
      });
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _newConversation() {
    if (_sending) return;
    setState(() {
      _token = null;
      _conversation = null;
      _messages = const [];
      _status = 'open';
      _lastMessageId = 0;
      _error = null;
      _composer.clear();
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openAttachment(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !{'api.ygntv.org', 'ygntv.org'}.contains(uri.host)) {
      _showMessage('This attachment link is not available.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showMessage('Could not open this attachment.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    appBar: AppBar(
      title: const Text('Help & Support'),
      actions: [
        AppPageLinkButton(uri: AppDeepLink.linkFor('support')),
        IconButton(
          tooltip: 'New conversation',
          onPressed: _sending ? null : _newConversation,
          icon: const Icon(Icons.add_comment_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(
              children: [
                const YgntvBrandLockup(compact: true),
                const Spacer(),
                Icon(Icons.circle, color: _statusColor, size: 8),
                const SizedBox(width: 6),
                Text(
                  _statusLabel,
                  style: const TextStyle(color: ygntvMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Expanded(child: _messageArea()),
          if (_error != null) _errorBanner(),
          _composerBar(),
        ],
      ),
    ),
  );

  Color get _statusColor =>
      _status == 'closed' ? ygntvMuted : const Color(0xFF81D398);

  String get _statusLabel => _status == 'closed' ? 'Closed' : 'Support chat';

  Widget _messageArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: ygntvRed));
    }
    if (_error != null && _conversation == null && _token == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: ygntvGold, size: 30),
              const SizedBox(height: 10),
              const Text(
                'Support chat could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ygntvMuted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadLatestConversation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: ygntvRed.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: ygntvGold,
                  size: 30,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'How can we help with your subscription?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Send a message to contact the YGNTV support team.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ygntvMuted, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _messageBubble(_messages[index]),
    );
  }

  Widget _messageBubble(SupportChatMessage message) {
    final ownMessage = message.senderType == 'visitor';
    final sender = switch (message.senderType) {
      'admin' => 'Support team',
      'system' => 'System',
      _ => 'You',
    };
    return Align(
      alignment: ownMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: BoxDecoration(
          color: ownMessage ? const Color(0xFF48252B) : ygntvPanel,
          border: Border.all(
            color: ownMessage
                ? ygntvRed.withValues(alpha: .36)
                : Colors.white.withValues(alpha: .06),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(ownMessage ? 17 : 5),
            bottomRight: Radius.circular(ownMessage ? 5 : 17),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!ownMessage) ...[
              Text(
                sender,
                style: const TextStyle(
                  color: ygntvGold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            if (message.attachmentUrl != null) ...[
              if (message.body.isNotEmpty) const SizedBox(height: 5),
              TextButton.icon(
                onPressed: () => _openAttachment(message.attachmentUrl),
                icon: const Icon(Icons.attach_file_rounded, size: 15),
                label: Text(message.attachmentName ?? 'View attachment'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatTime(message.createdAt),
                style: const TextStyle(color: ygntvMuted, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF3A1E22),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _error!,
      style: const TextStyle(color: Color(0xFFFFC4C7), fontSize: 10),
    ),
  );

  Widget _composerBar() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
    decoration: const BoxDecoration(
      color: Color(0xFF111116),
      border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _composer,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Write a message…',
              filled: true,
              fillColor: const Color(0xFF1A1920),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send message',
          onPressed: _sending || _composer.text.trim().isEmpty ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
        ),
      ],
    ),
  );
}

String _formatTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
