import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../distribution.dart';
import '../main.dart';
import '../services/account_store.dart';
import '../services/updater.dart';
import '../theme.dart';
import 'account_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// Shared update flow: confirm, download with progress, hand to installer.
  static Future<void> runUpdateFlow(
      BuildContext context, UpdateInfo update) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${update.version}?'),
        content: SingleChildScrollView(
          child: Text(
            update.notes.isEmpty
                ? 'A new version of Ranse is ready.'
                : update.notes,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Downloading update…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) =>
              LinearProgressIndicator(value: value == 0 ? null : value),
        ),
      ),
    );
    try {
      await Updater.downloadAndInstall(update,
          onProgress: (p) => progress.value = p);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    try {
      final update = await Updater.check();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ranse is up to date.')),
        );
      } else {
        await SettingsScreen.runUpdateFlow(context, update);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not reach the update server.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _editName(String id, String email, String current) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name shown to recipients'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Adaeze Okafor',
            helperText: email,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) {
      await AccountStore.instance.updateDisplayName(id, saved);
    }
  }

  Future<void> _confirmRemove(String id, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text('$email will be removed from this phone. '
            'Mail on the server is not touched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AccountStore.instance.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AccountStore.instance;
    final themeController = RanseApp.themeOf(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([store, themeController]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text('Settings', style: context.disp(size: 21)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 17),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 17),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Auto'),
                      icon: Icon(Icons.phone_android_outlined, size: 17),
                    ),
                  ],
                  selected: {themeController.mode},
                  onSelectionChanged: (selection) =>
                      themeController.setMode(selection.first),
                ),
              ),
              _sectionLabel(context, 'ACCOUNTS'),
              RanseCard(
                child: Column(
                  children: [
                    for (final account in store.accounts)
                      ListTile(
                        leading: Icon(Icons.email_outlined,
                            size: 20, color: scheme.primary),
                        title: Text(
                          account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          account.displayName.trim().isNotEmpty
                              ? 'Sends as "${account.displayName}"'
                              : 'No name set - tap to add one',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onTap: () => _editName(account.id,
                            account.email, account.displayName),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () =>
                              _confirmRemove(account.id, account.email),
                        ),
                      ),
                    ListTile(
                      leading: Icon(Icons.add,
                          size: 20, color: scheme.onSurfaceVariant),
                      title: const Text('Add account',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AccountSetupScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              _sectionLabel(context, 'UPDATES'),
              RanseCard(
                child: kSelfUpdateEnabled
                    ? ListTile(
                        leading: _checking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Icon(Icons.system_update_alt,
                                size: 20, color: scheme.primary),
                        title: const Text('Check for updates',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            _version.isEmpty ? '' : 'Version $_version',
                            style: const TextStyle(fontSize: 11.5)),
                        onTap: _checking ? null : _checkForUpdates,
                      )
                    : ListTile(
                        leading: Icon(Icons.shop_outlined,
                            size: 20, color: scheme.primary),
                        title: const Text(
                            'Updates arrive through Google Play',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            _version.isEmpty ? '' : 'Version $_version',
                            style: const TextStyle(fontSize: 11.5)),
                      ),
              ),
              const SizedBox(height: 26),
              Center(
                child: Column(
                  children: [
                    Text('Ranse',
                        style: context.disp(
                            size: 22,
                            italic: true,
                            color: context.ranse.brass)),
                    const SizedBox(height: 3),
                    Text(
                      'Your mail, delivered.\nA Data Druid Tech Services product.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: context.ranse.brass,
        ),
      ),
    );
  }
}
