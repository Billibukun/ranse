import 'package:enough_mail/enough_mail.dart';
import 'package:workmanager/workmanager.dart';

import '../models/account.dart';
import 'account_store.dart';
import 'notifier.dart';

const String pollTaskName = 'ranse-poll-mail';
const String pollUniqueName = 'ranse-periodic-poll';

/// Background entry point for WorkManager. Runs in its own isolate.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await pollAllAccounts();
      return true;
    } catch (_) {
      // Transient network failures are normal on mobile — retry next cycle.
      return true;
    }
  });
}

Future<void> registerPolling() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    pollUniqueName,
    pollTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
  );
}

/// Checks every configured account for mail newer than the stored uidNext
/// watermark and fires one notification per new message (capped).
///
/// Returns the number of new messages found across all accounts.
Future<int> pollAllAccounts() async {
  final accounts = await AccountStore.readAccounts();
  var totalNew = 0;
  for (final account in accounts) {
    try {
      totalNew += await _pollAccount(account);
    } catch (_) {
      // One broken account must not block the others.
    }
  }
  return totalNew;
}

const int _maxNotificationsPerPoll = 5;

Future<int> _pollAccount(RanseAccount account) async {
  final client = ImapClient(isLogEnabled: false);
  try {
    await client.connectToServer(
      account.imapHost,
      account.imapPort,
      isSecure: account.imapUseSsl,
      timeout: const Duration(seconds: 15),
    );
    if (!account.imapUseSsl) {
      await client.startTls();
    }
    await client.login(account.loginName, account.password);
    final inbox = await client.selectInbox();
    final uidNext = inbox.uidNext;
    if (uidNext == null) return 0;

    final lastSeen = await AccountStore.lastSeenUidNext(account.id);
    if (lastSeen == null || uidNext <= lastSeen) {
      // First run establishes the watermark silently.
      await AccountStore.setLastSeenUidNext(account.id, uidNext);
      return 0;
    }

    final result = await client.uidFetchMessages(
      MessageSequence.fromRange(lastSeen, uidNext - 1, isUidSequence: true),
      '(UID ENVELOPE)',
    );
    final fresh = result.messages;
    await AccountStore.setLastSeenUidNext(account.id, uidNext);
    if (fresh.isEmpty) return 0;

    final toShow = fresh.length > _maxNotificationsPerPoll
        ? fresh.sublist(fresh.length - _maxNotificationsPerPoll)
        : fresh;
    for (final message in toShow) {
      final from = message.decodeSender();
      final sender = from.isNotEmpty
          ? (from.first.personalName?.isNotEmpty ?? false
              ? from.first.personalName!
              : from.first.email)
          : account.email;
      await Notifier.showNewMail(
        id: (message.uid ?? DateTime.now().millisecondsSinceEpoch) % 0x7FFFFFFF,
        accountEmail: account.email,
        sender: sender,
        subject: message.decodeSubject() ?? '',
      );
    }
    if (fresh.length > toShow.length) {
      await Notifier.showNewMail(
        id: account.id.hashCode & 0x7FFFFFFF,
        accountEmail: account.email,
        sender: account.email,
        subject: '${fresh.length} new emails',
      );
    }
    return fresh.length;
  } finally {
    try {
      await client.logout();
    } catch (_) {}
    try {
      await client.disconnect();
    } catch (_) {}
  }
}
