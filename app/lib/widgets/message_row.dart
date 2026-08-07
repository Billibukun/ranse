import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Dense message row: sender + time / subject / quiet flags.
/// No avatars by design. Everything single-line and ellipsized so text can
/// never look jumbled.
class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.folderHint,
  });

  final MimeMessage message;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;
  final String? folderHint;

  String _sender() {
    final from = message.decodeSender();
    if (from.isEmpty) return '(unknown sender)';
    final first = from.first;
    final name = first.personalName;
    return (name != null && name.trim().isNotEmpty) ? name : first.email;
  }

  String? _senderDomain() {
    final from = message.decodeSender();
    if (from.isEmpty) return null;
    final email = from.first.email;
    final at = email.lastIndexOf('@');
    return at > 0 ? email.substring(at + 1) : null;
  }

  String _time() {
    final date = message.decodeDate();
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat.Hm().format(local);
    }
    if (now.difference(local).inDays < 6 && local.year == now.year) {
      return DateFormat.E().format(local);
    }
    if (local.year == now.year) return DateFormat.MMMd().format(local);
    return DateFormat.yMMMd().format(local);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    final unread = !message.isSeen;
    final domain = _senderDomain();

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? ranse.tagBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selectionMode) ...[
              _CheckDot(selected: selected),
              const SizedBox(width: 12),
            ] else if (unread) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
            ] else
              const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          _sender(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.8,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _time(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: unread
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    message.decodeSubject() ?? '(no subject)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.8,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread ? scheme.onSurface : ranse.bodyText,
                    ),
                  ),
                  if (domain != null || folderHint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          if (folderHint != null) ...[
                            _Tag(text: folderHint!, bg: ranse.tagBrassBg,
                                fg: ranse.brass),
                            const SizedBox(width: 6),
                          ],
                          if (domain != null)
                            Expanded(
                              child: Text(
                                domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
          color: fg,
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  const _CheckDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 13, color: scheme.onPrimary)
          : null,
    );
  }
}
