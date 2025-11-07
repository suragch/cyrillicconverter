import Dexie, { type Table } from 'dexie';

// Define the structure of the data you'll queue
export interface QueuedContribution {
  id?: number;
  payload: {
    cyrillic_word: string;
    menksoft: string;
    context: string;
  };
  timestamp: number;
}

export class MySubClassedDexie extends Dexie {
  // Define tables (object stores)
  cyrillicWords!: Table<any>;
  traditionalConversions!: Table<any>;
  abbreviations!: Table<any>;
  expansions!: Table<any>;
  userContributions!: Table<any>;
  syncQueue!: Table<QueuedContribution>; // <<< ADD THIS LINE

  constructor() {
    super('mongol-converter-db');
    this.version(2).stores({ // <<< INCREMENT THE VERSION NUMBER
      cyrillicWords: '++id, cyrillic_word',
      traditionalConversions: '++id, word_id, traditional',
      abbreviations: '++id, cyrillic_abbreviation',
      expansions: '++id, abbreviation_id',
      userContributions: '++id, cyrillic_word',
      syncQueue: '++id, timestamp' // <<< ADD THIS SCHEMA DEFINITION
    });
  }
}

export const db = new MySubClassedDexie();
