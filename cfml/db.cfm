<cfscript>
    request.pageTitle = "Hyperdrive query demo";
    request.activeNav = "db";

    // Both bindings are optional. Default to Postgres; override with
    // /db.cfm?ds=HYPERDRIVE_MYSQL once a MySQL Hyperdrive binding is set
    // up in wrangler.toml.
    datasource = url.ds ?: "HYPERDRIVE_PG";

    queryError = "";
    rs = "";
    try {
        rs = queryExecute(
            "SELECT 1 AS one, 'hello from hyperdrive' AS greeting",
            [],
            { datasource: datasource }
        );
    } catch (any e) {
        queryError = e.message;
    }
</cfscript>
<cfinclude template="includes/header.cfm">
<cfoutput>

<div class="panel">
    <div class="panel-header">Hyperdrive datasource</div>
    <div class="panel-body">
        <p>This page runs <code>queryExecute()</code> against the
        Hyperdrive binding named <strong>#datasource#</strong>. The CFML
        side is synchronous; the underlying <code>postgres</code> /
        <code>mysql2</code> client is awaited inside a JSPI suspending
        callback while the wasm stack is parked.</p>
        <p>Switch engines by visiting
        <a href="/db.cfm?ds=HYPERDRIVE_PG">?ds=HYPERDRIVE_PG</a> or
        <a href="/db.cfm?ds=HYPERDRIVE_MYSQL">?ds=HYPERDRIVE_MYSQL</a>.
        The binding must be declared in <code>wrangler.toml</code>.</p>
    </div>
</div>

<cfif len(queryError)>
<div class="panel">
    <div class="panel-header">Query failed</div>
    <div class="panel-body">
        <pre><code>#encodeForHTML(queryError)#</code></pre>
    </div>
</div>
<cfelse>
<div class="panel">
    <div class="panel-header">Result</div>
    <div class="panel-body">
        <dl class="kv">
            <dt>recordCount</dt><dd>#rs.recordCount#</dd>
            <dt>columnList</dt><dd>#rs.columnList#</dd>
            <dt>duration</dt><dd>#rs._meta.duration_ms# ms</dd>
        </dl>
        <p>Raw result JSON:</p>
        <pre>#encodeForHTML(serializeJSON(rs))#</pre>
    </div>
</div>
</cfif>

</cfoutput>
<cfinclude template="includes/footer.cfm">
