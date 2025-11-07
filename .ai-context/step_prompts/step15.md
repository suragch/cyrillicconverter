### **Objective: Implement Step 15**

Your goal is to create the secure backend API endpoints that allow users with a 'moderator' role to review, approve, and reject community submissions. This involves enhancing the authentication middleware to check for roles, creating a new service to handle the business logic, and defining the new API routes.

This implementation will heavily rely on database transactions to ensure data integrity and prevent race conditions.

### 👉 **Part 1: Enhance Middleware for Role-Based Authorization**

The existing JWT middleware only validates a token. You need to upgrade it to check for a specific user role, which is a prerequisite for securing the moderation endpoints.

**File to Edit:** `backend/api/lib/auth_middleware.dart`

**Instructions:**
1.  Refactor the existing middleware into a higher-order function named `createAuthMiddleware` that can optionally accept a `requiredRole`.
2.  Inside the middleware, after validating the JWT, decode its payload.
3.  Check for a specific claim that identifies a moderator. Based on the technical specification, PocketBase will manage users, so we'll assume the JWT payload contains a custom field like `'is_moderator': true`.
4.  If a `requiredRole` is specified and the user's token does not satisfy that role, return a `403 Forbidden` response.

```dart
// backend/api/lib/auth_middleware.dart

import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Assume you have a way to get your JWT secret
const jwtSecret = 'YOUR_POCKETBASE_JWT_SECRET'; // IMPORTANT: Load from .env

Middleware createAuthMiddleware({String? requiredRole}) {
  return (Handler innerHandler) {
    return (Request request) {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized('Missing or invalid Authorization header.');
      }

      final token = authHeader.substring(7);

      try {
        // Verify the token
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        final payload = jwt.payload as Map<String, dynamic>;

        // Role check
        if (requiredRole == 'moderator') {
          // PocketBase JWTs often contain custom fields in the payload.
          // We check for the `is_moderator` flag we defined in the spec.
          final isModerator = payload['is_moderator'] as bool? ?? false;
          if (!isModerator) {
            return Response.forbidden('Access denied. Moderator role required.');
          }
        }
        
        // Add user info to the request context to be used by handlers
        final updatedRequest = request.change(context: {
          'user_id': payload['id'],
          'is_moderator': payload['is_moderator'] ?? false,
        });

        return innerHandler(updatedRequest);
      } on JWTExpiredException {
        return Response.unauthorized('Token expired.');
      } on JWTException catch (err) {
        return Response.unauthorized('Invalid token: ${err.message}');
      } catch (e) {
        return Response.internalServerError(body: 'An unexpected error occurred.');
      }
    };
  };
}
```

### 👉 **Part 2: Create the Moderation Service**

Create a new service file to contain all the business logic for moderation actions. This service will interact directly with the PostgreSQL database.

**File to Create:** `backend/api/lib/moderation_service.dart`

**Instructions:**
1.  Create the new file.
2.  Define a `ModerationService` class that takes a `PostgreSQLConnection` in its constructor.
3.  Implement methods to fetch pending submissions (`getPendingConversions`, `getPendingExpansions`). These will be used by the moderation dashboard.
4.  Implement the core action methods: `approveConversion`, `rejectConversion`, `approveExpansion`, and `rejectExpansion`.
5.  **Crucially, use database transactions (`db.transaction(...)`) for all approval/rejection methods.** Within the transaction, you must:
    a.  Select the current `approval_count` for the item, locking the row with `FOR UPDATE` to prevent race conditions.
    b.  Calculate the new count and determine the new status based on the rules in the technical spec.
    c.  Update the item in the `TraditionalConversions` or `Expansions` table.
    d.  Insert a record into the `ModeratorActions` table to log the action.

