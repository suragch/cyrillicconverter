import 'package:flutter/material.dart';
import 'package:mongol/mongol.dart';
import '../../services/latin_ime.dart';

class AddEditWordDialog extends StatefulWidget {
  final String? initialCyrillic;
  final String? initialLatin;
  final String? initialExplanation;
  final Future<void> Function({
    required String cyrillic,
    required String menksoft,
    String? explanation,
  }) onSubmit;
  final String title;
  final String submitButtonText;

  const AddEditWordDialog({
    super.key,
    this.initialCyrillic,
    this.initialLatin,
    this.initialExplanation,
    required this.onSubmit,
    this.title = 'Үг нэмэх / санал болгох',
    this.submitButtonText = 'Илгээх',
  });

  @override
  State<AddEditWordDialog> createState() => _AddEditWordDialogState();
}

class _AddEditWordDialogState extends State<AddEditWordDialog> {
  late final TextEditingController _cyrillicController;
  late final TextEditingController _latinController;
  late final TextEditingController _explanationController;
  String _previewMenksoft = '';
  bool _isSubmitting = false;
  bool _showKeyboard = true;

  @override
  void initState() {
    super.initState();
    _cyrillicController = TextEditingController(text: widget.initialCyrillic);
    _latinController = TextEditingController(text: widget.initialLatin);
    _explanationController = TextEditingController(text: widget.initialExplanation);

    _latinController.addListener(_onLatinChanged);
    _onLatinChanged();
  }

  void _onLatinChanged() {
    final text = _latinController.text;
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
    super.dispose();
  }

  Future<void> _submit() async {
    final cyrillic = _cyrillicController.text.trim();
    if (cyrillic.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        cyrillic: cyrillic,
        menksoft: _previewMenksoft,
        explanation: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCyrillicFixed = widget.initialCyrillic != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
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
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
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
                  // Vertical Mongolian preview
                  Container(
                    width: 70,
                    height: 160,
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
                          fontSize: 28,
                          fontFamily: 'Menksoft',
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
                        if (isCyrillicFixed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              'Кирилл: ${widget.initialCyrillic}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          TextField(
                            controller: _cyrillicController,
                            decoration: const InputDecoration(
                              labelText: 'Кирилл үг',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _latinController,
                          autofocus: true,
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
                        TextField(
                          controller: _explanationController,
                          decoration: const InputDecoration(
                            labelText: 'Тайлбар / утга (жишээ: он жил, төр засаг)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Collapsible Virtual Keyboard & Transliteration Table
              if (_showKeyboard)
                Flexible(
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
                          _buildKeyboardCategory(
                            'Эгшиг (Vowels)',
                            [
                              ('a', 'ᠠ a'),
                              ('e', 'ᠡ e'),
                              ('i', 'ᠢ i'),
                              ('q', 'ᠣ o'),
                              ('u', 'ᠤ u'),
                              ('o', 'ᠥ ö'),
                              ('v', 'ᠦ ü'),
                              ('E', 'ᠧ ee'),
                            ],
                          ),
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
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.submitButtonText),
                  ),
                ],
              ),
            ],
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
