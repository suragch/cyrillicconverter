import '../lib/database.dart';

void main() {
  final appDb = AppDatabase.open('dictionary.db');
  final db = appDb.db;

  print('Seeding verified homonyms and missing common words...');

  // 1. хүү (ᠬᠦᠦ - son / ᠬᠦᠪᠦᠦ - interest)
  appDb.addWordDefinition(
    cyrillic: 'хүү',
    menksoft: '\uE2E1\uE28D\uE28D', // ᠬᠦᠦ
    explanation: 'хүүхэд, эрэгтэй хүүхэд',
    isPrimary: true,
    verifiedBy: 'system_seed',
  );
  appDb.addWordDefinition(
    cyrillic: 'хүү',
    menksoft: '\uE2E1\uE28D\uE2C1\uE28D\uE28D', // ᠬᠦᠪᠦᠦ
    explanation: 'мөнгөний хүү',
    isPrimary: false,
    verifiedBy: 'system_seed',
  );

  // 2. төр (ᠲᠥᠷᠥ - state / ᠲᠥᠷᠦ - born)
  appDb.addWordDefinition(
    cyrillic: 'төр',
    menksoft: '\uE309\uE29C\uE2E6\uE29C', // ᠲᠥᠷᠥ
    explanation: 'төр засаг, улс төр',
    isPrimary: true,
    verifiedBy: 'system_seed',
  );
  appDb.addWordDefinition(
    cyrillic: 'төр',
    menksoft: '\uE309\uE29C\uE2E6\uE2A3', // ᠲᠥᠷᠦ
    explanation: 'төрөх, мэндлэх',
    isPrimary: false,
    verifiedBy: 'system_seed',
  );

  // 3. гол (ᠭᠣᠣᠯ - river, main / ᠭᠣᠯ - target)
  appDb.addWordDefinition(
    cyrillic: 'гол',
    menksoft: '\uE2E4\uE289\uE289\uE2F9', // ᠭᠣᠣᠯ
    explanation: 'гол мөрөн, гол утга',
    isPrimary: true,
    verifiedBy: 'system_seed',
  );
  appDb.addWordDefinition(
    cyrillic: 'гол',
    menksoft: '\uE2E4\uE289\uE2F9', // ᠭᠣᠯ
    explanation: 'голыг олох, голдох',
    isPrimary: false,
    verifiedBy: 'system_seed',
  );

  // 4. он (ᠣᠨ - year)
  appDb.addWordDefinition(
    cyrillic: 'он',
    menksoft: '\uE289\uE2B5', // ᠣᠨ
    explanation: 'он жил, хуанлийн он',
    isPrimary: true,
    verifiedBy: 'system_seed',
  );

  print('Homonyms successfully added to dictionary.db:');
  final check = db.select('''
    SELECT w.cyrillic, d.menksoft_code, d.explanation, d.is_primary
    FROM words w
    JOIN definitions d ON w.id = d.word_id
    WHERE w.cyrillic IN ('хүү', 'төр', 'гол', 'он');
  ''');

  for (final row in check) {
    print('${row['cyrillic']} -> ${row['menksoft_code']} (${row['explanation']}, primary=${row['is_primary']})');
  }

  appDb.close();
}
