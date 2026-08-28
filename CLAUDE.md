# Project memory — read this before scanning the repo

This file exists so an agent can get oriented from one read instead of scanning
every file. It captures *why* things are the way they are — decisions, fixes,
gotchas — not just *what* the code does. For setup steps, see `README.md`.

## What this project is

Data pipelines pulling XML exports from a SharePoint site (Microsoft Graph API)
into two destinations:
- **PostgreSQL**, via Kestra flows (`kestra_storage/flows/`)
- **Google Sheets**, via a standalone Jupyter notebook (`Colab/SharePoint2GSheet.ipynb`),
  which a separate Google Apps Script (`Colab/mover.js`) then syncs into
  consolidated destination spreadsheets

These two paths are **independent** — the notebook doesn't feed the Kestra
flows or vice versa. Same SharePoint source, two unrelated consumers.

## Current state (as of this writing)

### Notebook (`Colab/SharePoint2GSheet.ipynb`)
- Auth: Google **service account** (not OAuth, not Colab's built-in auth — this
  was originally a Colab notebook migrated to run locally in VS Code via a conda
  env named `notebook-env`). Key file lives **outside the repo**, at
  `C:\Users\Administrator\.secrets\google\lbc-infrastructure-kestra-sheets-bot.json`,
  referenced by absolute path in the notebook. The service account email
  (`kestra-sheets-bot@lbc-infrastructure.iam.gserviceaccount.com`) must have
  Editor access on every target spreadsheet — 403 errors here almost always
  mean a specific spreadsheet wasn't shared with the bot, not a code bug. When
  debugging 403s, it's faster to mint a token directly from the key file with
  Node (`crypto.createSign('RSA-SHA256')` + JWT bearer flow) and hit the Sheets
  API raw than to keep re-running the notebook — this was done repeatedly in
  this session to pinpoint exactly which spreadsheet lacked access.
- `MS_GRAPH_CLIENT_SECRET` is read via `python-dotenv` from `Colab/.env`
  (gitignored, never committed). If you see `KeyError: 'MS_GRAPH_CLIENT_SECRET'`,
  that file is missing or empty — it's *supposed* to be absent on a fresh
  clone.
- **"Оприбуткування (всі)/2026/30д"** — these 3 reports used to each
  independently fetch a single hardcoded month's XML file
  (`storage_operations_2026_06_latest.xml`), so they silently went stale every
  month. The `/LatestXML/Storage_operations_latest/` SharePoint folder actually
  contains *separate files per month* (plus older yearly/quarterly rollups for
  2022–2025), not one evergreen "latest" file. Fixed: the notebook cell now
  lists the whole folder, downloads **every** file, concatenates them, and
  derives all 3 sheet outputs (all/2026/30d) from that one merged dataframe —
  avoids re-downloading ~1GB three times. Downloads include a retry-with-size-check
  because `requests.get()` was silently truncating some of the larger (100MB+)
  files, which showed up as `xmltodict.parse` `ExpatError: unclosed token`
  further down — confirmed via direct MS Graph download that the source files
  themselves are fine, so this needed a re-download-on-mismatch fix rather than
  a source-side one.
- The `storage_operations` XML has an inherent xmltodict quirk: an operation
  with exactly one product parses as a nested dict (`products.product.X`
  columns), while an operation with multiple products parses as a list
  (`products.product_X` columns after explode). Both column families coexist
  in the same dataframe/sheet — any downstream logic reading product fields
  needs to coalesce both names, not just pick one.
- git-tracked `.ipynb` diffs used to be noisy on every run (Jupyter writes
  `outputs`/`execution_count` into the file). `scripts/strip_notebook_output.js`
  + `.gitattributes` (`filter=nbstrip`) fix this — but the filter is **local
  git config**, not something `.gitattributes` alone can carry. One-time setup
  per clone is in `README.md`. If a fresh clone shows huge notebook diffs on
  every run, this filter hasn't been registered yet.
