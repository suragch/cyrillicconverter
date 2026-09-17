import 'package:flutter/material.dart';
import '../desktop_theme.dart';

class DesktopStatusBar extends StatelessWidget {
  final bool isLoading;
  final String statusText;
  final int wordCount;
  final int charCount;
  final int homonymCount;
  final int unknownCount;
  final double fontSize;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final String encodingLabel;
  final String serverStatus;

  const DesktopStatusBar({
    super.key,
    this.isLoading = false,
    this.statusText = 'Бэлэн',
    this.wordCount = 0,
    this.charCount = 0,
    this.homonymCount = 0,
    this.unknownCount = 0,
    this.fontSize = 26.0,
    this.onZoomIn,
    this.onZoomOut,
    this.encodingLabel = 'Юникод',
    this.serverStatus = 'Сервер: 8080 (Хэвийн)',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: DesktopTheme.panelBackground,
        border: Border(
          top: BorderSide(color: DesktopTheme.border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Left Group: Status + Text Metrics ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLoading ? DesktopTheme.warning : DesktopTheme.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLoading ? 'Хөрвүүлж байна...' : statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: DesktopTheme.textSecondary,
                          fontFamily: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildDivider(),
                      const SizedBox(width: 12),
                      Text(
                        'Үг: $wordCount  •  Тэмдэгт: $charCount',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DesktopTheme.textSecondary,
                          fontFamily: null,
                        ),
                      ),
                      if (!isCompact && (homonymCount > 0 || unknownCount > 0)) ...[
                        const SizedBox(width: 10),
                        _buildDivider(),
                        const SizedBox(width: 10),
                        if (homonymCount > 0) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: DesktopTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Олон утгатай: $homonymCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: DesktopTheme.primary,
                              fontFamily: null,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (unknownCount > 0) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: DesktopTheme.danger,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Тольд үгүй: $unknownCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: DesktopTheme.danger,
                              fontFamily: null,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),

                  const SizedBox(width: 16),

                  // --- Right Group: Zoom + Encoding + Server ---
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Үсэг: ${fontSize.toInt()}pt',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DesktopTheme.textSecondary,
                          fontFamily: null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildCompactZoomBtn(
                        icon: Icons.remove,
                        onTap: onZoomOut,
                        tooltip: 'Жижигсгэх',
                      ),
                      _buildCompactZoomBtn(
                        icon: Icons.add,
                        onTap: onZoomIn,
                        tooltip: 'Томосгох',
                      ),
                      const SizedBox(width: 10),
                      _buildDivider(),
                      const SizedBox(width: 10),
                      Text(
                        encodingLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: DesktopTheme.textSecondary,
                          fontFamily: null,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 10),
                        _buildDivider(),
                        const SizedBox(width: 10),
                        Text(
                          serverStatus,
                          style: const TextStyle(
                            fontSize: 11,
                            color: DesktopTheme.textMuted,
                            fontFamily: null,
                          ),
                        ),
                      ],
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

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 14,
      color: DesktopTheme.border,
    );
  }

  Widget _buildCompactZoomBtn({
    required IconData icon,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: DesktopTheme.secondarySurface,
            ),
            child: Icon(icon, size: 12, color: DesktopTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}
