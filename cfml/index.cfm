<cfscript>
    greeter  = new components.Greeter( url.name ?: "World" );
    greeting = greeter.greet();
    formal   = greeter.greetFormal();
    facts    = greeter.getFacts();
    nameVal  = encodeForHTMLAttribute( url.name ?: "" );

    factItems = "";
    for ( f in facts ) {
        factItems &= "<li>" & f & "</li>";
    }
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>RustCFML Worker</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; max-width: 720px; margin: 0 auto; }
    h1 { font-size: 2rem; color: #f6821f; }
    h2 { color: #94a3b8; font-size: 1rem; font-weight: 400; margin-top: 0; }
    ul { line-height: 2; }
    li::marker { color: #f6821f; }
    .meta { color: #475569; font-size: 0.85rem; margin-top: 2rem; border-top: 1px solid #1e293b; padding-top: 1rem; }
    nav a { color: #64748b; text-decoration: none; margin-right: 1.5rem; }
    nav a:hover { color: #f6821f; }
    form { margin-top: 1.5rem; display: flex; gap: 0.75rem; }
    input { background: #1e293b; border: 1px solid #334155; color: #e2e8f0; padding: 0.5rem 1rem; border-radius: 6px; font-size: 1rem; }
    button { background: #f6821f; border: none; color: white; padding: 0.5rem 1.25rem; border-radius: 6px; font-size: 1rem; cursor: pointer; }
  </style>
</head>
<body>
  <nav><a href="/">Home</a><a href="/about">About</a></nav>

  <cfoutput>
  <h1>#greeting#</h1>
  <h2>#formal#</h2>

  <h3>Facts</h3>
  <ul>#factItems#</ul>

  <form method="get" action="/">
    <input type="text" name="name" placeholder="Enter your name" value="#nameVal#">
    <button type="submit">Greet me</button>
  </form>
  </cfoutput>

  <div class="meta">RustCFML on Cloudflare Workers &middot; timing via <code>wrangler tail</code></div>
</body>
</html>
