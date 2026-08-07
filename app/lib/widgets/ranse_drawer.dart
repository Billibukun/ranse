import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../models/account.dart';
import '../screens/account_setup_screen.dart';
import '../services/account_store.dart';
import '../theme.dart';

/// Folders + account switcher, styled per the synthesis (R3).
class RanseDrawer extends StatelessWidget {
  const RanseDrawer({
    super.key,
    required this.folders,
    required this.currentFolder,
    required this.onFolderSelected,
  });

  final List<Mailbox> folders;
  final Mailbox? currentFolder;
  final ValueChanged<Mailbox> onFolderSelected;

  IconData _folderIcon(Mailbox box) {
    if (box.isInbox) return Icons.inbox_outlined;
    if (box.isSent) return Icons.send_outlined;
    if (box.isDrafts) return Icons.edit_note_outlined;
    if (box.isJunk) return Icons.block_outlined;
    if (box.isTrash) return Icons.delete_outline;
    if (box.isArchive) return Icons.archive_outlined;
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final store = AccountStore.instance;
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ranse',
                        style: context.disp(size: 26, italic: true)),
                    const SizedBox(height: 2),
                    Text(
                      'YOUR MAIL, DELIVERED',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: ranse.brass,
                      ),
                    ),
                  ],
                ),
              ),
              RanseCard(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (final account in store.accounts)
                      _AccountRow(
                        account: account,
                        active: account.id == store.current?.id,
                        onTap: () {
                          store.setCurrent(account.id);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: RanseCard(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        for (final box in folders)
                          _FolderRow(
                            icon: _folderIcon(box),
                            name: box.name,
                            count: box.isInbox && box.messagesUnseen > 0
                                ? '${box.messagesUnseen}'
                                : (box.messagesExists > 0
                                    ? '${box.messagesExists}'
                                    : ''),
                            active: box == currentFolder ||
                                (currentFolder == null && box.isInbox),
                            onTap: () {
                              Navigator.of(context).pop();
                              onFolderSelected(box);
                            },
                          ),
                        if (folders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'Folders load once the mailbox connects.',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AccountSetupScreen()));
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 19, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(
                        'Add account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.active,
    required this.onTap,
  });

  final RanseAccount account;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: .8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                account.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (active)
              Icon(Icons.check, size: 16, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.icon,
    required this.name,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranse = context.ranse;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: active ? ranse.tagBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12.5),
        child: Row(
          children: [
            Icon(icon,
                size: 19,
                color: active ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (count.isNotEmpty)
              Text(
                count,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
