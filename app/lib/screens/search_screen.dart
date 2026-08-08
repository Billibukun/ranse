import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/mail_service.dart';
import '../services/sender_resolve.dart';
import '../theme.dart';
import '../widgets/message_row.dart';
import 'message_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.service,
    required this.account,
  });

  final MailService service;
  final RanseAccount account;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _Filter { all, unread }

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<MimeMessage>? _results;
  bool _searching = false;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Search failed.\n$e';
      });
    }
  }

  List<MimeMessage> get _filtered {
    final results = _results ?? [];
    return switch (_filter) {
      _Filter.all => results,
      _Filter.unread => results.where((m) => !m.isSeen).toList(),
    };
  }

  /// Top senders across the results - the "People" strip.
  List<(String, int)> get _people {
    final counts = <String, int>{};
    for (final m in _results ?? <MimeMessage>[]) {
      final label = m.senderLabel();
      if (label == '(unknown sender)') continue;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _run(),
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                  hintText: 'Search this mailbox'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _chip('All', _Filter.all),
                  const SizedBox(width: 8),
                  _chip('Unread', _Filter.unread),
                ],
              ),
            ),
            Expanded(child: _body(scheme, ranse)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final scheme = Theme.of(context).colorScheme;
    final on = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? scheme.primary : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: on ? scheme.primary : scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme, RanseColors ranse) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return Center(
        child: Text(
          'Search senders, subjects, and text.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }
    final filtered = _filtered;
    final people = _people;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (people.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              'PEOPLE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: ranse.brass,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (name, count) in people)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Text(' · $count',
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Text(
            'MESSAGES · ${filtered.length}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: ranse.brass,
            ),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: Text(
                'Nothing matched.',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else
          RanseCard(
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  MessageRow(
                    message: filtered[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MessageScreen(
                          service: widget.service,
                          account: widget.account,
                          message: filtered[i],
                        ),
                      ),
                    ),
                  ),
                  if (i != filtered.length - 1)
                    Divider(
                        height: 1,
                        thickness: .8,
                        color: scheme.outlineVariant),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
