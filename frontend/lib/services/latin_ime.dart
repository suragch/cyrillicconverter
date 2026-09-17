import 'package:mongol_code/mongol_code.dart';

class LatinIme {
  /// Converts a Latin transcription (e.g. 'monggol') into Menksoft Mongolian script.
  static String latinToMenksoft(String latinText) {
    final unicode = convertLatinToMongolianUnicode(latinText);
    return convertUnicodeToMenksoft(unicode);
  }

  /// Converts Menksoft code to Unicode Mongolian.
  static String menksoftToUnicode(String menksoft) {
    return convertMenksoftToUnicode(menksoft);
  }

  /// Converts Menksoft code to Latin transcription.
  static String menksoftToLatin(String menksoft) {
    final unicode = convertMenksoftToUnicode(menksoft);
    return convertMongolianUnicodeToLatin(unicode);
  }

  /// Converts standard Mongolian Unicode to Latin transcription.
  static String convertMongolianUnicodeToLatin(String unicodeText) {
    final buffer = StringBuffer();
    for (var i = 0; i < unicodeText.length; i++) {
      final codeUnit = unicodeText.codeUnitAt(i);
      switch (codeUnit) {
        case Mongol.a:
          buffer.write('a');
          break;
        case Mongol.e:
          buffer.write('e');
          break;
        case Mongol.i:
          buffer.write('i');
          break;
        case Mongol.o:
          buffer.write('q');
          break;
        case Mongol.u:
          buffer.write('v');
          break;
        case Mongol.oe:
          buffer.write('o');
          break;
        case Mongol.ue:
          buffer.write('u');
          break;
        case Mongol.ee:
          buffer.write('E');
          break;
        case Mongol.na:
          buffer.write('n');
          break;
        case Mongol.ang:
          buffer.write('N');
          break;
        case Mongol.ba:
          buffer.write('b');
          break;
        case Mongol.pa:
          buffer.write('p');
          break;
        case Mongol.qa:
          buffer.write('h');
          break;
        case Mongol.ga:
          buffer.write('g');
          break;
        case Mongol.ma:
          buffer.write('m');
          break;
        case Mongol.la:
          buffer.write('l');
          break;
        case Mongol.sa:
          buffer.write('s');
          break;
        case Mongol.sha:
          buffer.write('x');
          break;
        case Mongol.ta:
          buffer.write('t');
          break;
        case Mongol.da:
          buffer.write('d');
          break;
        case Mongol.cha:
          buffer.write('c');
          break;
        case Mongol.ja:
          buffer.write('j');
          break;
        case Mongol.ya:
          buffer.write('y');
          break;
        case Mongol.ra:
          buffer.write('r');
          break;
        case Mongol.wa:
          buffer.write('w');
          break;
        case Mongol.fa:
          buffer.write('f');
          break;
        case Mongol.ka:
          buffer.write('k');
          break;
        case Mongol.kha:
          buffer.write('K');
          break;
        case Mongol.tsa:
          buffer.write('C');
          break;
        case Mongol.za:
          buffer.write('z');
          break;
        case Mongol.haa:
          buffer.write('H');
          break;
        case Mongol.zra:
          buffer.write('R');
          break;
        case Mongol.lha:
          buffer.write('L');
          break;
        case Mongol.zhi:
          buffer.write('Z');
          break;
        case Mongol.chi:
          buffer.write('Q');
          break;
        case Mongol.mvs:
          buffer.write('-');
          break;
        case Mongol.fvs1:
          buffer.write('1');
          break;
        case Mongol.fvs2:
          buffer.write('2');
          break;
        case Mongol.fvs3:
          buffer.write('3');
          break;
        case Mongol.fvs4:
          buffer.write('4');
          break;
        default:
          buffer.write(String.fromCharCode(codeUnit));
      }
    }
    return buffer.toString();
  }

  static const Map<String, String> _punctuationMap = {
    '.': '\uE237', // Traditional Mongolian full stop
    '。': '\uE237',
    ',': '\uE236', // Traditional Mongolian comma
    '،': '\uE236',
    '?': '\uE251', // Vertical question mark
    '!': '\uE250', // Vertical exclamation mark
    ':': '\uE238', // Vertical colon
    ';': '\uE252', // Vertical semicolon
    '(': '\uE253', // Vertical left parenthesis
    ')': '\uE254', // Vertical right parenthesis
    '[': '\uE257', // Vertical left bracket
    ']': '\uE258', // Vertical right bracket
    '«': '\uE259', // Left double angle bracket
    '»': '\uE25A', // Right double angle bracket
    '“': '\uE259',
    '”': '\uE25A',
    '"': '\uE259',
    '—': '\uE261', // Em dash
    '–': '\uE260', // En dash
    '...': '\uE235', // Ellipsis
    '…': '\uE235',
    '?!': '\uE24E',
    '!?': '\uE24F',
  };

