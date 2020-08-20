package io.openliberty.guides.rest;

import java.util.Properties;
import org.json.simple.JSONObject;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("propertiesJavaRuntimeName")
public class PropertiesJavaRuntimeName {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public String getProperties() {
        final String javaHome = System.getProperty("java.runtime.name");

       return(javaHome);
    }

}