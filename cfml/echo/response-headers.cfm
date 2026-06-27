<cfscript>
    // ─────────────────────────────────────────────────────────────────────
    // Response-header reflector.
    //
    // Every URL query param is echoed back as a response header of the same
    // name, e.g. /echo/response-headers.cfm?X-Custom-Response=HelloWorld
    // produces a `X-Custom-Response: HelloWorld` header on the response.
    //
    // The same key/value map is also returned in the JSON body under
    // "reflected" so a client can assert on it without parsing headers.
    // ─────────────────────────────────────────────────────────────────────

    for ( key in url ) {
        cfheader( name = key, value = url[ key ] );
    }

    cfcontent( type = "application/json; charset=utf-8" );
    writeOutput( serializeJSON( { "reflected" = url } ) );
</cfscript>
