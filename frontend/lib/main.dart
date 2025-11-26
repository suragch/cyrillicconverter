import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mongol/mongol.dart';
import 'token.dart';

void main() {
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _tokens.map((token) {
                      // For now, just pick the first option or original if unknown
                      String textToDisplay = token.original;
                      if (token.type == 'word' && token.options.isNotEmpty) {
                        textToDisplay = token.options.first;
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: MongolText(
                          textToDisplay,
                          style: TextStyle(
                            fontSize: 24,
                            fontFamily: 'Menksoft',
                            color: token.type == 'unknown' ? Colors.red : Colors.black,
                            decoration: token.type == 'unknown' ? TextDecoration.underline : null,
                            decorationColor: Colors.red,
                            decorationStyle: TextDecorationStyle.wavy,
                          ),
                        ),
                      );
                    }).toList(),
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
