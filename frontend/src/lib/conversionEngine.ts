
import { db } from '$lib/db';

// In-memory dictionaries for performance
const abbreviationsMap = new Map<string, { expansion: string }[]>();
const conversionsMap = new Map<string, { traditional: string }[]>();

// Call this on application startup
export async function initializeEngine() {
    console.log("Initializing conversion engine...");
    const allAbbrs = await db.abbreviations.toArray();
    const allExps = await db.expansions.toArray();
    // TODO: Load traditionalConversions and cyrillicWords as well

    // Example loading logic (needs to be completed)
    // You will need to join these tables to build the maps correctly.
    // For now, you can populate with dummy data to test the logic.
    
    // Dummy data for testing:
    abbreviationsMap.set('АН', [
        { expansion: 'Ардчилсан Нам' },
        { expansion: 'Америкийн Нэгдсэн Улс' },
    ]);
    conversionsMap.set('Монгол', [{ traditional: 'ᠮᠣᠩᠭᠣᠯ' }]);
    conversionsMap.set('хүн', [{ traditional: 'ᠬᠦᠮᠦᠨ' }]);

    console.log("Engine initialized.");
}

export type ConversionResultSegment =
  | { type: 'converted'; original: string; converted: string }
  | { type: 'unconverted'; original: string }
  | { type: 'ambiguous_abbreviation'; original: string; options: string[] }
  | { type: 'whitespace'; value: string };

export function convert(text: string): ConversionResultSegment[] {
    const segments: ConversionResultSegment[] = [];
    // Regex to split text by words, abbreviations, and keep whitespace/punctuation
    const parts = text.split(/(\s+)/); 

    for (const part of parts) {
        if (part.match(/^\s+$/)) { // It's whitespace
            segments.push({ type: 'whitespace', value: part });
            continue;
        }
        if (part === '') continue;

        // Check if it's an abbreviation with multiple options
        if (abbreviationsMap.has(part) && abbreviationsMap.get(part)!.length > 1) {
            segments.push({
                type: 'ambiguous_abbreviation',
                original: part,
                options: abbreviationsMap.get(part)!.map(o => o.expansion),
            });
        } else if (conversionsMap.has(part)) {
            // For now, assume the first conversion is correct
            const conversion = conversionsMap.get(part)![0];
            segments.push({
                type: 'converted',
                original: part,
                converted: conversion.traditional,
            });
        } else {
            segments.push({ type: 'unconverted', original: part });
        }
    }
    return segments;
}
