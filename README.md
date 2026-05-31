# RustCFML Cloudflare Worker

Reference Cloudflare Workers host wiring for [`cfml-worker`](../crates/cfml-worker).

Demonstrates:

- Lazy session storage in Workers KV (`this.lazySessionCreation`).
- Durable Object–backed application scope with strong consistency.
- Cron-driven KV tidy-up that deletes expired session blobs on a
  configurable schedule (`onSessionEnd` is **not** supported in the
  Cloudflare host — see notes below).
- `<cfquery>` against Postgres or MySQL via Cloudflare Hyperdrive,
  using JSPI to make the underlying async driver look synchronous to
  CFML. Dispatched through `postgres` (postgres.js) or `mysql2/promise`,
  selected from the Hyperdrive binding's `connectionString` prefix.

## How `<cfquery>` works (JSPI architecture)

`#[event(fetch)]` from `worker-macros` is async — `wasm-bindgen-futures`
drives the request via a poll loop, with the original wasm fetch call
returning a Promise handle to JS long before request work is done. That
breaks the contiguous-wasm-stack requirement of `WebAssembly.promising`:
Suspending imports invoked from inside the async-driven activation have
no promising wrapper above them on the wasm stack and the request hangs.

The fix in `cfml-worker` (introduced for Hyperdrive support):

1. `handle_fetch` stays async. It does all the KV/DO worker-SDK awaits
   needed to prime session and application scope before the VM runs.
2. The VM execution is split off into a **separate sync wasm export**
   (`cfml_worker_run_sync` in `cfml_worker::sync_runner`). It pops a
   `RunContext` staged in a thread-local and runs the VM synchronously.
3. The async handler invokes that export via a JS import that awaits
   `WebAssembly.promising(wasm.cfml_worker_run_sync)`. That call site is
   a *fresh* contiguous wasm activation — JSPI gets a clean stack to
   suspend on when `<cfquery>` hits the Hyperdrive Suspending import.
4. The post-build patch (`jspi-patch.mjs`) installs the promising wrapper
   on `globalThis.__cfmlJspi.runSync`, bypasses the wasm-bindgen JS
   adapter for the Suspending import, hoists CommonJS `__require("node:*")`
   calls into real ESM imports (so `postgres` / `mysql2` bundle under
   `nodejs_compat`), and wires `setEnv` / `clearEnv` around the fetch
   entry.

A smoke test at `/__cfml_smoke` bypasses the entire CFML execution and
calls the Hyperdrive Suspending directly from a sync wasm activation —
handy for isolating JSPI plumbing from CFML semantics when debugging.

## Layout

| Path | Purpose |
|---|---|
| `src/lib.rs` | Worker entry — `#[event(fetch)]`, `#[event(scheduled)]`, `#[durable_object] ApplicationScopeDO`. |
| `build.rs` | Walks `cfml/` at build time and emits a static `CFML_FILES` table. |
| `cfml/Application.cfc` | Sample app demonstrating `onApplicationStart`, `onSessionStart`, `onSessionEnd`. |
| `cfml/index.cfm` | Sample page reading from session + application scope. |
| `wrangler.toml` | Bindings + cron trigger. Edit the `<paste-id-here>` placeholders. |

## Setup

1. Install `wrangler`, `worker-build`, and the npm dev deps:
   ```bash
   npm i -g wrangler
   cargo install worker-build
   npm install        # pulls in `postgres` and `mysql2` for the JSPI snippet
   ```
2. Provision KV namespaces:
   ```bash
   wrangler kv namespace create SESSIONS   # paste the returned id into wrangler.toml
   wrangler kv namespace create APP
   ```
3. (Optional) Provision Hyperdrive bindings for the databases you want
   `<cfquery>` to reach. Declare only the engines you actually use.

   Hyperdrive stores the connection string **encrypted on Cloudflare** and
   hands back an `id`. Only that `id` goes in `wrangler.toml` — the
   credentials never touch the repo. Let wrangler prompt for the
   connection string interactively so the password stays out of your shell
   history:
   ```bash
   wrangler hyperdrive create rustcfml-pg      # prompts for the connection string
   wrangler hyperdrive create rustcfml-mysql
   ```
   (Or pass `--connection-string="postgres://user:pass@host:5432/dbname"`
   non-interactively in CI, sourcing the value from a secret store rather
   than typing it inline.)

   Uncomment the matching `[[hyperdrive]]` blocks in `wrangler.toml` and
   paste the returned ids. CFML datasource names map 1:1 to the binding
   names (`HYPERDRIVE_PG`, `HYPERDRIVE_MYSQL`).
4. Deploy:
   ```bash
   wrangler deploy
   ```

## Session tidy-up cadence

The `[triggers] crons` entry in `wrangler.toml` controls how often the
worker sweeps expired session blobs from KV. The default is
`*/30 * * * *` (every 30 minutes). Tighten or loosen it freely — the
only knock-on effect is timeliness of cleanup vs. KV `list` cost.

**`onSessionEnd` is deliberately not implemented.** Firing it from the
scheduled handler would require loading Application.cfc and spinning up
a VM per expired session, which is heavy and rarely needed in a
serverless deployment. If your app needs cleanup semantics:

- Make `onSessionStart` idempotent and recover from cold state there, or
- Write a CFML page that does the cleanup and hit it from a separate
  cron (e.g. via the `[triggers]` mechanism pointing at a fetch URL).

## Verifying DO-backed application scope

After deploy, hit the worker from two different regions in quick
succession (e.g. `curl --resolve` against two PoPs). `application.requestCount`
should stay monotonically increasing — that's strong consistency the
KV-only path can't guarantee.

## Notes

- This crate is **not** a workspace member because the host is wasm32-only;
  `cargo build` from the repo root will not pick it up. Build it from
  this directory.
- The `[build] command = "worker-build --release"` line handles wasm-bindgen
  output, JSPI wiring (`WebAssembly.promising`), and the JSPI snippet copy
  from `cfml-worker/src/cfml_jspi.js`. No hand-rolled bootstrap mjs needed.
- For multi-app deployments, append every `this.name` to `config.app_names`
  in `src/lib.rs`. Each application gets its own DO instance via
  `idFromName(<app_name>)`.
