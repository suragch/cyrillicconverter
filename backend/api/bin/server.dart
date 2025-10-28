import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final handler = const Pipeline().addHandler(_echoRequest);

  final server = await io.serve(handler, '0.0.0.0', 8080);

  print('Server listening on port ${server.port}');
}

Response _echoRequest(Request request) {
  return Response.ok('Request for "${request.url}"\n');
}

