import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/mail_service.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.service,
    required this.account,
    this.prepared,
  });

  final MailService service;
  final RanseAccount account;

  /// Pre-filled builder from reply/forward; null for a fresh message.
  final MessageBuilder? prepared;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<PlatformFile> _attachments = [];
  bool _showCc = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final prepared = widget.prepared;
    if (prepared != null) {
      _toController.text =
          (prepared.to ?? []).map((a) => a.email).join(', ');
      final cc = (prepared.cc ?? []).map((a) => a.email).join(', ');
      _ccController.text = cc;
      _showCc = cc.isNotEmpty;
      _subjectController.text = prepared.subject ?? '';
      _bodyController.text = prepared.text ?? '';
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
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
    setState(() => _attachments.addAll(result.files.where((f) => f.path != null)));
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

    setState(() => _sending = true);
    try {
      final builder = widget.prepared ?? MessageBuilder();
      builder
        ..from = [MailAddress(widget.account.displayName, widget.account.email)]
        ..to = to
        ..cc = cc.isEmpty ? null : cc
        ..subject = _subjectController.text.trim()
        ..text = _bodyController.text;
      for (final file in _attachments) {
        final path = file.path;
        if (path == null) continue;
        await builder.addFile(
          File(path),
          MediaType.guessFromFileName(file.name),
        );
      }
      final message = builder.buildMimeMessage();
      await widget.service.send(message);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose'),
        actions: [
          IconButton(
            tooltip: 'Attach file',
            icon: const Icon(Icons.attach_file),
            onPressed: _sending ? null : _pickAttachment,
          ),
          IconButton(
            tooltip: 'Send',
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _toController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'To',
              hintText: 'name@example.com, other@example.com',
              suffixIcon: _showCc
                  ? null
                  : TextButton(
                      onPressed: () => setState(() => _showCc = true),
                      child: const Text('Cc'),
                    ),
            ),
          ),
          if (_showCc) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _ccController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Cc'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          if (_attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _attachments.length; i++)
                    InputChip(
                      avatar: const Icon(Icons.attach_file, size: 18),
                      label: Text(
                        _attachments[i].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () =>
                          setState(() => _attachments.removeAt(i)),
                    ),
                ],
              ),
            ),
          TextField(
            controller: _bodyController,
            maxLines: null,
            minLines: 12,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
