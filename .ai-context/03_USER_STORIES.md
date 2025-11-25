# User Stories

## 1. The Converter (General User)
*   **Story**: As a user, I want to paste a document and click convert.
*   **Constraint**: If a word has multiple meanings (like 'bank'), I want the system to guess the most common one but let me change it if it's wrong.
*   **Outcome**: I see a blue dotted line. I click it and pick the other meaning.

## 2. The Contributor (The "Fixer")
*   **Story**: As a user, I see a word that wasn't converted (red underline). I know the translation.
*   **Action**: I click the word, type the correct Traditional script, and hit save.
*   **Benefit**:
    1.  It fixes it on my screen immediately.
    2.  It saves it to my browser so next time I convert this specific word, it works automatically.
    3.  It sends the data to the server so others can benefit later.

## 3. The Moderator
*   **Story**: As a moderator, I want to know what words are missing from the dictionary.
*   **Action**: I view the "Most Frequent Unknown Words" list.
*   **Benefit**: I don't waste time translating rare words nobody uses. I focus on the words causing the most errors for users right now.

## 4. The Content Creator (Efficiency)
*   **Story**: As a writer, I don't want to sign in just to convert text.
*   **Requirement**: I can use the tool anonymously. My local browser storage keeps my personal fixes, but I don't need a cloud account unless I want to sync across devices (future feature).