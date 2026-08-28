# Kestra YAML — SharePoint → Postgres / Google Sheets pipelines

Data pipelines that pull XML exports from a SharePoint site (via Microsoft Graph) and load them into either PostgreSQL (through Kestra flows) or Google Sheets (through a standalone Python/Jupyter script).

## Structure

- **`kestra_storage/`** — Kestra flow definitions.
  - `flows/` — production pipelines (`FLOW_sharepoint_*_to_postgres.yaml`) that download SharePoint XML exports and bulk-insert them into PostgreSQL, plus `Storage_balance_to_PG.yaml` and `Storage_balance_to_PG copy.yaml` (two divergent versions of the same flow — see **Known issues**) and the experimental `sharepoint_python_duckdb_pipeline.yaml`.
  - `tests/` — connectivity smoke tests (`test_google_service_account.yaml`, `test_docker_global.yaml`, `sharepoint_debug.yaml`), not part of the production pipeline.
- **`Colab/`** — `SharePoint2GSheet.ipynb`: pulls the same SharePoint data and writes it into Google Sheets (via a Google service account), organized by report (Залишки, Постачання, Оприбуткування). `mover.js` is a Google Apps Script that syncs data between those Sheets into consolidated destination spreadsheets.
- **`postgres_data/`** — Postgres side of the pipeline.
  - `schema/` — `CREATE_*.sql` table definitions.
  - `queries/` — reporting `SELECT_*.sql` queries.
- **`Docker files/docker-compose.yml`** — local Kestra + Postgres stack for running the flows.

## Setup

### Kestra flows (`kestra_storage/`)
Run against a local Kestra + Postgres stack:
```
docker compose -f "Docker files/docker-compose.yml" up
```
Each flow reads the Microsoft Graph client secret via `{{ secret('MS_GRAPH_CLIENT_SECRET') }}`. Set it through Kestra's secrets manager before running — e.g. as an environment variable on the Kestra server/container:
```
SECRET_MS_GRAPH_CLIENT_SECRET=<base64-encoded secret>
```
(Kestra expects secret values base64-encoded; see the [Kestra secrets docs](https://kestra.io/docs/concepts/secret)). The local Postgres password (`kestra`/`kestra`) is left as the standard Kestra quickstart default — fine for the local-only dev stack in `docker-compose.yml`.

### Notebook (`Colab/SharePoint2GSheet.ipynb`)
Requires a Google service account JSON key with Editor access on the target spreadsheets, kept **outside** this repository (e.g. `~/.secrets/google/...`). Each report cell points `SERVICE_ACCOUNT_FILE` at that path. The Microsoft Graph client secret is read from the `MS_GRAPH_CLIENT_SECRET` environment variable via a local `Colab/.env` file (gitignored, loaded automatically with `python-dotenv` — create it yourself with `MS_GRAPH_CLIENT_SECRET=<value>`, it's never committed). Install dependencies from the `pip install` cell at the top of each notebook section.

### `mover.js`
Google Apps Script, meant to be pasted into the Apps Script editor bound to the destination Google Sheets — not run from this repo directly.

## One-time git setup (per clone)

Running the notebook rewrites its cell outputs/execution counts on every execution, which would otherwise show up as noisy diffs on every commit. A git clean filter strips them automatically when staging — register it once per clone:
```
git config filter.nbstrip.clean "node scripts/strip_notebook_output.js"
git config filter.nbstrip.smudge cat
git config filter.nbstrip.required true
```
(Requires Node.js on PATH.) After this, `.ipynb` files keep their real outputs on disk — only what gets committed is stripped, so re-running cells locally won't dirty `git status` unless the actual code changed.

## Known issues / TODO

- `kestra_storage/flows/Storage_balance_to_PG.yaml` and `Storage_balance_to_PG copy.yaml` are two different iterations of the same flow (different `id`, namespace, and NULL-handling logic in the insert step) — figure out which one is canonical and remove the other.
- The Microsoft Graph client secret that used to be hardcoded in this repo (before it was moved to `secret()`/`os.environ`) was exposed in plaintext for a while — rotate it in Azure AD when convenient, even though it's no longer in the tracked files.
