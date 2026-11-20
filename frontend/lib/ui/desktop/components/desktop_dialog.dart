import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../desktop_theme.dart';
import 'desktop_button.dart';

class DesktopDialogFrame extends StatelessWidget {
  final String title;
  final Widget? leadingIcon;
  final Widget content;
  final List<Widget>? actions;
  final List<Widget>? headerActions;
  final double maxWidth;
  final double? maxHeight;
  final VoidCallback? onClose;

  const DesktopDialogFrame({
    super.key,
    required this.title,
    this.leadingIcon,
    required this.content,
    this.actions,
    this.headerActions,
    this.maxWidth = 520,
    this.maxHeight,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenWidth < 600;
    final bottomInset = mediaQuery.viewInsets.bottom;

    final effectiveMargin = isCompact
        ? EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset)
        : EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset);

    final horizontalPadding = isCompact ? 32.0 : 48.0;
    final effectiveWidth = math.max(
      200.0,
      math.min(maxWidth, screenWidth - horizontalPadding),
    );
    final availableHeight = math.max(
      120.0,
      mediaQuery.size.height - horizontalPadding - bottomInset,
    );
    final effectiveMaxHeight = maxHeight != null
        ? math.min(maxHeight!, availableHeight)
        : availableHeight;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: effectiveWidth,
          constraints: BoxConstraints(
            maxWidth: effectiveWidth,
            maxHeight: effectiveMaxHeight,
          ),
          margin: effectiveMargin,
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
                    if (headerActions != null && headerActions!.isNotEmpty) ...[
                      ...headerActions!,
                      const SizedBox(width: 8),
                    ],
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
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: content,
                ),
              ),

              // Dialog Action Footer
              if (actions != null && actions!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: DesktopTheme.panelHeaderBackground,
                    border: Border(
                      top: BorderSide(color: DesktopTheme.border, width: 1),
                    ),
                  ),
                  child: _buildActionsFooter(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsFooter() {
    final items = actions!;
    final spacerIndex = items.indexWhere((w) => w is Spacer);
    if (spacerIndex != -1) {
      final leading = items.sublist(0, spacerIndex);
      final trailing = items.sublist(spacerIndex + 1);
      return Row(
        children: [
          ...leading,
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: trailing,
            ),
          ),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}
