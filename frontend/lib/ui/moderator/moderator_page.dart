import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import '../../services/latin_ime.dart';
import '../dialogs/add_edit_word_dialog.dart';
import 'edit_suggestion_dialog.dart';

class ModeratorPage extends StatefulWidget {
  final String serverUrl;
  final String? authToken;
  final String? moderatorId;

  const ModeratorPage({
    super.key,
    required this.serverUrl,
    this.authToken,
    this.moderatorId,
  });

  @override
  State<ModeratorPage> createState() => _ModeratorPageState();
}

class _ModeratorPageState extends State<ModeratorPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _missingWords = [];
  List<dynamic> _suggestions = [];

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (widget.authToken != null) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return headers;
  }

  Future<void> _changeMinFrequency(int newMinFreq) async {
    if (_minFrequency == newMinFreq) return;
    setState(() {
      _minFrequency = newMinFreq;
      _missingIndex = 0;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final missingRes = await http.get(
        Uri.parse('${widget.serverUrl}/admin/missing?limit=100&min_frequency=$_minFrequency'),
        headers: _headers,
      );
      final suggRes = await http.get(
        Uri.parse('${widget.serverUrl}/admin/suggestions?limit=100'),
        headers: _headers,
      );

      if (missingRes.statusCode == 200 && suggRes.statusCode == 200) {
        final missingData = jsonDecode(missingRes.body);
        final suggData = jsonDecode(suggRes.body);

        final newSuggestions = (suggData['suggestions'] as List?) ?? [];
        final newMissing = (missingData['missing'] as List?) ?? [];

        setState(() {
          _missingWords = newMissing;
          _suggestions = newSuggestions;

          if (_currentIndex >= _suggestions.length) {
            _currentIndex = _suggestions.isEmpty ? 0 : _suggestions.length - 1;
          }
          if (_missingIndex >= _missingWords.length) {
            _missingIndex = _missingWords.isEmpty ? 0 : _missingWords.length - 1;
          }
        });

        _checkWordForCurrent();
        _checkWordForMissing();
      } else {
        setState(() {
          _error = 'Өгөгдөл татахад алдаа: ${missingRes.statusCode} / ${suggRes.statusCode}';
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
      });
      return;
    }

    final current = _suggestions[_currentIndex];
    final cyrillic = (current['cyrillic'] as String?)?.trim() ?? '';
    if (cyrillic.isEmpty) {
      setState(() {
        _currentWordCheckResult = null;
        _isCheckingCurrentWord = false;
      });
      return;
    }

    setState(() {
      _isCheckingCurrentWord = true;
      _currentWordCheckResult = null;
    });

    try {
      final res = await http.get(
        Uri.parse('${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(cyrillic)}'),
        headers: _headers,
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _currentWordCheckResult = data;
        });
      }
    } catch (_) {
      // Ignore network errors or 404
    } finally {
      if (mounted) {
        setState(() => _isCheckingCurrentWord = false);
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

  Future<void> _handleApproveCurrent() async {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) return;
    final current = _suggestions[_currentIndex];
    final id = current['id'] as int;
    final cyrillic = current['cyrillic'] as String;
    final menksoft = current['menksoft_code'] as String;
    String? note = (current['context'] as String?)?.trim();

    final exists = _currentWordCheckResult?['exists'] == true;
    final definitions = (_currentWordCheckResult?['definitions'] as List?) ?? [];

    // Check if duplicate of an existing definition
    final alreadyIdentical = definitions.any((d) => (d['menksoft'] as String?)?.trim() == menksoft.trim());
    if (alreadyIdentical) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Аль хэдийн бүртгэгдсэн байна'),
          content: Text(
            '"$cyrillic" үгэнд энэхүү босоо бичлэг толь бичигт аль хэдийн байна.\n'
            'Та давхардуулж нэмэхдээ итгэлтэй байна уу?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Цуцлах')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Батлах')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Really it is only the homonyms that need a note.
    if (!mounted) return;
    if (exists && (note == null || note.isEmpty)) {
      final inputController = TextEditingController();
      final addedNote = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Олон утгатай үг (Homonym)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$cyrillic" кирилл үг толь бичигт өмнө нь өөр бичлэгтэй бүртгэгдсэн байна.\n'
                'Энэ хоёрыг хэрэглэгч ялгахын тулд ялгах тэмдэглэл/тайлбар оруулна уу:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: inputController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Тэмдэглэл (жишээ: он жил, төр засаг)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Цуцлах')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, inputController.text.trim()),
              child: const Text('Батлах'),
            ),
          ],
        ),
      );

      if (addedNote == null) return;
      note = addedNote.isEmpty ? null : addedNote;
    }

    await _executeApprove(
      id: id,
      cyrillic: cyrillic,
      menksoft: menksoft,
      explanation: note,
    );
  }

  Future<void> _executeApprove({
    required int id,
    String? cyrillic,
    String? menksoft,
    String? explanation,
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
          'moderatorId': widget.moderatorId,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Амжилттай баталлаа'), backgroundColor: Colors.green),
        );
        _advanceQueue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: ${res.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Холболтын алдаа: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRejectCurrent(String reason) async {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) return;
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

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Татгалзлаа: $reason'), backgroundColor: Colors.orange),
        );
        _advanceQueue();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: ${res.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Холболтын алдаа: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _advanceQueue() {
    setState(() {
      _suggestions.removeAt(_currentIndex);
      if (_currentIndex >= _suggestions.length) {
        _currentIndex = _suggestions.isEmpty ? 0 : _suggestions.length - 1;
      }
    });
    _checkWordForCurrent();
  }

  void _openEditDialog() {
    if (_suggestions.isEmpty || _currentIndex >= _suggestions.length) return;
    final current = _suggestions[_currentIndex];

    showDialog(
      context: context,
      builder: (ctx) => EditSuggestionDialog(
        initialCyrillic: current['cyrillic'] as String,
        initialMenksoft: current['menksoft_code'] as String,
        initialExplanation: current['context'] as String?,
        serverUrl: widget.serverUrl,
        authToken: widget.authToken,
        onSave: ({
          required String cyrillic,
          required String menksoft,
          String? explanation,
          required bool andApprove,
        }) async {
          if (andApprove) {
            await _executeApprove(
              id: current['id'] as int,
              cyrillic: cyrillic,
              menksoft: menksoft,
              explanation: explanation,
            );
          } else {
            // Update local suggestion in queue
            setState(() {
              current['cyrillic'] = cyrillic;
              current['menksoft_code'] = menksoft;
              current['context'] = explanation;
            });
            _checkWordForCurrent();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Санал шинэчлэгдлээ'), backgroundColor: Colors.blue),
            );
          }
        },
      ),
    );
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
      final res = await http.get(
        Uri.parse('${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(cyrillic)}'),
        headers: _headers,
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _missingWordCheckResult = data;
        });
      }
    } catch (_) {
      // Ignore network errors or 404
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

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Татгалзсан жагсаалтад бүртгэгдлээ: $reason'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _missingWords.removeAt(_missingIndex);
          if (_missingIndex >= _missingWords.length) {
            _missingIndex = _missingWords.isEmpty ? 0 : _missingWords.length - 1;
          }
        });
        _checkWordForMissing();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: ${res.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Холболтын алдаа: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addWord({
    required String cyrillic,
    required String menksoft,
    String? explanation,
  }) async {
    final res = await http.post(
      Uri.parse('${widget.serverUrl}/admin/words'),
      headers: _headers,
      body: jsonEncode({
        'cyrillic': cyrillic,
        'menksoft': menksoft,
        'explanation': explanation,
        'isPrimary': true,
        'moderatorId': widget.moderatorId,
      }),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Үг толь бичигт нэмэгдлээ'), backgroundColor: Colors.green),
      );
      // Remove from missing queue if it was there
      setState(() {
        _missingWords.removeWhere((item) => (item['cyrillic'] as String?)?.trim().toLowerCase() == cyrillic.trim().toLowerCase());
        if (_missingIndex >= _missingWords.length) {
          _missingIndex = _missingWords.isEmpty ? 0 : _missingWords.length - 1;
        }
      });
      _checkWordForMissing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Модераторын хяналтын самбар'),
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.rate_review),
                text: 'Хянагдах саналууд (${_suggestions.length})',
              ),
              Tab(
                icon: const Icon(Icons.warning_amber),
                text: 'Дутуу үгс (${_missingWords.length})',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Шинэчлэх',
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSingleSuggestionReviewTab(),
                      _buildSingleMissingWordReviewTab(),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AddEditWordDialog(
                title: 'Шинэ үг толь бичигт нэмэх',
                submitButtonText: 'Нэмэх',
                onSubmit: _addWord,
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Үг нэмэх'),
        ),
      ),
    );
  }

  Widget _buildFrequencyFilterSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _minFrequency,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(
              value: 2,
              child: Text('Давтамж ≥ 2 (Зөвлөмжтэй)'),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text('Бүгд (≥ 1)'),
            ),
            DropdownMenuItem(
              value: 5,
              child: Text('Их давтамжтай (≥ 5)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) _changeMinFrequency(val);
          },
        ),
      ),
    );
  }

  Widget _buildRejectionHistoryBadge(List<dynamic> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    final first = history.first as Map<String, dynamic>;
    final reason = first['reason'] as String? ?? 'Татгалзсан';
    final count = history.length;
    final reviewer = first['reviewed_by'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Өмнөх түүх: Энэ үгийг өмнө нь $count удаа татгалзсан байна ($reason)'
              '${reviewer != null ? ' • Шүүгч: $reviewer' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.brown.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Single-card one-at-a-time suggestions moderation queue
  Widget _buildSingleSuggestionReviewTab() {
    if (_suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
              const SizedBox(height: 16),
              const Text(
                'Бүх саналыг хянаж дууслаа!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Хянагдах санал одоогоор байхгүй байна.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Дахин шалгах'),
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
    final submittedBy = current['submitted_by'] as String?;
    final createdAt = current['created_at'] as String?;
    final latin = LatinIme.menksoftToLatin(menksoft);

    final exists = _currentWordCheckResult?['exists'] == true;
    final definitions = (_currentWordCheckResult?['definitions'] as List?) ?? [];
    final rejectionHistory = (_currentWordCheckResult?['rejectionHistory'] as List?) ?? [];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Queue Header: Navigation, Counter, and Skip button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Санал ${_currentIndex + 1} / ${_suggestions.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Өмнөх санал',
                            onPressed: _currentIndex > 0 ? () => _goToIndex(_currentIndex - 1) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            tooltip: 'Дараах санал',
                            onPressed: _currentIndex < _suggestions.length - 1 ? () => _goToIndex(_currentIndex + 1) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Word Showcase Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Traditional Mongolian Preview Container
                      Container(
                        height: 240,
                        width: 110,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: MongolText(
                            menksoft,
                            style: const TextStyle(
                              fontSize: 42, // Traditional word in large text
                              fontFamily: 'Menksoft',
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Details Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cyrillic Title with Copy Button
                            Row(
                              children: [
                                Text(
                                  cyrillic,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Кирилл үгийг хуулах',
                                  splashRadius: 18,
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
                            const SizedBox(height: 10),
                            // Latin Transliteration
                            Row(
                              children: [
                                Text(
                                  'Латин галиг: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    latin.isEmpty ? '—' : latin,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Note / Explanation
                            Text(
                              'Тэмдэглэл / Тайлбар:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (contextText != null && contextText.trim().isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  contextText,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              )
                            else
                              Text(
                                'Тэмдэглэл байхгүй (Зөвхөн олон утгатай үгсэд шаардлагатай)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            const SizedBox(height: 14),
                            // Database existence & Homonym status indicator
                            if (_isCheckingCurrentWord)
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Толь бичиг шалгаж байна...',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              )
                            else if (exists)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Энэ кирилл үг толь бичигт бүртгэгдсэн байна (Олон утгатай / Homonym)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Одоо байгаа бичлэгүүд: ${definitions.length} хувилбар байна. Олон утгатай үгэнд ялгах тайлбар шаардлагатай.',
                                      style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Шинэ кирилл үг (Толь бичигт бүртгэлгүй)',
                                    style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            // Submitter info
                            Text(
                              'Илгээсэн: ${submittedBy ?? 'хэрэглэгч'} • ${createdAt != null ? createdAt.split('T').first : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            _buildRejectionHistoryBadge(rejectionHistory),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Options: Accept, Reject (misspelled), Reject (not a word), Edit, Skip
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Accept
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text(
                          'Зөвшөөрөх',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _handleApproveCurrent,
                      ),
                      // 2. Reject: Cyrillic misspelled
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade900,
                          side: BorderSide(color: Colors.orange.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.spellcheck, size: 18),
                        label: const Text('Кирилл алдаатай'),
                        onPressed: () => _handleRejectCurrent('Кирилл бичгийн алдаатай'),
                      ),
                      // 3. Reject: Cyrillic not a word
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Үг биш'),
                        onPressed: () => _handleRejectCurrent('Кирилл үг биш'),
                      ),
                      // 4. Edit
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade800,
                          side: BorderSide(color: Colors.blue.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Засах'),
                        onPressed: _openEditDialog,
                      ),
                      // 5. Skip button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Алгасах'),
                        onPressed: _suggestions.length > 1 ? _skipCurrent : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Single-card one-at-a-time missing words queue
  Widget _buildSingleMissingWordReviewTab() {
    if (_missingWords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
              const SizedBox(height: 16),
              Text(
                _minFrequency > 1
                    ? 'Давтамж ≥ $_minFrequency бүхий дутуу үг олдсонгүй'
                    : 'Бүх дутуу үгийг шалгаж дууслаа!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _minFrequency > 1
                    ? 'Давтамжийн шүүлтүүрийг өөрчлөх эсвэл дахин шалгана уу.'
                    : 'Дутуу үг бүртгэгдээгүй байна.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _buildFrequencyFilterSelector(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Дахин шалгах'),
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
    final definitions = (_missingWordCheckResult?['definitions'] as List?) ?? [];
    final rejectionHistory = (_missingWordCheckResult?['rejectionHistory'] as List?) ?? [];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Queue Header: Navigation, Index counter, and Frequency filter
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.deepPurple.shade200),
                            ),
                            child: Text(
                              'Дутуу үг ${_missingIndex + 1} / ${_missingWords.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('$freq удаа хайгдсан'),
                            backgroundColor: freq > 3 ? Colors.red.shade100 : Colors.grey.shade200,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFrequencyFilterSelector(),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Өмнөх дутуу үг',
                            onPressed: _missingIndex > 0 ? () => _goToMissingIndex(_missingIndex - 1) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            tooltip: 'Дараах дутуу үг',
                            onPressed: _missingIndex < _missingWords.length - 1 ? () => _goToMissingIndex(_missingIndex + 1) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Word Display
                  Row(
                    children: [
                      Text(
                        cyrillic,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Кирилл үгийг хуулах',
                        splashRadius: 20,
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
                  const SizedBox(height: 16),
                  // Context Sentence
                  Text(
                    'Жишээ өгүүлбэр / хэрэглээ:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (lastContext != null && lastContext.trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        '"...$lastContext..."',
                        style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black87),
                      ),
                    )
                  else
                    Text(
                      'Жишээ өгүүлбэр бүртгэгдээгүй байна',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Dictionary existence status indicator
                  if (_isCheckingMissingWord)
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Толь бичиг шалгаж байна...',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  else if (exists)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Text(
                        'ℹ️ Энэ үг толь бичигт ${definitions.length} хувилбартайгаар бүртгэлтэй байна.',
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Толь бичигт бүртгэлгүй шинэ үг',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  _buildRejectionHistoryBadge(rejectionHistory),
                  const SizedBox(height: 12),
                  if (lastSeen != null)
                    Text(
                      'Сүүлд хайгдсан: ${lastSeen.split('T').first}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  const Divider(height: 32),
                  // Options: Define/Add, Reject (misspelled), Reject (not a word), Skip
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 1. Define / Add word
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Тодорхойлох / Нэмэх',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AddEditWordDialog(
                              title: 'Үг тодорхойлох: $cyrillic',
                              initialCyrillic: cyrillic,
                              submitButtonText: 'Хадгалах',
                              onSubmit: _addWord,
                            ),
                          );
                        },
                      ),
                      // 2. Reject: Cyrillic misspelled
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade900,
                          side: BorderSide(color: Colors.orange.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.spellcheck, size: 18),
                        label: const Text('Кирилл алдаатай'),
                        onPressed: () => _handleRejectMissing(cyrillic, 'Кирилл бичгийн алдаатай'),
                      ),
                      // 3. Reject: Cyrillic not a word
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Үг биш'),
                        onPressed: () => _handleRejectMissing(cyrillic, 'Кирилл үг биш'),
                      ),
                      // 4. Skip button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Алгасах'),
                        onPressed: _missingWords.length > 1 ? _skipMissing : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
