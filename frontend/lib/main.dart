import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'token.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('user_overrides');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyrillic Converter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Menksoft', // Default font for the app
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
  final TextEditingController _controller = TextEditingController();
  List<Token> _tokens = [];
  bool _isLoading = false;
  String? _error;
  final Box _overridesBox = Hive.box('user_overrides');

  Future<void> _convert() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _tokens = [];
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/convert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': _controller.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tokenList = data['tokens'];
        setState(() {
          _tokens = tokenList.map((json) => Token.fromJson(json)).toList();
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFixDialog(Token token) {
    final TextEditingController fixController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Fix "${token.original}"'),
          content: TextField(
            controller: fixController,
            decoration: const InputDecoration(labelText: 'Menksoft Code'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _overridesBox.put(token.original, fixController.text);
                setState(() {}); // Re-render to apply override
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAmbiguityMenu(BuildContext context, Token token, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: token.options.map((option) {
        return PopupMenuItem(
          value: option.menksoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MongolText(option.menksoft, style: const TextStyle(fontSize: 20)),
              if (option.explanation != null)
                Text(option.explanation!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        _overridesBox.put(token.original, value);
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cyrillic to Traditional Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter Cyrillic Text',
                border: OutlineInputBorder(),
              ),
              // Ensure input is horizontal and uses default system font (not Menksoft)
              style: const TextStyle(fontFamily: null), 
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _convert,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Convert'),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                // Vertical Rendering Area
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: MongolText.rich(
                    TextSpan(
                      children: _tokens.expand((token) {
                        List<TextSpan> spans = [];
                        
                        if (token.type == 'space') {
                          // Use Mongolian vowel separator for proper spacing in vertical text
                          spans.add(const TextSpan(
                            text: ' ',  // Mongolian Vowel Separator - provides word spacing
                            style: TextStyle(fontSize: 24, fontFamily: 'Menksoft'),
                          ));
                          return spans;
                        }
                        
                        // Check override first
                        String? override = _overridesBox.get(token.original);
                        String textToDisplay = override ?? '';
                        bool isAmbiguous = token.options.length > 1;
                        bool isUnknown = token.type == 'unknown';

                        if (override == null) {
                          if (token.options.isNotEmpty) {
                             // Find default or first
                             final def = token.options.firstWhere((o) => o.isDefault, orElse: () => token.options.first);
                             textToDisplay = def.menksoft;
                          } else {
                            textToDisplay = token.original;
                          }
                        }

                        spans.add(TextSpan(
                          text: textToDisplay,
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Menksoft',
                            color: isUnknown && override == null ? Colors.red : Colors.black,
                            decoration: isUnknown && override == null 
                                ? TextDecoration.underline 
                                : (isAmbiguous && override == null 
                                    ? TextDecoration.underline 
                                    : null),
                            decorationColor: isUnknown && override == null ? Colors.red : Colors.blue,
                            decorationStyle: isUnknown && override == null 
                                ? TextDecorationStyle.wavy 
                                : TextDecorationStyle.solid,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTapUp = (details) {
                              if (isAmbiguous) {
                                _showAmbiguityMenu(context, token, details.globalPosition);
                              } else {
                                _showFixDialog(token);
                              }
                            },
                        ));
                        
                        return spans;
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
