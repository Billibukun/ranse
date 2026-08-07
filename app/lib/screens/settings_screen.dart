import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../distribution.dart';
import '../main.dart';
import '../services/account_store.dart';
import '../services/updater.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, themeController]),
        builder: (context, _) => ListView(
          children: [
            const _SectionHeader('Appearance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.phone_android_outlined),
                  ),
                ],
                selected: {themeController.mode},
                onSelectionChanged: (selection) =>
                    themeController.setMode(selection.first),
              ),
            ),
            const Divider(),
            const _SectionHeader('Accounts'),
            for (final account in store.accounts)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(account.email),
                subtitle: Text(
                    '${account.imapHost} · ${account.smtpHost}:${account.smtpPort}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      _confirmRemove(account.id, account.email),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add account'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AccountSetupScreen()),
              ),
            ),
            const Divider(),
            const _SectionHeader('Updates'),
            if (kSelfUpdateEnabled)
              ListTile(
                leading: _checking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt),
                title: const Text('Check for updates'),
                subtitle: Text(_version.isEmpty ? '' : 'Version $_version'),
                onTap: _checking ? null : _checkForUpdates,
              )
            else
              ListTile(
                leading: const Icon(Icons.shop_outlined),
                title: const Text('Updates arrive through Google Play'),
                subtitle: Text(_version.isEmpty ? '' : 'Version $_version'),
              ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Ranse'),
              subtitle: Text(
                  'Your mail, delivered.\nA Data Druid Tech Services product.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