- Google Sheet ID mapping (worth checking directly if something seems to write
  to the wrong place — this was a repeated source of confusion in this
  session because two spreadsheets have very similar sounding names):
  - `1hIyUSO_FYyaM4FIc6prSahlt62qxNvXOrAUIV8kh4U0` — **"Складські залишки"**
    (title confirmed via API), tab "Залишки (всі)" — Python writes here directly.
  - `1yHi1I3F9qhm-V1AdqaklhwO8DZGjlqEkHwqDt35QzH8` — **"Постачання"** staging,
    tabs: Постачання (всі), Постачання 14д, Постачання 30д, Запаси.
  - `1NTB_t8qmMz0jd2f9FWngk6X3O7O2uSTKhiL0PWKRYRU` — **"Оприбуткування"** staging,
    tabs: Оприбуткування (всі)/2026/30д.
  - `1kPFNolw6IbC_l5mgwEph_vxzFGlGb6hF03XG2zV2U98` — a **separate consolidated
    "final" spreadsheet** that `mover.js` (not Python) populates by copying from
    the above staging sheets. The service account does **not** have access to
    this one (by design — Python never writes here). Do not "fix" a 403 on this
    ID by sharing it with the bot; that's not the intended flow.
  - `1V9DP0mfOiTBsxMubeCC4V8CbtIk73w0OKAryvKntk8U` — final destination for
    Постачання 14д/30д/Запаси (also populated by `mover.js`, not Python).

### `mover.js` (Google Apps Script)
Copies staging spreadsheets (above) into the two final consolidated ones. All
8 sync tasks now run in `MODE: "OVERWRITE"` (one of them, `POSTACHANNYA`, used
to run `UPSERT` keyed on `order_date`, which isn't unique per row — silently
collapsed/lost rows whenever two source rows shared a date. OVERWRITE sidesteps
this entirely). This script must be run from the Apps Script editor bound to
the destination sheets — it's not invoked from this repo or by the notebook.

### Kestra flows (`kestra_storage/flows/`)
Insert into flat `*_raw` Postgres tables (see `postgres_data/schema/`, the
original `CREATE_*_raw.sql` files). `Storage_balance_to_PG.yaml` and
`Storage_balance_to_PG copy.yaml` are two genuinely different iterations of the
same flow (different `id`/namespace/NULL-handling) — nobody has confirmed which
is canonical, both are still in the repo.

### `postgres_data/schema/CREATE_all_tables.sql`
A separate, much more sophisticated **normalized** schema (UUID PKs, an
immutable storage_operations ledger with reversal/sign, currency handling,
partitioned order_status_history, a `staging` + `etl.process_order*()` ETL
layer). **This is not wired up to the existing Kestra flows** — those still
write to the old flat `*_raw` tables. The `etl.process_order`/`process_order_items`
functions only cover `orders`/`order_items`; there's no ETL yet from `staging.*`
into `storage_balances`, `storage_operations`, `payments`, etc. Whole script is
idempotent (`CREATE TABLE/INDEX/MATERIALIZED VIEW IF NOT EXISTS`,
`CREATE OR REPLACE VIEW`, `DROP TRIGGER IF EXISTS` before each `CREATE TRIGGER`,
`ADD CONSTRAINT` wrapped in a `DO $$ ... EXCEPTION WHEN duplicate_object`
block since Postgres has no `ADD CONSTRAINT IF NOT EXISTS`) — safe to re-run.
`mv_inventory_report` has no refresh schedule anywhere; needs one if it's
actually going to be used (cron or a Kestra flow).

## Secrets

- Google service account key: outside the repo (`~/.secrets/google/...` on this
  machine), never committed. Has a **1-day expiry** by policy — if Google auth
  starts failing with 403 *despite* correct sharing, check whether the key is
  simply past its 24h window before debugging anything else.
- `MS_GRAPH_CLIENT_SECRET`: read from `Colab/.env` (notebook) and Kestra's
  `secret()` mechanism (flows) — see README for the exact setup. The **old**
  value that used to be hardcoded throughout this repo was exposed in plaintext
  for a long time (including in git history briefly, before GitHub's push
  protection caught it and the commit was reworded/cleaned before ever
  reaching a remote) — it should be rotated in Azure AD when convenient, it's
  not blocking anything by staying in code now.
- A third, unrelated Google service account key (project `docs-integration-prod`)
  was found hardcoded in `kestra_storage/glogin.yaml` — that file was deleted
  (superseded by `kestra_storage/tests/test_google_service_account.yaml`, which
  does the same thing correctly via `{{ secret('GOOGLE_SA_JSON') }}`). If that
  key is still active, it should be rotated too.

## Repo housekeeping

- Two remotes are pushed: `origin` → `github.com/yukhymshulha/BD-Scripts`, and
  `github.com/SYNERHIIA/DB-Scripts` (note: **not** `BD-Scripts` — GitHub
  reports that org repo was renamed; the old `SYNERHIIA/BD-Scripts` URL still
  redirects and works, but use the `DB-Scripts` URL going forward).
- No GitHub CLI (`gh`) and no stored git credentials in this shell environment —
  pushes rely on whatever credential manager is registered in the user's actual
  Git for Windows install, which works when run from their own terminal even
  though this session has no visibility into it.
