component {

    property name="name" type="string";

    public function init( required string name ) {
        variables.name = arguments.name;
        return this;
    }

    public string function greet() {
        return "Hello, #variables.name#!";
    }

    public string function greetFormal( string title = "World" ) {
        return "Greetings, #arguments.title# #variables.name#. Welcome to RustCFML on Cloudflare Workers.";
    }

    public array function getFacts() {
        return [
            "RustCFML is a CFML interpreter written in Rust",
            "It compiles to WebAssembly and runs at the edge",
            "No JVM — just a ~8 MB binary",
            "Startup time: instant"
        ];
    }

}
