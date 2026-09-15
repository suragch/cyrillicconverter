import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import '../dialogs/add_edit_word_dialog.dart';

class ModeratorPage extends StatefulWidget {
  final String serverUrl;
  final String? authToken;

  const ModeratorPage({
    super.key,
    required this.serverUrl,
    this.authToken,
  });

  @override
  State<ModeratorPage> createState() => _ModeratorPageState();
}

class _ModeratorPageState extends State<ModeratorPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _missingWords = [];
  List<dynamic> _suggestions = [];
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final missingRes = await http.get(
        Uri.parse('${widget.serverUrl}/admin/missing?limit=100'),
        headers: _headers,
      );
      final suggRes = await http.get(
        Uri.parse('${widget.serverUrl}/admin/suggestions?limit=100'),
        headers: _headers,
      );

      if (missingRes.statusCode == 200 && suggRes.statusCode == 200) {
        final missingData = jsonDecode(missingRes.body);
        final suggData = jsonDecode(suggRes.body);

        setState(() {
          _missingWords = missingData['missing'] ?? [];
          _suggestions = suggData['suggestions'] ?? [];
        });
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

  Future<void> _approveSuggestion(int id) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/suggestions/approve'),
        headers: _headers,
        body: jsonEncode({'id': id}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Амжилттай баталлаа'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectSuggestion(int id) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverUrl}/admin/suggestions/reject'),
        headers: _headers,
        body: jsonEncode({'id': id, 'reason': 'rejected by moderator'}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Татгалзлаа'), backgroundColor: Colors.orange),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа: $e'), backgroundColor: Colors.red),
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
      }),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Үг толь бичигт нэмэгдлээ'), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Модераторын хяналтын самбар'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.warning_amber),
              text: 'Дутуу үгс (${_missingWords.length})',
            ),
            Tab(
              icon: const Icon(Icons.rate_review),
              text: 'Хэрэглэгчийн саналууд (${_suggestions.length})',
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
                    _buildMissingWordsTab(),
                    _buildSuggestionsTab(),
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
    );
  }

  Widget _buildMissingWordsTab() {
    if (_missingWords.isEmpty) {
      return const Center(child: Text('Дутуу үг бүртгэгдээгүй байна'));
    }

    return ListView.separated(
      itemCount: _missingWords.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _missingWords[index];
        final cyrillic = item['cyrillic'] as String;
        final freq = item['frequency'] as int;
        final lastContext = item['last_context'] as String?;

        return ListTile(
          title: Row(
            children: [
              Text(
                cyrillic,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text('$freq удаа хайгдсан'),
                backgroundColor: freq > 3 ? Colors.red.shade100 : Colors.grey.shade200,
              ),
            ],
          ),
          subtitle: lastContext != null && lastContext.isNotEmpty
              ? Text('Жишээ: "...$lastContext..."')
              : null,
          trailing: ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Тодорхойлох'),
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
        );
      },
    );
  }

  Widget _buildSuggestionsTab() {
    if (_suggestions.isEmpty) {
      return const Center(child: Text('Хянагдах санал одоогоор байхгүй байна'));
    }

    return ListView.separated(
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _suggestions[index];
        final id = item['id'] as int;
        final cyrillic = item['cyrillic'] as String;
        final menksoft = item['menksoft_code'] as String;
        final contextText = item['context'] as String?;

        return ListTile(
          leading: Container(
            width: 40,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: MongolText(
              menksoft,
              style: const TextStyle(fontSize: 20, fontFamily: 'Menksoft'),
            ),
          ),
          title: Text(
            cyrillic,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: contextText != null && contextText.isNotEmpty
              ? Text('Тайлбар: $contextText')
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'Батлах',
                onPressed: () => _approveSuggestion(id),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Татгалзах',
                onPressed: () => _rejectSuggestion(id),
              ),
            ],
          ),
        );
      },
    );
  }
}
