## 1.1.0

- Set SQLite `PRAGMA busy_timeout = 5000` to prevent concurrency lock errors.
- Decouple unknown word telemetry into an async background queue.
- Cloudflare `CF-Connecting-IP` session composite keying for rate limiting.
- Memory-guarded FIFO deduplication cache (5,000 entries).
- Lower request payload ceiling to 512KB.
- Active database probe on `/health` endpoint (HTTP 200/503).

## 1.0.0

- Initial version.
