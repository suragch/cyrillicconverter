import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';

import '../../models/local_word_entry.dart';
import '../../services/latin_ime.dart';
import '../../services/local_dictionary_service.dart';
import '../desktop/components/desktop_button.dart';
import '../desktop/desktop_theme.dart';
import '../dialogs/add_edit_word_dialog.dart';

class DictionaryBrowseView extends StatefulWidget {
  final String serverUrl;
  final String? authToken;
  final String? moderatorId;
  final VoidCallback? onDownloadDictionary;

  const DictionaryBrowseView({
    super.key,
    required this.serverUrl,
    this.authToken,
    this.moderatorId,
    this.onDownloadDictionary,
  });

  @override
  State<DictionaryBrowseView> createState() => _DictionaryBrowseViewState();
}

class _DictionaryBrowseViewState extends State<DictionaryBrowseView> {
  int _selectedSubTab = 0; // 0 = Бүх нийтийн толь, 1 = Миний үгс
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _localSearchController = TextEditingController();
  String _localSearchQuery = '';
  bool _isSearching = false;
  String? _errorMessage;
  String? _lastSearchedWord;
  Map<String, dynamic>? _searchResult;

  @override
  void dispose() {
    _searchController.dispose();
    _localSearchController.dispose();
    super.dispose();
  }

