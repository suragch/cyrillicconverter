import 'package:flutter/material.dart';
import '../desktop_theme.dart';
import 'desktop_button.dart';

enum DesktopNavTab {
  converter,
  moderator,
  dictionary,
}

enum HeaderExportEncoding {
  unicode,
  menksoft,
}

class DesktopHeader extends StatelessWidget {
  final DesktopNavTab activeTab;
  final ValueChanged<DesktopNavTab> onTabChanged;
  final int moderatorBadgeCount;
  final double fontSize;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final HeaderExportEncoding copyEncoding;
  final ValueChanged<HeaderExportEncoding> onEncodingChanged;
  final bool isRestoringSession;
  final bool isLoggedIn;
  final Map<String, dynamic>? currentUser;
  final VoidCallback onLoginPressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback onHelpPressed;

  const DesktopHeader({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    this.moderatorBadgeCount = 0,
    required this.fontSize,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.copyEncoding,
    required this.onEncodingChanged,
    required this.isRestoringSession,
    required this.isLoggedIn,
    this.currentUser,
    required this.onLoginPressed,
    required this.onLogoutPressed,
    required this.onHelpPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: DesktopTheme.panelBackground,
        border: Border(
          bottom: BorderSide(color: DesktopTheme.border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 950;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Left Group: Brand + Navigation Tabs ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Logo & Title
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: DesktopTheme.primary,
                          borderRadius: DesktopTheme.roundedSmall,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'ᠮ',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Menksoft',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Кирилл ➜ ᠮᠣᠩᠭᠣᠯ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DesktopTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildVerticalDivider(),
                      const SizedBox(width: 8),

                      // Navigation Tabs
                      _buildNavTab(
                        tab: DesktopNavTab.converter,
                        label: 'Хөрвүүлэгч',
                        icon: Icons.translate,
                      ),
                      const SizedBox(width: 4),
                      _buildNavTab(
                        tab: DesktopNavTab.moderator,
                        label: isCompact ? 'Шүүгч' : 'Шүүгч / Модератор',
                        icon: Icons.rate_review_outlined,
                        badgeCount: moderatorBadgeCount,
                      ),
                      const SizedBox(width: 4),
                      _buildNavTab(
                        tab: DesktopNavTab.dictionary,
                        label: isCompact ? 'Толь' : 'Толь бичиг',
                        icon: Icons.menu_book_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // --- Right Group: Zoom + Encoding + Help + Auth ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zoom Controls: [A-] 26pt [A+]
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: DesktopTheme.secondarySurface,
                          borderRadius: DesktopTheme.roundedSmall,
                          border: Border.all(color: DesktopTheme.border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeaderIconBtn(
                              text: 'A-',
                              tooltip: 'Үсэг жижигсгэх',
                              onTap: onZoomOut,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${fontSize.toInt()}pt',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: DesktopTheme.textSecondary,
                                ),
                              ),
                            ),
                            _buildHeaderIconBtn(
                              text: 'A+',
                              tooltip: 'Үсэг томосгох',
                              onTap: onZoomIn,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Copy Encoding Selector
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: DesktopTheme.secondarySurface,
                          borderRadius: DesktopTheme.roundedSmall,
                          border: Border.all(color: DesktopTheme.border, width: 1),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<HeaderExportEncoding>(
                            value: copyEncoding,
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: DesktopTheme.textPrimary,
                              fontFamily: null,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: HeaderExportEncoding.unicode,
                                child: Text('Unicode'),
                              ),
                              DropdownMenuItem(
                                value: HeaderExportEncoding.menksoft,
                                child: Text('Menksoft'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) onEncodingChanged(val);
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),
                      DesktopIconButton(
                        icon: Icons.help_outline,
                        tooltip: 'Товчлуурын хослол',
                        size: 16,
                        onPressed: onHelpPressed,
                      ),

                      const SizedBox(width: 8),
                      _buildVerticalDivider(),
                      const SizedBox(width: 8),

                      // User / Auth Strip
                      if (isRestoringSession)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (isLoggedIn) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: DesktopTheme.secondarySurface,
                            borderRadius: DesktopTheme.roundedSmall,
                            border: Border.all(color: DesktopTheme.border, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: DesktopTheme.primary,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  (currentUser?['email'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (!isCompact) ...[
                                const SizedBox(width: 6),
                                Text(
                                  currentUser?['email'] as String? ?? 'Хэрэглэгч',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: DesktopTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        DesktopButton(
                          onPressed: onLogoutPressed,
                          label: 'Гарах',
                          variant: DesktopButtonVariant.subtle,
                          isDense: true,
                        ),
                      ] else
                        DesktopButton(
                          onPressed: onLoginPressed,
                          label: 'Нэвтрэх',
                          icon: const Icon(Icons.login, size: 13),
                          variant: DesktopButtonVariant.secondary,
                          isDense: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavTab({
    required DesktopNavTab tab,
    required String label,
    required IconData icon,
    int badgeCount = 0,
  }) {
    final isActive = activeTab == tab;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTabChanged(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? DesktopTheme.secondarySurface : Colors.transparent,
            borderRadius: DesktopTheme.roundedSmall,
            border: Border.all(
              color: isActive ? DesktopTheme.borderMedium : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? DesktopTheme.primary : DesktopTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? DesktopTheme.textPrimary : DesktopTheme.textSecondary,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive ? DesktopTheme.primary : DesktopTheme.borderMedium,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : DesktopTheme.textPrimary,
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

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 18,
      color: DesktopTheme.border,
    );
  }

  Widget _buildHeaderIconBtn({
    required String text,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: DesktopTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
