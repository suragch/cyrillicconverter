import 'dart:convert';
import 'dart:io';
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
      String? token;
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7).trim();
      } else if (request.url.queryParameters.containsKey('token')) {
        token = request.url.queryParameters['token']?.trim();
      }

      if (token == null || token.isEmpty) {
        return innerHandler(request.change(context: {'auth': const AuthContext()}));
      }

      // Allow test moderator token if set in environment (for unit & integration tests)
      final testModToken = Platform.environment['TEST_MODERATOR_TOKEN'];
      if (testModToken != null && testModToken.isNotEmpty && token == testModToken) {
        return innerHandler(request.change(context: {
          'auth': AuthContext(
            user: RecordModel({'id': 'test-moderator', 'email': 'moderator@test.com', 'role': 'moderator'}),
            isModerator: true,
            token: token,
          ),
        }));
      }

      try {
        final pb = PocketBase(pbUrl);
        pb.authStore.save(token, null);
        RecordAuth? authRecord;
        bool isSuperuser = false;

        try {
          authRecord = await pb.collection('users').authRefresh();
        } catch (_) {
          try {
            authRecord = await pb.collection('_superusers').authRefresh();
            isSuperuser = true;
          } catch (_) {}
        }

        if (authRecord == null) {
          return await innerHandler(request.change(context: {'auth': const AuthContext()}));
        }

        final user = authRecord.record;
        final role = user.data['role'] as String? ?? (isSuperuser ? 'admin' : '');
        // Superusers or designated moderators/admins have moderator privileges
        final isModerator = isSuperuser || role == 'moderator' || role == 'admin';

        return await innerHandler(request.change(context: {
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
