import 'package:enough_mail/enough_mail.dart';

/// Sender resolution that works for envelope-only fetches.
///
/// enough_mail's decodeSender() reads only the reply-to/sender/from HEADERS,
/// but folder listings fetch the IMAP ENVELOPE - whose parser copies subject
/// and date into headers and leaves the from-address solely on the envelope.
/// Result: "(unknown sender)" on every list row unless we look at the
/// envelope ourselves.
extension SenderResolve on MimeMessage {
  List<MailAddress> resolvedSenders() {
    final env = envelope;
    if (env != null) {
      final envFrom = env.from;
      if (envFrom != null && envFrom.isNotEmpty) return envFrom;
      final envSender = env.sender;
      if (envSender != null) return [envSender];
    }
    final decoded = decodeSender();
    if (decoded.isNotEmpty) return decoded;
    final headerFrom = from;
    if (headerFrom != null && headerFrom.isNotEmpty) return headerFrom;
    return const [];
  }

  /// Display name of the first sender, falling back to their address.
  String senderLabel() {
    final senders = resolvedSenders();
    if (senders.isEmpty) return '(unknown sender)';
    final first = senders.first;
    final name = first.personalName;
    return (name != null && name.trim().isNotEmpty) ? name : first.email;
  }

  /// Domain of the first sender, or null.
  String? senderDomain() {
    final senders = resolvedSenders();
    if (senders.isEmpty) return null;
    final email = senders.first.email;
    final at = email.lastIndexOf('@');
    return at > 0 ? email.substring(at + 1) : null;
  }
}
