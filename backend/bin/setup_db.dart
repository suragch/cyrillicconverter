import 'package:backend/database.dart';

void main() {
  final appDb = AppDatabase.open('dictionary.db');
  appDb.initSchema();
  print('Tables created.');

  // Seed data with Menksoft PUA codes
  final words = [
    {
      'cyrillic': 'Монгол',
      'menksoft': '\uE2CE\uE283\uE2BA\uE2C6\uE283\uE2BE',
      'explanation': 'Mongol',
    },
    {
      'cyrillic': 'сайн',
      'menksoft': '\uE2AC\uE281\uE2B5',
      'explanation': 'good',
    },
    {
      'cyrillic': 'байна',
      'menksoft': '\uE2A5\uE281\uE2B5\uE281',
      'explanation': 'is/exists',
    },
    {
      'cyrillic': 'уу',
      'menksoft': '\uE28D\uE28D',
      'explanation': 'question particle',
    },
  ];

  for (final w in words) {
    appDb.addWordDefinition(
      cyrillic: w['cyrillic']!,
      menksoft: w['menksoft']!,
      explanation: w['explanation'],
      isPrimary: true,
      verifiedBy: 'setup_seed',
    );
  }

  // Seed homonym "банк"
  appDb.addWordDefinition(
    cyrillic: 'банк',
    menksoft: '\uE2A5\uE280\uE2B2\uE2C7',
    explanation: 'financial institution',
    isPrimary: true,
    verifiedBy: 'setup_seed',
  );
  appDb.addWordDefinition(
    cyrillic: 'банк',
    menksoft: '\uE2A5\uE280\uE2B2\uE2C7_river',
    explanation: 'river bank',
    isPrimary: false,
    verifiedBy: 'setup_seed',
  );

  appDb.close();
  print('Seed data inserted.');
}
