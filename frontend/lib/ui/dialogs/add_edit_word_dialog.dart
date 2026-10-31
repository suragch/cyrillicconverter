import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongol/mongol.dart';
import '../../services/latin_ime.dart';
import '../desktop/components/desktop_button.dart';
import '../desktop/components/desktop_dialog.dart';
import '../desktop/desktop_theme.dart';

class AddEditWordDialog extends StatefulWidget {
  final String? initialCyrillic;
  final String? initialLatin;
  final String? initialExplanation;
  final Future<void> Function({
    required String cyrillic,
    required String menksoft,
    String? explanation,
  })
  onSubmit;
  final String title;
  final String submitButtonText;
  final bool initialShowKeyboard;

  const AddEditWordDialog({
    super.key,
    this.initialCyrillic,
    this.initialLatin,
    this.initialExplanation,
    required this.onSubmit,
    this.title = 'Үг нэмэх / санал болгох',
    this.submitButtonText = 'Илгээх',
    this.initialShowKeyboard = false,
  });

  @override
  State<AddEditWordDialog> createState() => _AddEditWordDialogState();
}

class _AddEditWordDialogState extends State<AddEditWordDialog> {
  late final TextEditingController _cyrillicController;
  late final TextEditingController _latinController;
  late final TextEditingController _explanationController;
  late final FocusNode _latinFocusNode;
  String _previewMenksoft = '';
  bool _isSubmitting = false;
  late bool _showKeyboard;

  @override
  void initState() {
    super.initState();
    _showKeyboard = widget.initialShowKeyboard;
    _cyrillicController = TextEditingController(text: widget.initialCyrillic);
    _latinController = TextEditingController(text: widget.initialLatin);
    _explanationController = TextEditingController(
      text: widget.initialExplanation,
    );
    _latinFocusNode = FocusNode();
    _latinFocusNode.addListener(_onLatinFocusChanged);

    _latinController.addListener(_onLatinChanged);
    _onLatinChanged();
  }

  void _onLatinFocusChanged() {
    setState(() {});
  }

  void _onLatinChanged() {
    final text = _latinController.text;
    if (LatinIme.containsMongolianScript(text)) {
      final converted = LatinIme.convertToLatin(text);
      _latinController.value = TextEditingValue(
        text: converted,
        selection: TextSelection.collapsed(offset: converted.length),
      );
      return;
    }
    setState(() {
      _previewMenksoft = LatinIme.latinToMenksoft(text);
    });
  }

