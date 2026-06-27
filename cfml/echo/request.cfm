<cfscript>
    // ─────────────────────────────────────────────────────────────────────
    // Request mirror — a stable, highly-available HTTP echo endpoint.
    //
    // Returns a JSON description of the incoming request: method, url, query
    // args, form fields, headers (original case), cookies and the raw body.
    // Works for GET / POST / PUT / PATCH / DELETE.
    //
    // This is the edge-hosted replacement for httpbin.org used by the RustCFML
    // engine test-suite (tests/stdlib/test_cfhttp.cfm). httpbin was flaky;
    // this worker is deployed on Cloudflare and effectively always-on.
    //
    // Response shape:
    //   {
    //     "method":      "POST",
    //     "url":         "https://host/echo/request.cfm?foo=bar",
    //     "path":        "/echo/request.cfm",
    //     "queryString": "foo=bar",
    //     "args":        { "foo": "bar" },              // url scope (keys lc)
    //     "form":        { "username": "bob" },         // form scope
    //     "headers":     { "X-Custom-Header": "v", ... },// original case
    //     "cookies":     { "session_id": "abc123" },    // cookie scope
    //     "body":        "<raw request body>",
    //     "userAgent":   "<User-Agent header>"
    //   }
    // ─────────────────────────────────────────────────────────────────────

    requestData = getHttpRequestData();

    fullUrl = cgi.request_url;
    if ( len( cgi.query_string ) ) {
        fullUrl &= "?" & cgi.query_string;
    }

    mirror = {
          "method"      = cgi.request_method
        , "url"         = fullUrl
        , "path"        = cgi.script_name
        , "queryString" = cgi.query_string
        , "args"        = url
        , "form"        = form
        , "headers"     = requestData.headers
        , "cookies"     = cookie
        , "body"        = requestData.content ?: ""
        , "userAgent"   = requestData.headers[ "User-Agent" ] ?: ""
    };

    cfcontent( type = "application/json; charset=utf-8" );
    writeOutput( serializeJSON( mirror ) );
</cfscript>
