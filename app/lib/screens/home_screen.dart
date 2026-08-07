import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/account_store.dart';
import '../services/mail_service.dart';
import '../services/updater.dart';
import '../widgets/message_tile.dart';
import 'account_setup_screen.dart';
import 'compose_screen.dart';
import 'message_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MailService? _service;
  List<MimeMessage> _messages = [];
  bool _loading = false;
  String? _error;
  bool _updatePrompted = false;

  AccountStore get _store => AccountStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onAccountsChanged);
    _connectAndLoad();
    _checkForUpdate();
  }

  @override
  void dispose() {
    _store.removeListener(_onAccountsChanged);
    _service?.disconnect();
    super.dispose();
  }

  void _onAccountsChanged() => _connectAndLoad();

  Future<void> _connectAndLoad() async {
    final account = _store.current;
    await _service?.disconnect();
    _service = null;
    if (account == null) {
      setState(() {
        _messages = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = MailService(account);
      final messages = await service.fetchInbox();
      if (!mounted) return;
      setState(() {
        _service = service;
        _messages = messages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the inbox.\n$e';
      });
    }
  }

  Future<void> _refresh() async {
    final service = _service;
    if (service == null) {
      await _connectAndLoad();
      return;
    }
    try {
      final messages = await service.fetchInbox();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
    } catch (_) {
      await _connectAndLoad();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_updatePrompted) return;
    try {
      final update = await Updater.check();
      if (update == null || !mounted) return;
      _updatePrompted = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Ranse ${update.version} is available'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () => SettingsScreen.runUpdateFlow(context, update),
          ),
        ),
      );
    } catch (_) {
      // Update check is best-effort; never bother the user about it.
    }
  }

  void _openMessage(MimeMessage message) {
    final service = _service;
    final account = _store.current;
    if (service == null || account == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MessageScreen(
        service: service,
        account: account,
        message: message,
      ),
    ));
  }

  void _compose() {
    final service = _service;
    final account = _store.current;
    if (service == null || account == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComposeScreen(service: service, account: account),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final account = _store.current;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ranse'),
            if (account != null)
              Text(
                account.email,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: _AccountDrawer(store: _store),
      floatingActionButton: account == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _compose,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Compose'),
            ),
      body: _buildBody(account),
    );
  }

  Widget _buildBody(RanseAccount? account) {
    if (!_store.isLoaded || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (account == null) {
      return _EmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'Welcome to Ranse',
        message: 'Add your email account to get started.',
        actionLabel: 'Add account',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountSetupScreen()),
        ),
      );
    }
    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Connection problem',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _connectAndLoad,
      );
    }
    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No messages in the inbox.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: _messages.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final message = _messages[index];
          return MessageTile(
            message: message,
            onTap: () => _openMessage(message),
          );
        },
      ),
    );
  }
}

class _AccountDrawer extends StatelessWidget {
  const _AccountDrawer({required this.store});

  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: const Icon(Icons.send_outlined),
                ),
                title: const Text(
                  'Ranse',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
                subtitle: const Text('Your mail, delivered'),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final account in store.accounts)
                      ListTile(
                        leading: Icon(
                          account.id == store.current?.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: scheme.primary,
                        ),
                        title: Text(
                          account.displayName.isEmpty
                              ? account.email
                              : account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          store.setCurrent(account.id);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add account'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AccountSetupScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
