# AURA

Clean-slate production rebuild for the Acoustic Urgency Recognition Assistant.

The legacy `aura_app/`, `ml/`, and `datasets/` directories are preserved as reference artifacts. Production code belongs in `apps/`, `supabase/`, and `packages/`.

## Repository layout

- `apps/mobile` — Flutter client for Android and iOS.
- `apps/portal` — trusted-contact web portal.
- `supabase` — migrations and Edge Functions.
- `ml` — model data-governance, training, and evaluation tooling; legacy assets remain isolated under `ml/legacy` when migrated manually.
- `docs` — safety, privacy, and operational requirements.

## Local setup

Copy `.env.example` to a local untracked environment file and populate it only after creating the named hosted services. Never commit API keys, phone numbers, or audio samples.

See `docs/READINESS.md` for the audited prerequisite list.
