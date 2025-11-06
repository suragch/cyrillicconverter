// backend/api/lib/database.dart
import 'dart:io';
import 'package:postgres/postgres.dart';

class DatabaseService {
  late final Pool _pool;

  Future<void> start() async {
    _pool = Pool.withEndpoints([
      Endpoint(
        host: Platform.environment['DB_HOST'] ?? 'localhost',
        port: int.parse(Platform.environment['DB_PORT'] ?? '5432'),
        database: Platform.environment['DB_NAME']!,
        username: Platform.environment['DB_USER']!,
        password: Platform.environment['DB_PASSWORD']!,
      ),
    ]);
  }

  Future<void> close() async {
    await _pool.close();
  }

  // Provide a way to access the pool
  Pool get pool => _pool;
}
