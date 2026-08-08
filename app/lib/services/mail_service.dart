import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';

import '../models/account.dart';

/// Thin wrapper around enough_mail's MailClient for one account.
/// The device talks straight to the customer's cPanel server - nothing is
/// proxied.
class MailService {
  MailService(this.account);

  final RanseAccount account;
  MailClient? _client;
  List<Mailbox>? _mailboxes;

  /// Session caches - lists per folder and full messages by UID - so
  /// revisiting a folder or reopening a message is instant.
  final Map<String, List<MimeMessage>> folderCache = {};
  final Map<int, MimeMessage> _contentCache = {};

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

  /// Standard folders in display order, resolved from the server's own list
  /// by their SPECIAL-USE flags (with name fallbacks for older servers).
  Future<List<Mailbox>> listFolders() async {
    final client = await _ensureConnected();
    final all = _mailboxes ??= await client.listMailboxes();

    Mailbox? byFlag(MailboxFlag flag, List<String> names) {
      for (final box in all) {
        if (box.flags.contains(flag)) return box;
      }
      for (final box in all) {
        if (names.contains(box.name.toLowerCase())) return box;
      }
      return null;
    }

    final ordered = <Mailbox>[];
    void add(Mailbox? box) {
      if (box != null && !ordered.contains(box)) ordered.add(box);
    }

    add(byFlag(MailboxFlag.inbox, ['inbox']));
    add(byFlag(MailboxFlag.sent, ['sent', 'sent items', 'sent messages']));
    add(byFlag(MailboxFlag.drafts, ['drafts', 'draft']));
    add(byFlag(MailboxFlag.junk, ['junk', 'spam', 'junk e-mail']));
    add(byFlag(MailboxFlag.trash, ['trash', 'deleted', 'deleted items']));
    add(byFlag(MailboxFlag.archive, ['archive', 'archives']));
    // Any remaining real folders the user created on the server.
    for (final box in all) {
      if (!ordered.contains(box) && !box.isNotSelectable) ordered.add(box);
    }
    return ordered;
  }

  /// Newest-first envelope fetch of any folder (defaults to the inbox).
  /// Successful fetches refresh [folderCache] under the folder's path.
  Future<List<MimeMessage>> fetchFolder({
    Mailbox? mailbox,
    int count = 50,
  }) async {
    final client = await _ensureConnected();
    Mailbox selected;
    if (mailbox == null) {
      selected = await client.selectInbox();
    } else {
      selected = await client.selectMailbox(mailbox);
    }
    // An empty folder must short-circuit: fetching zero messages sends an
    // invalid message set that servers answer with BAD.
    if (selected.messagesExists == 0) {
      folderCache[selected.encodedPath] = [];
      return [];
    }
    final messages = await client.fetchMessages(
      count: count,
      fetchPreference: FetchPreference.envelope,
    );
    messages.sort(_newestFirst);
    folderCache[selected.encodedPath] = messages;
    return messages;
  }

  List<MimeMessage>? cachedFolder(Mailbox? mailbox) =>
      folderCache[mailbox?.encodedPath ?? 'INBOX'];

  static int _newestFirst(MimeMessage a, MimeMessage b) {
    final da = a.decodeDate();
    final db = b.decodeDate();
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  /// Downloads the full message (body + attachments) and marks it seen.
  /// Cached by UID so reopening a message is instant.
  Future<MimeMessage> fetchContents(MimeMessage message) async {
    final uid = message.uid;
    final cached = uid == null ? null : _contentCache[uid];
    if (cached != null) return cached;
    final client = await _ensureConnected();
    final full =
        await client.fetchMessageContents(message, markAsSeen: true);
    if (uid != null) {
      if (_contentCache.length > 30) {
        _contentCache.remove(_contentCache.keys.first);
      }
      _contentCache[uid] = full;
    }
    return full;
  }

  /// Server-side search across the currently relevant folder.
  Future<List<MimeMessage>> search(String query) async {
    final client = await _ensureConnected();
    final result = await client.searchMessages(
      MailSearch(query, SearchQueryType.allTextHeaders, pageSize: 40),
    );
    final messages = result.messages.toList()..sort(_newestFirst);
    return messages;
  }

  /// Sends and appends to the account's Sent folder.
  Future<void> send(MimeMessage message) async {
    final client = await _ensureConnected();
    await client.sendMessage(message, appendToSent: true);
  }

  Future<void> moveToTrash(List<MimeMessage> messages) async {
    final client = await _ensureConnected();
    for (final m in messages) {
      await client.deleteMessage(m);
    }
  }

  Future<void> moveToJunk(List<MimeMessage> messages) async {
    final client = await _ensureConnected();
    for (final m in messages) {
      await client.junkMessage(m);
    }
  }

  Future<void> moveToArchive(List<MimeMessage> messages) async {
    final client = await _ensureConnected();
    final archive = (await listFolders())
        .where((b) => b.flags.contains(MailboxFlag.archive))
        .firstOrNull;
    for (final m in messages) {
      if (archive != null) {
        await client.moveMessage(m, archive);
      } else {
        await client.deleteMessage(m);
      }
    }
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    _mailboxes = null;
    folderCache.clear();
    _contentCache.clear();
    if (client != null) {
      try {
        await client.disconnect();
      } catch (_) {
        // already gone - fine
      }
    }
  }
}
