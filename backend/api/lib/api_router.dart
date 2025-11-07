
// backend/api/lib/api_router.dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth_middleware.dart';
import 'moderation_service.dart';
import 'services/contribution_service.dart';
import 'models/conversion_model.dart';

class ApiRouter {
  final ModerationService moderationService;
  final ContributionService contributionService;

  ApiRouter(this.moderationService, this.contributionService);

  Handler get handler {
    final router = Router();

    // --- Public Routes ---
    router.get('/ping', (Request request) {
        return Response.ok('pong');
    });

    // --- API Routes ---
    final apiRouter = Router();
    apiRouter.post('/conversions', _addConversionHandler);

    // --- Moderation Routes ---
    final moderationRouter = Router();

    moderationRouter.get('/conversions/pending', (Request request) async {
        final items = await moderationService.getPendingConversions();
        return Response.ok(jsonEncode(items));
    });
    // TODO: Add GET /expansions/pending handler

    moderationRouter.post('/conversions/<id>/approve', (Request request, String id) async {
      final conversionId = int.tryParse(id);
      // The user_id is expected to be in the context from the middleware
      final moderatorId = request.context['user_id'] as String?;
      if (conversionId == null) return Response.badRequest(body: 'Invalid ID');
      if (moderatorId == null) return Response.unauthorized('Not authenticated');

      try {
        final result = await moderationService.approveConversion(conversionId, moderatorId);
        return Response.ok(jsonEncode(result));
      } catch (e) {
        return Response.notFound(e.toString());
      }
    });

    moderationRouter.post('/conversions/<id>/reject', (Request request, String id) async {
       final conversionId = int.tryParse(id);
       final moderatorId = request.context['user_id'] as String?;
       if (conversionId == null) return Response.badRequest(body: 'Invalid ID');
       if (moderatorId == null) return Response.unauthorized('Not authenticated');

       try {
         final result = await moderationService.rejectConversion(conversionId, moderatorId);
         return Response.ok(jsonEncode(result));
       } catch (e) {
         return Response.notFound(e.toString());
       }
    });

    // TODO: Add handlers for /expansion/<id>/approve and /expansion/<id>/reject

    final moderatorMiddleware = createAuthMiddleware(requiredRole: 'moderator');
    apiRouter.mount('/moderation', const Pipeline().addMiddleware(moderatorMiddleware).addHandler(moderationRouter.call));
    
    router.mount('/api', apiRouter.call);

    return router;
  }

  Future<Response> _addConversionHandler(Request request) async {
    try {
      final bodyString = await request.readAsString();
      final json = jsonDecode(bodyString) as Map<String, dynamic>;
      final contribution = Contribution.fromJson(json);

      await contributionService.createConversion(contribution);

      return Response(
        201, // Created
        body: jsonEncode({'status': 'success', 'message': 'Contribution received.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on FormatException catch (e) {
      return Response.badRequest(body: e.message);
    } catch (e) {
      print('Error processing contribution: $e');
      return Response.internalServerError(body: 'An unexpected error occurred.');
    }
  }
}
