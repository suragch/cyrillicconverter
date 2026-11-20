# Design Document Sitemap

Index of technical design documents for the Cyrillic to Traditional Mongolian Converter.

| Document | Date | Author | Components | Description |
| :--- | :--- | :--- | :--- | :--- |
| [Public Web Release Readiness](./public_web_release_readiness.md) | 2026-11-02 | suragch | `frontend/`, `backend/`, `web/` | Architecture and implementation plan for mobile responsiveness, SQLite concurrency, trans-Pacific asset preloading, and Cloudflare integration. |
| [Local-First Word Persistence & Reconciliation](./local_first_word_persistence.md) | 2026-11-06 | suragch | `frontend/` | Client-side persistent dictionary fallback with green visual styling, background moderation submission, and silent purge reconciliation. |
| [Variant vs. Correction Differentiation & Moderation Pipeline](./variant_vs_correction_differentiation.md) | 2026-11-10 | suragch | `frontend/`, `backend/` | Separates dictionary meaning from moderator comments, retains known-word local overrides for 30 days, and adds explicit moderator replacement, variant, and primary-selection controls. |
| [Bug Audit & Remediation Plan](./bug_audit_and_fix_plan.md) | 2026-11-20 | suragch | `backend/`, `frontend/` | Comprehensive catalog of 20 backend, moderator, converter, and UI bugs (including moderator delete/skip root causes) with resolved design decisions and a 3-phase fix and verification plan. |
