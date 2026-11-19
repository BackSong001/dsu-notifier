# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture
- **System**: DSU Notifier is a serverless application collecting DSU notices and pushing alerts via FCM.
- **Frontend**: Flutter-based mobile app.
- **Backend/API**: Supabase PostgreSQL + Edge Functions.
- **Data flow**: Edge Functions (`scrape-notices`) pull HTML, store via RPC `store_board_snapshot`, and push via `dispatch-notifications`.
- **Identity**: Device-based registration (UUID + HMAC-SHA256 of a random secret) instead of user accounts.

## Common Tasks
### Testing
- **Backend Unit**: `npm test` (uses Node built-in runner).
- **Database Integration**: `npm run test:db` (spins up a transient Docker postgres).
- **Edge Functions**: `npm run test:edge` (requires Deno).

### Deployment
- Refer to `docs/RELEASE.md` for production deployment, signing, and secret management.
- Secrets are managed in Supabase Edge Function Secrets and never committed.

## Development Rules
- **Environment**: Use `.env.product` for production-data testing (do not commit).
- **Branching**: `main` for release, `product` for verified production-data testing.
- **Security**: Never expose service keys, FCM creds, or Google OAuth secrets.
