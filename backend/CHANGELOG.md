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
