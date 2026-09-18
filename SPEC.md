# Serge Finance — Spec v0.4

*Personal finance tracker. One web app on iPhone and Mac, one shared store, Shortcuts for zero-friction capture.*

Status: v0.4 · 2026-09-18 · adds §3.2 visual design system and the phone/Mac screen structure it
brings; steps 1–5 of §8 are built.

## 1. Goal

Know where the money goes with near-zero friction at the moment of spending, and use that knowledge to make discretionary spending something that is earned (the "lock"). Personal use only; one user; Spanish UI; MXN.

## 2. Principles

1. **Capture in seconds, on the phone.** Logging should be one tap and one choice. Ideally zero taps: the purchase is captured automatically and you only pick the category.
2. **Same app everywhere, different layout.** One `index.html`, responsive: a thumb-friendly phone layout (inbox, quick add, status) and a wide Mac layout (tables, budgets, goals, lock).
3. **One source of truth, instant sync.** A small hosted database (Supabase) that the app and the Shortcuts both talk to. The iCloud folder keeps the code and CSV exports, not the live ledger.
4. **No AI in v1.** Categories are picked by hand from a short list. Claude comes later, once there is data worth talking about.
5. **Desktop wins ties** for anything analytical; the phone wins for anything about capture.

## 3. Architecture

```
 iPhone                              Mac
 ┌──────────────────────┐            ┌──────────────────────┐
 │ Shortcuts            │            │ Safari/Chrome        │
 │  • Apple Pay trigger │            │  index.html (wide)   │
 │  • "Gasto" quick add │──REST──┐   └──────────┬───────────┘
 │  • "¿Puedo gastar?"  │        │              │
 ├──────────────────────┤        ▼              ▼
 │ Safari → Home Screen │   ┌─────────────────────────┐
 │  index.html (phone)  │──▶│ Supabase (free tier)    │
 └──────────────────────┘   │  Postgres + Auth + REST │
                            └─────────────────────────┘
 Hosting: GitHub Pages (static index.html).  Code + CSV exports: iCloud "Serge Apps/Serge Finance".
```

**Why not iCloud files?** A web app on iPhone cannot read or write iCloud Drive, and an HTML file opened from the Files app is only a preview. A hosted store is the only way to have a real app on both devices.

**Why Supabase?** Free tier is plenty for one user; Postgres with a REST API means Shortcuts can insert rows with a single "Get Contents of URL" action; built-in Auth keeps the data private; and it is the sync layer already pencilled in for the life OS.

**Privacy/security.** The app signs in with email + password (session remembered per device). Row Level Security: every table has `user_id` and a policy `user_id = auth.uid()`. Shortcuts log in the same way (two HTTP calls: token, then insert); the password lives only inside the shortcut on your phone. The anon key in the HTML is safe to publish because RLS denies everything without a valid session.

### 3.1 App code structure (`app/index.html`)

One file, but with labeled rooms — every build session follows this shape so later features are additive, never surgery:

- **Order inside the file**: design-token CSS variables → base styles → one commented style block per screen → responsive rules (phone-first; Mac layout at a breakpoint). Then the HTML shell: one `<section>` per screen (bottom nav on the phone, sidebar on the Mac). All JS at the bottom.
- **JS as small named modules** (plain objects, no framework):
  - `api` — the only code that talks to Supabase; one function per operation. The future Claude API lands here too.
  - `store` — single in-memory state (user, movimientos, categorias, presupuestos…); everything on screen is drawn from it.
  - `views` — one render function per screen; views never fetch, only draw the store.
  - `router` — hash-based navigation (`#/inbox`, `#/hoy`) so the back gesture and bookmarks work.
  - `fmt` and helpers — MXN formatting, America/Chihuahua dates, ISO-week math; written once, used everywhere.
- **One-way data flow**: action → `api` → `store` update → re-render. No view touches the network or keeps its own state.
- **Growth path**: each step of §8 adds `api` functions + `store` fields + a view section. If the file ever gets unwieldy (~step 5–6), the escape hatch is splitting the script into a few plain `.js` files loaded by `index.html` — still no build step — updating `CLAUDE.md` in the same commit.

### 3.2 Visual design system

Ported 2026-09-18 from the Claude Design file `Serge Finance — UI.html`, which stays in the iCloud
archive (6.8 MB; too big for the repo) and is the visual source of truth. Its «Tokens» page defines:

