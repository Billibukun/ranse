import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

/// Shared rich-text state for compose and inline reply.
/// Wraps a Quill controller and turns its content into the plain + HTML pair
/// that goes into a multipart/alternative email.
class RichComposer {
  RichComposer({String? initialText})
      : controller = QuillController.basic() {
    if (initialText != null && initialText.isNotEmpty) {
      controller.document.insert(0, initialText);
      controller.moveCursorToStart();
    }
  }

  final QuillController controller;

  String get plainText => controller.document.toPlainText().trimRight();

  bool get isEmpty => plainText.trim().isEmpty;

  /// True when any inline formatting was applied anywhere in the document.
  bool get hasFormatting {
    for (final op in controller.document.toDelta().toList()) {
      final attrs = op.attributes;
      if (attrs != null && attrs.isNotEmpty) return true;
    }
    return false;
  }

  String get html => QuillDeltaToHtmlConverter(
        controller.document.toDelta().toJson(),
        ConverterOptions.forEmail(),
      ).convert();

  void dispose() => controller.dispose();
}

/// Minimal formatting toolbar: bold, italic, underline (+ optional trailing
/// widgets like attach/send). Premium-quiet, no stock Quill chrome.
class FormatBar extends StatefulWidget {
  const FormatBar({super.key, required this.composer, this.trailing});

  final RichComposer composer;
  final List<Widget>? trailing;

  @override
  State<FormatBar> createState() => _FormatBarState();
}

class _FormatBarState extends State<FormatBar> {
  QuillController get _c => widget.composer.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool _isActive(Attribute attribute) =>
      _c.getSelectionStyle().attributes.containsKey(attribute.key);

  void _toggle(Attribute attribute) {
    if (_isActive(attribute)) {
      _c.formatSelection(Attribute.clone(attribute, null));
    } else {
      _c.formatSelection(attribute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FmtButton(
          label: 'B',
          style: const TextStyle(fontWeight: FontWeight.w800),
          active: _isActive(Attribute.bold),
          onTap: () => _toggle(Attribute.bold),
        ),
        _FmtButton(
          label: 'I',
          style: const TextStyle(fontStyle: FontStyle.italic),
          active: _isActive(Attribute.italic),
          onTap: () => _toggle(Attribute.italic),
        ),
        _FmtButton(
          label: 'U',
          style: const TextStyle(decoration: TextDecoration.underline),
          active: _isActive(Attribute.underline),
          onTap: () => _toggle(Attribute.underline),
        ),
        const Spacer(),
        ...?widget.trailing,
      ],
    );
  }
}

class _FmtButton extends StatelessWidget {
  const _FmtButton({
    required this.label,
    required this.style,
    required this.active,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: active ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 34,
            child: Center(
              child: Text(
                label,
                style: style.copyWith(
                  fontSize: 15,
                  color: active ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
