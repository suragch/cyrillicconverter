import 'package:flutter/material.dart';
import '../desktop_theme.dart';
import 'desktop_button.dart';

class DesktopDialogFrame extends StatelessWidget {
  final String title;
  final Widget? leadingIcon;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final VoidCallback? onClose;

  const DesktopDialogFrame({
    super.key,
    required this.title,
    this.leadingIcon,
    required this.content,
    this.actions,
    this.maxWidth = 520,
    this.maxHeight,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: maxWidth,
          constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight!) : null,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DesktopTheme.panelBackground,
            borderRadius: DesktopTheme.roundedMedium,
            border: Border.all(color: DesktopTheme.borderMedium, width: 1),
            boxShadow: DesktopTheme.dialogShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Window Header
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: DesktopTheme.panelHeaderBackground,
                  border: Border(
                    bottom: BorderSide(color: DesktopTheme.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    if (leadingIcon != null) ...[
                      leadingIcon!,
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DesktopTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DesktopIconButton(
                      icon: Icons.close,
                      size: 16,
                      tooltip: 'Хаах (Esc)',
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Dialog Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: content,
                ),
              ),

              // Dialog Action Footer
              if (actions != null && actions!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: DesktopTheme.panelHeaderBackground,
                    border: Border(
                      top: BorderSide(color: DesktopTheme.border, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
