<cfscript>
    request.pageTitle = "HTTP test server (echo endpoints)";
    request.activeNav = "echo";

    base = "#cgi.https eq 'on' ? 'https' : 'http'#://#cgi.server_name#";
</cfscript>
<cfinclude template="../includes/header.cfm">
<cfoutput>

<div class="panel">
    <div class="panel-header">What this is</div>
    <div class="panel-body">
        <p>A small, always-on HTTP echo service used by the
        <strong>RustCFML engine test-suite</strong> to exercise
        <code>&lt;cfhttp&gt;</code>. It replaces the public
        <code>httpbin.org</code> dependency, which was flaky in CI. Because it
        runs on Cloudflare's edge it is effectively always available and low
        latency from anywhere.</p>
        <p>Each endpoint returns JSON. Point a client at the URLs below.</p>
    </div>
</div>

<div class="panel">
    <div class="panel-header">/echo/request.cfm — request mirror</div>
    <div class="panel-body">
        <p>Returns a JSON description of the request: method, full URL, query
        <code>args</code>, <code>form</code> fields, <code>headers</code>
        (original case), <code>cookies</code> and the raw <code>body</code>.
        Works for GET / POST / PUT / PATCH / DELETE.</p>
        <pre class="code">GET #base#/echo/request.cfm?foo=bar</pre>
        <pre class="output">#encodeForHTML( serializeJSON( {
              "method"      = "GET"
            , "url"         = "#base#/echo/request.cfm?foo=bar"
            , "path"        = "/echo/request.cfm"
            , "queryString" = "foo=bar"
            , "args"        = { "foo" = "bar" }
            , "form"        = {}
            , "headers"     = { "Host" = cgi.server_name }
            , "cookies"     = {}
            , "body"        = ""
            , "userAgent"   = ""
        } ) )#</pre>
        <p><a class="go" href="/echo/request.cfm?foo=bar">Try it &rarr;</a></p>
    </div>
</div>

<div class="panel">
    <div class="panel-header">/echo/response-headers.cfm — header reflector</div>
    <div class="panel-body">
        <p>Echoes every query param back as a response header of the same name,
        and returns the same map as JSON under <code>reflected</code>.</p>
        <pre class="code">GET #base#/echo/response-headers.cfm?X-Custom-Response=HelloWorld
&rarr; X-Custom-Response: HelloWorld</pre>
        <p><a class="go" href="/echo/response-headers.cfm?X-Custom-Response=HelloWorld">Try it &rarr;</a></p>
    </div>
</div>

<div class="panel">
    <div class="panel-header">/echo/status.cfm — status code</div>
    <div class="panel-body">
        <p>Responds with the status code in <code>?code=NNN</code> (default
        200).</p>
        <pre class="code">GET #base#/echo/status.cfm?code=404</pre>
        <p><a class="go" href="/echo/status.cfm?code=404">Try it &rarr;</a></p>
    </div>
</div>

</cfoutput>
<cfinclude template="../includes/footer.cfm">