  void _insertKey(String ch) {
    final text = _latinController.text;
    final selection = _latinController.selection;
    int start = selection.start >= 0 ? selection.start : text.length;
    int end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, ch);
    _latinController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + ch.length),
    );
  }

  @override
  void dispose() {
    _cyrillicController.dispose();
    _latinController.dispose();
    _explanationController.dispose();
    _latinFocusNode.removeListener(_onLatinFocusChanged);
    _latinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final cyrillic = _cyrillicController.text.trim();
    if (cyrillic.isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        cyrillic: cyrillic,
        menksoft: _previewMenksoft,
        explanation: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCyrillicFixed = widget.initialCyrillic != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isSubmitting) {
            _submit();
          }
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isSubmitting) {
            _submit();
          }
        },
      },
      child: DesktopDialogFrame(
        title: widget.title,
        maxWidth: 700,
        maxHeight: 740,
        leadingIcon: const Icon(
          Icons.edit_note,
          size: 18,
          color: DesktopTheme.primary,
        ),
        content: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical Mongolian preview
              Container(
                width: 80,
                constraints: const BoxConstraints(minHeight: 220),
                decoration: BoxDecoration(
                  color: DesktopTheme.canvas,
                  borderRadius: DesktopTheme.roundedSmall,
                  border: Border.all(
                    color: DesktopTheme.borderMedium,
                    width: 1,
                  ),
                ),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: MongolText(
                      _previewMenksoft.isEmpty ? ' ' : _previewMenksoft,
                      style: const TextStyle(
                        fontSize: 32,
                        fontFamily: 'Menksoft',
                        color: DesktopTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Inputs and Keyboard on the right side
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCyrillicFixed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: DesktopTheme.secondarySurface,
                          borderRadius: DesktopTheme.roundedSmall,
                          border: Border.all(
                            color: DesktopTheme.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Кирилл: ${widget.initialCyrillic}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: DesktopTheme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            DesktopIconButton(
                              icon: Icons.copy,
                              size: 14,
                              tooltip: 'Кирилл үгийг хуулах',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: widget.initialCyrillic ?? '',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Кирилл үг хуулагдлаа'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      TextField(
                        controller: _cyrillicController,
                        style: const TextStyle(fontSize: 13),
                        onSubmitted: (_) {
                          if (!_isSubmitting) {
                            _submit();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Кирилл үг',
                          labelStyle: const TextStyle(fontSize: 12),
                          border: const OutlineInputBorder(
                            borderRadius: DesktopTheme.roundedSmall,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          suffixIcon: _cyrillicController.text.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: DesktopIconButton(
                                    icon: Icons.copy,
                                    size: 14,
                                    tooltip: 'Кирилл үгийг хуулах',
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: _cyrillicController.text,
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Кирилл үг хуулагдлаа'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _latinController,
                      focusNode: _latinFocusNode,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      onSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submit();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Латин галиг',
                        labelStyle: const TextStyle(fontSize: 12),
                        helperText: 'Энд монгол бичвэр (Юникод) буулгаж болно',
                        helperStyle: const TextStyle(
                          fontSize: 11,
                          color: DesktopTheme.textMuted,
                        ),
                        hintText: _latinFocusNode.hasFocus
                            ? null
                            : 'q=o, w=wa, v=u, o=oe, u=ue, E=ee',
                        hintStyle: const TextStyle(
                          fontSize: 11,
                          color: DesktopTheme.textMuted,
                        ),
                        border: const OutlineInputBorder(
                          borderRadius: DesktopTheme.roundedSmall,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: DesktopIconButton(
                            icon: Icons.content_paste,
                            size: 14,
                            tooltip: 'Буулгах',
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              final text = data?.text;
                              if (text != null && text.isNotEmpty) {
                                _latinController.text = text;
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _explanationController,
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Тайлбар (заавал биш)',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: DesktopTheme.roundedSmall,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DesktopIconButton(
                        icon: Icons.keyboard_outlined,
                        tooltip: _showKeyboard
                            ? 'Товчлуур нуух'
                            : 'Товчлуур харах',
                        color: _showKeyboard ? DesktopTheme.primary : null,
                        onPressed: () =>
                            setState(() => _showKeyboard = !_showKeyboard),
                      ),
                    ),
                    if (_showKeyboard) ...[
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: DesktopTheme.canvas,
                          borderRadius: DesktopTheme.roundedSmall,
                          border: Border.all(
                            color: DesktopTheme.border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildKeyboardCategory('Эгшиг (Vowels)', [
                              ('a', 'ᠠ a'),
                              ('e', 'ᠡ e'),
                              ('i', 'ᠢ i'),
                              ('q', 'ᠣ o'),
                              ('v', 'ᠤ u'),
                              ('o', 'ᠥ ö'),
                              ('u', 'ᠦ ü'),
                              ('E', 'ᠧ ee'),
                            ]),
                            const SizedBox(height: 6),
                            _buildKeyboardCategory(
                              'Үндсэн гийгүүлэгч (Consonants)',
                              [
                                ('n', 'ᠨ na'),
                                ('b', 'ᠪ ba'),
                                ('p', 'ᠫ pa'),
                                ('h', 'ᠬ qa'),
                                ('g', 'ᠭ ga'),
                                ('m', 'ᠮ ma'),
                                ('l', 'ᠯ la'),
                                ('s', 'ᠰ sa'),
                                ('x', 'ᡧ sha'),
                                ('t', 'ᠲ ta'),
                                ('d', 'ᠳ da'),
                                ('c', 'ᠴ cha'),
                                ('j', 'ᠵ ja'),
                                ('y', 'ᠶ ya'),
                                ('r', 'ᠷ ra'),
                                ('w', 'ᠸ wa'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildKeyboardCategory(
                              'Гадаад & Тусгай (Foreign & Special)',
                              [
                                ('f', 'ᠹ fa'),
                                ('k', 'ᠺ ka'),
                                ('K', 'ᠻ kha'),
                                ('C', 'ᠼ tsa'),
                                ('z', 'ᠽ za'),
                                ('H', 'ᠾ haa'),
                                ('R', 'ᠿ zra'),
                                ('L', 'ᡀ lha'),
                                ('Z', 'ᡁ zhi'),
                                ('Q', 'ᡂ chi'),
                                ('N', 'ᠩ ang'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildKeyboardCategory(
                              'Дагавар & Хувилбар (Control / Suffixes)',
                              [
                                ('-', 'MVS (-)'),
                                ('1', 'FVS1 (1)'),
                                ('2', 'FVS2 (2)'),
                                ('3', 'FVS3 (3)'),
                                ('4', 'FVS4 (4)'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          DesktopButton(
            onPressed: () => Navigator.pop(context),
            label: 'Цуцлах',
            variant: DesktopButtonVariant.secondary,
            isDense: true,
          ),
          const SizedBox(width: 8),
          DesktopButton(
            onPressed: _isSubmitting ? null : _submit,
            label: widget.submitButtonText,
            variant: DesktopButtonVariant.primary,
            isLoading: _isSubmitting,
            isDense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardCategory(
    String label,
    List<(String key, String display)> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: items.map((item) {
            return InkWell(
              onTap: () => _insertKey(item.$1),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: '${item.$1} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      TextSpan(
                        text: item.$2,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
