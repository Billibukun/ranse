import 'package:enough_mail/enough_mail.dart';

import '../models/account.dart';

/// Thin wrapper around enough_mail's MailClient for one account.
/// The device talks straight to the customer's cPanel server — nothing is
/// proxied.
class MailService {
  MailService(this.account);

  final RanseAccount account;
  MailClient? _client;

  Future<MailClient> _ensureConnected() async {
    final existing = _client;
    if (existing != null && existing.isConnected) return existing;
    final client = MailClient(
      account.toMailAccount(),
      isLogEnabled: false,
      logName: account.email,
    );
    await client.connect();
    _client = client;
    return client;
  }

  /// Newest-first envelope fetch of the inbox.
  Future<List<MimeMessage>> fetchInbox({int count = 40}) async {
    final client = await _ensureConnected();
    await client.selectInbox();
    final messages = await client.fetchMessages(
      count: count,
      fetchPreference: FetchPreference.envelope,
    );
    messages.sort(_newestFirst);
    return messages;
  }

  static int _newestFirst(MimeMessage a, MimeMessage b) {
    final da = a.decodeDate();
    final db = b.decodeDate();
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  /// Downloads the full message (body + attachments) and marks it seen.
  Future<MimeMessage> fetchContents(MimeMessage message) async {
    final client = await _ensureConnected();
    return client.fetchMessageContents(message, markAsSeen: true);
  }

  /// Sends and appends to the account's Sent folder.
  Future<void> send(MimeMessage message) async {
    final client = await _ensureConnected();
    await client.sendMessage(message, appendToSent: true);
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        await client.disconnect();
      } catch (_) {
        // already gone — fine
      }
    }
  }
}
