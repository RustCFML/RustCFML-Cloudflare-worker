#!/bin/sh
# worker-build's bundle step does not know about `nodejs_compat`. We
# intercept the esbuild invocation via the ESBUILD_BIN override and force
# `--platform=node`, which makes esbuild treat Node built-ins as external
# for BOTH `import` and `require()` paths (sql-escaper, a transitive
# mysql2 dep, uses CommonJS `require("node:buffer")`). Workers
# `nodejs_compat` then resolves them at runtime.
#
# Postgres.js and mysql2 are otherwise bundled normally.

set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
ESBUILD="$HERE/../node_modules/.bin/esbuild"

exec "$ESBUILD" --platform=node "$@"
