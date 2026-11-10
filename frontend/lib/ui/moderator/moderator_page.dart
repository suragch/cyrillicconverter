import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';

import '../../services/file_downloader.dart';
import '../../services/latin_ime.dart';
import '../desktop/components/desktop_button.dart';
import '../desktop/components/desktop_dialog.dart';
import '../desktop/desktop_theme.dart';
import '../dialogs/add_edit_word_dialog.dart';
import 'edit_suggestion_dialog.dart';

class ModeratorPage extends StatefulWidget {
  final String serverUrl;
  final String? authToken;
  final bool isAdmin;
  final String? moderatorId;
  final ValueChanged<int>? onCountChanged;

  const ModeratorPage({
    super.key,
    required this.serverUrl,
    this.authToken,
    this.isAdmin = false,
    this.moderatorId,
    this.onCountChanged,
  });

  @override
  State<ModeratorPage> createState() => _ModeratorPageState();
}

class _ModeratorPageState extends State<ModeratorPage> {
  int _activeQueueTab = 0; // 0: Suggestions, 1: Missing words
  List<dynamic> _missingWords = [];
  List<dynamic> _suggestions = [];
  int _totalSuggestions = 0;
  String? _selectedTargetMenksoft;

  // Suggestions Queue State
  int _currentIndex = 0;
  bool _isCheckingCurrentWord = false;
  Map<String, dynamic>? _currentWordCheckResult;

  // Missing Words Queue State
  int _missingIndex = 0;
  bool _isCheckingMissingWord = false;
  Map<String, dynamic>? _missingWordCheckResult;
  int _minFrequency = 2; // Default to frequency >= 2

