import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageTile extends StatelessWidget {
  const MessageTile({super.key, required this.message, required this.onTap});

  final MimeMessage message;
  final VoidCallback onTap;

  String _senderLabel() {
    final from = message.decodeSender();
    if (from.isEmpty) return '(unknown sender)';
    final first = from.first;
    final name = first.personalName;
    return (name != null && name.trim().isNotEmpty) ? name : first.email;
  }

  String _dateLabel() {
    final date = message.decodeDate();
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat.Hm().format(local);
    }
    if (local.year == now.year) {
      return DateFormat.MMMd().format(local);
    }
    return DateFormat.yMMMd().format(local);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !message.isSeen;
    final sender = _senderLabel();
    final subject = message.decodeSubject() ?? '(no subject)';
    final weight = unread ? FontWeight.w700 : FontWeight.w400;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(sender.isNotEmpty ? sender[0].toUpperCase() : '?'),
      ),
      title: Text(
        sender,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: weight),
      ),
      subtitle: Text(
        subject,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _dateLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: weight,
              color: unread ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          if (unread)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
