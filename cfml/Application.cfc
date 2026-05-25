component {

    this.name = "rustcfml-worker";
    this.sessionManagement = true;
    this.sessionTimeout = createTimeSpan( 0, 0, 30, 0 );

    public boolean function onApplicationStart() {
        application.startedAt = now();
        application.hitCounter = 0;
        return true;
    }

    public boolean function onSessionStart() {
        session.startedAt = now();
        session.pageViews = 0;
        return true;
    }

    public boolean function onRequestStart( required string targetPage ) {
        application.hitCounter = ( application.hitCounter ?: 0 ) + 1;
        session.pageViews     = ( session.pageViews     ?: 0 ) + 1;
        return true;
    }

}
