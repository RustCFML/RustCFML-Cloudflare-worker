# RustCFML Worker

A Cloudflare Worker that runs [RustCFML](https://github.com/RustCFML/RustCFML) — a pure-Rust CFML interpreter — compiled to WebAssembly and deployed at the edge.

**Live demo:** https://rustcfml-worker.rustcfml.workers.dev

---

## What this is

CFML files under `cfml/` are embedded into the worker binary at compile time. When a request arrives, the worker maps the URL path to a `.cfm` file, runs it through the full RustCFML pipeline (tag pre-processor → parser → compiler → VM), and returns the output as an HTTP response.

CFC files are resolved from the same embedded virtual filesystem, so `createObject`, `new ComponentName()`, and `<cfinclude>` all work without any filesystem access at runtime.

Almost all of the hosting machinery (VFS, scope builders, routing, `Application.cfc` lifecycle, KV/D1 wiring, JSPI bridge) lives in the `cfml-worker` crate that ships with RustCFML. This template just provides the embedded CFML file table, the bindings glue, and a JSPI shim for async Cloudflare bindings.

## Project layout

```
cfml/                       CFML application files — edit these
├── Application.cfc         onApplicationStart / onSessionStart / onRequestStart
├── index.cfm               Served at GET /
├── about.cfm               Served at GET /about
├── d1.cfm                  D1 cfquery / queryExecute demo (GET /d1)
└── components/
    └── Greeter.cfc         Example CFC called from index.cfm
build.rs                    Embeds cfml/ into the binary at compile time
src/
├── lib.rs                  29-line worker entry; delegates to cfml-worker crate
├── jspi-shim.mjs           Worker entry that enables WebAssembly.promising
└── cfml-jspi-shim.mjs      Suspending d1_query import + alloc/free helpers
Cargo.toml
wrangler.toml
```

## Adding pages and components

- **New page:** add `cfml/mypage.cfm` → served at `GET /mypage`
- **Sub-path:** add `cfml/blog/post.cfm` → served at `GET /blog/post`
- **Index fallback:** add `cfml/blog/index.cfm` → served at `GET /blog`
- **New CFC:** add `cfml/components/MyService.cfc` → usable in CFML as `new components.MyService()`

`build.rs` picks up all `.cfm` / `.cfc` files automatically on the next build.

## Request context in CFML

The following scopes are injected for every request:

| Scope         | Contains                                                                 |
|---------------|--------------------------------------------------------------------------|
| `url`         | Query string parameters (`url.name`, `url.page`, …)                      |
| `cgi`         | HTTP metadata (`cgi.request_method`, `cgi.path_info`, `cgi.http_host`, …) |
| `form`        | POST body parameters when `Content-Type: application/x-www-form-urlencoded` |
| `session`     | Per-visitor state (requires `SESSIONS` KV binding — see below)           |
| `application` | Cross-isolate shared state (requires `APPLICATION` KV binding)           |

`cfheader`, `cflocation`, and `cfcontent` are all respected and flow through to the HTTP response.

## Application.cfc lifecycle

`cfml/Application.cfc` is loaded once per isolate and fires the standard lifecycle hooks:

- `onApplicationStart()` — first request to an application name
- `onSessionStart()` — first request for a new session cookie
- `onRequestStart( targetPage )` — every request, before the target `.cfm` runs

Set `this.name`, `this.sessionManagement`, and `this.sessionTimeout` as you would on a traditional CFML engine.

> **v1 limitation:** `onSessionEnd` does not fire for KV-backed sessions. KV TTL evicts the bytes silently; a scheduled-handler sweep is planned but not shipped.

## Bindings

The worker reads three optional bindings from `env` and wires them into CFML automatically. All are commented out in `wrangler.toml` — uncomment and supply IDs to opt in.

### `SESSIONS` (KV) — session scope persistence

```bash
wrangler kv namespace create SESSIONS
```

Paste the returned `id` into the `[[kv_namespaces]]` block for `SESSIONS`. Without this binding, session scope is in-memory per isolate (effectively useless on Workers).

### `APPLICATION` (KV) — application scope persistence

```bash
wrangler kv namespace create APPLICATION
```

Paste the returned `id` into the `[[kv_namespaces]]` block for `APPLICATION`. Eventually consistent across isolates — fine for config / factory caches, not ideal for counters. A Durable Object backend is planned for stronger consistency.

### `MAIN` (D1) — `<cfquery>` and `queryExecute()`

```bash
wrangler d1 create rustcfml-worker
wrangler d1 execute rustcfml-worker --remote \
  --command="CREATE TABLE things (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP)"
```

Paste the returned `database_id` into the `[[d1_databases]]` block. The binding name (`MAIN`) is matched case-insensitively against the `datasource` attribute in CFML, so `<cfquery datasource="main">` resolves to this binding.

D1 calls cross the sync/async boundary via [JSPI](https://github.com/WebAssembly/js-promise-integration). `src/jspi-shim.mjs` wraps the worker-build wasm export with `WebAssembly.promising` and supplies the suspending `d1_query` import — if you swap `main` in `wrangler.toml` back to the default `build/worker/shim.mjs`, cfquery will return a runtime error.

`cfml/d1.cfm` is a working demo using both `<cfquery>` and `queryExecute()` with parameterised inserts.

## RustCFML version

This template depends on the `cfml-worker` crate via a local path:

```toml
cfml-worker = { path = "../RustCFML/crates/cfml-worker" }
```

Point this at your checkout of RustCFML, or replace with a git dependency:

```toml
cfml-worker = { git = "https://github.com/RustCFML/RustCFML", tag = "vX.Y.Z" }
```

Then run `cargo check --target wasm32-unknown-unknown` before deploying.

---

## Prerequisites

```bash
# Rust with the wasm32 target
rustup target add wasm32-unknown-unknown

# Wrangler CLI (v4+)
npm install -g wrangler
```

## Local development

```bash
# Install worker-build (needed once)
cargo install worker-build

# Start a local dev server at http://localhost:8787
wrangler dev
```

`wrangler dev` (without `--remote`) uses Miniflare-backed KV and SQLite-backed D1 stored under `.wrangler/state/`, so you can exercise sessions and D1 without any cloud setup.

Changes to `.cfm` / `.cfc` files require a rebuild since they're embedded at compile time. Wrangler's `--watch` flag will trigger a rebuild on any file change:

```bash
wrangler dev --watch
```

## Deploying to Cloudflare

### First time

1. Create a free account at [dash.cloudflare.com](https://dash.cloudflare.com)
2. Log in via the CLI:
   ```bash
   wrangler login
   ```
3. Register a `workers.dev` subdomain — **required once per account:**
   - Go to **dash.cloudflare.com → Workers & Pages → Get started**
   - Choose a subdomain (e.g. `yourname.workers.dev`)
4. Deploy:
   ```bash
   wrangler deploy
   ```
   Your worker will be live at `https://rustcfml-worker.<your-subdomain>.workers.dev` (e.g. `https://rustcfml-worker.rustcfml.workers.dev`)

### Subsequent deploys

```bash
wrangler deploy
```

That's it. `wrangler deploy` runs `worker-build` (which compiles Rust → WASM → optimises with `wasm-opt`), then uploads the bundle to Cloudflare.

### Viewing live logs

```bash
wrangler tail
```

### Rolling back

```bash
wrangler rollback          # revert to previous version
wrangler versions list     # see all deployed versions
```

## What's not supported

RustCFML in a Worker context doesn't support:
- `cfthread` (no threads in a Worker isolate)
- `cfschedule` (use Cloudflare Cron Triggers instead)
- `cfmail` (use a transactional-mail binding from your `Application.cfc`)
- `cfhttp` (use `fetch` via a service binding or a wrapper function)
- File I/O (`cffile`, `cfdirectory`) — the VFS is read-only and embedded at compile time
- `onSessionEnd` for KV-backed sessions (planned; pending a scheduled-handler sweep)