- **Surfaces** (dark is primary): `#0B1F17` canvas · `#12291F` surface · `#183626` raised.
  Light theme (`prefers-color-scheme: light`): `#F2EDE1` · `#EBE5D6` · `#E2DBC9`.
- **Bone ink**: `#E9E2D0` · `#C9C0A9` · `#9C947E`. **Accents**: sage `#6F8F6A` (income, goals),
  oxblood `#7A2E2E` (over budget, lock closed).
- **Hairlines** (bone at 12 % and 24 %) instead of heavy borders; **no shadows**.
- **Type**: Playfair Display for money and titles, IBM Plex Sans for the interface, both from Google
  Fonts — the app's only external dependency. Money is serif with tabular figures; the `$` and the
  decimals render at 60 % in secondary ink.
- **Components**: 44 px chips that fill with bone in 160 ms, 2 px progress bars (oxblood past
  100 %, sage for goals), underlined fields (never boxes), bottom sheets, undo toast.
- Radii 4 px (buttons, chips) and 6 px (cards, sheets). Motion: 160 ms, opacity and position only.

## 4. How capture works on the iPhone

iOS does not let Shortcuts read push notifications from other apps (Santander's included). What works:

1. **Apple Pay (primary).** Cards live in Wallet; the Wallet **"Transaction" automation** (limited to the two tracked cards) runs on every payment and hands the shortcut the amount, merchant and card, with no typing. The shortcut shows the category menu right there, maps the Wallet card name to the account (`cuenta`) with an If, and saves via `agregar_movimiento`; picking "Después" (or dismissing nothing) sends it to the inbox. Ignoring the menu entirely means nothing is saved — capture it later with "Gasto".
2. **Santander SMS/email alerts — not available.** Checked 2026-09-16: SuperMóvil does not offer per-purchase SMS/email alerts, so there is no automation path for physical-card purchases. They are captured with the quick add below.
3. **"Gasto" quick add (fallback).** Home-screen widget / Action button / Back Tap: type amount, optional note → inbox. Covers cash, physical-card purchases and anything the triggers miss.

**Categorizing.** Both shortcuts show the **category menu in the shortcut itself** (decided 2026-09-16/17): they call the `agregar_movimiento` SQL function with the category *name* — and, for Apple Pay, the account *name* — so the shortcut never handles ids; picking "Después" (or anything unmatched) sends it to the inbox. The app's inbox is always there as the catch-all.

## 5. Scope

### v1

**Phone layout** — bottom tabs: Hoy · Inbox · Mes · Más
- **Hoy**: lock status (abierto/cerrado), discretionary remaining this month, spent today/this week, latest movements.
- **Inbox**: pending movements; the top card expands and takes category + account in place, with an undo toast.
- **Gasto rápido**: a bottom sheet (tabs Gasto / Ingreso / Meta) rather than a tab of its own.
- **Mes**: budget bars, goals and account balances.
- **Más**: Candado, Movimientos, Presupuestos, CSV export, sign out.

**Mac layout (adds)** — sidebar: Resumen · Movimientos · Presupuestos · Inbox · Candado
- **Movimientos**: full ledger, filters, edit, bulk categorize, CSV export.
- **Cuentas**: cash, debit, credit card(s), running balances, balance adjustments for reconciling against the bank.
- **Presupuestos**: monthly limit per category, spent vs remaining, carry-over off by default. The first time the app runs in a new month it copies last month's limits forward automatically and notes it in Resumen (no silent empty months).
- **Metas de ahorro**: named goals, target and date; contributions are movements of type `ahorro`.
- **Candado (lock)**: weekly checklist of self-improvement goals entered by hand (e.g., 3 workouts, 2 reading sessions). Categories marked `discrecional` count toward the lock. Lock is **open** this week only if last week's checklist was met; "met" is a **configurable threshold** (fraction of checklist items, e.g. 1.0 = strict, 0.8 = lenient) stored where the `estado` view reads it — the exact value gets picked once there is real data. v1 is informational: it never blocks, it tells the truth (red discretionary spend, "cerrado" on the phone).
- **Recurrentes**: rent, subscriptions, salary defined once, generated on their day as pending until confirmed.
- **Resumen**: the month at a glance.

**Shortcuts**: Apple Pay automation, "Gasto", "¿Puedo gastar?" (reads status, answers in a banner), and if available the Santander alert automation.

### Later
- Claude API: auto-categorization from merchant/note, natural-language questions over the ledger.
- Bank CSV import; spending predictions; subscription detection.
- Life OS integration (fitness and mind modules feed the lock automatically).

### Out of scope
- Multi-user, bank connections/aggregators, investments, taxes.

## 6. Data model (Supabase / Postgres)

All tables have `id uuid`, `user_id uuid` (RLS), `creado timestamptz`. Amounts are `numeric(12,2)`, MXN, negative = expense.

| Table | Key columns | Notes |
|---|---|---|
| `movimientos` | `fecha date, monto, cuenta_id, categoria_id (null = inbox), nota, comercio, origen (apple_pay/sms/manual/app/recurrente), tipo (gasto/ingreso/ahorro/ajuste), meta_id` | The ledger. Inbox = rows with `categoria_id is null`. |
| `cuentas` | `nombre, tipo (efectivo/debito/credito), saldo_inicial, activa` | Balance = saldo_inicial + Σ movimientos. |
| `categorias` | `nombre, icono, discrecional bool, orden` | Aim for 10–12. `icono` is the slug of a minimalist inline-SVG icon drawn by the app (no emoji). |
| `presupuestos` | `mes (YYYY-MM), categoria_id, limite` | One row per category per month. |
| `metas` | `nombre, objetivo, fecha_objetivo, activa` | Progress = Σ movimientos tipo ahorro with `meta_id`. |
| `recurrentes` | `nombre, monto, dia, categoria_id, cuenta_id, activa` | Generated as pending on `dia`. |
| `semana_metas` | `nombre, veces_objetivo, activa` | The checklist definition. |
| `semana_registro` | `semana (ISO week), semana_meta_id, veces` | What you actually did. |

A SQL view `estado` returns `{candado, semana, discrecional_restante, actualizado}` for the "¿Puedo gastar?" shortcut and the phone's Hoy screen.

## 7. Folder layout (iCloud, code and exports only)

```
Serge Apps/Serge Finance/
  SPEC.md                ← this file
  app/index.html         ← the app, single self-contained file (also pushed to GitHub Pages)
  supabase/schema.sql    ← tables, RLS policies, the estado view
  shortcuts/README.md    ← how to build and install each shortcut, step by step
  exports/               ← CSV exports from the app (backup you can open in Excel)
```

## 8. Build order

1. **Supabase project + schema** (you create the free account; I write `schema.sql` and you paste it in the SQL editor). Seed your accounts and categories.
2. **App v0**: sign-in, Inbox, quick add, Movimientos list. Deploy to GitHub Pages, Add to Home Screen on the phone. *Milestone: log a coffee on the phone, see it on the Mac.*
3. **Apple Pay automation + "Gasto" shortcut.** *Milestone: pay with Apple Pay, categorize from the notification.*
4. **Presupuestos, Cuentas, Metas, Resumen.** ✓ 2026-09-17
5. **Candado**: checklist, rule, `estado` view, "¿Puedo gastar?" shortcut. ✓ 2026-09-18, together
   with the visual redesign (§3.2) and CSV export, which moved up from step 6.
6. **Recurrentes** and polish.

## 9. Open questions

Resolved 2026-09-16:

- **GitHub/hosting**: account exists; git 2.53.0 and the `gh` CLI are installed on the Mac. The repo lives at `~/Code/serge-finance` (outside iCloud, per the kickoff notes); the iCloud folder stays as the archive.
- **Accounts to seed**: Efectivo, Santander débito, Santander TDC.
- **Categories to seed**: Súper · Comida fuera* · Café/antojos* · Transporte · Renta/servicios · Salud · Ropa* · Ocio/salidas* · Suscripciones · Regalos* · Viajes* · Ahorro · Ingreso (* = discrecional).
- **Lock rule**: implemented as a configurable threshold (see §5 Candado); the value is chosen later with real data.
- **Presupuestos rollover**: the app auto-copies last month's budgets forward (see §5 Presupuestos).

- **SuperMóvil alerts**: checked 2026-09-16 — no per-purchase SMS/email alerts available. Physical-card purchases are captured with the "Gasto" quick add (§4).

No questions remain open.
