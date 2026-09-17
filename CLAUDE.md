# Serge Finance

Personal finance tracker for one user (Serge). Read `SPEC.md` first; it is the source of truth for scope, architecture and data model. When a decision changes the spec, update `SPEC.md` in the same commit.

## Stack
- Frontend: a single self-contained `app/index.html` (vanilla HTML/CSS/JS, no build step, no framework). Responsive: phone layout (thumb-friendly, bottom nav) and wide Mac layout.
- Backend: Supabase (Postgres + Auth + PostgREST). Schema and RLS policies live in `supabase/schema.sql`; apply through the Supabase SQL editor. Never put the service-role key in the repo or the HTML; the anon key is fine.
- Hosting: GitHub Pages from `main`, serving `app/`.
- Capture: Apple Shortcuts (documented step by step in `shortcuts/README.md`).

## Conventions
- UI language: Spanish (es-MX). Code, comments and commit messages: English.
- Currency: MXN only in v1. Amounts are `numeric(12,2)`; negative = expense, positive = income.
- Dates in `America/Chihuahua`. Weeks are ISO weeks.
- No AI features in v1 (see SPEC §2). Do not add the Claude API yet.
- Keep `index.html` a single file. Prefer small vanilla helpers over dependencies; if a library is unavoidable, load it from a CDN with a pinned version.
- Every table has `user_id` with RLS `user_id = auth.uid()`. Every new table gets its policy in the same change.
- Mobile first: every screen must work at 390px wide before it works on the Mac.

## Workflow
- Small commits, one feature each. Push to `main` deploys to Pages.
- Before marking a step of SPEC §8 done, test it on a real iPhone (Add to Home Screen) and on the Mac.
- Exports (CSV) are written by the app for the user to save into iCloud `Serge Apps/Serge Finance/exports/`; the repo does not store data.

## Repo layout
```
SPEC.md
CLAUDE.md
app/index.html
supabase/schema.sql
shortcuts/README.md
```
