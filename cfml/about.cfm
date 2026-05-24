<cfscript>
    pageTitle = "About";

    stats = {
        memory:  "~8 MB",
        startup: "instant",
        rps:     "~2,500",
        runtime: "Cloudflare Workers (WASM)"
    };
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><cfoutput>#pageTitle# — RustCFML Worker</cfoutput></title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; max-width: 720px; margin: 0 auto; }
    h1 { color: #f6821f; }
    table { border-collapse: collapse; width: 100%; margin-top: 1rem; }
    th, td { text-align: left; padding: 0.6rem 1rem; border-bottom: 1px solid #1e293b; }
    th { color: #94a3b8; font-weight: 600; }
    td:last-child { color: #f6821f; font-family: monospace; }
    nav a { color: #64748b; text-decoration: none; margin-right: 1.5rem; }
    nav a:hover { color: #f6821f; }
  </style>
</head>
<body>
  <nav><a href="/">Home</a><a href="/about">About</a></nav>
  <h1>About RustCFML on Cloudflare Workers</h1>

  <p>
    <a href="https://github.com/RustCFML/RustCFML" style="color:#f6821f">RustCFML</a>
    is a CFML interpreter written entirely in Rust. It compiles to WebAssembly and
    runs inside Cloudflare's edge network with no JVM, no container, and no cold-start delay.
  </p>

  <h2>Runtime stats</h2>
  <table>
    <tr><th>Metric</th><th>Value</th></tr>
    <cfloop collection="#stats#" item="key">
      <cfoutput><tr><td>#key#</td><td>#stats[key]#</td></tr></cfoutput>
    </cfloop>
  </table>

  <h2>How this worker is built</h2>
  <p>
    CFML files under <code>cfml/</code> are embedded into the worker binary at compile time
    via a <code>build.rs</code> script. The Cloudflare Worker receives HTTP requests, maps
    the URL path to a <code>.cfm</code> file, runs it through the RustCFML pipeline
    (tag pre-processor → parser → compiler → VM), and streams the output back as HTML.
    CFC files are resolved from the same embedded virtual filesystem, so
    <code>createObject</code>, <code>new</code>, and <code>&lt;cfinclude&gt;</code> all work.
  </p>
</body>
</html>
