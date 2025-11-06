You are an expert backend developer specializing in Dart and PostgreSQL. Your task is to complete Step 13 of the project plan by implementing the API endpoints required to receive new word contributions from the frontend.

**Step 13: Implement Contribution API Endpoints**

**Task:**
Create a `POST /api/conversions` endpoint in the Dart Shelf API. This endpoint will receive a JSON payload containing a Cyrillic word and its proposed Traditional Mongolian translation, validate the data, and insert it into the PostgreSQL database with a `pending` status.

**Instructions:**

1.  **Add PostgreSQL Dependency:**
    *   Open the `backend/api/pubspec.yaml` file.
    *   Add the `postgres` package to your dependencies.
    ```yaml
    dependencies:
      # ... other dependencies
      postgres: ^2.6.1 # Use the latest version
    ```
    *   Run `dart pub get` inside the `backend/api` directory to install it.

2.  **Set Up Database Connection:**
    *   Create a new file at `backend/api/lib/database.dart`. This module will manage the database connection pool.
    *   Read database credentials from environment variables.

    ```dart
    // backend/api/lib/database.dart
    import 'dart:io';
    import 'package:postgres/postgres.dart';

    class DatabaseService {
      late final Pool _pool;

      Future<void> connect() async {
        _pool = Pool.open(
          Endpoint(
            host: Platform.environment['DB_HOST'] ?? 'localhost',
            port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
            database: Platform.environment['DB_NAME']!,
            username: Platform.environment['DB_USER']!,
            password: Platform.environment['DB_PASSWORD']!,
          ),
          settings: const PoolSettings(maxConnectionCount: 4),
        );
        print('Database connection pool established.');
      }

      // Provide a way to access the pool
      Pool get pool => _pool;
    }
    ```

3.  **Create a Data Model for the Payload:**
    *   Create a new file at `backend/api/lib/models/conversion_model.dart`.
    *   This class will represent the incoming JSON data.

    ```dart
    // backend/api/lib/models/conversion_model.dart
    class Contribution {
      final String cyrillicWord;
      final String menksoft;
      final String? context;

      Contribution({
        required this.cyrillicWord,
        required this.menksoft,
        this.context,
      });

      factory Contribution.fromJson(Map<String, dynamic> json) {
        if (json['cyrillic_word'] == null || json['menksoft'] == null) {
          throw FormatException('Missing required fields: cyrillic_word, menksoft');
        }
        return Contribution(
          cyrillicWord: json['cyrillic_word'] as String,
          menksoft: json['menksoft'] as String,
          context: json['context'] as String?,
        );
      }
    }
    ```

4.  **Create the Contribution Service:**
    *   Create a new file at `backend/api/lib/services/contribution_service.dart`.
    *   This service will contain the core business logic for saving the contribution to the database.

    ```dart
    // backend/api/lib/services/contribution_service.dart
    import 'package:postgres/postgres.dart';
    import '../models/conversion_model.dart';

    class ContributionService {
      final Pool _pool;
      ContributionService(this._pool);

      Future<void> createConversion(Contribution contribution) async {
        await _pool.use((connection) async {
          // Use a transaction to ensure atomicity
          await connection.transaction((tx) async {
            // Step 1: Find or create the Cyrillic word
            final result = await tx.execute(
              Sql.named('SELECT word_id FROM "CyrillicWords" WHERE cyrillic_word = @word'),
              parameters: {'word': contribution.cyrillicWord},
            );

            int wordId;
            if (result.isEmpty) {
              // Not found, so insert it
              final insertResult = await tx.execute(
                Sql.named('INSERT INTO "CyrillicWords" (cyrillic_word) VALUES (@word) RETURNING word_id'),
                parameters: {'word': contribution.cyrillicWord},
              );
              wordId = insertResult.single.first as int;
            } else {
              wordId = result.single.first as int;
            }

            // Step 2: Insert the new TraditionalConversion
            // Use ON CONFLICT DO NOTHING to prevent errors if the exact same pair is submitted twice
            await tx.execute(
              Sql.named('''
                INSERT INTO "TraditionalConversions" (word_id, traditional, context, status)
                VALUES (@wordId, @menksoft, @context, 'pending')
                ON CONFLICT (word_id, traditional) DO NOTHING
              '''),
              parameters: {
                'wordId': wordId,
                'menksoft': contribution.menksoft,
                'context': contribution.context,
              },
            );
          });
        });
      }
    }
    ```

5.  **Update the Server and Router:**
    *   Modify `backend/api/bin/server.dart` to initialize the database and the new service, and to create the new endpoint.

    ```dart
    // backend/api/bin/server.dart
    import 'dart:convert';
    import 'package:shelf/shelf.dart';
    import 'package:shelf/shelf_io.dart' as io;
    import 'package:shelf_router/shelf_router.dart';
    
    // ... other imports
    import '../lib/database.dart';
    import '../lib/models/conversion_model.dart';
    import '../lib/services/contribution_service.dart';

    void main() async {
      // 1. Initialize Database
      final dbService = DatabaseService();
      await dbService.connect();

      // 2. Initialize Services
      final contributionService = ContributionService(dbService.pool);
      
      final app = Router();
      // ... (existing /ping and protected routes)

      // --- New Contribution Endpoint ---
      app.post('/api/conversions', (Request request) async {
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
      });
      
      // ... (Start the server as before)
      final server = await io.serve(app, '0.0.0.0', 8080);
      print('Server listening on port ${server.port}');
    }
    ```

Execute the plan. The server will need to be restarted with the correct database environment variables for the changes to take effect.