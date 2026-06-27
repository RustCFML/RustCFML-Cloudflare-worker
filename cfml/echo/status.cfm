<cfscript>
    // ─────────────────────────────────────────────────────────────────────
    // Status-code endpoint.
    //
    // Returns the HTTP status code given in `?code=NNN` (default 200), with a
    // small JSON body echoing it. Useful for exercising cfhttp status handling
    // and error paths, e.g. /echo/status.cfm?code=404
    // ─────────────────────────────────────────────────────────────────────

    code = val( url.code ?: 200 );
    if ( code < 100 || code > 599 ) {
        code = 200;
    }

    cfheader( statusCode = code, statusText = "" );
    cfcontent( type = "application/json; charset=utf-8" );
    writeOutput( serializeJSON( { "status" = code } ) );
</cfscript>
