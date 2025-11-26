import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

// Configure routes.
final _router = Router()
  ..post('/echo', _echoHandler)
  ..post('/convert', _convertHandler);

Future<Response> _echoHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content);
    return Response.ok(
      jsonEncode({'received': json['text']}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return Response.badRequest(body: 'Invalid JSON');
  }
}

Future<Response> _convertHandler(Request request) async {
  final content = await request.readAsString();
  try {
    final json = jsonDecode(content);
    final text = json['text'] as String;
    
    // Mock Logic:
    // If input is "Монгол", return Menksoft code for Mongol.
    // Otherwise return unknown.
    // For now, let's just return a hardcoded list for "Монгол"
    
    final List<Map<String, dynamic>> tokens = [];
    
    if (text.contains('Монгол')) {
      tokens.add({
        'type': 'word',
        'original': 'Монгол',
        'options': ['\u182E\u1823\u1829\u182D\u1823\u182F'] // Menksoft code for Mongol (approximate for mock)
      });
    } else {
       tokens.add({
        'type': 'unknown',
        'original': text,
        'options': []
      });
    }

    return Response.ok(
      jsonEncode({'tokens': tokens}),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    print(e);
    return Response.badRequest(body: 'Invalid JSON or Server Error');
  }
}

// Manual CORS Middleware
Middleware corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });
      }
      final response = await handler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
      });
    };
  };
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware()) // Add CORS headers
      .addHandler(_router.call);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
