import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import '../../services/latin_ime.dart';

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
  }) onSave;

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
    _explanationController = TextEditingController(text: widget.initialExplanation);
    _previewMenksoft = widget.initialMenksoft;

    _latinController.addListener(_onLatinChanged);
    _cyrillicController.addListener(_onCyrillicChanged);

    _checkCyrillicWord(widget.initialCyrillic);
  }

  void _onLatinChanged() {
    final text = _latinController.text;
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
        Uri.parse('${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(cyrillic)}'),
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
      if (mounted) setState(() => _isCheckingCyrillic = false);
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
    super.dispose();
  }

  Future<void> _handleSave({required bool andApprove}) async {
    final cyrillic = _cyrillicController.text.trim();
    if (cyrillic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Кирилл үг хоосон байна'), backgroundColor: Colors.red),
      );
      return;
    }

    // Check if homonym without note
    final exists = _cyrillicCheckResult?['exists'] == true;
    final note = _explanationController.text.trim();
    if (exists && note.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ялгах тэмдэглэл шаардлагатай'),
          content: Text(
            '"$cyrillic" кирилл үг толь бичигт аль хэдийн бүртгэгдсэн байна. '
            'Энэ нь олон утгатай үг (homonym) болох тул ялгах тайлбар/тэмдэглэл бичих шаардлагатай.\n\n'
            'Тэмдэглэлгүйгээр үргэлжлүүлэх үү?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Тэмдэглэл бичих'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Тэмдэглэлгүй үргэлжлүүлэх'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        cyrillic: cyrillic,
        menksoft: _previewMenksoft,
        explanation: note.isEmpty ? null : note,
        andApprove: andApprove,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exists = _cyrillicCheckResult?['exists'] == true;
    final definitions = (_cyrillicCheckResult?['definitions'] as List?) ?? [];

    return SelectionArea(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Санал засах',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _showKeyboard = !_showKeyboard),
                      icon: Icon(_showKeyboard ? Icons.keyboard_hide : Icons.keyboard),
                      label: Text(_showKeyboard ? 'Товчлуур нуух' : 'Товчлуур харах'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vertical Mongolian preview in Large Text
                    Container(
                      width: 80,
                      height: 190,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: MongolText(
                          _previewMenksoft.isEmpty ? ' ' : _previewMenksoft,
                          style: const TextStyle(
                            fontSize: 32,
                            fontFamily: 'Menksoft',
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Inputs
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cyrillic Input
                          TextField(
                            controller: _cyrillicController,
                            decoration: InputDecoration(
                              labelText: 'Кирилл бичлэг',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              suffixIcon: _isCheckingCyrillic
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Cyrillic existence / homonym alert
                          if (exists)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade900),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Энэ кирилл үг толь бичигт аль хэдийн бүртгэгдсэн байна (Олон утгатай / Homonym).',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
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
                                        style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else if (_cyrillicController.text.trim().isNotEmpty && !_isCheckingCyrillic)
                            Row(
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Шинэ кирилл үг (Толь бичигт бүртгэлгүй)',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          // Latin Input
                          TextField(
                            controller: _latinController,
                            decoration: InputDecoration(
                              labelText: 'Латин галиг (жишээ: monggol, on, huu)',
                              hintText: 'q=o, w=wa, v=u, o=oe, u=ue, E=ee',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              suffixIcon: _latinController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.backspace_outlined, size: 18),
                                      onPressed: () {
                                        final t = _latinController.text;
                                        if (t.isNotEmpty) {
                                          _latinController.text = t.substring(0, t.length - 1);
                                        }
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Note / Explanation Input
                          TextField(
                            controller: _explanationController,
                            decoration: const InputDecoration(
                              labelText: 'Тэмдэглэл / утга (зөвхөн олон утгатай үгсэд)',
                              hintText: 'Жишээ: он жил, төр засаг',
                              helperText: 'Олон утгатай (homonym) үгсийг ялгахад ашиглагдана.',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Collapsible Virtual Keyboard
                if (_showKeyboard)
                  Flexible(
                    child: SelectionContainer.disabled(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKeyboardCategory('Эгшиг (Vowels)', [
                                ('a', 'ᠠ a'),
                                ('e', 'ᠡ e'),
                                ('i', 'ᠢ i'),
                                ('q', 'ᠣ o'),
                                ('u', 'ᠤ u'),
                                ('o', 'ᠥ ö'),
                                ('v', 'ᠦ ü'),
                                ('E', 'ᠧ ee'),
                              ]),
                              const SizedBox(height: 6),
                              _buildKeyboardCategory('Үндсэн гийгүүлэгч (Consonants)', [
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
                              ]),
                              const SizedBox(height: 6),
                              _buildKeyboardCategory('Гадаад & Тусгай (Foreign & Special)', [
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
                              ]),
                              const SizedBox(height: 6),
                              _buildKeyboardCategory('Дагавар & Хувилбар (Control / Suffixes)', [
                                ('-', 'MVS (-)'),
                                ('1', 'FVS1 (1)'),
                                ('2', 'FVS2 (2)'),
                                ('3', 'FVS3 (3)'),
                                ('4', 'FVS4 (4)'),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Цуцлах'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => _handleSave(andApprove: false),
                      child: const Text('Шинэчлэх'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSaving ? null : () => _handleSave(andApprove: true),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Хадгалаад батлах'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardCategory(String label, List<(String key, String display)> items) {
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
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      TextSpan(
                        text: item.$2,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
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
