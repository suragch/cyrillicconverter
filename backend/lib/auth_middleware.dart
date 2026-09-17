import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthContext {
  final RecordModel? user;
  final bool isModerator;
  final String? token;

  const AuthContext({this.user, this.isModerator = false, this.token});
}

Middleware pocketBaseAuth({String pbUrl = 'https://cyrillic.suragch.dev'}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return innerHandler(request.change(context: {'auth': const AuthContext()}));
      }

      final token = authHeader.substring(7).trim();
      if (token.isEmpty) {
        return innerHandler(request.change(context: {'auth': const AuthContext()}));
      }

      try {
        final pb = PocketBase(pbUrl);
        pb.authStore.save(token, null);
        final authRecord = await pb.collection('users').authRefresh();
        final user = authRecord.record;
        final role = user.data['role'] as String? ?? '';
        // If user is valid and role is moderator/admin (or any authenticated user if role not explicitly set)
        final isModerator = role == 'moderator' || role == 'admin' || user != null;

        return innerHandler(request.change(context: {
          'auth': AuthContext(
            user: user,
            isModerator: isModerator,
            token: authRecord.token,
          ),
        }));
      } catch (e) {
        return innerHandler(request.change(context: {'auth': const AuthContext()}));
      }
    };
  };
}

Handler requireModerator(Handler innerHandler) {
  return (Request request) {
    final auth = request.context['auth'] as AuthContext?;
    if (auth == null || !auth.isModerator) {
      return Response.forbidden(
        jsonEncode({'error': 'Moderator authentication required'}),
        headers: {'content-type': 'application/json'},
      );
    }
    return innerHandler(request);
  };
}
