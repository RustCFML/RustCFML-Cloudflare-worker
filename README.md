# RustCFML Worker

A Cloudflare Worker that runs [RustCFML](https://github.com/RustCFML/RustCFML) — a pure-Rust CFML interpreter — compiled to WebAssembly and deployed at the edge.

**Live demo:** https://rustcfml-worker.rustcfml.workers.dev

---

## What this is

CFML files under `cfml/` are embedded into the worker binary at compile time. When a request arrives, the worker maps the URL path to a `.cfm` file, runs it through the full RustCFML pipeline (tag pre-processor → parser → compiler → VM), and returns the output as an HTTP response.

CFC files are resolved from the same embedded virtual filesystem, so `createObject`, `new ComponentName()`, and `<cfinclude>` all work without any filesystem access at runtime.

## Project layout

```
cfml/                    CFML application files — edit these
├── index.cfm            Served at GET /
├── about.cfm            Served at GET /about
└── components/
    └── Greeter.cfc      Example CFC called from index.cfm
build.rs                 Embeds cfml/ into the binary at compile time
src/lib.rs               Worker entry point — routing, VM setup, scope injection
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

| Scope | Contains |
|-------|----------|
| `url` | Query string parameters (`url.name`, `url.page`, …) |
| `cgi` | HTTP metadata (`cgi.request_method`, `cgi.path_info`, `cgi.http_host`, …) |
| `form` | POST body parameters when `Content-Type: application/x-www-form-urlencoded` |

`cfheader`, `cflocation`, and `cfcontent` are all respected and flow through to the HTTP response.

## RustCFML version

Pinned to `v0.15.0` via git tag in `Cargo.toml`. To upgrade:

```toml
cfml-vm = { git = "https://github.com/RustCFML/RustCFML", tag = "v0.16.0" }
```

Update all five `cfml-*` lines to the same tag, then run `cargo check --target wasm32-unknown-unknown` before deploying.

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

RustCFML v0.15 doesn't support:
- `cfthread` (concurrent threading)
- `cfschedule`
- `cfmail` / `cfhttp` (no outbound I/O in a Cloudflare Worker without bindings)
- `queryExecute` (no database — add a D1 binding and register a native query function)
- Session scope (stateless — use KV or Durable Objects for persistence)
- `Application.cfc` lifecycle hooks
