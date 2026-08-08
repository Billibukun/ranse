import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../distribution.dart';
import '../models/account.dart';
import '../services/account_store.dart';
import '../services/mail_service.dart';
import '../services/updater.dart';
import '../theme.dart';
import '../widgets/glass_bar.dart';
import '../widgets/message_row.dart';
import '../widgets/ranse_drawer.dart';
import 'account_setup_screen.dart';
import 'compose_screen.dart';
import 'message_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  MailService? _service;
  List<Mailbox> _folders = [];
  Mailbox? _folder;
  List<MimeMessage> _messages = [];
  final Set<MimeMessage> _selected = {};
  bool _loading = false;
  String? _error;
  bool _updatePrompted = false;

  AccountStore get _store => AccountStore.instance;
  bool get _selecting => _selected.isNotEmpty;

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
    _folder = null;
    _folders = [];
    _selected.clear();
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
      // Inbox and folder list ride the same connection concurrently.
      final results = await Future.wait([
        service.fetchFolder(),
        service.listFolders().catchError((_) => <Mailbox>[]),
      ]);
      final messages = results[0] as List<MimeMessage>;
      final folders = results[1] as List<Mailbox>;
      if (!mounted) return;
      setState(() {
        _service = service;
        _messages = messages;
        _folders = folders;
        _folder = folders.where((f) => f.isInbox).firstOrNull;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the mailbox.\n$e';
      });
    }
  }

  Future<void> _openFolder(Mailbox box) async {
    final service = _service;
    if (service == null) return;
    // Cache-first: paint whatever we already have instantly, then refresh.
    final cached = service.cachedFolder(box);
    setState(() {
      _folder = box;
      _selected.clear();
      if (cached != null) {
        _messages = cached;
        _loading = false;
      } else {
        _loading = true;
      }
    });
    try {
      final messages = await service.fetchFolder(mailbox: box);
      if (!mounted || _folder != box) return;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || _folder != box) return;
      setState(() {
        _loading = false;
        if (cached == null) {
          _error = 'Could not open ${box.name}.\n$e';
        }
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
      final messages = await service.fetchFolder(mailbox: _folder);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
    } catch (_) {
      await _connectAndLoad();
    }
  }

  void _quickFolder(QuickFolder which) {
    final target = switch (which) {
      QuickFolder.inbox => _folders.where((f) => f.isInbox).firstOrNull,
      QuickFolder.sent => _folders.where((f) => f.isSent).firstOrNull,
      QuickFolder.drafts => _folders.where((f) => f.isDrafts).firstOrNull,
    };
    if (target != null) _openFolder(target);
  }

  QuickFolder? get _activeQuick {
    final f = _folder;
    if (f == null || f.isInbox) return QuickFolder.inbox;
    if (f.isSent) return QuickFolder.sent;
    if (f.isDrafts) return QuickFolder.drafts;
    return null;
  }

  Future<void> _checkForUpdate() async {
    if (!kSelfUpdateEnabled || _updatePrompted) return;
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

  Future<void> _bulk(
      Future<void> Function(List<MimeMessage>) action, String done) async {
    final service = _service;
    if (service == null) return;
    final targets = _selected.toList();
    setState(() => _selected.clear());
    try {
      await action(targets);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('That failed: $e')));
    }
    await _refresh();
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final account = _store.current;
    return Scaffold(
      key: _scaffoldKey,
      drawer: account == null
          ? null
          : RanseDrawer(
              folders: _folders,
              currentFolder: _folder,
              onFolderSelected: _openFolder,
            ),
      body: SafeArea(
        child: account == null
            ? _welcome()
            : Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _selecting ? _selectionHeader() : _header(account),
                      Expanded(child: _list()),
                    ],
                  ),
                  GlassBar(
                    active: _activeQuick,
                    onFolder: _quickFolder,
                    onCompose: _compose,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _header(RanseAccount account) {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    final unread = _messages.where((m) => !m.isSeen).length;
    final folderName = _folder?.isInbox ?? true ? 'Inbox' : _folder!.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, ${account.displayName.trim().isNotEmpty ? account.displayName.trim().split(' ').first : account.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(folderName, style: context.disp(size: 22)),
                    const SizedBox(width: 8),
                    if (unread > 0)
                      Text(
                        '$unread new',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ranse.brass,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 23),
            onPressed: () {
              final service = _service;
              final account = _store.current;
              if (service == null || account == null) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    SearchScreen(service: service, account: account),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu, size: 23),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Glass(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_selected.length} selected',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Archive',
              icon: const Icon(Icons.archive_outlined, size: 21),
              onPressed: () =>
                  _bulk(_service!.moveToArchive, 'Archived'),
            ),
            IconButton(
              tooltip: 'Junk',
              icon: const Icon(Icons.block_outlined, size: 21),
              onPressed: () => _bulk(_service!.moveToJunk, 'Marked as junk'),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 21),
              onPressed: () => _bulk(_service!.moveToTrash, 'Moved to Trash'),
            ),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close, size: 21),
              onPressed: () => setState(() => _selected.clear()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final scheme = Theme.of(context).colorScheme;
    if (!_store.isLoaded || _loading) {
      return _skeleton();
    }
    if (_error != null) {
      return _empty(
        art: 'Hm.',
        title: 'Connection problem',
        text: _error!,
        actionLabel: 'Retry',
        onAction: _connectAndLoad,
      );
    }
    if (_messages.isEmpty) {
      final inbox = _folder?.isInbox ?? true;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: _empty(
                art: inbox ? 'All clear.' : 'Empty.',
                title: inbox ? 'Every letter answered' : 'Nothing in here',
                text: inbox
                    ? 'Nothing waits for you. New mail will announce itself.'
                    : 'This folder has no messages.',
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110, top: 6),
        children: [
          RanseCard(
            child: Column(
              children: [
                for (var i = 0; i < _messages.length; i++) ...[
                  _swipeable(_messages[i]),
                  if (i != _messages.length - 1)
                    Divider(
                        height: 1,
                        thickness: .8,
                        color: scheme.outlineVariant),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeable(MimeMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final row = MessageRow(
      message: message,
      selectionMode: _selecting,
      selected: _selected.contains(message),
      onTap: () {
        if (_selecting) {
          setState(() {
            _selected.contains(message)
                ? _selected.remove(message)
                : _selected.add(message);
          });
        } else {
          _openMessage(message);
        }
      },
      onLongPress: () {
        HapticFeedback.selectionClick();
        setState(() => _selected.add(message));
      },
    );
    if (_selecting) return row;
    return Dismissible(
      key: ValueKey(message.uid ?? message.hashCode),
      background: Container(
        color: scheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 22),
        child: Icon(Icons.archive_outlined, color: scheme.onPrimary),
      ),
      secondaryBackground: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (direction) async {
        final service = _service;
        setState(() => _messages.remove(message));
        if (service == null) return;
        final archive = direction == DismissDirection.startToEnd;
        try {
          if (archive) {
            await service.moveToArchive([message]);
          } else {
            await service.moveToTrash([message]);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(archive ? 'Archived' : 'Moved to Trash')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('That failed: $e')));
            await _refresh();
          }
        }
      },
      child: row,
    );
  }

  /// Pulsing placeholder rows - faster-feeling than a spinner.
  Widget _skeleton() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 6),
      children: [
        RanseCard(
          child: Column(
            children: [
              for (var i = 0; i < 8; i++) ...[
                _SkeletonRow(seed: i),
                if (i != 7)
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

  Widget _empty({
    required String art,
    required String title,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(art,
                style: context.disp(
                    size: 42, italic: true, color: ranse.brass)),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center, style: context.disp(size: 20)),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    if (!_store.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return _empty(
      art: 'Ranse',
      title: 'Welcome',
      text: 'Add your email account to get started. Just your email address '
          'and password - Ranse finds the rest.',
      actionLabel: 'Add account',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountSetupScreen()),
      ),
    );
  }
}

class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow({required this.seed});

  final int seed;

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final widths = [.55, .7, .45, .62, .5, .68, .58, .48];
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
    return FadeTransition(
      opacity: Tween(begin: .45, end: 1.0).animate(_pulse),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Column(
          children: [
            bar(widths[widget.seed % widths.length], 11),
            const SizedBox(height: 7),
            bar(widths[(widget.seed + 3) % widths.length] + .2, 9),
          ],
        ),
      ),
    );
  }
}
