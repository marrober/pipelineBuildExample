package io.openliberty.guides.rest;

import javax.ws.rs.core.Application;
import javax.ws.rs.ApplicationPath;

// tag::applicationPath[]
@ApplicationPath("System")
// end::applicationPath[]
// tag::systemApplication[]
public class SystemApplication extends Application {

}
// end::systemApplication[]