// Comment

package io.openliberty.guides.rest;

import java.util.Properties;
import org.json.simple.JSONObject;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

// oc get route liberty-rest-route -o jsonpath='{"http://"}{.spec.host}{"/System/propertiesJavaHome"}'

@Path("propertiesJavaHome")
public class PropertiesJavaHome {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public String getProperties() {
<<<<<<< HEAD
       String javaHome = "Java Home -=----> " + System.getProperty("java.home");
=======
       String javaHome = "Java Home -----> " + System.getProperty("java.home");
>>>>>>> triggers

       return(javaHome);
    }

}
