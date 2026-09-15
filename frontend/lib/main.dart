import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import 'package:pocketbase/pocketbase.dart';

import 'services/latin_ime.dart';
import 'token.dart';
import 'ui/converter_controller.dart';
import 'ui/dialogs/add_edit_word_dialog.dart';
import 'ui/moderator/moderator_page.dart';

enum ExportEncoding { unicode, menksoft }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Кирилл ➜ ᠮᠣᠩᠭᠣᠯ Хөрвүүлэгч',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Menksoft',
      ),
      home: const ConverterScreen(),
    );
  }
}

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final TextEditingController _inputTextController = TextEditingController();
  late final MongolConverterController _outputController;
  final GlobalKey _fieldKey = GlobalKey();

  final String _serverUrl = 'http://localhost:8080';
  final PocketBase _pb = PocketBase('https://cyrillic.suragch.dev');

  List<Token> _tokens = [];
  List<TokenSpanInfo> _tokenSpanInfos = [];
  final Map<int, int> _selectedOptionIndices = {}; // tokenIndex -> optionIndex
  final Map<String, String> _localOverrides = {}; // lowercase cyrillic -> menksoft code

  bool _isLoading = false;
  String? _errorMessage;
  ExportEncoding _copyEncoding = ExportEncoding.unicode;
  MouseCursor _currentCursor = SystemMouseCursors.text;
  Offset? _lastPointerPosition;

  @override
  void initState() {
    super.initState();
    _outputController = MongolConverterController(
      tokenSpansProvider: () => _tokenSpanInfos,
    );
  }

  @override
  void dispose() {
    _inputTextController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => _pb.authStore.isValid;

  Future<void> _convert() async {
    final text = _inputTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _tokens = [];
      _tokenSpanInfos = [];
      _selectedOptionIndices.clear();
    });

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/convert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tokenList = data['tokens'] ?? [];
        final parsed = tokenList.map((j) => Token.fromJson(j)).toList();

        // Apply any session local overrides
        for (var i = 0; i < parsed.length; i++) {
          final t = parsed[i];
          final norm = t.original.trim().toLowerCase();
          if (_localOverrides.containsKey(norm)) {
            parsed[i] = Token(
              type: 'word',
              original: t.original,
              options: [
                TokenOption(
                  menksoft: _localOverrides[norm]!,
                  isDefault: true,
                  explanation: 'Таны нэмсэн хувилбар',
                ),
              ],
            );
          }
        }

        setState(() {
          _tokens = parsed;
          _syncOutputText();
        });
      } else {
        setState(() {
          _errorMessage = 'Серверийн алдаа: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Сервертэй холбогдож чадсангүй: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _syncOutputText() {
    final buffer = StringBuffer();
    final newSpans = <TokenSpanInfo>[];
    int currentOffset = 0;

    for (var i = 0; i < _tokens.length; i++) {
      final token = _tokens[i];
      String text;
      if (token.type == 'space') {
        text = ' ';
      } else if (token.type == 'delimiter') {
        text = token.menksoft ?? LatinIme.convertPunctuationToMenksoft(token.original);
      } else if (token.type == 'word' && token.options.isNotEmpty) {
        final optIdx = _selectedOptionIndices[i] ?? 0;
        final chosen = token.options[optIdx.clamp(0, token.options.length - 1)];
        text = chosen.menksoft;
      } else {
        text = token.original;
      }

      final start = currentOffset;
      final end = currentOffset + text.length;
      newSpans.add(TokenSpanInfo(
        tokenIndex: i,
        start: start,
        end: end,
        token: token,
        text: text,
      ));
      buffer.write(text);
      currentOffset = end;
    }

    _tokenSpanInfos = newSpans;
    _outputController.text = buffer.toString();
  }

  TokenSpanInfo? _getTokenAtCharOffset(int charOffset) {
    for (final info in _tokenSpanInfos) {
      if (charOffset >= info.start && charOffset < info.end) {
        return info;
      }
    }
    return null;
  }

  MongolRenderEditable? _findMongolRenderEditable(RenderObject? root) {
    if (root == null) return null;
    if (root is MongolRenderEditable) return root;
    MongolRenderEditable? result;
    root.visitChildren((child) {
      result ??= _findMongolRenderEditable(child);
    });
    return result;
  }

  void _handleHover(Offset globalPosition) {
    final root = _fieldKey.currentContext?.findRenderObject();
    final editable = _findMongolRenderEditable(root);
    if (editable == null) return;

    final textPosition = editable.getPositionForPoint(globalPosition);
    final info = _getTokenAtCharOffset(textPosition.offset);

    final MouseCursor newCursor;
    if (info != null && (info.token.type == 'word' || info.token.type == 'unknown')) {
      newCursor = SystemMouseCursors.click;
    } else {
      newCursor = SystemMouseCursors.text;
    }

    if (_currentCursor != newCursor) {
      setState(() {
        _currentCursor = newCursor;
      });
    }
  }

  void _handleTextFieldTap() {
    final selection = _outputController.selection;
    // If the user made an active range selection by dragging, do not open popups
    if (!selection.isCollapsed || !selection.isValid) {
      return;
    }

    final charOffset = selection.baseOffset;
    final info = _getTokenAtCharOffset(charOffset);
    if (info == null) return;

    final token = info.token;
    final pos = _lastPointerPosition ?? Offset.zero;

    if (token.type == 'unknown') {
      _showFixDialog(token);
    } else if (token.type == 'word') {
      if (token.options.length > 1) {
        _showAmbiguityMenu(context, info.tokenIndex, token, pos);
      } else {
        _showWordActionMenu(context, info.tokenIndex, token, pos);
      }
    }
  }

  void _handleSecondaryTap(Offset globalPosition) {
    _lastPointerPosition = globalPosition;
    final root = _fieldKey.currentContext?.findRenderObject();
    final editable = _findMongolRenderEditable(root);
    if (editable == null) return;

    final textPosition = editable.getPositionForPoint(globalPosition);
    final info = _getTokenAtCharOffset(textPosition.offset);
    if (info == null) return;

    if (info.token.type == 'unknown') {
      _showFixDialog(info.token);
    } else if (info.token.type == 'word') {
      if (info.token.options.length > 1) {
        _showAmbiguityMenu(context, info.tokenIndex, info.token, globalPosition);
      } else {
        _showWordActionMenu(context, info.tokenIndex, info.token, globalPosition);
      }
    }
  }

  Future<void> _handleWordAddedOrSuggested({
    required String cyrillic,
    required String menksoft,
    String? explanation,
  }) async {
    final normalized = cyrillic.trim().toLowerCase();

    // 1. Immediately update local conversion display in place
    setState(() {
      _localOverrides[normalized] = menksoft;
      for (var i = 0; i < _tokens.length; i++) {
        if (_tokens[i].original.trim().toLowerCase() == normalized) {
          _tokens[i] = Token(
            type: 'word',
            original: _tokens[i].original,
            options: [
              TokenOption(
                menksoft: menksoft,
                isDefault: true,
                explanation: explanation ?? 'Таны оруулсан хувилбар',
              ),
            ],
          );
        }
      }
      _syncOutputText();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$cyrillic" үг шууд солигдож, модераторын дараалалд нэмэгдлээ.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 2. Asynchronously submit to remote server for moderator queue
    try {
      final headers = {'Content-Type': 'application/json'};
      if (_isLoggedIn) {
        headers['Authorization'] = 'Bearer ${_pb.authStore.token}';
      }

      await http.post(
        Uri.parse('$_serverUrl/contribute'),
        headers: headers,
        body: jsonEncode({
          'cyrillic': cyrillic,
          'menksoft': menksoft,
          'context': explanation ?? '',
        }),
      );
    } catch (e) {
      debugPrint('Background submission error: $e');
    }
  }

  void _showFixDialog(Token token) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditWordDialog(
        title: 'Үл мэдэгдэх үг: "${token.original}"',
        initialCyrillic: token.original,
        submitButtonText: 'Нэмэх & Илгээх',
        onSubmit: _handleWordAddedOrSuggested,
      ),
    );
  }

  void _showFlagErrorDialog(Token token) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditWordDialog(
        title: 'Алдаа мэдээлэх: "${token.original}"',
        initialCyrillic: token.original,
        initialExplanation: 'Залруулга / Алдаатай байна',
        submitButtonText: 'Залруулга илгээх',
        onSubmit: _handleWordAddedOrSuggested,
      ),
    );
  }

  void _showAmbiguityMenu(BuildContext context, int tokenIndex, Token token, Offset position) {
    final items = <PopupMenuEntry<int>>[];

    items.add(
      PopupMenuItem<int>(
        enabled: false,
        child: Text(
          'Кирилл: ${token.original}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
    items.add(const PopupMenuDivider());

    for (var idx = 0; idx < token.options.length; idx++) {
      final option = token.options[idx];
      final isSelected = (_selectedOptionIndices[tokenIndex] ?? 0) == idx;

      items.add(
        PopupMenuItem<int>(
          value: idx,
          child: Row(
            children: [
              if (isSelected)
                const Icon(Icons.check, size: 16, color: Colors.blue)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MongolText(
                    option.menksoft,
                    style: const TextStyle(fontSize: 22, fontFamily: 'Menksoft'),
                  ),
                  if (option.explanation != null && option.explanation!.isNotEmpty)
                    Text(
                      option.explanation!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem<int>(
        value: -1,
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 18, color: Colors.amber),
            SizedBox(width: 8),
            Text('Алдаа мэдээлэх / Өөр утга нэмэх'),
          ],
        ),
      ),
    );

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    ).then((selectedIndex) {
      if (selectedIndex == null) return;
      if (selectedIndex == -1) {
        _showFlagErrorDialog(token);
      } else {
        setState(() {
          _selectedOptionIndices[tokenIndex] = selectedIndex;
          _syncOutputText();
        });
      }
    });
  }

  void _showWordActionMenu(BuildContext context, int tokenIndex, Token token, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Кирилл: ${token.original}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'flag_error',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: Colors.amber),
              SizedBox(width: 8),
              Text('Алдаа мэдээлэх / Засах'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'copy_word',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Энэ үгийг хуулах'),
            ],
          ),
        ),
      ],
    ).then((action) {
      if (action == 'flag_error') {
        _showFlagErrorDialog(token);
      } else if (action == 'copy_word') {
        final optIdx = _selectedOptionIndices[tokenIndex] ?? 0;
        final chosen = token.options.isNotEmpty
            ? token.options[optIdx.clamp(0, token.options.length - 1)].menksoft
            : token.original;
        _copyToClipboard(customText: chosen);
      }
    });
  }

  void _copyToClipboard({String? customText}) {
    final sel = _outputController.selection;
    final fullText = _outputController.text;
    String rawText;

    if (customText != null) {
      rawText = customText;
    } else if (!sel.isCollapsed && sel.isValid) {
      rawText = sel.textInside(fullText);
    } else {
      rawText = fullText;
    }

    if (rawText.isEmpty) return;

    final textToCopy = _copyEncoding == ExportEncoding.unicode
        ? LatinIme.menksoftToUnicode(rawText)
        : rawText;

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_copyEncoding == ExportEncoding.unicode
            ? 'Юникод (Unicode) хэлбэрээр хууллаа'
            : 'Menksoft код хэлбэрээр хууллаа'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нэвтрэх (PocketBase)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Имэйл / Нэвтрэх нэр',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Нууц үг',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Цуцлах'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _pb.collection('users').authWithPassword(
                  emailController.text.trim(),
                  passwordController.text,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Амжилттай нэвтэрлээ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Нэвтрэх амжилтгүй: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Нэвтрэх'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кирилл ➜ ᠮᠣᠩᠭᠣᠯ'),
        actions: [
          // Encoding selector
          Row(
            children: [
              const Text('Хуулах:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              DropdownButton<ExportEncoding>(
                value: _copyEncoding,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: ExportEncoding.unicode,
                    child: Text('Unicode', style: TextStyle(fontSize: 13)),
                  ),
                  DropdownMenuItem(
                    value: ExportEncoding.menksoft,
                    child: Text('Menksoft', style: TextStyle(fontSize: 13)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _copyEncoding = val);
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          if (_isLoggedIn) ...[
            TextButton.icon(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Модератор'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => ModeratorPage(
                      serverUrl: _serverUrl,
                      authToken: _pb.authStore.token,
                    ),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () {
                _pb.authStore.clear();
                setState(() {});
              },
              child: const Text('Гарах'),
            ),
          ] else
            TextButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Нэвтрэх'),
              onPressed: _showLoginDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cyrillic Input Box
            Stack(
              children: [
                TextField(
                  controller: _inputTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Кирилл текст оруулна уу',
                    hintText: 'Жишээ: 2026 онд Монгол улсын хүү, төр, гол хоёр утгатай.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: null, fontSize: 16),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.paste, size: 20),
                        tooltip: 'Санах ойгоос буулгах',
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _inputTextController.text = data!.text!;
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: 'Цэвэрлэх',
                        onPressed: () {
                          _inputTextController.clear();
                          _outputController.clear();
                          setState(() {
                            _tokens = [];
                            _tokenSpanInfos = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions Row
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _convert,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate),
                  label: const Text('Хөрвүүлэх'),
                ),
                const SizedBox(width: 16),
                if (_tokens.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Хуулж авах'),
                  ),
                  const Spacer(),
                  Text(
                    'Цэнхэр: Олон утгатай  |  Улаан: Үл мэдэгдэх  |  Үг дээр дарж сонгох / засах',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            // Unified Output Area (Selectable + Clickable + Hover Cursor)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.3),
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: _tokens.isEmpty
                    ? Center(
                        child: Text(
                          _isLoading
                              ? 'Хөрвүүлж байна...'
                              : 'Хөрвүүлсэн текст энд босоо монгол бичгээр харагдана.',
                          style: TextStyle(color: Colors.grey.shade600, fontFamily: null),
                        ),
                      )
                    : _buildUnifiedOutput(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single unified vertical output:
  /// - Full mouse drag-and-drop text selection
  /// - Ctrl+C / Cmd+C copies selected text respecting Unicode / Menksoft setting
  /// - Click on ambiguous words opens homonym selection menu
  /// - Click on unknown words opens fix dialog
  /// - Click / Right-click on any word allows flagging error or suggesting correction
  /// - Real-time hover cursor changes to pointer (SystemMouseCursors.click) over interactive words
  Widget _buildUnifiedOutput() {
    return Actions(
      actions: {
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (intent) {
            _copyToClipboard();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: _currentCursor,
        onHover: (event) => _handleHover(event.position),
        onExit: (_) {
          if (_currentCursor != SystemMouseCursors.basic) {
            setState(() => _currentCursor = SystemMouseCursors.basic);
          }
        },
        child: Listener(
          onPointerDown: (event) => _lastPointerPosition = event.position,
          child: GestureDetector(
            onSecondaryTapUp: (details) => _handleSecondaryTap(details.globalPosition),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MongolTextField(
                key: _fieldKey,
                controller: _outputController,
                readOnly: true,
                maxLines: null,
                mouseCursor: _currentCursor,
                onTap: _handleTextFieldTap,
                style: const TextStyle(
                  fontSize: 26,
                  fontFamily: 'Menksoft',
                  color: Colors.black87,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
