import 'package:test/test.dart';
import '../../lib/models/conversion_model.dart';

void main() {
  group('Contribution', () {
    test('can be created from JSON', () {
      final json = {
        'cyrillic_word': 'слово',
        'menksoft': 'sülüg',
        'context': 'контекст',
      };

      final contribution = Contribution.fromJson(json);

      expect(contribution.cyrillicWord, 'слово');
      expect(contribution.menksoft, 'sülüg');
      expect(contribution.context, 'контекст');
    });

    test('throws FormatException if required fields are missing', () {
      final json = {
        'context': 'контекст',
      };

      expect(() => Contribution.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
