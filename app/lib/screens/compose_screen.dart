import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillEditor, QuillEditorConfig;

import '../models/account.dart';
import '../services/mail_service.dart';
import '../theme.dart';
import '../widgets/rich_composer.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.service,
    required this.account,
    this.prepared,
  });

  final MailService service;
  final RanseAccount account;

  /// Pre-filled builder from forward; null for a fresh message.
  final MessageBuilder? prepared;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _subjectController = TextEditingController();
  late final RichComposer _composer;
  final List<PlatformFile> _attachments = [];
  bool _showCc = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final prepared = widget.prepared;
    _composer = RichComposer(initialText: prepared?.text);
    if (prepared != null) {
      prepared.text = null;
      _toController.text =
          (prepared.to ?? []).map((a) => a.email).join(', ');
      final cc = (prepared.cc ?? []).map((a) => a.email).join(', ');
      _ccController.text = cc;
      _showCc = cc.isNotEmpty;
      _subjectController.text = prepared.subject ?? '';
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _composer.dispose();
    super.dispose();
  }

  List<MailAddress>? _parseAddresses(String raw) {
    final parts = raw
        .split(RegExp(r'[,;]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return [];
    if (parts.any((p) => !p.contains('@') || p.contains(' '))) return null;
    return parts.map((p) => MailAddress(null, p)).toList();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() =>
        _attachments.addAll(result.files.where((f) => f.path != null)));
  }

  Future<void> _send() async {
    final to = _parseAddresses(_toController.text);
    if (to == null || to.isEmpty) {
      _snack('Enter at least one valid recipient address.');
      return;
    }
    final cc = _parseAddresses(_ccController.text);
    if (cc == null) {
      _snack('One of the Cc addresses is not valid.');
      return;
    }
    if (_composer.isEmpty && _subjectController.text.trim().isEmpty) {
      _snack('Write a subject or a message first.');
      return;
    }

    setState(() => _sending = true);
    try {
      final builder = widget.prepared ?? MessageBuilder();
      builder
        ..from = [
          MailAddress(widget.account.displayName, widget.account.email)
        ]
        ..to = to
        ..cc = cc.isEmpty ? null : cc
        ..subject = _subjectController.text.trim();
      builder.addMultipartAlternative(
        plainText: _composer.plainText,
        htmlText: _composer.html,
      );
      for (final file in _attachments) {
        final path = file.path;
        if (path == null) continue;
        await builder.addFile(
          File(path),
          MediaType.guessFromFileName(file.name),
        );
      }
      await widget.service.send(builder.buildMimeMessage());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Message sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('Sending failed: $e');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed:
                        _sending ? null : () => Navigator.of(context).pop(),
                  ),
                  Text('New message', style: context.disp(size: 18)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Attach file',
                    icon: const Icon(Icons.attach_file, size: 21),
                    onPressed: _sending ? null : _pickAttachment,
                  ),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RanseCard(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(
                      label: 'FROM',
                      child: Text(
                        widget.account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    _field(
                      label: 'TO',
                      child: TextField(
                        controller: _toController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: const InputDecoration(
                            hintText: 'name@example.com, other@…'),
                      ),
                      trailing: _showCc
                          ? null
                          : TextButton(
                              onPressed: () =>
                                  setState(() => _showCc = true),
                              child: const Text('+ Cc'),
                            ),
                    ),
                    if (_showCc)
                      _field(
                        label: 'CC',
                        child: TextField(
                          controller: _ccController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: const TextStyle(fontSize: 13.5),
                          decoration:
                              const InputDecoration(hintText: 'Cc'),
                        ),
                      ),
                    _field(
                      label: 'SUBJECT',
                      child: TextField(
                        controller: _subjectController,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                        decoration:
                            const InputDecoration(hintText: 'Subject'),
                      ),
                    ),
                    if (_attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _attachments.length; i++)
                              InputChip(
                                avatar: const Icon(Icons.attach_file,
                                    size: 16),
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: 140),
                                  child: Text(
                                    _attachments[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(fontSize: 12),
                                  ),
                                ),
                                onDeleted: () => setState(
                                    () => _attachments.removeAt(i)),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: QuillEditor.basic(
                          controller: _composer.controller,
                          config: const QuillEditorConfig(
                            placeholder: 'Write your message…',
                            expands: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Glass(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: FormatBar(
                  composer: _composer,
                  trailing: [
                    IconButton(
                      tooltip: 'Attach file',
                      icon: Icon(Icons.attach_file,
                          size: 20, color: scheme.onSurfaceVariant),
                      onPressed: _sending ? null : _pickAttachment,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: scheme.outlineVariant, width: .8)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: child),
          ?trailing,
        ],
      ),
    );
  }
}