  /// Converts standard punctuation marks into vertical Menksoft glyph codes.
  static String convertPunctuationToMenksoft(String p) {
    if (_punctuationMap.containsKey(p)) {
      return _punctuationMap[p]!;
    }
    final buffer = StringBuffer();
    for (var i = 0; i < p.length; i++) {
      final ch = p[i];
      buffer.write(_punctuationMap[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Transliterates Latin characters into standard Mongolian Unicode (U+1800).
  static String convertLatinToMongolianUnicode(String latinText) {
    final converted = StringBuffer();
    for (var i = 0; i < latinText.length; i++) {
      final char = latinText[i];
      if (char == 'q') {
        converted.write(String.fromCharCode(Mongol.o));
      } else if (char == 'w') {
        converted.write(String.fromCharCode(Mongol.wa));
      } else if (char == 'e') {
        converted.write(String.fromCharCode(Mongol.e));
      } else if (char == 'r') {
        converted.write(String.fromCharCode(Mongol.ra));
      } else if (char == 't') {
        converted.write(String.fromCharCode(Mongol.ta));
      } else if (char == 'y') {
        converted.write(String.fromCharCode(Mongol.ya));
      } else if (char == 'u') {
        converted.write(String.fromCharCode(Mongol.ue));
      } else if (char == 'i') {
        converted.write(String.fromCharCode(Mongol.i));
      } else if (char == 'o') {
        converted.write(String.fromCharCode(Mongol.oe));
      } else if (char == 'p') {
        converted.write(String.fromCharCode(Mongol.pa));
      } else if (char == 'a') {
        converted.write(String.fromCharCode(Mongol.a));
      } else if (char == 's') {
        converted.write(String.fromCharCode(Mongol.sa));
      } else if (char == 'd') {
        converted.write(String.fromCharCode(Mongol.da));
      } else if (char == 'f') {
        converted.write(String.fromCharCode(Mongol.fa));
      } else if (char == 'g') {
        converted.write(String.fromCharCode(Mongol.ga));
      } else if (char == 'h') {
        converted.write(String.fromCharCode(Mongol.qa));
      } else if (char == 'j') {
        converted.write(String.fromCharCode(Mongol.ja));
      } else if (char == 'k') {
        converted.write(String.fromCharCode(Mongol.ka));
      } else if (char == 'l') {
        converted.write(String.fromCharCode(Mongol.la));
      } else if (char == 'z') {
        converted.write(String.fromCharCode(Mongol.za));
      } else if (char == 'x') {
        converted.write(String.fromCharCode(Mongol.sha));
      } else if (char == 'c') {
        converted.write(String.fromCharCode(Mongol.cha));
      } else if (char == 'v') {
        converted.write(String.fromCharCode(Mongol.u));
      } else if (char == 'b') {
        converted.write(String.fromCharCode(Mongol.ba));
      } else if (char == 'n') {
        converted.write(String.fromCharCode(Mongol.na));
      } else if (char == 'm') {
        converted.write(String.fromCharCode(Mongol.ma));
      }
      // Uppercase letters
      else if (char == 'Q') {
        converted.write(String.fromCharCode(Mongol.chi));
      } else if (char == 'E') {
        converted.write(String.fromCharCode(Mongol.ee));
      } else if (char == 'R') {
        converted.write(String.fromCharCode(Mongol.zra));
      } else if (char == 'H') {
        converted.write(String.fromCharCode(Mongol.haa));
      } else if (char == 'K') {
        converted.write(String.fromCharCode(Mongol.kha));
      } else if (char == 'L') {
        converted.write(String.fromCharCode(Mongol.lha));
      } else if (char == 'Z') {
        converted.write(String.fromCharCode(Mongol.zhi));
      } else if (char == 'C') {
        converted.write(String.fromCharCode(Mongol.tsa));
      } else if (char == 'N') {
        converted.write(String.fromCharCode(Mongol.ang));
      }
      // Control characters
      else if (char == '\'') {
        converted.write(String.fromCharCode(Mongol.fvs1));
      } else if (char == '"') {
        converted.write(String.fromCharCode(Mongol.fvs2));
      } else if (char == '`') {
        converted.write(String.fromCharCode(Mongol.fvs3));
      } else if (char == '~') {
        converted.write(String.fromCharCode(Mongol.fvs4));
      } else if (char == '-') {
        converted.write(String.fromCharCode(Mongol.mvs));
      } else if (char == '1' && _notNumber(latinText)) {
        converted.write(String.fromCharCode(Mongol.fvs1));
      } else if (char == '2' && _notNumber(latinText)) {
        converted.write(String.fromCharCode(Mongol.fvs2));
      } else if (char == '3' && _notNumber(latinText)) {
        converted.write(String.fromCharCode(Mongol.fvs3));
      } else if (char == '4' && _notNumber(latinText)) {
        converted.write(String.fromCharCode(Mongol.fvs4));
      } else {
        converted.write(char);
      }
    }
    return converted.toString();
  }

  static bool _notNumber(String word) {
    return int.tryParse(word) == null;
  }
}
