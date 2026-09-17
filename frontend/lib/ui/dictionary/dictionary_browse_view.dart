import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';

import '../../services/latin_ime.dart';
import '../desktop/components/desktop_button.dart';
import '../desktop/desktop_theme.dart';
import '../dialogs/add_edit_word_dialog.dart';

class DictionaryBrowseView extends StatefulWidget {
  final String serverUrl;
  final String? authToken;
  final String? moderatorId;

  const DictionaryBrowseView({
    super.key,
    required this.serverUrl,
    this.authToken,
    this.moderatorId,
  });

  @override
  State<DictionaryBrowseView> createState() => _DictionaryBrowseViewState();
}

class _DictionaryBrowseViewState extends State<DictionaryBrowseView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;
  String? _lastSearchedWord;
  Map<String, dynamic>? _searchResult;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      final res = await http.get(
        Uri.parse('${widget.serverUrl}/admin/words/check?cyrillic=${Uri.encodeComponent(clean)}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 6));

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
        onSubmit: ({
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
                              border: Border.all(color: DesktopTheme.borderMedium, width: 1),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 13, fontFamily: null),
                              decoration: const InputDecoration(
                                hintText: 'Жишээ: монгол, төр, гол, ажил...',
                                hintStyle: TextStyle(fontSize: 13, color: DesktopTheme.textMuted),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: Icon(Icons.search, size: 18, color: DesktopTheme.textSecondary),
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
                          icon: const Icon(Icons.search, size: 14),
                          variant: DesktopButtonVariant.primary,
                          isLoading: _isSearching,
                        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: DesktopTheme.dangerSurface,
                    borderRadius: DesktopTheme.roundedSmall,
                    border: Border.all(color: DesktopTheme.dangerBorder, width: 1),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 13, color: DesktopTheme.danger),
                  ),
                ),

              // Results Area
              Expanded(
                child: _buildResultsArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
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
            Icon(Icons.search, size: 48, color: DesktopTheme.textMuted.withValues(alpha: 0.5)),
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
    final rejectionHistory = (_searchResult!['rejectionHistory'] as List?) ?? [];
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: exists ? DesktopTheme.successSurface : DesktopTheme.warningSurface,
                      borderRadius: DesktopTheme.roundedSmall,
                      border: Border.all(
                        color: exists ? DesktopTheme.successBorder : DesktopTheme.warningBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      exists ? 'Толь бичигт байна (${definitions.length})' : 'Толь бичигт байхгүй',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: exists ? DesktopTheme.success : DesktopTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
              DesktopButton(
                onPressed: () => _addNewDefinition(searchedWord),
                label: 'Шинэ хувилбар нэмэх',
                icon: const Icon(Icons.add, size: 14),
                variant: DesktopButtonVariant.secondary,
                isDense: true,
              ),
            ],
          ),

          if (rejectionHistory.isNotEmpty) ...[
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
                  const Icon(Icons.history, size: 16, color: DesktopTheme.warning),
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
                    const Icon(Icons.info_outline, size: 36, color: DesktopTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      '"$searchedWord" үгэнд одоогоор босоо бичлэгийн хувилбар бүртгэгдээгүй байна.',
                      style: const TextStyle(color: DesktopTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    DesktopButton(
                      onPressed: () => _addNewDefinition(searchedWord),
                      label: 'Толь бичигт бүртгэх',
                      icon: const Icon(Icons.add, size: 14),
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
                            border: Border.all(color: DesktopTheme.borderMedium, width: 1),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: DesktopTheme.primarySurface,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: DesktopTheme.primary.withValues(alpha: 0.3), width: 1),
                                      ),
                                      child: const Text(
                                        'Үндсэн утга',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: DesktopTheme.primary),
                                      ),
                                    ),
                                  Text(
                                    'Хувилбар #${index + 1}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesktopTheme.textSecondary),
                                  ),
                                  const Spacer(),
                                  DesktopIconButton(
                                    icon: Icons.copy,
                                    tooltip: 'Юникод хэлбэрээр хуулах',
                                    size: 15,
                                    onPressed: () {
                                      final unicode = LatinIme.menksoftToUnicode(menksoft);
                                      Clipboard.setData(ClipboardData(text: unicode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Юникод хэлбэрээр хууллаа'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Латин галиг: ', style: DesktopTheme.caption),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: DesktopTheme.panelBackground,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: DesktopTheme.border, width: 1),
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
                                  color: explanation != null && explanation.isNotEmpty
                                      ? DesktopTheme.textPrimary
                                      : DesktopTheme.textMuted,
                                  fontStyle: explanation == null || explanation.isEmpty
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
