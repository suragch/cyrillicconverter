## 1.3.1

- Add ALL-CAPS lowercase fallback and `TRIM(menksoft_code)` matching on definition delete, primary promotion, and replacement; return HTTP 404/409 on missing or already-reviewed moderator actions.
- Make `rejectMissingWord` and `rejectSuggestion` transactional and idempotent; delete raw and normalized forms from `unknown_logs`; scope suggestion rejection to the single suggestion `id`; return `total` in `GET /admin/missing`.
- Support explicitly clearing `explanation` on approval and update, omit auto-generated `"ECK ..."` notes unless edited, reject empty `menksoft` on non-`resolve_only` approvals, and exempt comment-bearing suggestions from auto-resolution.
- Fix Cyrillic case matching in `getRejectionHistory`/`logRejectedWord`, preserve newlines and compound/paired punctuation in `/convert`, batch unknown-word flushes with `normalizeWord`, enforce 512KB limit on chunked requests, expose `isModerator` in `/auth/login` and `/auth/me`, remove `_` from `CyrillicValidator`, and fix `seed.dart`, `migrate_seed.dart`, and `setup_db.dart`.

## 1.3.0

- Additive schema columns `comment` and `target_menksoft` on `suggestions` table.
- Single-primary definition invariant across additions, replacements, and deletions.
- 4-tier pending suggestions queue priority (`db_discrepancy_review` first).
- Auto-resolution of matching pending suggestions on word writes with document context redaction (`context = NULL`).
- Direct moderator endpoints: `POST /admin/definitions/update`, `POST /admin/definitions/delete`, `POST /admin/definitions/primary`.
- Support text-only error reports and comment length validation on `POST /contribute`.

## 1.1.0

- Set SQLite `PRAGMA busy_timeout = 5000` to prevent concurrency lock errors.
- Decouple unknown word telemetry into an async background queue.
- Cloudflare `CF-Connecting-IP` session composite keying for rate limiting.
- Memory-guarded FIFO deduplication cache (5,000 entries).
- Lower request payload ceiling to 512KB.
- Active database probe on `/health` endpoint (HTTP 200/503).

## 1.0.0

- Initial version.
