import 'package:flutter/material.dart';

import '../theme.dart';

enum QuickFolder { inbox, sent, drafts }

/// The centered frosted-glass bottom bar: Inbox / Sent / Drafts + Compose.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.active,
    required this.onFolder,
    required this.onCompose,
  });

  final QuickFolder? active;
  final ValueChanged<QuickFolder> onFolder;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Glass(
          radius: 30,
          padding: const EdgeInsets.all(7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Item(
                icon: Icons.inbox_outlined,
                label: 'Inbox',
                selected: active == QuickFolder.inbox,
                onTap: () => onFolder(QuickFolder.inbox),
              ),
              _Item(
                icon: Icons.send_outlined,
                label: 'Sent',
                selected: active == QuickFolder.sent,
                onTap: () => onFolder(QuickFolder.sent),
              ),
              _Item(
                icon: Icons.edit_note_outlined,
                label: 'Drafts',
                selected: active == QuickFolder.drafts,
                onTap: () => onFolder(QuickFolder.drafts),
              ),
              const SizedBox(width: 4),
              Material(
                color: scheme.onSurface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onCompose,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.edit_outlined,
                        size: 21, color: scheme.surface),
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

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
