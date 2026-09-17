import 'package:flutter/material.dart';
import '../desktop_theme.dart';

enum DesktopButtonVariant {
  primary,
  secondary,
  subtle,
  danger,
  success,
}

class DesktopButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final String label;
  final String? shortcutHint;
  final DesktopButtonVariant variant;
  final bool isLoading;
  final bool isDense;
  final Color? customColor;

  const DesktopButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.shortcutHint,
    this.variant = DesktopButtonVariant.secondary,
    this.isLoading = false,
    this.isDense = false,
    this.customColor,
  });

  @override
  State<DesktopButton> createState() => _DesktopButtonState();
}

class _DesktopButtonState extends State<DesktopButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    Border? border;

    switch (widget.variant) {
      case DesktopButtonVariant.primary:
        bg = _isPressed
            ? DesktopTheme.primaryActive
            : (_isHovered ? DesktopTheme.primaryHover : DesktopTheme.primary);
        fg = Colors.white;
        border = null;
        break;

      case DesktopButtonVariant.secondary:
        bg = _isPressed
            ? DesktopTheme.activeBackground
            : (_isHovered ? DesktopTheme.hoverBackground : DesktopTheme.panelBackground);
        fg = DesktopTheme.textPrimary;
        border = Border.all(color: DesktopTheme.borderMedium, width: 1);
        break;

      case DesktopButtonVariant.subtle:
        bg = _isPressed
            ? DesktopTheme.activeBackground
            : (_isHovered ? DesktopTheme.secondarySurface : Colors.transparent);
        fg = DesktopTheme.textSecondary;
        border = null;
        break;

      case DesktopButtonVariant.danger:
        bg = _isPressed
            ? DesktopTheme.danger.withValues(alpha: 0.15)
            : (_isHovered ? DesktopTheme.dangerSurface : DesktopTheme.panelBackground);
        fg = DesktopTheme.danger;
        border = Border.all(color: DesktopTheme.dangerBorder, width: 1);
        break;

      case DesktopButtonVariant.success:
        bg = _isPressed
            ? DesktopTheme.success.withValues(alpha: 0.15)
            : (_isHovered ? DesktopTheme.successSurface : DesktopTheme.panelBackground);
        fg = DesktopTheme.success;
        border = Border.all(color: DesktopTheme.successBorder, width: 1);
        break;
    }

    if (widget.customColor != null) {
      fg = widget.customColor!;
    }

    if (!isEnabled) {
      bg = bg.withValues(alpha: 0.5);
      fg = fg.withValues(alpha: 0.5);
      if (border != null) {
        border = Border.all(color: DesktopTheme.border.withValues(alpha: 0.5), width: 1);
      }
    }

    final verticalPadding = widget.isDense ? 5.0 : 8.0;
    final horizontalPadding = widget.isDense ? 8.0 : 12.0;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DesktopTheme.roundedSmall,
            border: border,
            boxShadow: widget.variant == DesktopButtonVariant.primary && isEnabled
                ? DesktopTheme.subtleShadow
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: widget.isDense ? 12 : 14,
                    height: widget.isDense ? 12 : 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  ),
                )
              else if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: IconTheme(
                    data: IconThemeData(size: widget.isDense ? 14 : 16, color: fg),
                    child: widget.icon!,
                  ),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.isDense ? 12 : 13,
                  fontWeight: widget.variant == DesktopButtonVariant.primary
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: fg,
                  fontFamily: null,
                ),
              ),
              if (widget.shortcutHint != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.variant == DesktopButtonVariant.primary
                        ? Colors.white.withValues(alpha: 0.2)
                        : DesktopTheme.secondarySurface,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: widget.variant == DesktopButtonVariant.primary
                          ? Colors.white.withValues(alpha: 0.3)
                          : DesktopTheme.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.shortcutHint!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: widget.variant == DesktopButtonVariant.primary
                          ? Colors.white
                          : DesktopTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  const DesktopIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 16,
    this.color,
  });

  @override
  State<DesktopIconButton> createState() => _DesktopIconButtonState();
}

class _DesktopIconButtonState extends State<DesktopIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    final child = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered && isEnabled ? DesktopTheme.hoverBackground : Colors.transparent,
            borderRadius: DesktopTheme.roundedSmall,
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color ?? (isEnabled ? DesktopTheme.textSecondary : DesktopTheme.textMuted),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: child,
      );
    }

    return child;
  }
}