  bool get _isModerator =>
      widget.authToken != null && widget.authToken!.isNotEmpty;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (widget.authToken != null) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return headers;
  }

  Future<void> _searchWord(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _lastSearchedWord = clean;
    });

    try {
      final endpoint = _isModerator ? '/admin/words/check' : '/words/check';
      final res = await http
          .get(
            Uri.parse(
              '${widget.serverUrl}$endpoint?cyrillic=${Uri.encodeComponent(clean)}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _searchResult = data;
        });
      } else {
        setState(() {
          _errorMessage = 'Серверээс алдаа ирлээ (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Сервертэй холбогдож чадсангүй: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _addNewDefinition(String cyrillic) async {
    showDialog(
      context: context,
      builder: (ctx) => AddEditWordDialog(
        title: 'Толь бичигт нэмэх: "$cyrillic"',
        initialCyrillic: cyrillic,
        submitButtonText: 'Хадгалах',
        onSubmit:
            ({
              required String cyrillic,
              required String menksoft,
              String? context,
              String? explanation,
            }) async {
              final res = await http.post(
                Uri.parse('${widget.serverUrl}/admin/words'),
                headers: _headers,
                body: jsonEncode({
                  'cyrillic': cyrillic,
                  'menksoft': menksoft,
                  'explanation': explanation,
                  'isPrimary': false,
                  'moderatorId': widget.moderatorId,
                }),
              );

              if (res.statusCode == 200) {
                _searchWord(cyrillic);
              } else {
                throw Exception(res.body);
              }
            },
      ),
    );
  }

  Future<void> _suggestWord(String cyrillic) async {
    showDialog(
      context: context,
      builder: (ctx) => AddEditWordDialog(
        title: 'Шинэ үгийн санал илгээх: "$cyrillic"',
        initialCyrillic: cyrillic,
        submitButtonText: 'Санал илгээх',
        onSubmit:
            ({
              required String cyrillic,
              required String menksoft,
              String? context,
              String? explanation,
            }) async {
              final res = await http.post(
                Uri.parse('${widget.serverUrl}/contribute'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'cyrillic': cyrillic,
                  'menksoft': menksoft,
                  'context': context ?? '',
                  'explanation': explanation ?? '',
                }),
              );

              if (res.statusCode == 200) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"$cyrillic" үгийн санал модераторын дараалалд амжилттай нэмэгдлээ.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                throw Exception(res.body);
              }
            },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DesktopTheme.canvas,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sub-navigation: Public Dictionary vs My Words
              ListenableBuilder(
                listenable: LocalDictionaryService.instance,
                builder: (context, _) {
                  final localCount = LocalDictionaryService.instance.count;
                  return Row(
                    children: [
                      _buildSubTabButton(
                        index: 0,
                        title: 'Бүх нийтийн толь',
                        isSelected: _selectedSubTab == 0,
                      ),
                      const SizedBox(width: 8),
                      _buildSubTabButton(
                        index: 1,
                        title: 'Миний үгс ($localCount)',
                        isSelected: _selectedSubTab == 1,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              if (_selectedSubTab == 0) ...[
                // Search Toolbar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DesktopTheme.panelBackground,
                    borderRadius: DesktopTheme.roundedMedium,
                    border: Border.all(color: DesktopTheme.border, width: 1),
                    boxShadow: DesktopTheme.subtleShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Толь бичиг хайх & шалгах',
                        style: DesktopTheme.titleBold,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Кирилл үг бичиж толь бичиг дэх босоо бичлэгийн хувилбарууд болон олон утгыг шууд шалгана уу.',
                        style: DesktopTheme.bodySecondary,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: DesktopTheme.panelBackground,
                                borderRadius: DesktopTheme.roundedSmall,
                                border: Border.all(
                                  color: DesktopTheme.borderMedium,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: null,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Жишээ: монгол, төр, гол, ажил...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: DesktopTheme.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: DesktopTheme.textSecondary,
                                  ),
                                ),
                                onSubmitted: _searchWord,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DesktopButton(
                            onPressed: _isSearching
                                ? null
                                : () => _searchWord(_searchController.text),
                            label: 'Хайх',
                            variant: DesktopButtonVariant.primary,
                            isLoading: _isSearching,
                          ),
                          if (widget.onDownloadDictionary != null) ...[
                            const SizedBox(width: 8),
                            DesktopButton(
                              onPressed: widget.onDownloadDictionary,
                              label: 'Толь татах (CSV)',
                              variant: DesktopButtonVariant.secondary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Error banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DesktopTheme.dangerSurface,
                      borderRadius: DesktopTheme.roundedSmall,
                      border: Border.all(
                        color: DesktopTheme.dangerBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: DesktopTheme.danger,
                      ),
                    ),
                  ),

                // Results Area
                Expanded(child: _buildResultsArea()),
              ] else ...[
                // Local Words Panel
                Expanded(child: _buildLocalWordsPanel()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required String title,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSubTab = index;
        });
      },
      borderRadius: DesktopTheme.roundedSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? DesktopTheme.primary
              : DesktopTheme.panelBackground,
          borderRadius: DesktopTheme.roundedSmall,
          border: Border.all(
            color: isSelected
                ? DesktopTheme.primary
                : DesktopTheme.borderMedium,
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : DesktopTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalWordsPanel() {
    return ListenableBuilder(
      listenable: LocalDictionaryService.instance,
      builder: (context, _) {
        final all = LocalDictionaryService.instance.allWords;
        final filtered = _localSearchQuery.isEmpty
            ? all
            : all.where((e) {
                final q = _localSearchQuery.toLowerCase();
                return e.cyrillic.toLowerCase().contains(q) ||
                    (e.explanation?.toLowerCase().contains(q) ?? false);
              }).toList();

        return Column(
          children: [
            // Search & header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DesktopTheme.panelBackground,
                borderRadius: DesktopTheme.roundedMedium,
                border: Border.all(color: DesktopTheme.border, width: 1),
                boxShadow: DesktopTheme.subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Миний оруулсан үгс (Хувийн толь)',
                    style: DesktopTheme.titleBold,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Таны хөрвүүлэгчид шууд ашиглагдах үгс. Модератор баталтал энэ төхөөрөмж дээр хадгалагдана.',
                    style: DesktopTheme.bodySecondary,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: DesktopTheme.panelBackground,
                      borderRadius: DesktopTheme.roundedSmall,
                      border: Border.all(
                        color: DesktopTheme.borderMedium,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _localSearchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Хувийн үгсээс хайх...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: DesktopTheme.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: DesktopTheme.textSecondary,
                        ),
                        suffixIcon: _localSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _localSearchController.clear();
                                    _localSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _localSearchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: all.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: DesktopTheme.panelBackground,
                        borderRadius: DesktopTheme.roundedMedium,
                        border: Border.all(
                          color: DesktopTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Танд одоогоор хувийн үг бүртгэгдээгүй байна',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: DesktopTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Хөрвүүлэгч дээр үл мэдэгдэх үг нэмэх үед энэ жагсаалтад автоматаар хадгалагдана.',
                            style: TextStyle(
                              fontSize: 13,
                              color: DesktopTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: DesktopTheme.panelBackground,
                        borderRadius: DesktopTheme.roundedMedium,
                        border: Border.all(
                          color: DesktopTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '"$_localSearchQuery" хайлтад тохирох үг олдсонгүй.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: DesktopTheme.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (ctx, index) {
                        final entry = filtered[index];
                        return _buildLocalWordCard(entry);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocalWordCard(LocalWordEntry entry) {
    final latin = LatinIme.convertToLatin(entry.menksoft);
    final dateStr =
        '${entry.createdAt.year}.${entry.createdAt.month.toString().padLeft(2, '0')}.${entry.createdAt.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesktopTheme.panelBackground,
        borderRadius: DesktopTheme.roundedMedium,
        border: Border.all(color: DesktopTheme.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical Menksoft text preview
          Container(
            width: 50,
            height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: DesktopTheme.roundedSmall,
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: MongolText(
                entry.menksoft,
                style: const TextStyle(
                  fontSize: 22,
                  fontFamily: 'Menksoft',
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Word info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.cyrillic,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DesktopTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Хувийн толь',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Латин: $latin',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DesktopTheme.textSecondary,
                  ),
                ),
                if (entry.explanation != null &&
                    entry.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Тайлбар: ${entry.explanation}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: DesktopTheme.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Нэмсэн огноо: $dateStr',
                  style: const TextStyle(
                    fontSize: 11,
                    color: DesktopTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Actions: Edit and Delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Засах',
                onPressed: () {
                  _editLocalWord(entry);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red.shade600,
                ),
                tooltip: 'Устгах',
                onPressed: () {
                  _deleteLocalWord(entry);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editLocalWord(LocalWordEntry entry) async {
    showDialog(
      context: context,
      builder: (ctx) => AddEditWordDialog(
        title: 'Хувийн толь засах: "${entry.cyrillic}"',
        initialCyrillic: entry.cyrillic,
        initialLatin: LatinIme.convertToLatin(entry.menksoft),
        initialExplanation: entry.explanation,
        submitButtonText: 'Хадгалах',
        onDelete: () async {
          await LocalDictionaryService.instance.deleteWord(entry.cyrillic);
        },
        onSubmit:
            ({
              required String cyrillic,
              required String menksoft,
              String? context,
              String? explanation,
            }) async {
              await LocalDictionaryService.instance.addOrUpdateWord(
                cyrillic: cyrillic,
                menksoft: menksoft,
                explanation: explanation,
              );
            },
      ),
    );
  }

  Future<void> _deleteLocalWord(LocalWordEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Устгах уу?'),
        content: Text('"${entry.cyrillic}" үгийг хувийн тольноос устгах уу?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
            },
            child: const Text('Үгүй'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await LocalDictionaryService.instance.deleteWord(entry.cyrillic);
    }
  }

  Widget _buildResultsArea() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_searchResult == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesktopTheme.panelBackground,
          borderRadius: DesktopTheme.roundedMedium,
          border: Border.all(color: DesktopTheme.border, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: DesktopTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Толь бичгээс хайх үгээ дээрх талбарт оруулна уу.',
              style: TextStyle(fontSize: 14, color: DesktopTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final exists = _searchResult!['exists'] == true;
    final definitions = (_searchResult!['definitions'] as List?) ?? [];
    final rejectionHistory =
        (_searchResult!['rejectionHistory'] as List?) ?? [];
    final searchedWord = _lastSearchedWord ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesktopTheme.panelBackground,
        borderRadius: DesktopTheme.roundedMedium,
        border: Border.all(color: DesktopTheme.border, width: 1),
        boxShadow: DesktopTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    searchedWord,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: DesktopTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: exists
                          ? DesktopTheme.successSurface
                          : DesktopTheme.warningSurface,
                      borderRadius: DesktopTheme.roundedSmall,
                      border: Border.all(
                        color: exists
                            ? DesktopTheme.successBorder
                            : DesktopTheme.warningBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      exists
                          ? 'Толь бичигт байна (${definitions.length})'
                          : 'Толь бичигт байхгүй',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: exists
                            ? DesktopTheme.success
                            : DesktopTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              DesktopButton(
                onPressed: _isModerator
                    ? () => _addNewDefinition(searchedWord)
                    : () => _suggestWord(searchedWord),
                label: _isModerator ? 'Шинэ хувилбар нэмэх' : 'Санал илгээх',
                variant: DesktopButtonVariant.secondary,
                isDense: true,
              ),
            ],
          ),

          if (_isModerator && rejectionHistory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: DesktopTheme.warningSurface,
                borderRadius: DesktopTheme.roundedSmall,
                border: Border.all(color: DesktopTheme.warningBorder, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    size: 16,
                    color: DesktopTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Өмнөх түүх: Энэ үгийг өмнө нь ${rejectionHistory.length} удаа татгалзсан байна '
                      '(${rejectionHistory.first['reason'] ?? 'Татгалзсан'})',
                      style: const TextStyle(fontSize: 12, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),

          // Definitions List
          if (definitions.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 36,
                      color: DesktopTheme.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"$searchedWord" үгэнд одоогоор босоо бичлэгийн хувилбар бүртгэгдээгүй байна.',
                      style: const TextStyle(color: DesktopTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    DesktopButton(
                      onPressed: _isModerator
                          ? () => _addNewDefinition(searchedWord)
                          : () => _suggestWord(searchedWord),
                      label: _isModerator
                          ? 'Толь бичигт бүртгэх'
                          : 'Санал илгээх',
                      variant: DesktopButtonVariant.primary,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: definitions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final def = definitions[index] as Map<String, dynamic>;
                  final menksoft = def['menksoft'] as String? ?? '';
                  final explanation = def['explanation'] as String?;
                  final isPrimary = def['isPrimary'] == true;
                  final latin = LatinIme.menksoftToLatin(menksoft);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DesktopTheme.canvas,
                      borderRadius: DesktopTheme.roundedSmall,
                      border: Border.all(color: DesktopTheme.border, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vertical Traditional Mongolian Script Display
                        Container(
                          width: 80,
                          height: 150,
                          decoration: BoxDecoration(
                            color: DesktopTheme.panelBackground,
                            borderRadius: DesktopTheme.roundedSmall,
                            border: Border.all(
                              color: DesktopTheme.borderMedium,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: MongolText(
                              menksoft,
                              style: const TextStyle(
                                fontSize: 32,
                                fontFamily: 'Menksoft',
                                color: DesktopTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Details & Badges
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isPrimary)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: DesktopTheme.primarySurface,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: DesktopTheme.primary
                                              .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Text(
                                        'Үндсэн утга',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: DesktopTheme.primary,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    'Хувилбар #${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: DesktopTheme.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  DesktopIconButton(
                                    icon: Icons.copy,
                                    tooltip: 'Юникод хэлбэрээр хуулах',
                                    size: 15,
                                    onPressed: () {
                                      final unicode =
                                          LatinIme.menksoftToUnicode(menksoft);
                                      Clipboard.setData(
                                        ClipboardData(text: unicode),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Юникод хэлбэрээр хууллаа',
                                          ),
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
                                      color: DesktopTheme.panelBackground,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: DesktopTheme.border,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      latin.isEmpty ? '—' : latin,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        color: DesktopTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                explanation != null && explanation.isNotEmpty
                                    ? 'Тайлбар: $explanation'
                                    : 'Ялгах тайлбар байхгүй',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      explanation != null &&
                                          explanation.isNotEmpty
                                      ? DesktopTheme.textPrimary
                                      : DesktopTheme.textMuted,
                                  fontStyle:
                                      explanation == null || explanation.isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
