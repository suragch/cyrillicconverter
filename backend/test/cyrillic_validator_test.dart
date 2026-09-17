import 'package:backend/cyrillic_validator.dart';
import 'package:test/test.dart';

void main() {
  group('CyrillicValidator Tests', () {
    test('Accepts standard Cyrillic words', () {
      expect(CyrillicValidator.isCyrillicWord('монгол'), true);
      expect(CyrillicValidator.isCyrillicWord('хөрвүүлэгч'), true);
      expect(CyrillicValidator.isCyrillicWord('мазаалай'), true);
      expect(CyrillicValidator.isCyrillicWord('хөх-ногоон'), true);
      expect(CyrillicValidator.isCyrillicWord('ном-а'), true);
    });

    test('Accepts single letters and consonant acronyms', () {
      expect(CyrillicValidator.isCyrillicWord('в'), true);
      expect(CyrillicValidator.isCyrillicWord('г'), true);
      expect(CyrillicValidator.isCyrillicWord('а'), true);
      expect(CyrillicValidator.isCyrillicWord('УИХ'), true);
      expect(CyrillicValidator.isCyrillicWord('ХХК'), true);
      expect(CyrillicValidator.isCyrillicWord('МХЕГ'), true);
      expect(CyrillicValidator.isCyrillicWord('бвгд'), true);
    });

    test('Rejects Latin characters, digits, and mixed scripts', () {
      expect(CyrillicValidator.isCyrillicWord('mongol'), false);
      expect(CyrillicValidator.isCyrillicWord('сайн123'), false);
      expect(CyrillicValidator.isCyrillicWord('12345'), false);
      // 'хoх' where the middle 'o' is Latin letter 'o' (0x6F) instead of Cyrillic 'о' (0x43E)
      expect(CyrillicValidator.isCyrillicWord('х\u006Fх'), false);
    });

    test('Rejects URLs, symbols, emails, and whitespace', () {
      expect(CyrillicValidator.isCyrillicWord('https://example.com'), false);
      expect(CyrillicValidator.isCyrillicWord('user@domain.mn'), false);
      expect(CyrillicValidator.isCyrillicWord('#монгол'), false);
      expect(CyrillicValidator.isCyrillicWord(''), false);
      expect(CyrillicValidator.isCyrillicWord('   '), false);
      expect(CyrillicValidator.isCyrillicWord(null), false);
    });
  });
}
