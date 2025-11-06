import Dexie, { type Table } from 'dexie';

export interface CyrillicWord {
  word_id?: number;
  cyrillic_word: string;
}

export interface TraditionalConversion {
  conversion_id?: number;
  word_id: number;
  traditional: string;
  status: 'pending' | 'approved' | 'rejected';
}

export interface Abbreviation {
  abbreviation_id?: number;
  cyrillic_abbreviation: string;
}

export interface Expansion {
  expansion_id?: number;
  abbreviation_id: number;
  cyrillic_expansion: string;
  status: 'pending' | 'approved' | 'rejected';
}

export interface UserContribution {
  id?: number;
  cyrillic_word: string;
  traditional_conversion: string;
}

export class MongolConverterDB extends Dexie {
  cyrillicWords!: Table<CyrillicWord>;
  traditionalConversions!: Table<TraditionalConversion>;
  abbreviations!: Table<Abbreviation>;
  expansions!: Table<Expansion>;
  userContributions!: Table<UserContribution>;

  constructor() {
    super('mongol-converter-db');
    this.version(1).stores({
      cyrillicWords: '++word_id, &cyrillic_word',
      traditionalConversions: '++conversion_id, word_id, status, &[word_id+traditional]',
      abbreviations: '++abbreviation_id, &cyrillic_abbreviation',
      expansions: '++expansion_id, abbreviation_id, status, &[abbreviation_id+cyrillic_expansion]',
      userContributions: '++id, cyrillic_word',
    });
  }
}

export const db = new MongolConverterDB();
