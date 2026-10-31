import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthContext {
  final RecordModel? user;
  final bool isModerator;
  final bool isAdmin;
  final String? token;

  const AuthContext({
    this.user,
    this.isModerator = false,
    this.isAdmin = false,
    this.token,
  });
}

Middleware pocketBaseAuth({String pbUrl = 'https://cyrillic.suragch.dev'}) {
  return (Handler innerHandler) {
    return (Request request) async {
      String? token;
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7).trim();
      }

      if (token == null || token.isEmpty) {
        return innerHandler(
          request.change(context: {'auth': const AuthContext()}),
        );
      }

      // Allow test admin token if set in environment (for unit & integration tests)
      final testAdminToken = Platform.environment['TEST_ADMIN_TOKEN'];
      if (testAdminToken != null &&
          testAdminToken.isNotEmpty &&
          token == testAdminToken) {
        return innerHandler(
          request.change(
            context: {
              'auth': AuthContext(
                user: RecordModel({
                  'id': 'test-admin',
                  'email': 'admin@test.com',
                  'role': 'admin',
                }),
                isModerator: true,
                isAdmin: true,
                token: token,
              ),
            },
          ),
        );
      }

      // Allow test moderator token if set in environment (for unit & integration tests)
      final testModToken = Platform.environment['TEST_MODERATOR_TOKEN'];
      if (testModToken != null &&
          testModToken.isNotEmpty &&
          token == testModToken) {
        return innerHandler(
          request.change(
            context: {
              'auth': AuthContext(
                user: RecordModel({
                  'id': 'test-moderator',
                  'email': 'moderator@test.com',
                  'role': 'moderator',
                }),
                isModerator: true,
                isAdmin: false,
                token: token,
              ),
            },
          ),
        );
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
          return await innerHandler(
            request.change(context: {'auth': const AuthContext()}),
          );
        }

        final user = authRecord.record;
        final rawRole = (user.data['role'] as String?)?.trim() ?? '';
        final role = rawRole.isNotEmpty
            ? rawRole
            : (isSuperuser ? 'admin' : '');
        final isAdmin = isSuperuser || role == 'admin';
        // Superusers or designated moderators/admins have moderator privileges
        final isModerator = isAdmin || role == 'moderator';

        return await innerHandler(
          request.change(
            context: {
              'auth': AuthContext(
                user: user,
                isModerator: isModerator,
                isAdmin: isAdmin,
                token: authRecord.token,
              ),
            },
          ),
        );
      } catch (e) {
        return innerHandler(
          request.change(context: {'auth': const AuthContext()}),
        );
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

Handler requireAdmin(Handler innerHandler) {
  return (Request request) {
    final auth = request.context['auth'] as AuthContext?;
    if (auth == null || !auth.isAdmin) {
      return Response.forbidden(
        jsonEncode({'error': 'Admin privileges required'}),
        headers: {'content-type': 'application/json'},
      );
    }
    return innerHandler(request);
  };
}