  bool _isLoading = false;
  bool _isDownloadingDb = false;
  String? _error;

  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (widget.authToken != null) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return headers;
  }

  Future<void> _changeMinFrequency(int newMinFreq) async {
    if (_minFrequency == newMinFreq) {
      return;
    }
    setState(() {
      _minFrequency = newMinFreq;
      _missingIndex = 0;
    });
    await _loadData();
  }

  Future<void> _downloadDatabase() async {
    if (_isDownloadingDb) {
      return;
    }
    setState(() {
      _isDownloadingDb = true;
    });
    try {
      final res = await http
          .get(
            Uri.parse('${widget.serverUrl}/admin/db/download'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 60));
      if (!mounted) {
        return;
      }
      if (res.statusCode == 200) {
        final dateStr = DateTime.now().toIso8601String().split('T').first;
        final filename = 'cyrillic_dictionary_full_$dateStr.db';
        downloadFileFromBytes(
          res.bodyBytes,
          filename,
          'application/vnd.sqlite3',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename амжилттай татагдлаа.'),
            backgroundColor: DesktopTheme.textPrimary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Бааз татахад алдаа гарлаа (${res.statusCode})'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Холболтын алдаа: $e'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingDb = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final missingRes = await http
          .get(
            Uri.parse(
              '${widget.serverUrl}/admin/missing?limit=100&min_frequency=$_minFrequency',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      final suggRes = await http
          .get(
            Uri.parse('${widget.serverUrl}/admin/suggestions?limit=100'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      if (missingRes.statusCode == 200 && suggRes.statusCode == 200) {
        final missingData = jsonDecode(missingRes.body);
        final suggData = jsonDecode(suggRes.body);

        final newSuggestions = (suggData['suggestions'] as List?) ?? [];
        final newMissing = (missingData['missing'] as List?) ?? [];
        final totalCount = (suggData['total'] as int?) ?? newSuggestions.length;

        setState(() {
          _missingWords = newMissing;
          _suggestions = newSuggestions;
          _totalSuggestions = totalCount;

          if (_currentIndex >= _suggestions.length) {
            _currentIndex = _suggestions.isEmpty ? 0 : _suggestions.length - 1;
          }
          if (_missingIndex >= _missingWords.length) {
            _missingIndex = _missingWords.isEmpty
                ? 0
                : _missingWords.length - 1;
          }
        });

        widget.onCountChanged?.call(_totalSuggestions);

        _checkWordForCurrent();
        _checkWordForMissing();
      } else {
        setState(() {
          _error =
              'Өгөгдөл татахад алдаа: ${missingRes.statusCode} / ${suggRes.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Холболтын алдаа: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Suggestions Queue Helpers ---

  Future<void> _checkWordForCurrent() async {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) {
      setState(() {
        _currentWordCheckResult = null;
        _isCheckingCurrentWord = false;
        _selectedTargetMenksoft = null;
      });
      return;
    }

    final current = _suggestions[_currentIndex];
    final cyrillic = (current['cyrillic'] as String?)?.trim() ?? '';
    if (cyrillic.isEmpty) {
      setState(() {
        _currentWordCheckResult = null;
        _isCheckingCurrentWord = false;
        _selectedTargetMenksoft = null;
      });
      return;
    }

    setState(() {
      _isCheckingCurrentWord = true;
      _currentWordCheckResult = null;
      _selectedTargetMenksoft = null;
    });

    try {
      final res = await http
          .get(
            Uri.parse(
              '${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(cyrillic)}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final defs = (data['definitions'] as List?) ?? [];
        final curr = (_currentIndex < _suggestions.length)
            ? _suggestions[_currentIndex]
            : null;
        final target = (curr?['target_menksoft'] as String?)?.trim();

        String? initTarget;
        if (target != null && target.isNotEmpty) {
          initTarget = target;
        } else if (defs.length == 1) {
          initTarget = (defs.first['menksoft'] as String?)?.trim();
        }

        setState(() {
          _currentWordCheckResult = data;
          _selectedTargetMenksoft = initTarget;
        });
      }
    } catch (_) {
      // Ignore network errors or 404
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingCurrentWord = false;
        });
      }
    }
  }

  void _goToIndex(int index) {
    if (index >= 0 && index < _suggestions.length) {
      setState(() => _currentIndex = index);
      _checkWordForCurrent();
    }
  }

  void _skipCurrent() {
    if (_suggestions.length > 1) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _suggestions.length;
      });
      _checkWordForCurrent();
    }
  }

  Future<void> _handleApproveCurrent({
    String action = 'add_primary',
    String? targetMenksoft,
  }) async {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) {
      return;
    }
    final current = _suggestions[_currentIndex];
    final id = current['id'] as int;
    final cyrillic = current['cyrillic'] as String;
    final menksoft = current['menksoft_code'] as String;
    String? note = (current['explanation'] as String?)?.trim();

    final exists = _currentWordCheckResult?['exists'] == true;
    final definitions =
        (_currentWordCheckResult?['definitions'] as List?) ?? [];

    final finalTargetMenksoft = targetMenksoft ?? _selectedTargetMenksoft;

    // Check if duplicate of an existing definition (only if adding a new definition)
    if (action != 'replace' && action != 'resolve_only') {
      final alreadyIdentical = definitions.any(
        (d) => (d['menksoft'] as String?)?.trim() == menksoft.trim(),
      );
      if (alreadyIdentical) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => DesktopDialogFrame(
            title: 'Аль хэдийн бүртгэгдсэн байна',
            maxWidth: 420,
            leadingIcon: const Icon(
              Icons.info_outline,
              size: 18,
              color: DesktopTheme.warning,
            ),
            content: Text(
              '"$cyrillic" үгэнд энэхүү босоо бичлэг толь бичигт аль хэдийн байна.\n'
              'Та давхардуулж нэмэхдээ итгэлтэй байна уу?',
              style: DesktopTheme.body,
            ),
            actions: [
              DesktopButton(
                onPressed: () => Navigator.pop(ctx, false),
                label: 'Цуцлах',
                variant: DesktopButtonVariant.secondary,
                isDense: true,
              ),
              const SizedBox(width: 8),
              DesktopButton(
                onPressed: () => Navigator.pop(ctx, true),
                label: 'Батлах',
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

      if (!mounted) {
        return;
      }
      if (exists && (note == null || note.isEmpty)) {
        final inputController = TextEditingController();
        final addedNote = await showDialog<String>(
          context: context,
          builder: (ctx) => DesktopDialogFrame(
            title: 'Олон утгатай үг (Homonym)',
            maxWidth: 440,
            leadingIcon: const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: DesktopTheme.warning,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$cyrillic" кирилл үг толь бичигт өмнө нь өөр бичлэгтэй бүртгэгдсэн байна.\n'
                  'Энэ хоёрыг хэрэглэгч ялгахын тулд ялгах тэмдэглэл/тайлбар оруулна уу:',
                  style: DesktopTheme.body,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: inputController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Тэмдэглэл (жишээ: он жил, төр засаг)',
                    border: OutlineInputBorder(
                      borderRadius: DesktopTheme.roundedSmall,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
                ),
              ],
            ),
            actions: [
              DesktopButton(
                onPressed: () => Navigator.pop(ctx, null),
                label: 'Цуцлах',
                variant: DesktopButtonVariant.secondary,
                isDense: true,
              ),
              const SizedBox(width: 8),
              DesktopButton(
                onPressed: () =>
                    Navigator.pop(ctx, inputController.text.trim()),
                label: 'Батлах',
                variant: DesktopButtonVariant.primary,
                isDense: true,
              ),
            ],
          ),
        );

        if (addedNote == null) {
          return;
        }
        note = addedNote.isEmpty ? null : addedNote;
      }
    }

    await _executeApprove(
      id: id,
      cyrillic: cyrillic,
      menksoft: menksoft,
      explanation: note,
      action: action,
      targetMenksoft: finalTargetMenksoft,
    );
  }

  Future<void> _executeApprove({
    required int id,
    String? cyrillic,
    String? menksoft,
    String? explanation,
    String action = 'add_primary',
    String? targetMenksoft,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/suggestions/approve'),
        headers: _headers,
        body: jsonEncode({
          'id': id,
          'cyrillic': cyrillic,
          'menksoft': menksoft,
          'explanation': explanation,
          'action': action,
          'targetMenksoft': targetMenksoft,
          'moderatorId': widget.moderatorId,
        }),
      );

      if (!mounted) {
        return;
      }
      if (res.statusCode == 200) {
        _advanceQueue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: ${res.body}'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Холболтын алдаа: $e'),
          backgroundColor: DesktopTheme.danger,
        ),
      );
    }
  }

  Future<void> _handleRejectCurrent(String reason) async {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) {
      return;
    }
    final current = _suggestions[_currentIndex];
    final id = current['id'] as int;

    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/suggestions/reject'),
        headers: _headers,
        body: jsonEncode({
          'id': id,
          'reason': reason,
          'moderatorId': widget.moderatorId,
        }),
      );

      if (!mounted) {
        return;
      }
      if (res.statusCode == 200) {
        _advanceQueue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: ${res.body}'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Холболтын алдаа: $e'),
          backgroundColor: DesktopTheme.danger,
        ),
      );
    }
  }

  void _advanceQueue() {
    setState(() {
      _suggestions.removeAt(_currentIndex);
      if (_totalSuggestions > 0) {
        _totalSuggestions--;
      }
      if (_currentIndex >= _suggestions.length) {
        _currentIndex = _suggestions.isEmpty ? 0 : _suggestions.length - 1;
      }
    });
    widget.onCountChanged?.call(_totalSuggestions);
    if (_suggestions.isEmpty && _totalSuggestions > 0) {
      _loadData();
    } else {
      _checkWordForCurrent();
    }
  }

  void _openEditDialog() {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) {
      return;
    }
    final current = _suggestions[_currentIndex];

    showDialog(
      context: context,
      builder: (ctx) => EditSuggestionDialog(
        initialCyrillic: current['cyrillic'] as String,
        initialMenksoft: current['menksoft_code'] as String,
        initialExplanation: current['explanation'] as String?,
        initialComment: current['comment'] as String?,
        targetMenksoft:
            _selectedTargetMenksoft ?? (current['target_menksoft'] as String?),
        serverUrl: widget.serverUrl,
        authToken: widget.authToken,
        onSave:
            ({
              required String cyrillic,
              required String menksoft,
              String? explanation,
              required bool andApprove,
              String action = 'add_primary',
              String? targetMenksoft,
            }) async {
              if (andApprove) {
                await _executeApprove(
                  id: current['id'] as int,
                  cyrillic: cyrillic,
                  menksoft: menksoft,
                  explanation: explanation,
                  action: action,
                  targetMenksoft: targetMenksoft,
                );
              } else {
                setState(() {
                  current['cyrillic'] = cyrillic;
                  current['menksoft_code'] = menksoft;
                  current['explanation'] = explanation;
                });
                _checkWordForCurrent();
              }
            },
      ),
    );
  }

  Future<void> _setPrimaryForWord(String cyrillic, String menksoft) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/definitions/primary'),
        headers: _headers,
        body: jsonEncode({'cyrillic': cyrillic, 'menksoft': menksoft}),
      );
      if (res.statusCode == 200) {
        _checkWordForCurrent();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Алдаа гарлаа: ${res.body}'),
              backgroundColor: DesktopTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Холболтын алдаа: $e'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _deleteDefinitionForWord(
    String cyrillic,
    String menksoft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Устгах уу?'),
        content: Text(
          '"$cyrillic" үгийн энэ бичлэгийг толь бичгээс устгах уу?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Цуцлах'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Устгах', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/definitions/delete'),
        headers: _headers,
        body: jsonEncode({'cyrillic': cyrillic, 'menksoft': menksoft}),
      );
      if (res.statusCode == 200) {
        _checkWordForCurrent();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Алдаа гарлаа: ${res.body}'),
              backgroundColor: DesktopTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Холболтын алдаа: $e'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    }
  }

  // --- Missing Words Queue Helpers ---

  Future<void> _checkWordForMissing() async {
    if (_missingWords.isEmpty || _missingIndex >= _missingWords.length) {
      setState(() {
        _missingWordCheckResult = null;
        _isCheckingMissingWord = false;
      });
      return;
    }

    final current = _missingWords[_missingIndex];
    final cyrillic = (current['cyrillic'] as String?)?.trim() ?? '';
    if (cyrillic.isEmpty) {
      setState(() {
        _missingWordCheckResult = null;
        _isCheckingMissingWord = false;
      });
      return;
    }

    setState(() {
      _isCheckingMissingWord = true;
      _missingWordCheckResult = null;
    });

    try {
      final res = await http
          .get(
            Uri.parse(
              '${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(cyrillic)}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _missingWordCheckResult = data;
        });
      }
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => _isCheckingMissingWord = false);
      }
    }
  }

  void _goToMissingIndex(int index) {
    if (index >= 0 && index < _missingWords.length) {
      setState(() => _missingIndex = index);
      _checkWordForMissing();
    }
  }

  void _skipMissing() {
    if (_missingWords.length > 1) {
      setState(() {
        _missingIndex = (_missingIndex + 1) % _missingWords.length;
      });
      _checkWordForMissing();
    }
  }

  Future<void> _handleRejectMissing(String cyrillic, String reason) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/missing/reject'),
        headers: _headers,
        body: jsonEncode({
          'cyrillic': cyrillic,
          'reason': reason,
          'moderatorId': widget.moderatorId,
        }),
      );

      if (!mounted) {
        return;
      }
      if (res.statusCode == 200) {
        setState(() {
          _missingWords.removeAt(_missingIndex);
          if (_missingIndex >= _missingWords.length) {
            _missingIndex = _missingWords.isEmpty
                ? 0
                : _missingWords.length - 1;
          }
        });
        _checkWordForMissing();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: ${res.body}'),
            backgroundColor: DesktopTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Холболтын алдаа: $e'),
          backgroundColor: DesktopTheme.danger,
        ),
      );
    }
  }

  Future<void> _addWord({
    required String cyrillic,
    required String menksoft,
    String? context,
    String? explanation,
    String? comment,
    bool isPrimary = true,
  }) async {
    final res = await http.post(
      Uri.parse('${widget.serverUrl}/admin/words'),
      headers: _headers,
      body: jsonEncode({
        'cyrillic': cyrillic,
        'menksoft': menksoft,
        'explanation': explanation,
        'isPrimary': isPrimary,
        'moderatorId': widget.moderatorId,
      }),
    );
    if (!mounted) {
      return;
    }
    if (res.statusCode == 200) {
      setState(() {
        _missingWords.removeWhere(
          (item) =>
              (item['cyrillic'] as String?)?.trim().toLowerCase() ==
              cyrillic.trim().toLowerCase(),
        );
        if (_missingIndex >= _missingWords.length) {
          _missingIndex = _missingWords.isEmpty ? 0 : _missingWords.length - 1;
        }
      });
      _checkWordForMissing();
    }
  }

  void _openDefineMissingDialog(String cyrillic) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditWordDialog(
        title: 'Үг тодорхойлох: $cyrillic',
        initialCyrillic: cyrillic,
        submitButtonText: 'Хадгалах',
        onSubmit: _addWord,
      ),
    );
  }

  /// Single-key keyboard navigation handler
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (_activeQueueTab == 0) {
      // --- Suggestions Tab Shortcuts ---
      if (_suggestions.isEmpty) {
        return KeyEventResult.ignored;
      }

      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1) {
        final current = _suggestions[_currentIndex];
        final menksoft = (current['menksoft_code'] as String?)?.trim() ?? '';
        final exists = _currentWordCheckResult?['exists'] == true;
        if (menksoft.isEmpty) {
          _handleApproveCurrent(action: 'resolve_only');
        } else if (exists) {
          _handleApproveCurrent(
            action: 'replace',
            targetMenksoft: _selectedTargetMenksoft,
          );
        } else {
          _handleApproveCurrent(action: 'add_primary');
        }
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.numpad4) {
        final current = _suggestions[_currentIndex];
        final menksoft = (current['menksoft_code'] as String?)?.trim() ?? '';
        final exists = _currentWordCheckResult?['exists'] == true;
        if (menksoft.isNotEmpty && exists) {
          _handleApproveCurrent(action: 'add_secondary');
          return KeyEventResult.handled;
        }
      } else if (key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.numpad2) {
        _handleRejectCurrent('Кирилл бичгийн алдаатай');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.numpad3) {
        _handleRejectCurrent('Кирилл үг биш');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyE) {
        _openEditDialog();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowRight) {
        _skipCurrent();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        if (_currentIndex > 0) {
          _goToIndex(_currentIndex - 1);
        }
        return KeyEventResult.handled;
      }
    } else {
      // --- Missing Words Tab Shortcuts ---
      if (_missingWords.isEmpty) {
        return KeyEventResult.ignored;
      }
      final current = _missingWords[_missingIndex];
      final cyrillic = current['cyrillic'] as String;

      if (key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.numpad1 ||
          key == LogicalKeyboardKey.keyE) {
        _openDefineMissingDialog(cyrillic);
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.numpad2) {
        _handleRejectMissing(cyrillic, 'Кирилл бичгийн алдаатай');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.numpad3) {
        _handleRejectMissing(cyrillic, 'Кирилл үг биш');
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowRight) {
        _skipMissing();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        if (_missingIndex > 0) {
          _goToMissingIndex(_missingIndex - 1);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        color: DesktopTheme.canvas,
        child: Column(
          children: [
            // Desktop Moderator Sub-Header Strip
            _buildSubHeader(),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: DesktopTheme.danger),
                      ),
                    )
                  : _activeQueueTab == 0
                  ? _buildSingleSuggestionReviewTab()
                  : _buildSingleMissingWordReviewTab(),
            ),
          ],
        ),
      ),
    );
  }

  /// Sub-Header: Queue switcher tabs, hotkey cheatsheet, and actions
  Widget _buildSubHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: DesktopTheme.panelBackground,
        border: Border(
          bottom: BorderSide(color: DesktopTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Queue Switcher Tabs
          _buildQueueTabBtn(
            index: 0,
            label: 'Хянагдах саналууд',
            count: _totalSuggestions,
          ),
          const SizedBox(width: 8),
          _buildQueueTabBtn(
            index: 1,
            label: 'Дутуу үгс',
            count: _missingWords.length,
          ),

          if (_activeQueueTab == 1) ...[
            const SizedBox(width: 16),
            _buildFrequencyFilterSelector(),
          ],

          const Spacer(),

          if (widget.isAdmin) ...[
            DesktopButton(
              label: _isDownloadingDb ? 'Татаж байна...' : 'Бааз татах (.db)',
              icon: const Icon(Icons.storage_outlined, size: 15),
              onPressed: _isDownloadingDb ? null : _downloadDatabase,
            ),
            const SizedBox(width: 8),
          ],

          DesktopIconButton(
            icon: Icons.refresh,
            tooltip: 'Дахин ачааллах',
            size: 16,
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueTabBtn({
    required int index,
    required String label,
    required int count,
    IconData? icon,
  }) {
    final isActive = _activeQueueTab == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeQueueTab = index;
          });
          _keyboardFocusNode.requestFocus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? DesktopTheme.secondarySurface
                : Colors.transparent,
            borderRadius: DesktopTheme.roundedSmall,
            border: Border.all(
              color: isActive ? DesktopTheme.borderMedium : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isActive
                      ? DesktopTheme.primary
                      : DesktopTheme.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? DesktopTheme.textPrimary
                      : DesktopTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? DesktopTheme.primary
                      : DesktopTheme.borderMedium,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : DesktopTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyFilterSelector() {
    final label = switch (_minFrequency) {
      1 => 'Бүгд (≥ 1)',
      5 => 'Их давтамжтай (≥ 5)',
      _ => 'Давтамж ≥ 2 (Зөвлөмжтэй)',
    };

    return MenuAnchor(
      builder: (context, controller, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: DesktopTheme.secondarySurface,
                borderRadius: DesktopTheme.roundedSmall,
                border: Border.all(color: DesktopTheme.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DesktopTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: DesktopTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: SizedBox(
            width: 16,
            height: 16,
            child: _minFrequency == 2
                ? const Icon(Icons.check, size: 16, color: DesktopTheme.primary)
                : null,
          ),
          onPressed: () => _changeMinFrequency(2),
          child: const Text('Давтамж ≥ 2 (Зөвлөмжтэй)'),
        ),
        MenuItemButton(
          leadingIcon: SizedBox(
            width: 16,
            height: 16,
            child: _minFrequency == 1
                ? const Icon(Icons.check, size: 16, color: DesktopTheme.primary)
                : null,
          ),
          onPressed: () => _changeMinFrequency(1),
          child: const Text('Бүгд (≥ 1)'),
        ),
        MenuItemButton(
          leadingIcon: SizedBox(
            width: 16,
            height: 16,
            child: _minFrequency == 5
                ? const Icon(Icons.check, size: 16, color: DesktopTheme.primary)
                : null,
          ),
          onPressed: () => _changeMinFrequency(5),
          child: const Text('Их давтамжтай (≥ 5)'),
        ),
      ],
    );
  }

  Widget _buildRejectionHistoryBadge(List<dynamic> history) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }
    final first = history.first as Map<String, dynamic>;
    final reason = first['reason'] as String? ?? 'Татгалзсан';
    final count = history.length;
    final reviewer = first['reviewed_by'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DesktopTheme.warningSurface,
        borderRadius: DesktopTheme.roundedSmall,
        border: Border.all(color: DesktopTheme.warningBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history, size: 16, color: DesktopTheme.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Өмнөх түүх: Энэ үгийг өмнө нь $count удаа татгалзсан байна ($reason)'
              '${reviewer != null ? ' • Шүүгч: $reviewer' : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.brown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Suggestions moderation queue view
  Widget _buildSingleSuggestionReviewTab() {
    if (_suggestions.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: DesktopTheme.panelBackground,
            borderRadius: DesktopTheme.roundedMedium,
            border: Border.all(color: DesktopTheme.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 56,
                color: DesktopTheme.success,
              ),
              const SizedBox(height: 12),
              const Text(
                'Бүх саналыг хянаж дууслаа!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesktopTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Хянагдах санал одоогоор байхгүй байна.',
                style: TextStyle(
                  fontSize: 13,
                  color: DesktopTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              DesktopButton(
                onPressed: _loadData,
                label: 'Дахин шалгах',
                variant: DesktopButtonVariant.secondary,
              ),
            ],
          ),
        ),
      );
    }

    final current = _suggestions[_currentIndex];
    final cyrillic = current['cyrillic'] as String;
    final menksoft = current['menksoft_code'] as String;
    final contextText = current['context'] as String?;
    final explanationText = current['explanation'] as String?;
    final commentText = (current['comment'] as String?)?.trim();
    final submittedBy = current['submitted_by'] as String?;
    final createdAt = current['created_at'] as String?;
    final latin = LatinIme.menksoftToLatin(menksoft);

    final exists = _currentWordCheckResult?['exists'] == true;
    final definitions =
        (_currentWordCheckResult?['definitions'] as List?) ?? [];
    final rejectionHistory =
        (_currentWordCheckResult?['rejectionHistory'] as List?) ?? [];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            decoration: BoxDecoration(
              color: DesktopTheme.panelBackground,
              borderRadius: DesktopTheme.roundedMedium,
              border: Border.all(color: DesktopTheme.border, width: 1),
              boxShadow: DesktopTheme.subtleShadow,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Queue Navigation Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DesktopTheme.secondarySurface,
                        borderRadius: DesktopTheme.roundedSmall,
                        border: Border.all(
                          color: DesktopTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Санал ${_currentIndex + 1} / ${_suggestions.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: DesktopTheme.textPrimary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        DesktopIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Өмнөх санал (←)',
                          size: 16,
                          onPressed: _currentIndex > 0
                              ? () => _goToIndex(_currentIndex - 1)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        DesktopIconButton(
                          icon: Icons.arrow_forward,
                          tooltip: 'Дараах санал (Space / →)',
                          size: 16,
                          onPressed: _currentIndex < _suggestions.length - 1
                              ? () => _goToIndex(_currentIndex + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Split inspection layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Traditional Mongolian Large Preview
                    Container(
                      width: 100,
                      height: 230,
                      decoration: BoxDecoration(
                        color: DesktopTheme.canvas,
                        borderRadius: DesktopTheme.roundedSmall,
                        border: Border.all(
                          color: DesktopTheme.borderMedium,
                          width: 1,
                        ),
                      ),
                      alignment: menksoft.trim().isEmpty
                          ? Alignment.center
                          : Alignment.topCenter,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      child: menksoft.trim().isEmpty
                          ? const Text(
                              'Текстэн мэдээлэл\n(Бичлэг оруулаагүй)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: DesktopTheme.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: MongolText(
                                menksoft,
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontFamily: 'Menksoft',
                                  color: DesktopTheme.textPrimary,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(width: 20),

                    // Middle Column: Cyrillic + Latin + Submitter
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                cyrillic,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: DesktopTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              DesktopIconButton(
                                icon: Icons.copy,
                                size: 14,
                                tooltip: 'Кирилл үгийг хуулах',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: cyrillic),
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                'Латин галиг: ',
                                style: DesktopTheme.caption,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: DesktopTheme.secondarySurface,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: DesktopTheme.border,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  latin.isEmpty ? '—' : latin,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: DesktopTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Утгын орчин / Жишээ өгүүлбэр (Шүүгчид зориулсан):',
                            style: DesktopTheme.caption,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DesktopTheme.canvas,
                              borderRadius: DesktopTheme.roundedSmall,
                              border: Border.all(
                                color: DesktopTheme.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              (contextText != null &&
                                      contextText.trim().isNotEmpty)
                                  ? contextText
                                  : 'Утгын орчин байхгүй',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    (contextText != null &&
                                        contextText.trim().isNotEmpty)
                                    ? DesktopTheme.textPrimary
                                    : DesktopTheme.textMuted,
                                fontStyle:
                                    (contextText != null &&
                                        contextText.trim().isNotEmpty)
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Үгийн тайлбар (Толь бичигт бүртгэгдэх):',
                            style: DesktopTheme.caption,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DesktopTheme.canvas,
                              borderRadius: DesktopTheme.roundedSmall,
                              border: Border.all(
                                color: DesktopTheme.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              (explanationText != null &&
                                      explanationText.trim().isNotEmpty)
                                  ? explanationText
                                  : 'Тайлбар байхгүй',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    (explanationText != null &&
                                        explanationText.trim().isNotEmpty)
                                    ? DesktopTheme.textPrimary
                                    : DesktopTheme.textMuted,
                                fontStyle:
                                    (explanationText != null &&
                                        explanationText.trim().isNotEmpty)
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (commentText != null &&
                              commentText.isNotEmpty) ...[
                            const Text(
                              'Хэрэглэгчийн тэмдэглэл / Алдааны мэдээлэл (Зөвхөн модераторт):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: DesktopTheme.warning,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: DesktopTheme.warningSurface,
                                borderRadius: DesktopTheme.roundedSmall,
                                border: Border.all(
                                  color: DesktopTheme.warningBorder,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                commentText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: DesktopTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            'Илгээсэн: ${submittedBy ?? 'хэрэглэгч'} • ${createdAt != null ? createdAt.split('T').first : ''}',
                            style: DesktopTheme.caption,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right Column: Dictionary Status & Rejection History
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Толь бичгийн төлөв:',
                            style: DesktopTheme.caption,
                          ),
                          const SizedBox(height: 6),
                          if (_isCheckingCurrentWord)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Толь бичиг шалгаж байна...',
                                  style: DesktopTheme.caption,
                                ),
                              ],
                            )
                          else if (exists) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
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
                                          'Тольд бүртгэлтэй үг',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: DesktopTheme.warning,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Тольд одоо ${definitions.length} бичлэг байна. Бичлэг дээр дарж солих зорилтоор сонгох боломжтой.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.brown,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...definitions.map((d) {
                              final dMap = d as Map<String, dynamic>;
                              final dMenk =
                                  (dMap['menksoft'] as String?)?.trim() ?? '';
                              final dExpl = dMap['explanation'] as String?;
                              final dIsPrimary =
                                  dMap['isDefault'] == true ||
                                  dMap['isPrimary'] == true;
                              final dLatin = LatinIme.menksoftToLatin(dMenk);
                              final isSelected =
                                  _selectedTargetMenksoft == dMenk;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTargetMenksoft = isSelected
                                        ? null
                                        : dMenk;
                                  });
                                },
                                borderRadius: DesktopTheme.roundedSmall,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? DesktopTheme.primarySurface
                                        : DesktopTheme.canvas,
                                    borderRadius: DesktopTheme.roundedSmall,
                                    border: Border.all(
                                      color: isSelected
                                          ? DesktopTheme.primary
                                          : DesktopTheme.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: DesktopTheme.panelBackground,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          border: Border.all(
                                            color: DesktopTheme.borderMedium,
                                          ),
                                        ),
                                        alignment: Alignment.topCenter,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: MongolText(
                                            dMenk,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontFamily: 'Menksoft',
                                              color: DesktopTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (dIsPrimary)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: DesktopTheme
                                                          .primarySurface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                      border: Border.all(
                                                        color: DesktopTheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Үндсэн',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: DesktopTheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                if (isSelected)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.blue.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            3,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Сонгосон',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Text(
                                                    dLatin.isEmpty
                                                        ? '—'
                                                        : dLatin,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (!dIsPrimary)
                                                  DesktopIconButton(
                                                    icon: Icons.star_border,
                                                    tooltip: 'Үндсэн болгох',
                                                    size: 13,
                                                    onPressed: () {
                                                      _setPrimaryForWord(
                                                        cyrillic,
                                                        dMenk,
                                                      );
                                                    },
                                                  ),
                                                DesktopIconButton(
                                                  icon: Icons.delete_outline,
                                                  tooltip: 'Устгах',
                                                  size: 13,
                                                  color: DesktopTheme.danger,
                                                  onPressed: () {
                                                    _deleteDefinitionForWord(
                                                      cyrillic,
                                                      dMenk,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                            if (dExpl != null &&
                                                dExpl.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                dExpl,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: DesktopTheme
                                                      .textSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: DesktopTheme.successSurface,
                                borderRadius: DesktopTheme.roundedSmall,
                                border: Border.all(
                                  color: DesktopTheme.successBorder,
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 15,
                                    color: DesktopTheme.success,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Шинэ кирилл үг (Тольд бүртгэлгүй)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: DesktopTheme.success,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildRejectionHistoryBadge(rejectionHistory),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 28),

                // Footer Actions with Hotkey Badges
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (menksoft.trim().isNotEmpty && !exists)
                      DesktopButton(
                        onPressed: () {
                          _handleApproveCurrent(action: 'add_primary');
                        },
                        label: 'Зөвшөөрөх (Үндсэн)',
                        shortcutHint: '1',
                        variant: DesktopButtonVariant.primary,
                      ),
                    if (menksoft.trim().isNotEmpty && exists) ...[
                      DesktopButton(
                        onPressed: () {
                          _handleApproveCurrent(
                            action: 'replace',
                            targetMenksoft: _selectedTargetMenksoft,
                          );
                        },
                        label: 'Одоогийн бичлэгийг солих',
                        shortcutHint: '1',
                        variant: DesktopButtonVariant.primary,
                      ),
                      DesktopButton(
                        onPressed: () {
                          _handleApproveCurrent(action: 'add_secondary');
                        },
                        label: 'Нэмэлт хувилбараар нэмэх',
                        shortcutHint: '4',
                        variant: DesktopButtonVariant.secondary,
                      ),
                      DesktopButton(
                        onPressed: () {
                          _handleApproveCurrent(action: 'add_primary');
                        },
                        label: 'Үндсэн болгож нэмэх',
                        variant: DesktopButtonVariant.secondary,
                      ),
                    ],
                    if (menksoft.trim().isEmpty ||
                        ((current['comment'] as String?)?.trim().isNotEmpty ==
                            true))
                      DesktopButton(
                        onPressed: () {
                          _handleApproveCurrent(action: 'resolve_only');
                        },
                        label: 'Шийдвэрлэсэн (Хаах)',
                        shortcutHint: menksoft.trim().isEmpty ? '1' : null,
                        variant: DesktopButtonVariant.secondary,
                      ),
                    DesktopButton(
                      onPressed: () {
                        _handleRejectCurrent('Кирилл бичгийн алдаатай');
                      },
                      label: 'Кирилл алдаатай',
                      shortcutHint: '2',
                      variant: DesktopButtonVariant.danger,
                    ),
                    DesktopButton(
                      onPressed: () {
                        _handleRejectCurrent('Кирилл үг биш');
                      },
                      label: 'Үг биш',
                      shortcutHint: '3',
                      variant: DesktopButtonVariant.danger,
                    ),
                    DesktopButton(
                      onPressed: _openEditDialog,
                      label: 'Засах',
                      shortcutHint: 'E',
                      variant: DesktopButtonVariant.secondary,
                    ),
                    DesktopButton(
                      onPressed: _suggestions.length > 1 ? _skipCurrent : null,
                      label: 'Алгасах',
                      shortcutHint: 'Space',
                      variant: DesktopButtonVariant.subtle,
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

  /// Missing words queue view
  Widget _buildSingleMissingWordReviewTab() {
    if (_missingWords.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: DesktopTheme.panelBackground,
            borderRadius: DesktopTheme.roundedMedium,
            border: Border.all(color: DesktopTheme.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 56,
                color: DesktopTheme.success,
              ),
              const SizedBox(height: 12),
              Text(
                _minFrequency > 1
                    ? 'Давтамж ≥ $_minFrequency бүхий дутуу үг олдсонгүй'
                    : 'Бүх дутуу үгийг шалгаж дууслаа!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesktopTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Давтамжийн шүүлтүүрийг өөрчлөх эсвэл дахин шалгана уу.',
                style: TextStyle(
                  fontSize: 13,
                  color: DesktopTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              DesktopButton(
                onPressed: _loadData,
                label: 'Дахин шалгах',
                variant: DesktopButtonVariant.secondary,
              ),
            ],
          ),
        ),
      );
    }

    final item = _missingWords[_missingIndex];
    final cyrillic = item['cyrillic'] as String;
    final freq = item['frequency'] as int;
    final lastContext = item['last_context'] as String?;
    final lastSeen = item['last_seen'] as String?;

    final exists = _missingWordCheckResult?['exists'] == true;
    final definitions =
        (_missingWordCheckResult?['definitions'] as List?) ?? [];
    final rejectionHistory =
        (_missingWordCheckResult?['rejectionHistory'] as List?) ?? [];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            decoration: BoxDecoration(
              color: DesktopTheme.panelBackground,
              borderRadius: DesktopTheme.roundedMedium,
              border: Border.all(color: DesktopTheme.border, width: 1),
              boxShadow: DesktopTheme.subtleShadow,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Queue Navigation Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: DesktopTheme.secondarySurface,
                            borderRadius: DesktopTheme.roundedSmall,
                            border: Border.all(
                              color: DesktopTheme.border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Дутуу үг ${_missingIndex + 1} / ${_missingWords.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: DesktopTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: freq > 3
                                ? DesktopTheme.dangerSurface
                                : DesktopTheme.secondarySurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: freq > 3
                                  ? DesktopTheme.dangerBorder
                                  : DesktopTheme.border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$freq удаа хайгдсан',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: freq > 3
                                  ? DesktopTheme.danger
                                  : DesktopTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        DesktopIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Өмнөх дутуу үг (←)',
                          size: 16,
                          onPressed: _missingIndex > 0
                              ? () => _goToMissingIndex(_missingIndex - 1)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        DesktopIconButton(
                          icon: Icons.arrow_forward,
                          tooltip: 'Дараах дутуу үг (Space / →)',
                          size: 16,
                          onPressed: _missingIndex < _missingWords.length - 1
                              ? () => _goToMissingIndex(_missingIndex + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Cyrillic Title with Copy
                Row(
                  children: [
                    Text(
                      cyrillic,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: DesktopTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DesktopIconButton(
                      icon: Icons.copy,
                      size: 15,
                      tooltip: 'Кирилл үгийг хуулах',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cyrillic));
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

                const SizedBox(height: 14),

                // Context sentence
                const Text(
                  'Жишээ өгүүлбэр / хэрэглээ:',
                  style: DesktopTheme.caption,
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DesktopTheme.canvas,
                    borderRadius: DesktopTheme.roundedSmall,
                    border: Border.all(color: DesktopTheme.border, width: 1),
                  ),
                  child: Text(
                    (lastContext != null && lastContext.trim().isNotEmpty)
                        ? '"...$lastContext..."'
                        : 'Жишээ өгүүлбэр бүртгэгдээгүй байна',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle:
                          (lastContext != null && lastContext.trim().isNotEmpty)
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color:
                          (lastContext != null && lastContext.trim().isNotEmpty)
                          ? DesktopTheme.textPrimary
                          : DesktopTheme.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Dictionary Status
                if (_isCheckingMissingWord)
                  const Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Толь бичиг шалгаж байна...',
                        style: DesktopTheme.caption,
                      ),
                    ],
                  )
                else if (exists)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesktopTheme.warningSurface,
                      borderRadius: DesktopTheme.roundedSmall,
                      border: Border.all(
                        color: DesktopTheme.warningBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'ℹ️ Энэ үг толь бичигт ${definitions.length} хувилбартайгаар бүртгэлтэй байна.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.brown,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: DesktopTheme.success,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Толь бичигт бүртгэлгүй шинэ үг',
                        style: TextStyle(
                          fontSize: 12,
                          color: DesktopTheme.success,
                        ),
                      ),
                    ],
                  ),

                _buildRejectionHistoryBadge(rejectionHistory),

                if (lastSeen != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Сүүлд хайгдсан: ${lastSeen.split('T').first}',
                    style: DesktopTheme.caption,
                  ),
                ],

                const Divider(height: 28),

                // Footer Actions with Hotkey Badges
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DesktopButton(
                      onPressed: () => _openDefineMissingDialog(cyrillic),
                      label: 'Тодорхойлох / Нэмэх',
                      shortcutHint: '1 / E',
                      variant: DesktopButtonVariant.primary,
                    ),
                    DesktopButton(
                      onPressed: () => _handleRejectMissing(
                        cyrillic,
                        'Кирилл бичгийн алдаатай',
                      ),
                      label: 'Кирилл алдаатай',
                      shortcutHint: '2',
                      variant: DesktopButtonVariant.danger,
                    ),
                    DesktopButton(
                      onPressed: () =>
                          _handleRejectMissing(cyrillic, 'Кирилл үг биш'),
                      label: 'Үг биш',
                      shortcutHint: '3',
                      variant: DesktopButtonVariant.danger,
                    ),
                    DesktopButton(
                      onPressed: _missingWords.length > 1 ? _skipMissing : null,
                      label: 'Алгасах',
                      shortcutHint: 'Space',
                      variant: DesktopButtonVariant.subtle,
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
}
