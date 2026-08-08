import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillEditor, QuillEditorConfig;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../services/mail_service.dart';
import '../services/quoting.dart';
import '../services/sender_resolve.dart';
import '../theme.dart';
import '../widgets/rich_composer.dart';
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
  RichComposer? _reply;
  bool _replyAll = false;
  bool _sending = false;
  bool _includeQuote = true;
  bool _quoteExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply?.dispose();
    super.dispose();
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

  void _startReply({required bool all}) {
    setState(() {
      _replyAll = all;
      if (_reply == null) {
        _reply = RichComposer();
        _includeQuote = true;
        _quoteExpanded = false;
      }
    });
  }

  Future<void> _sendReply() async {
    final full = _full;
    final reply = _reply;
    if (full == null || reply == null || reply.isEmpty) return;
    setState(() => _sending = true);
    try {
      final builder = MessageBuilder.prepareReplyToMessage(
        full,
        MailAddress(widget.account.displayName, widget.account.email),
        replyAll: _replyAll,
      )..text = null;
      var plain = reply.plainText;
      var html = reply.html;
      if (_includeQuote) {
        plain = '$plain\n\n${Quoting.replyQuotePlain(full)}';
        html = '$html<br>${Quoting.replyQuoteHtml(full)}';
      }
      builder.addMultipartAlternative(plainText: plain, htmlText: html);
      await widget.service.send(builder.buildMimeMessage());
      if (!mounted) return;
      setState(() {
        _reply?.dispose();
        _reply = null;
        _sending = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reply sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sending failed: $e')));
    }
  }

  void _forward() {
    final full = _full;
    if (full == null) return;
    // quoteMessage: false - we place the forwarded block in the editor
    // ourselves so it is always visible and editable, whatever the original
    // format was. Attachments still ride along on the builder.
    final builder = MessageBuilder.prepareForwardMessage(
      full,
      from: MailAddress(widget.account.displayName, widget.account.email),
      quoteMessage: false,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComposeScreen(
        service: widget.service,
        account: widget.account,
        prepared: builder,
        initialBody: '\n\n${Quoting.forwardPlain(full)}',
      ),
    ));
  }

  Future<void> _tool(Future<void> Function(List<MimeMessage>) action,
      String done) async {
    try {
      await action([widget.message]);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('That failed: $e')));
    }
  }

  Future<void> _openAttachment(ContentInfo info) async {
    final full = _full;
    if (full == null) return;
    final data = full.getPart(info.fetchId)?.decodeContentBinary();
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolbar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Text(
                message.decodeSubject() ?? '(no subject)',
                style: context.disp(size: 19),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child:
                            Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        RanseCard(
                          padding: const EdgeInsets.all(16),
                          child: _full == null
                              ? const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              : _messageBody(_full!),
                        ),
                        if (_reply != null) _replyPane(),
                        if (_reply == null) _actionBar(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Archive',
            icon: const Icon(Icons.archive_outlined, size: 22),
            onPressed: () =>
                _tool(widget.service.moveToArchive, 'Archived'),
          ),
          IconButton(
            tooltip: 'Junk',
            icon: const Icon(Icons.block_outlined, size: 22),
            onPressed: () =>
                _tool(widget.service.moveToJunk, 'Marked as junk'),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 22),
            onPressed: () =>
                _tool(widget.service.moveToTrash, 'Moved to Trash'),
          ),
        ],
      ),
    );
  }

  Widget _messageBody(MimeMessage full) {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    final from = full.resolvedSenders();
    final sender = from.isNotEmpty ? from.first : null;
    final date = full.decodeDate()?.toLocal();
    final attachments = full.findContentInfo();
    final html = full.decodeTextHtmlPart();
    final plain = full.decodeTextPlainPart();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: scheme.outlineVariant, width: .8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: sender?.personalName?.trim().isNotEmpty ?? false
                        ? sender!.personalName
                        : sender?.email ?? '(unknown)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (sender != null)
                    TextSpan(
                      text: '  <${sender.email}>',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                ]),
                style: const TextStyle(fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                [
                  'to ${widget.account.email}',
                  if (date != null)
                    DateFormat.MMMEd().add_Hm().format(date),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: html != null && html.trim().isNotEmpty
              ? HtmlWidget(
                  html,
                  textStyle: TextStyle(
                      fontSize: 13.6, height: 1.62, color: ranse.bodyText),
                )
              : SelectableText(
                  plain ?? '(empty message)',
                  style: TextStyle(
                      fontSize: 13.6, height: 1.62, color: ranse.bodyText),
                ),
        ),
        if (attachments.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final info in attachments)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openAttachment(info),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: ranse.tagBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            info.fileName ?? 'attachment',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        if (info.size != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _sizeLabel(info.size!),
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }

  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed:
                  _full == null ? null : () => _startReply(all: false),
              icon: const Icon(Icons.reply_outlined, size: 18),
              label: const Text('Reply'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _full == null ? null : () => _startReply(all: true),
              child: const Text('All'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _full == null ? null : _forward,
              child: const Text('Forward'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyPane() {
    final scheme = Theme.of(context).colorScheme;
    final reply = _reply!;
    final to = _replyAll ? 'everyone on this thread' : _replyToLabel();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Glass(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'YOUR REPLY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: scheme.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    _reply?.dispose();
                    _reply = null;
                  }),
                  child: Icon(Icons.close,
                      size: 17, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'To $to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            ConstrainedBox(
              constraints:
                  const BoxConstraints(minHeight: 70, maxHeight: 190),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: QuillEditor.basic(
                  controller: reply.controller,
                  config: const QuillEditorConfig(
                    autoFocus: true,
                    placeholder: 'Write your reply…',
                  ),
                ),
              ),
            ),
            if (_includeQuote) _quotePill(),
            FormatBar(
              composer: reply,
              trailing: [
                _sending
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _sendReply,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Send'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Gmail's "..." - the quoted history rides along collapsed; tap to peek,
  /// x to drop it from this reply.
  Widget _quotePill() {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    final full = _full;
    if (full == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () =>
                    setState(() => _quoteExpanded = !_quoteExpanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: ranse.tagBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Quoted text',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      Icon(
                        _quoteExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 15,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => setState(() => _includeQuote = false),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      size: 15, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (_quoteExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.outlineVariant, width: 2),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 130),
              child: SingleChildScrollView(
                child: Text(
                  '${Quoting.replyHeader(full)}\n${Quoting.plainBody(full)}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _replyToLabel() {
    final from = _full?.resolvedSenders();
    if (from == null || from.isEmpty) return 'the sender';
    return from.first.email;
  }
}
