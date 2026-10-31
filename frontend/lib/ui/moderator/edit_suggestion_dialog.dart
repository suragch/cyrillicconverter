import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import '../../services/latin_ime.dart';
import '../desktop/components/desktop_button.dart';
import '../desktop/components/desktop_dialog.dart';
import '../desktop/desktop_theme.dart';

class EditSuggestionDialog extends StatefulWidget {
  final String initialCyrillic;
  final String initialMenksoft;
  final String? initialExplanation;
  final String serverUrl;
  final String? authToken;
  final Future<void> Function({
    required String cyrillic,
    required String menksoft,
    String? explanation,
    required bool andApprove,
  })
  onSave;

  const EditSuggestionDialog({
    super.key,
    required this.initialCyrillic,
    required this.initialMenksoft,
    this.initialExplanation,
    required this.serverUrl,
    this.authToken,
    required this.onSave,
  });

  @override
  State<EditSuggestionDialog> createState() => _EditSuggestionDialogState();
}

class _EditSuggestionDialogState extends State<EditSuggestionDialog> {
  late final TextEditingController _cyrillicController;
  late final TextEditingController _latinController;
  late final TextEditingController _explanationController;
  late final FocusNode _latinFocusNode;
  String _previewMenksoft = '';
  bool _showKeyboard = false;
  bool _isSaving = false;

  Timer? _debounce;
  bool _isCheckingCyrillic = false;
  Map<String, dynamic>? _cyrillicCheckResult;

  @override
  void initState() {
    super.initState();
    _cyrillicController = TextEditingController(text: widget.initialCyrillic);
    _latinController = TextEditingController(
      text: LatinIme.menksoftToLatin(widget.initialMenksoft),
    );
    _explanationController = TextEditingController(
      text: widget.initialExplanation,
    );
    _previewMenksoft = widget.initialMenksoft;
    _latinFocusNode = FocusNode();
    _latinFocusNode.addListener(_onLatinFocusChanged);

    _latinController.addListener(_onLatinChanged);
    _cyrillicController.addListener(_onCyrillicChanged);

    _checkCyrillicWord(widget.initialCyrillic);
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

  void _onCyrillicChanged() {
    final text = _cyrillicController.text.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _checkCyrillicWord(text);
      }
    });
  }

  Future<void> _checkCyrillicWord(String cyrillic) async {
    if (cyrillic.isEmpty) {
      setState(() {
        _cyrillicCheckResult = null;
        _isCheckingCyrillic = false;
      });
      return;
    }

    setState(() => _isCheckingCyrillic = true);

    try {
      final headers = {'Content-Type': 'application/json'};
      if (widget.authToken != null) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final res = await http.get(
        Uri.parse(
          '${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(cyrillic)}',
        ),
        headers: headers,
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _cyrillicCheckResult = data;
          _isCheckingCyrillic = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingCyrillic = false);
      }
    }
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
    _debounce?.cancel();
    _cyrillicController.dispose();
    _latinController.dispose();
    _explanationController.dispose();
    _latinFocusNode.removeListener(_onLatinFocusChanged);
    _latinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave({required bool andApprove}) async {
    if (_isSaving) {
      return;
    }
    final cyrillic = _cyrillicController.text.trim();
    if (cyrillic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Кирилл үг хоосон байна'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if homonym without note
    final exists = _cyrillicCheckResult?['exists'] == true;
    final note = _explanationController.text.trim();
    if (exists && note.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => DesktopDialogFrame(
          title: 'Ялгах тэмдэглэл шаардлагатай',
          maxWidth: 440,
          leadingIcon: const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: DesktopTheme.warning,
          ),
          content: Text(
            '"$cyrillic" кирилл үг толь бичигт аль хэдийн бүртгэгдсэн байна. '
            'Энэ нь олон утгатай үг (homonym) болох тул ялгах тайлбар/тэмдэглэл бичих шаардлагатай.\n\n'
            'Тэмдэглэлгүйгээр үргэлжлүүлэх үү?',
            style: DesktopTheme.body,
          ),
          actions: [
            DesktopButton(
              onPressed: () => Navigator.pop(ctx, false),
              label: 'Тэмдэглэл бичих',
              variant: DesktopButtonVariant.secondary,
              isDense: true,
            ),
            const SizedBox(width: 8),
            DesktopButton(
              onPressed: () => Navigator.pop(ctx, true),
              label: 'Тэмдэглэлгүй үргэлжлүүлэх',
              variant: DesktopButtonVariant.primary,
              isDense: true,
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        cyrillic: cyrillic,
        menksoft: _previewMenksoft,
        explanation: note.isEmpty ? null : note,
        andApprove: andApprove,
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exists = _cyrillicCheckResult?['exists'] == true;
    final definitions = (_cyrillicCheckResult?['definitions'] as List?) ?? [];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_isSaving) {
            _handleSave(andApprove: false);
          }
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_isSaving) {
            _handleSave(andApprove: false);
          }
        },
      },
      child: DesktopDialogFrame(
        title: 'Санал засах',
        maxWidth: 740,
        maxHeight: 780,
        leadingIcon: const Icon(
          Icons.edit,
          size: 18,
          color: DesktopTheme.primary,
        ),
        content: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical Mongolian preview in Large Text
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
                    // Cyrillic Input
                    TextField(
                      controller: _cyrillicController,
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) {
                        if (!_isSaving) {
                          _handleSave(andApprove: false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Кирилл бичлэг',
                        labelStyle: const TextStyle(fontSize: 12),
                        border: const OutlineInputBorder(
                          borderRadius: DesktopTheme.roundedSmall,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        suffixIcon: _isCheckingCyrillic
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cyrillic existence / homonym alert
                    if (exists)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: DesktopTheme.warningSurface,
                          borderRadius: DesktopTheme.roundedSmall,
                          border: Border.all(
                            color: DesktopTheme.warningBorder,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: DesktopTheme.warning,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Энэ кирилл үг толь бичигт аль хэдийн бүртгэгдсэн байна (Олон утгатай / Homonym).',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: DesktopTheme.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (definitions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Толь дахь хувилбарууд: ${definitions.length} бичлэг бүртгэлтэй. Ялгах тайлбар/тэмдэглэл заавал бичнэ үү.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.brown,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (_cyrillicController.text.trim().isNotEmpty &&
                        !_isCheckingCyrillic)
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: DesktopTheme.success,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Шинэ кирилл үг (Толь бичигт бүртгэлгүй)',
                            style: TextStyle(
                              fontSize: 12,
                              color: DesktopTheme.success,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    // Latin Input
                    TextField(
                      controller: _latinController,
                      focusNode: _latinFocusNode,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                      onSubmitted: (_) {
                        if (!_isSaving) {
                          _handleSave(andApprove: false);
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
                    // Note / Explanation Input
                    TextField(
                      controller: _explanationController,
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) {
                        if (!_isSaving) {
                          _handleSave(andApprove: false);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Тайлбар (заавал биш)',
                        labelStyle: TextStyle(fontSize: 12),
                        helperText:
                            'Олон янзаар бичигддэг үгсийг ялгахад ашиглагдана.',
                        helperStyle: TextStyle(fontSize: 11),
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
            onPressed: _isSaving ? null : () => _handleSave(andApprove: false),
            label: 'Шинэчлэх',
            variant: DesktopButtonVariant.secondary,
            isDense: true,
          ),
          const SizedBox(width: 8),
          DesktopButton(
            onPressed: _isSaving ? null : () => _handleSave(andApprove: true),
            label: 'Хадгалаад батлах',
            variant: DesktopButtonVariant.primary,
            isLoading: _isSaving,
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
