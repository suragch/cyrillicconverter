// backend/api/lib/services/contribution_service.dart
import 'package:postgres/postgres.dart';
import '../models/conversion_model.dart';

class ContributionService {
  final Pool _pool;
  ContributionService(this._pool);

  Future<void> createConversion(Contribution contribution) async {
    await _pool.runTx((session) async {
      // Use a transaction to ensure atomicity
      // Step 1: Find or create the Cyrillic word
      final result = await session.execute(
        Sql.named('SELECT word_id FROM "CyrillicWords" WHERE cyrillic_word = @word'),
        parameters: {'word': contribution.cyrillicWord},
      );

      int wordId;
      if (result.isEmpty) {
        // Not found, so insert it
        final insertResult = await session.execute(
          Sql.named('INSERT INTO "CyrillicWords" (cyrillic_word) VALUES ( @word) RETURNING word_id'),
          parameters: {'word': contribution.cyrillicWord},
        );
        wordId = insertResult.single.first as int;
      } else {
        wordId = result.single.first as int;
      }

      // Step 2: Insert the new TraditionalConversion
      // Use ON CONFLICT DO NOTHING to prevent errors if the exact same pair is submitted twice
      await session.execute(
        Sql.named('''
              INSERT INTO "TraditionalConversions" (word_id, traditional, context, status)
              VALUES ( @wordId, @menksoft, @context, \'pending\')
              ON CONFLICT (word_id, traditional) DO NOTHING
            '''),
        parameters: {
          'wordId': wordId,
          'menksoft': contribution.menksoft,
          'context': contribution.context,
        },
      );
    });
  }
}
