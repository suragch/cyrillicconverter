

// backend/api/lib/moderation_service.dart



class ModerationService {
  final dynamic db;

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
        VALUES ( @conversionId, @moderatorId, @actionType, NOW())
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