import 'package:enough_mail/enough_mail.dart';
import 'package:intl/intl.dart';

/// Gmail-style quoting for replies and forwards.
class Quoting {
  Quoting._();

  static String _senderLabel(MimeMessage message) {
    final from = message.decodeSender();
    if (from.isEmpty) return 'the sender';
    final first = from.first;
    final name = first.personalName;
    return (name != null && name.trim().isNotEmpty)
        ? '$name <${first.email}>'
        : first.email;
  }

  static String _dateLabel(MimeMessage message) {
    final date = message.decodeDate()?.toLocal();
    if (date == null) return '';
    return DateFormat('EEE, d MMM yyyy \'at\' HH:mm').format(date);
  }

  /// Plain body of the original, falling back to a rough text version of
  /// its HTML so there is always something to quote.
  static String plainBody(MimeMessage message) {
    final plain = message.decodeTextPlainPart();
    if (plain != null && plain.trim().isNotEmpty) return plain.trim();
    final html = message.decodeTextHtmlPart();
    if (html == null) return '';
    return html
        .replaceAll(RegExp(r'<(br|/p|/div|/tr)[^>]*>',
            caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// `On Thu, 7 Aug 2026 at 09:14, Emeka Nwosu <emeka@x> wrote:`
  static String replyHeader(MimeMessage original) =>
      'On ${_dateLabel(original)}, ${_senderLabel(original)} wrote:';

  /// The quoted history, "> " prefixed, for the plain-text part.
  static String replyQuotePlain(MimeMessage original) {
    final body = plainBody(original);
    final quoted =
        body.split('\n').map((line) => '> $line').join('\n');
    return '${replyHeader(original)}\n$quoted';
  }

  /// The quoted history as a gmail_quote blockquote for the HTML part.
  static String replyQuoteHtml(MimeMessage original) {
    final html = original.decodeTextHtmlPart();
    final inner = (html != null && html.trim().isNotEmpty)
        ? html
        : _escapeHtml(plainBody(original)).replaceAll('\n', '<br>');
    return '<div class="gmail_quote">'
        '<div>${_escapeHtml(replyHeader(original))}</div>'
        '<blockquote style="margin:0 0 0 .8ex;border-left:1px solid #ccc;'
        'padding-left:1ex">$inner</blockquote></div>';
  }

  /// Gmail-style forwarded-message block for the editor.
  static String forwardPlain(MimeMessage original) {
    final to = (original.to ?? [])
        .map((a) => a.personalName?.isNotEmpty ?? false
            ? '${a.personalName} <${a.email}>'
            : a.email)
        .join(', ');
    final lines = [
      '---------- Forwarded message ----------',
      'From: ${_senderLabel(original)}',
      if (_dateLabel(original).isNotEmpty) 'Date: ${_dateLabel(original)}',
      'Subject: ${original.decodeSubject() ?? ''}',
      if (to.isNotEmpty) 'To: $to',
      '',
      plainBody(original),
    ];
    return lines.join('\n');
  }
}
