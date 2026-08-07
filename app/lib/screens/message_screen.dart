import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../services/mail_service.dart';
import 'compose_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({
    super.key,
    required this.service,
    required this.account,
    required this.message,
  });

  final MailService service;
  final RanseAccount account;
  final MimeMessage message;

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  MimeMessage? _full;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final full = await widget.service.fetchContents(widget.message);
      if (!mounted) return;
      setState(() => _full = full);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this message.\n$e');
    }
  }

  void _reply({required bool all}) {
    final full = _full;
    if (full == null) return;
    final builder = MessageBuilder.prepareReplyToMessage(
      full,
      MailAddress(widget.account.displayName, widget.account.email),
      replyAll: all,
      quoteOriginalText: true,
    );
    _openCompose(builder);
  }

  void _forward() {
    final full = _full;
    if (full == null) return;
    final builder = MessageBuilder.prepareForwardMessage(
      full,
      from: MailAddress(widget.account.displayName, widget.account.email),
    );
    _openCompose(builder);
  }

  void _openCompose(MessageBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComposeScreen(
        service: widget.service,
        account: widget.account,
        prepared: builder,
      ),
    ));
  }

  Future<void> _openAttachment(ContentInfo info) async {
    final full = _full;
    if (full == null) return;
    final part = full.getPart(info.fetchId);
    final data = part?.decodeContentBinary();
    if (data == null) {
      _snack('Could not decode this attachment.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final name = info.fileName ?? 'attachment.bin';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(data, flush: true);
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      _snack('No app on this phone can open "$name".');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final message = _full ?? widget.message;
    final subject = message.decodeSubject() ?? '(no subject)';

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Reply',
            icon: const Icon(Icons.reply_outlined),
            onPressed: _full == null ? null : () => _reply(all: false),
          ),
          IconButton(
            tooltip: 'Reply all',
            icon: const Icon(Icons.reply_all_outlined),
            onPressed: _full == null ? null : () => _reply(all: true),
          ),
          IconButton(
            tooltip: 'Forward',
            icon: const Icon(Icons.forward_outlined),
            onPressed: _full == null ? null : _forward,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(subject,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                _HeaderBlock(message: message),
                const Divider(height: 32),
                if (_full == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  _Body(message: _full!),
                  const SizedBox(height: 16),
                  _Attachments(
                    message: _full!,
                    onOpen: _openAttachment,
                  ),
                ],
              ],
            ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.message});

  final MimeMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final from = message.decodeSender();
    final sender = from.isNotEmpty ? from.first : null;
    final to = message.to ?? [];
    final date = message.decodeDate()?.toLocal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Text(
                (sender?.personalName ?? sender?.email ?? '?')
                    .substring(0, 1)
                    .toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sender?.personalName?.isNotEmpty ?? false
                        ? sender!.personalName!
                        : sender?.email ?? '(unknown)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (sender != null)
                    Text(
                      sender.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (date != null)
              Text(
                DateFormat.yMMMd().add_Hm().format(date),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (to.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'To: ${to.map((a) => a.email).join(', ')}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.message});

  final MimeMessage message;

  @override
  Widget build(BuildContext context) {
    final html = message.decodeTextHtmlPart();
    if (html != null && html.trim().isNotEmpty) {
      return HtmlWidget(
        html,
        textStyle: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final plain = message.decodeTextPlainPart();
    return SelectableText(plain ?? '(empty message)');
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments({required this.message, required this.onOpen});

  final MimeMessage message;
  final void Function(ContentInfo info) onOpen;

  @override
  Widget build(BuildContext context) {
    final infos = message.findContentInfo();
    if (infos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final info in infos)
              ActionChip(
                avatar: const Icon(Icons.attach_file, size: 18),
                label: Text(info.fileName ?? 'attachment'),
                onPressed: () => onOpen(info),
              ),
          ],
        ),
      ],
    );
  }
}
