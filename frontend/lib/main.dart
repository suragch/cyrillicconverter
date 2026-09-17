import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/latin_ime.dart';
import 'token.dart';
import 'ui/converter_controller.dart';
import 'ui/desktop/components/desktop_button.dart';
import 'ui/desktop/components/desktop_dialog.dart';
import 'ui/desktop/components/desktop_header.dart';
import 'ui/desktop/components/desktop_status_bar.dart';
import 'ui/desktop/desktop_theme.dart';
import 'ui/dialogs/add_edit_word_dialog.dart';
import 'ui/dictionary/dictionary_browse_view.dart';
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
      theme: DesktopTheme.themeData,
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

  static const String _authTokenStorageKey = 'cyrillic_converter_auth_token';
  final String _serverUrl = 'http://localhost:8080';
  String? _authToken;
  Map<String, dynamic>? _currentUser;
  bool _isRestoringSession = false;

  // Active navigation tab
  DesktopNavTab _activeTab = DesktopNavTab.converter;
  int _moderatorQueueCount = 0;

  // Font zoom level (clamped 18..48)
  double _fontSize = 26.0;

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
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_authTokenStorageKey);
      if (savedToken == null || savedToken.isEmpty) {
        return;
      }

      if (mounted) {
        setState(() {
          _isRestoringSession = true;
        });
      }

      // Validate saved token with server
      final response = await http.get(
        Uri.parse('$_serverUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $savedToken',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = (data['user'] as Map<String, dynamic>?) ?? {
          'id': data['id'],
          'email': data['email'],
          'role': data['role'],
        };
        final newToken = data['token'] as String? ?? savedToken;
        if (newToken != savedToken) {
          await prefs.setString(_authTokenStorageKey, newToken);
        }

        if (mounted) {
          setState(() {
            _authToken = newToken;
            _currentUser = user;
          });
        }
        _fetchModeratorCount();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await prefs.remove(_authTokenStorageKey);
        if (mounted) {
          setState(() {
            _authToken = null;
            _currentUser = null;
          });
        }
      }
    } catch (_) {
      // Offline / server unreachable
    } finally {
      if (mounted) {
        setState(() {
          _isRestoringSession = false;
        });
      }
    }
  }

  Future<void> _fetchModeratorCount() async {
    if (!_isLoggedIn) return;
    try {
      final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $_authToken'};
      final res = await http.get(
        Uri.parse('$_serverUrl/admin/suggestions?limit=1'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final total = data['total'] as int? ?? (data['suggestions'] as List?)?.length ?? 0;
        if (mounted) {
          setState(() => _moderatorQueueCount = total);
        }
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    final email = _currentUser?['email'] as String? ?? 'Хэрэглэгч';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenStorageKey);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _authToken = null;
        _currentUser = null;
        _moderatorQueueCount = 0;
        if (_activeTab == DesktopNavTab.moderator) {
          _activeTab = DesktopNavTab.converter;
        }
      });
      _showToast('$email системээс гарлаа');
    }
  }

  @override
  void dispose() {
    _inputTextController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  bool get _isLoggedIn => _authToken != null && _authToken!.isNotEmpty;

  void _zoomIn() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(18.0, 48.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(18.0, 48.0);
    });
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError ? DesktopTheme.danger : DesktopTheme.textPrimary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 36, right: 16, left: 16),
      ),
    );
  }

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
      _outputController.setHoveredTokenIndex(info.tokenIndex);
    } else {
      newCursor = SystemMouseCursors.text;
      _outputController.setHoveredTokenIndex(null);
    }

    if (_currentCursor != newCursor) {
      setState(() {
        _currentCursor = newCursor;
      });
    }
  }

  void _handleTextFieldTap() {
    final selection = _outputController.selection;
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

    _showToast('"$cyrillic" үг шууд солигдож, модераторын дараалалд нэмэгдлээ.');

    // 2. Asynchronously submit to remote server for moderator queue
    try {
      final headers = {'Content-Type': 'application/json'};
      if (_isLoggedIn) {
        headers['Authorization'] = 'Bearer $_authToken';
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
      _fetchModeratorCount();
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesktopTheme.textPrimary),
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
                const Icon(Icons.check, size: 16, color: DesktopTheme.primary)
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
                      style: const TextStyle(fontSize: 11, color: DesktopTheme.textSecondary),
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
            Icon(Icons.flag_outlined, size: 16, color: DesktopTheme.warning),
            SizedBox(width: 8),
            Text('Алдаа мэдээлэх / Өөр утга нэмэх', style: TextStyle(fontSize: 13)),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesktopTheme.textPrimary),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'flag_error',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: DesktopTheme.warning),
              SizedBox(width: 8),
              Text('Алдаа мэдээлэх / Засах', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'copy_word',
          child: Row(
            children: [
              Icon(Icons.copy, size: 16, color: DesktopTheme.textSecondary),
              SizedBox(width: 8),
              Text('Энэ үгийг хуулах', style: TextStyle(fontSize: 13)),
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
    _showToast(
      _copyEncoding == ExportEncoding.unicode
          ? 'Юникод (Unicode) хэлбэрээр хууллаа'
          : 'Menksoft код хэлбэрээр хууллаа',
    );
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoggingIn = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> doLogin() async {
            setDialogState(() => isLoggingIn = true);
            try {
              final response = await http.post(
                Uri.parse('$_serverUrl/auth/login'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                }),
              );

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body) as Map<String, dynamic>;
                final token = data['token'] as String;
                final user = data['user'] as Map<String, dynamic>?;

                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_authTokenStorageKey, token);
                } catch (_) {}

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  setState(() {
                    _authToken = token;
                    _currentUser = user;
                  });
                  _showToast('Амжилттай нэвтэрлээ');
                  _fetchModeratorCount();
                }
              } else {
                String message = 'Нэвтрэх амжилтгүй боллоо';
                try {
                  final err = jsonDecode(response.body);
                  if (err['error'] != null) message = err['error'].toString();
                } catch (_) {}
                _showToast(message, isError: true);
              }
            } catch (e) {
              _showToast('Нэвтрэх амжилтгүй: $e', isError: true);
            } finally {
              if (dialogCtx.mounted) {
                setDialogState(() => isLoggingIn = false);
              }
            }
          }

          return DesktopDialogFrame(
            title: 'Системд нэвтрэх',
            maxWidth: 400,
            leadingIcon: const Icon(Icons.lock_outline, size: 18, color: DesktopTheme.primary),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Шүүгчийн эрхээр нэвтэрч үгсийн сангийн саналуудыг хянах, дутуу үг нэмэх боломжтой.',
                  style: DesktopTheme.bodySecondary,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Имэйл / Нэвтрэх нэр',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: DesktopTheme.roundedSmall),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Нууц үг',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: DesktopTheme.roundedSmall),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) {
                    if (!isLoggingIn) doLogin();
                  },
                ),
              ],
            ),
            actions: [
              DesktopButton(
                onPressed: () => Navigator.pop(ctx),
                label: 'Цуцлах',
                variant: DesktopButtonVariant.secondary,
                isDense: true,
              ),
              const SizedBox(width: 8),
              DesktopButton(
                onPressed: isLoggingIn ? null : doLogin,
                label: 'Нэвтрэх',
                variant: DesktopButtonVariant.primary,
                isLoading: isLoggingIn,
                isDense: true,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShortcutsHelp() {
    showDialog(
      context: context,
      builder: (ctx) => DesktopDialogFrame(
        title: 'Товчлуурын хослолууд (Keyboard Shortcuts)',
        maxWidth: 540,
        leadingIcon: const Icon(Icons.keyboard_outlined, size: 18, color: DesktopTheme.primary),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Хөрвүүлэгч (Converter Workspace)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesktopTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            _buildShortcutRow('⌘ / Ctrl + Enter', 'Эх бичвэрийг монгол бичиг рүү хөрвүүлэх'),
            _buildShortcutRow('⌘ / Ctrl + C', 'Сонгосон / бүхэл монгол бичвэрийг хуулах'),
            _buildShortcutRow('A+ / A-', 'Босоо үсгийн хэмжээг томосгох / жижигсгэх'),
            const SizedBox(height: 16),
            const Text(
              'Шүүгч / Модератор (Moderator Workspace)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesktopTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            _buildShortcutRow('1', 'Санал эсвэл дутуу үгийг зөвшөөрөх / батлах'),
            _buildShortcutRow('2', 'Кирилл алдаатай гэж татгалзах'),
            _buildShortcutRow('3', 'Кирилл үг биш гэж татгалзах'),
            _buildShortcutRow('E', 'Сонгосон үгийг засах цонх нээх'),
            _buildShortcutRow('Space эсвэл →', 'Дараах үг рүү алгасах'),
            _buildShortcutRow('←', 'Өмнөх үг рүү буцах'),
          ],
        ),
        actions: [
          DesktopButton(
            onPressed: () => Navigator.pop(ctx),
            label: 'Хаах',
            variant: DesktopButtonVariant.secondary,
            isDense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: DesktopTheme.secondarySurface,
              borderRadius: DesktopTheme.roundedSmall,
              border: Border.all(color: DesktopTheme.borderMedium, width: 1),
            ),
            child: Text(
              keys,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 13, color: DesktopTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shortcuts handler (Cmd+Enter to convert)
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _convert,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _convert,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              // Top Desktop Application Header
              DesktopHeader(
                activeTab: _activeTab,
                onTabChanged: (tab) {
                  if (tab == DesktopNavTab.moderator && !_isLoggedIn) {
                    _showLoginDialog();
                    return;
                  }
                  setState(() => _activeTab = tab);
                },
                moderatorBadgeCount: _moderatorQueueCount,
                fontSize: _fontSize,
                onZoomIn: _zoomIn,
                onZoomOut: _zoomOut,
                copyEncoding: _copyEncoding == ExportEncoding.unicode
                    ? HeaderExportEncoding.unicode
                    : HeaderExportEncoding.menksoft,
                onEncodingChanged: (enc) {
                  setState(() {
                    _copyEncoding = enc == HeaderExportEncoding.unicode
                        ? ExportEncoding.unicode
                        : ExportEncoding.menksoft;
                  });
                },
                isRestoringSession: _isRestoringSession,
                isLoggedIn: _isLoggedIn,
                currentUser: _currentUser,
                onLoginPressed: _showLoginDialog,
                onLogoutPressed: _logout,
                onHelpPressed: _showShortcutsHelp,
              ),

              // Main Workspace View
              Expanded(
                child: _buildMainView(),
              ),

              // Bottom Desktop Status Bar (28px)
              DesktopStatusBar(
                isLoading: _isLoading,
                wordCount: _tokens.where((t) => t.type == 'word' || t.type == 'unknown').length,
                charCount: _inputTextController.text.length,
                homonymCount: _tokens.where((t) => t.type == 'word' && t.options.length > 1).length,
                unknownCount: _tokens.where((t) => t.type == 'unknown').length,
                fontSize: _fontSize,
                onZoomIn: _zoomIn,
                onZoomOut: _zoomOut,
                encodingLabel: _copyEncoding == ExportEncoding.unicode ? 'Юникод (UTF-8)' : 'Menksoft Код',
                serverStatus: 'Сервер: 8080 (Хэвийн)',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    switch (_activeTab) {
      case DesktopNavTab.converter:
        return _buildConverterWorkspace();

      case DesktopNavTab.moderator:
        return ModeratorPage(
          serverUrl: _serverUrl,
          authToken: _authToken,
          moderatorId: _currentUser?['id'] as String? ?? _currentUser?['email'] as String?,
          onCountChanged: (count) {
            if (mounted) setState(() => _moderatorQueueCount = count);
          },
        );

      case DesktopNavTab.dictionary:
        return DictionaryBrowseView(
          serverUrl: _serverUrl,
          authToken: _authToken,
          moderatorId: _currentUser?['id'] as String? ?? _currentUser?['email'] as String?,
        );
    }
  }

  /// Side-by-side split workspace for wide desktop screens, with responsive vertical fallback
  Widget _buildConverterWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        return Container(
          color: DesktopTheme.canvas,
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane: Cyrillic Source Editor
                    Expanded(
                      flex: 1,
                      child: _buildCyrillicSourcePane(),
                    ),
                    const SizedBox(width: 16),
                    // Right Pane: Traditional Mongolian Output
                    Expanded(
                      flex: 1,
                      child: _buildMongolianOutputPane(),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildCyrillicSourcePane(),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 6,
                      child: _buildMongolianOutputPane(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// Left Pane: Cyrillic Input Source Panel
  Widget _buildCyrillicSourcePane() {
    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.panelBackground,
        borderRadius: DesktopTheme.roundedMedium,
        border: Border.all(color: DesktopTheme.border, width: 1),
        boxShadow: DesktopTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header Bar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: DesktopTheme.panelHeaderBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(DesktopTheme.radiusMedium),
                topRight: Radius.circular(DesktopTheme.radiusMedium),
              ),
              border: Border(
                bottom: BorderSide(color: DesktopTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 16, color: DesktopTheme.textSecondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Эх бичвэр (Кирилл)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DesktopIconButton(
                  icon: Icons.paste_outlined,
                  tooltip: 'Санах ойгоос буулгах (Paste)',
                  size: 15,
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      _inputTextController.text = data!.text!;
                      setState(() {});
                    }
                  },
                ),
                DesktopIconButton(
                  icon: Icons.clear,
                  tooltip: 'Цэвэрлэх (Clear)',
                  size: 15,
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

          // Multi-line Text Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _inputTextController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: null,
                  color: DesktopTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Кирилл бичвэрээ энд оруулна уу...\nЖишээ: 2026 онд Монгол улсын хүү, төр, гол хоёр утгатай үгс гарна.',
                  hintStyle: TextStyle(fontSize: 13, color: DesktopTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: DesktopTheme.dangerSurface,
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: DesktopTheme.danger),
              ),
            ),

          // Panel Footer Action Bar
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: DesktopTheme.panelHeaderBackground,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(DesktopTheme.radiusMedium),
                bottomRight: Radius.circular(DesktopTheme.radiusMedium),
              ),
              border: Border(
                top: BorderSide(color: DesktopTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                DesktopButton(
                  onPressed: _isLoading ? null : _convert,
                  label: 'Хөрвүүлэх',
                  shortcutHint: '⌘↵',
                  icon: const Icon(Icons.translate, size: 14),
                  variant: DesktopButtonVariant.primary,
                  isLoading: _isLoading,
                ),
                const Spacer(),
                Text(
                  'Тэмдэгт: ${_inputTextController.text.length}',
                  style: DesktopTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Right Pane: Traditional Mongolian Output Panel
  Widget _buildMongolianOutputPane() {
    return Container(
      decoration: BoxDecoration(
        color: DesktopTheme.panelBackground,
        borderRadius: DesktopTheme.roundedMedium,
        border: Border.all(color: DesktopTheme.border, width: 1),
        boxShadow: DesktopTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header Bar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: DesktopTheme.panelHeaderBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(DesktopTheme.radiusMedium),
                topRight: Radius.circular(DesktopTheme.radiusMedium),
              ),
              border: Border(
                bottom: BorderSide(color: DesktopTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.article_outlined, size: 16, color: DesktopTheme.textSecondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Монгол бичиг (Босоо)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DesktopTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DesktopButton(
                  onPressed: _tokens.isNotEmpty ? () => _copyToClipboard() : null,
                  label: 'Хуулах',
                  shortcutHint: '⌘C',
                  icon: const Icon(Icons.copy, size: 13),
                  variant: DesktopButtonVariant.secondary,
                  isDense: true,
                ),
              ],
            ),
          ),

          // Traditional Mongolian Canvas
          Expanded(
            child: _tokens.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading) ...[
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Хөрвүүлж байна...',
                            style: TextStyle(fontSize: 13, color: DesktopTheme.textSecondary),
                          ),
                        ] else ...[
                          Icon(Icons.translate, size: 40, color: DesktopTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          const Text(
                            'Хөрвүүлсэн текст энд босоо монгол бичгээр гарна.',
                            style: TextStyle(fontSize: 13, color: DesktopTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Зүүн талын талбарт кирилл бичвэрээ оруулаад "Хөрвүүлэх" (⌘+Enter) дарна уу.',
                            style: DesktopTheme.caption,
                          ),
                        ],
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(16),
                    child: _buildUnifiedOutput(),
                  ),
          ),

          // Panel Footer Status & Legend
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: DesktopTheme.panelHeaderBackground,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(DesktopTheme.radiusMedium),
                bottomRight: Radius.circular(DesktopTheme.radiusMedium),
              ),
              border: Border(
                top: BorderSide(color: DesktopTheme.border, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLegendDot(color: DesktopTheme.primary, label: 'Олон утгатай'),
                  const SizedBox(width: 14),
                  _buildLegendDot(color: DesktopTheme.danger, label: 'Тольд үгүй'),
                  const SizedBox(width: 14),
                  const Text(
                    '• Үг дээр товшиж утга сонгох / засах',
                    style: DesktopTheme.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: DesktopTheme.textSecondary)),
      ],
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
    return SelectionContainer.disabled(
      child: Actions(
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
            _outputController.setHoveredTokenIndex(null);
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
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontFamily: 'Menksoft',
                    color: DesktopTheme.textPrimary,
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
      ),
    );
  }
}
