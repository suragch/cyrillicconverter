import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final app = Router();

  app.get('/ping', (Request request) {
    return Response.ok('pong');
  });

  app.all('/<ignored|.*>', (Request request) {
    return Response.ok('Request for "${request.url}"\n');
  });

  final handler = const Pipeline().addHandler(app);

  final server = await io.serve(handler, '0.0.0.0', 8080);

  print('Server listening on port ${server.port}');
}
