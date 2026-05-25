<!---
    D1 cfquery demo.

    Run on Workers with a D1 binding named "main" (see wrangler.toml).
    The page expects a `things` table; create it via:

        wrangler d1 execute MAIN --command="CREATE TABLE things (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP)"
        wrangler d1 execute MAIN --command="INSERT INTO things (name) VALUES ('alpha'), ('beta'), ('gamma')"
--->
<cfscript>
    name = url.name ?: "";

    if ( name != "" ) {
        // Parameterised insert via queryExecute.
        queryExecute(
            "INSERT INTO things (name) VALUES (?)",
            [ name ],
            { datasource: "main" }
        );
    }

    // Read back via cfquery tag form.
</cfscript>

<cfquery name="things" datasource="main">
    SELECT id, name, created_at FROM things ORDER BY id DESC LIMIT 20
</cfquery>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>RustCFML Worker · D1 demo</title>
    <style>
        body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; max-width: 720px; margin: 0 auto; }
        h1 { font-size: 1.75rem; color: #f6821f; }
        table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
        th, td { padding: 0.5rem 0.75rem; text-align: left; border-bottom: 1px solid #1e293b; }
        th { color: #94a3b8; font-weight: 500; }
        form { margin-top: 1.5rem; display: flex; gap: 0.75rem; }
        input { background: #1e293b; border: 1px solid #334155; color: #e2e8f0; padding: 0.5rem 1rem; border-radius: 6px; }
        button { background: #f6821f; border: none; color: white; padding: 0.5rem 1.25rem; border-radius: 6px; cursor: pointer; }
        nav a { color: #64748b; text-decoration: none; margin-right: 1.5rem; }
        nav a:hover { color: #f6821f; }
    </style>
</head>
<body>
    <nav><a href="/">Home</a><a href="/about">About</a><a href="/d1">D1 demo</a></nav>

    <cfoutput>
    <h1>D1 demo · #things.recordCount# rows</h1>

    <form method="get" action="/d1">
        <input type="text" name="name" placeholder="Add a thing" autofocus>
        <button type="submit">Insert</button>
    </form>

    <table>
        <thead>
            <tr><th>id</th><th>name</th><th>created_at</th></tr>
        </thead>
        <tbody>
            <cfloop query="things">
                <tr>
                    <td>#things.id#</td>
                    <td>#things.name#</td>
                    <td>#things.created_at#</td>
                </tr>
            </cfloop>
        </tbody>
    </table>
    </cfoutput>
</body>
</html>
