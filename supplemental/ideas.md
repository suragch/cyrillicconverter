## Notes

- Cyrillic, Bichig
- Five people need to check a word before it is considered good.
- Give a test to volunteers to weed out poor users.
- Cyrillic and bichig tests.
- Also through in known words every now and then to continually test the quality of graders.
- For bichig use old Menksoft code of Zcode to preserve graphic structure.
- Log users in. Should that be required?
- Have a stats page.
- Leader board?
- Download current database.
- Each user should have a quality grade.
- Each word should have a trustworthiness grade.
- Have a place for user feedback.
- Option to delete account.
- Two UI layouts: Cyrillic and Bichig

## User story

### Spell-check user

1. Paste text into app.
2. Unknown words will be underlined in red.
3. Click to show suggestions.

### Volunteer

1. Download and install app
2. Introduction
3. Apply to be a volunteer.
4. You need to take a test. Qualify in Cyrillic and Bichig.
5. Choose one test or the other. Or both.
6. Agree to put all work in the public domain.
7. Sign up with username and email. (Username is public. Email is private.)
8. Give the option to be anonymous. (but in that case if you forget password then can't reclaim account)
9. Three tabs: Cyrillic, Bichig, stats
10. Start reviewing words.
11. Choices: Correct, incorrect
12. If incorrect, give chance to correct word. (Include other people's choices as options.)

## Backend

- Require bearer token
- Oauth (and data?) with Supabase
- Dart frog and local database?
- Option to download database.
- Validate word.

## Database schema

```
{
    "word": "цаг",
    "script": "cyrillic",

}
```

## Areas for further research

- How many word databases are out there?
- Are they all closed source?
- How to be sure that a word is spelled correctly?
- How do AI models be so accurate in spelling and grammar?