```dart
// backend/api/lib/moderation_service.dart

import 'package:postgres/postgres.dart';

class ModerationService {
  final PostgreSQLConnection db;

  ModerationService(this.db);

  // Method to fetch pending conversions for the dashboard
  Future<List<Map<String, dynamic>>> getPendingConversions() async {
    final results = await db.query(
      '''
      SELECT tc.conversion_id, cw.cyrillic_word, tc.traditional, tc.context, tc.approval_count
      FROM TraditionalConversions tc
      JOIN CyrillicWords cw ON tc.word_id = cw.word_id
      WHERE tc.status = 'pending'
      ORDER BY tc.created_at ASC
      LIMIT 100;
      '''
    );
    return results.map((row) => row.toColumnMap()).toList();
  }

  // Method to approve a conversion
  Future<Map<String, dynamic>> approveConversion(int conversionId, String moderatorId) async {
    return await _updateConversionStatus(conversionId, moderatorId, 1, 'approve');
  }

  // Method to reject a conversion
  Future<Map<String, dynamic>> rejectConversion(int conversionId, String moderatorId) async {
    return await _updateConversionStatus(conversionId, moderatorId, -1, 'reject');
  }
  
  // Private helper method that contains the transactional logic
  Future<Map<String, dynamic>> _updateConversionStatus(int conversionId, String moderatorId, int vote, String actionType) async {
    return await db.transaction((ctx) async {
      // 1. Lock the row and get the current count
      final result = await ctx.query(
        'SELECT approval_count FROM TraditionalConversions WHERE conversion_id = @id FOR UPDATE',
        substitutionValues: {'id': conversionId},
      );
      if (result.isEmpty) {
        throw Exception('Conversion not found');
      }
      final currentCount = result.first.first as int;
      final newCount = currentCount + vote;

      // 2. Determine the new status based on spec rules
      String newStatus = 'pending';
      if (newCount >= 5) {
        newStatus = 'accepted';
      } else if (newCount >= 1) {
        newStatus = 'probation';
      } else if (newCount <= -3) {
        newStatus = 'rejected';
      }

      // 3. Update the conversion record
      await ctx.execute(
        '''
        UPDATE TraditionalConversions 
        SET approval_count = @count, status = @status, updated_at = NOW() 
        WHERE conversion_id = @id
        ''',
        substitutionValues: {'count': newCount, 'status': newStatus, 'id': conversionId},
      );

      // 4. Log the moderation action
      await ctx.execute(
        '''
        INSERT INTO ModeratorActions (conversion_id, moderator_id, action_type, timestamp)
        VALUES (@conversionId, @moderatorId, @actionType, NOW())
        ''',
        substitutionValues: {
          'conversionId': conversionId,
          'moderatorId': moderatorId,
          'actionType': actionType,
        },
      );

      return {'conversion_id': conversionId, 'new_approval_count': newCount, 'new_status': newStatus};
    });
  }

  // NOTE: You would implement similar methods for expansions:
  // getPendingExpansions(), approveExpansion(), rejectExpansion()
}
```

### 👉 **Part 3: Add the Moderation Endpoints to the API Router**

Finally, wire up the new service and middleware in your main router file.

**File to Edit:** `backend/api/lib/api_router.dart`

**Instructions:**
1.  Import the `ModerationService` and the `createAuthMiddleware` function.
2.  Instantiate the moderation service.
3.  Create an instance of the `moderatorMiddleware` by calling `createAuthMiddleware(requiredRole: 'moderator')`.
4.  Create a new `Router` for the moderation endpoints.
5.  Define all the required `GET` and `POST` routes, linking them to the appropriate methods in your `ModerationService`.
6.  Mount this new router at the `/api/moderation` path and protect the entire group with the `moderatorMiddleware`.

```dart
// backend/api/lib/api_router.dart

import 'package:shelf/shelf.dart';
import 'package.shelf_router/shelf_router.dart';
import 'dart:convert';
import 'moderation_service.dart'; // Import the new service
import 'auth_middleware.dart';    // Import the middleware

class ApiRouter {
  final ModerationService moderationService; // Add service
  // ... other services

  ApiRouter(this.moderationService /*, ... */);

  Handler get handler {
    final router = Router();
    
    // --- Existing public routes ---
    router.post('/conversions', _addConversionHandler);
    // ... other public routes

    // --- Moderation Routes ---
    final moderationRouter = Router();

    // GET endpoints to fetch pending items
    moderationRouter.get('/conversions/pending', (Request request) async {
        final items = await moderationService.getPendingConversions();
        return Response.ok(jsonEncode(items));
    });
    // TODO: Add GET /expansions/pending handler

    // POST endpoints for actions
    moderationRouter.post('/conversion/<id>/approve', (Request request, String id) async {
      final conversionId = int.tryParse(id);
      final moderatorId = request.context['user_id'] as String;
      if (conversionId == null) return Response.badRequest(body: 'Invalid ID');

      try {
        final result = await moderationService.approveConversion(conversionId, moderatorId);
        return Response.ok(jsonEncode(result));
      } catch (e) {
        return Response.notFound(body: e.toString());
      }
    });

    moderationRouter.post('/conversion/<id>/reject', (Request request, String id) async {
       final conversionId = int.tryParse(id);
       final moderatorId = request.context['user_id'] as String;
       if (conversionId == null) return Response.badRequest(body: 'Invalid ID');

       try {
         final result = await moderationService.rejectConversion(conversionId, moderatorId);
         return Response.ok(jsonEncode(result));
       } catch (e) {
         return Response.notFound(body: e.toString());
       }
    });

    // TODO: Add handlers for /expansion/<id>/approve and /expansion/<id>/reject

    // Mount the moderation router and protect it with the role-based middleware
    final moderatorMiddleware = createAuthMiddleware(requiredRole: 'moderator');
    router.mount('/moderation', moderationRouter, middleware: moderatorMiddleware);
    
    return router;
  }
  
  // ... existing handlers
}
```