import 'package:flutter/material.dart';
import '../desktop/components/desktop_button.dart';
import '../desktop/components/desktop_dialog.dart';
import '../desktop/desktop_theme.dart';

class PrivacySettingsDialog extends StatefulWidget {
  final bool initialSaveContext;
  final bool isFirstTimePrompt;

  const PrivacySettingsDialog({
    super.key,
    this.initialSaveContext = true,
    this.isFirstTimePrompt = false,
  });

  @override
  State<PrivacySettingsDialog> createState() => _PrivacySettingsDialogState();
}

class _PrivacySettingsDialogState extends State<PrivacySettingsDialog> {
  late bool _saveContext;

  @override
  void initState() {
    super.initState();
    _saveContext = widget.initialSaveContext;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopDialogFrame(
      title: widget.isFirstTimePrompt
          ? 'Нууцлалын сонголт'
          : 'Нууцлал ба тохиргоо',
      maxWidth: 520,
      leadingIcon: const Icon(
        Icons.shield_outlined,
        size: 18,
        color: DesktopTheme.primary,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isFirstTimePrompt
                  ? 'Таны оруулсан бичвэрт толь бичигт бүртгэлгүй үг тааралдвал серверт хэрхэн бүртгэх нууцлалын горимоо сонгоно уу:'
                  : 'Хөрвүүлэлт хийх үеийн нууцлалын горим:',
              style: DesktopTheme.body,
            ),
            const SizedBox(height: 16),
            _buildOptionCard(
              value: true,
              title: 'Үл мэдэгдэх үгийн утгын орчныг хадгалах',
              badgeText: 'Шүүгчдэд тустай',
              badgeColor: DesktopTheme.primary,
              description:
                  'Үл мэдэгдэх үг тааралдвал эргэн тойрны цөөн үгийг хамт хадгалж, шүүгчдэд шинэ үг нэмэхэд тусална. (Утасны дугаар, и-мэйл зэргийг автоматаар халхална).',
            ),
            const SizedBox(height: 12),
            _buildOptionCard(
              value: false,
              title: 'Утгын орчныг хадгалахгүй',
              badgeText: 'Хувийн баримт бичиг',
              badgeColor: DesktopTheme.textMuted,
              description:
                  'Бичвэрийн өгүүлбэр, утгын орчныг серверт огт хадгалахгүй. Зөвхөн ямар кирилл үг дутуу байгаа тоог бүртгэнэ.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesktopTheme.secondarySurface,
                borderRadius: DesktopTheme.roundedSmall,
                border: Border.all(color: DesktopTheme.border, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: DesktopTheme.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Та энэхүү сонголтыг хүссэн үедээ дээд самбарын «Тохиргоо» хэсгээс өөрчлөх боломжтой.',
                      style: DesktopTheme.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!widget.isFirstTimePrompt) ...[
          DesktopButton(
            onPressed: () {
              Navigator.pop(context, null);
            },
            label: 'Цуцлах',
            variant: DesktopButtonVariant.secondary,
            isDense: true,
          ),
          const SizedBox(width: 8),
        ],
        DesktopButton(
          onPressed: () {
            Navigator.pop(context, _saveContext);
          },
          label: widget.isFirstTimePrompt ? 'Сонгоод үргэлжлүүлэх' : 'Хадгалах',
          variant: DesktopButtonVariant.primary,
          isDense: true,
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required bool value,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
  }) {
    final isSelected = _saveContext == value;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _saveContext = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? DesktopTheme.primarySurface
                : DesktopTheme.panelBackground,
            borderRadius: DesktopTheme.roundedMedium,
            border: Border.all(
              color: isSelected
                  ? DesktopTheme.primary
                  : DesktopTheme.borderMedium,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: isSelected
                      ? DesktopTheme.primary
                      : DesktopTheme.textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: DesktopTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DesktopTheme.textSecondary,
                        height: 1.35,
                      ),
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
}
