import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';

/// Account credentials live in the Android Keystore-backed secure storage.
/// Non-sensitive sync state (last-seen UIDs) lives in SharedPreferences so the
/// background poll isolate can read it cheaply.
class AccountStore extends ChangeNotifier {
  AccountStore._();

  static final AccountStore instance = AccountStore._();

  static const _storage = FlutterSecureStorage();
  static const _accountsKey = 'ranse_accounts';
  static const _currentKey = 'ranse_current_account';

  List<RanseAccount> _accounts = [];
  String? _currentId;
  bool _loaded = false;

  List<RanseAccount> get accounts => List.unmodifiable(_accounts);
  bool get isLoaded => _loaded;

  RanseAccount? get current {
    if (_accounts.isEmpty) return null;
    return _accounts.firstWhere(
      (a) => a.id == _currentId,
      orElse: () => _accounts.first,
    );
  }

  Future<void> load() async {
    _accounts = await readAccounts();
    final prefs = await SharedPreferences.getInstance();
    _currentId = prefs.getString(_currentKey);
    _loaded = true;
    notifyListeners();
  }

  /// Static read usable from the background isolate (no notifier state).
  static Future<List<RanseAccount>> readAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RanseAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    await _storage.write(
      key: _accountsKey,
      value: jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> add(RanseAccount account) async {
    _accounts = [..._accounts, account];
    await _persist();
    await setCurrent(account.id);
  }

  Future<void> remove(String id) async {
    _accounts = _accounts.where((a) => a.id != id).toList();
    await _persist();
    if (_currentId == id) {
      await setCurrent(_accounts.isEmpty ? null : _accounts.first.id);
    } else {
      notifyListeners();
    }
    await clearLastSeenUid(id);
  }

  Future<void> setCurrent(String? id) async {
    _currentId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_currentKey);
    } else {
      await prefs.setString(_currentKey, id);
    }
    notifyListeners();
  }

  // --- Last-seen uidNext per account, for new-mail detection -------------

  static String _uidKey(String accountId) => 'last_uidnext_$accountId';

  static Future<int?> lastSeenUidNext(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_uidKey(accountId));
  }

  static Future<void> setLastSeenUidNext(String accountId, int uidNext) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_uidKey(accountId), uidNext);
  }

  static Future<void> clearLastSeenUid(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey(accountId));
  }
}
