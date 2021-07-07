Table of Content

1. [Introduction](#introduction)
    1. [Access to the source content](#access-to-the-source-content)
    2. [A comment on names](#a-comment-on-names)
2. [Introducing OpenShift Pipelines](#introducing-openshift-pipelines)
    1. [TASK EXECUTION HIERARCHY](#task-execution-hierarchy)
    2. [TASKS](#tasks)
    3. [ELEMENTS OF A STEP](#elements-of-a-step)
        1. [command](#command)
        2. [script](#script)
        3. [volumeMounts](#volumemounts)
        4. [workingDir](#workingdir)
        5. [parameters](#parameters)
        6. [resources](#resources)
            1. [Git Resource](#git-resource)
            2. [Image Resource](#image-resource)
        7. [workspace](#workspace)
        8. [image](#image)
3. [Source to Image Build in a Tekton pipeline](#source-to-image-build-in-a-tekton-pipeline)
    1. [Creating a runtime image without source code](#creating-a-runtime-image-without-source-code)
        1. [SOURCE TO IMAGE BUILD PROCESS](#source-to-image-build-process)
        2. [CONSUMING THE DOCKERFILE - RUNNING THE BUILD](#consuming-the-dockerfile---running-the-build)
4. [Image creation in Tekton](#image-creation-in-tekton)
    1. [Creating the runtime image](#creating-the-runtime-image)
    2. [Clear existing application resources](#clear-existing-application-resources)
        1. [Dependent tasks in tekton](#dependent-tasks-in-tekton)
        1. [Clear Resources task](#clear-resources-task)
    3. [Push image to quay.io](#push-image-to-quayio)
        1. [Content in the buildah repository](#content-in-the-buildah-repository)
        2. [Push to quay.io](#push-to-quayio)
5. [Application Deployment](#application-deployment)
    1. [Generation of deployment yaml file](#generation-of-deployment-yaml-file)
    2. [Creation of application resources](#creation-of-application-resources)
6. [Pipeline orchestration](#pipeline-orchestration)
    1. [Pipeline](#pipeline)
    2. [Pipeline run](#pipeline-run)
7. [Putting it all together](#putting-it-all-together)
    1. [Access to the source code and pipeline configuration](#access-to-the-source-code-and-pipeline-configuration)
    2. [Create the OpenShift project and assets](#create-the-openshift-project-and-assets)
    3. [Create a quay.io authentication secret](#create-a-quayio-authentication-secret)
    4. [Update parameters in the pipeline run](#update-parameters-in-the-pipeline-run)
    5. [Test the pipeline](#test-the-pipeline)
    6. [Test the application](#test-the-application)


# Introduction
OpenShift Pipelines is a Continuous Integration / Continuous Delivery (CI/CD) solution based on the open source Tekton project. The key objective of Tekton is to enable development teams to quickly create pipelines of activity from simple, repeatable steps. A unique characteristic of Tekton that differentiates it from previous CI/CD solutions is that Tekton steps execute within a container that is specifically created just for that task. This provides a degree of isolation that supports predictable and repeatable task execution, and ensures that development teams do not have to manage a shared build server instance. Additionally, Tekton components are Kubernetes resources which divests to the platform the management, scheduling, monitoring and removal of Tekton components.

This article is the first in a series that aims to show specific capabilities of Tekton for the purpose of carrying out the following main activities :

1. Build an application from source code using Maven and the OpenShift Source to Image process
2. Create a runtime container image
3. Push the image to the Quay image repository
4. Deploy the image into a project on OpenShift (after first clearing out the old version)

## Access to the source content
All assets required to create your own instance of the resources described in these articles can be found in the GitHub repository [here](https://github.com/marrober/pipelineBuildExample). In an attempt to save space and make the article more readable only the important aspects of Tekton resources are included within the text. Readers who want to see the context of a section of YAML should clone or download the Git repository and refer to the full version of the appropriate file.

## A comment on names
The Open Source Tekton project has been brought into the OpenShift platform as OpenShift Pipelines. 

`OpenShift Pipelines` and `Tekton` are often used `interchangeably`, and both will be used in this article.

# Introducing OpenShift Pipelines
OpenShift Pipelines is delivered to an OpenShift platform using the [Operator](https://www.openshift.com/learn/topics/operators) framework, which takes care of installing and managing all of the cluster components for you. This ensures that the system is simple to install and maintain over time within an OpenShift cluster. As soon as the Tekton Operator is installed users can start to add Tekton resources to their projects to create a build automation process.

Users can interact with OpenShift Pipelines using the web user interface, command line interface, and via a Visual Studio Code editor plugin. Other editor plugins do exist so check with your editors plugins page to see what it offers for Tekton. The command line access is a mixture of the OpenShift `oc` command line utility and the `tkn` command line for specific Tekton commands. The tkn and oc command line utilities can be downloaded from the OpenShift web user interface. Simply press the white circle containing a black question mark near your name on the top right corner and then select Command Line Tools as shown in figure 1.

![](/images/figure1.webp)

```Figure 1 - OpenShift web user interface command line tools access```

The fundamental resource of the Tekton process is the task. A Task contains at least one step to be executed and performs a useful function. It is possible to create a taskRun object that makes reference to a task, and enables the user to invoke the task. This will not be covered in this article since the purpose here is to create richer objects that can be used from within the OpenShift web user interface and can be called from a webhook as part of a CI/CD process. In the example presented here tasks are grouped into an ordered execution using a pipeline resource.

### TASK EXECUTION HIERARCHY
Tasks execute steps in the order in which they are written, with each step completing before the next step will start.

Pipelines execute tasks in parallel unless a task is directed to run after the completion of another task. This facilitates parallel execution of build / test / deploy activities and is a useful characteristic that guides the user in the grouping of steps within tasks.

A pipelineRun resource invokes the execution of a pipeline. This allows specific properties and resources to be used as inputs to the pipeline process, such that the steps within the tasks are configured for the requirements of the user or environment.

### TASKS
Each step has a number of elements that define how it will execute the required command. Figure 2 shows the elements of the step and the relationship between the above resources.

![](/images/figure2.webp)

```Figure 2 - Tekton resource relationship```

### ELEMENTS OF A STEP
The elements of the step are described below. Note that the snippets of YAML used to show the use of an element are not complete with respect to a working task, step or the command within the step.

#### command
The command to be executed. This can take the format of a sequence of a command and arguments as shown below under the step name :

``` yaml
- name: generate
     command:
       - s2i
       - build
       - $(params.PATH_CONTEXT)
       - registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
       - '--image-scripts-url'
       - 'image:///usr/local/s2i'
```

#### script
An alternative to the command is to use a script which can be useful if a single step is required to perform a number of command line operations as show below:

``` yaml
- name: parse-yaml
  script:|-
    #!/usr/bin/env python3
    ...
```

#### volumeMounts
A volumeMount is a mechanism for adding storage to a step. Since each step runs in an isolated container any data that is created by a step for use by another step must be stored appropriately. If the data is accessed by a subsequent step within the same task then it is possible to use the /workspace directory to hold any created files and directories. A further option for steps within the same task is to use an emptyDir storage mechanism which can be useful for separating out different data content for ease of use. If file stored data is to be accessed by a subsequent step that is in a different task then a Kubernetes persistent volume claim is required to be used.

Volumes are defined in a section of the task outside the scope of any steps, and then each step that needs the volume will mount it. The example below shows the volume definition and the use of a volume within a step.

``` yaml
 - name: view-images
     volumeMounts:
       - name: pipeline-cache
         mountPath: /var/lib/containers
       - name: gen-source
         mountPath: /gen-source
 - volumes:
   - name: gen-source
     emptyDir: {}
   - name: pipeline-cache
     persistentVolumeClaim:
       claimName: pipeline-task-cache-pvc
```

In the above example the view-images step uses an [emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) volume which is mounted under the path /gen-source. Other steps within the task can also mount this volume and reuse any data placed there by this step.

A persistent volume claim called pipeline-cache is mounted into the step at the path /var/lib/containers. Other steps within the task and within other tasks of the pipeline can also mount this volume and reuse any data placed there by this step. Note that the path used in this example is where the [Buildah](https://buildah.io/) command expects to find a local image repository. As a result any steps that invoke a Buildah command will mount this volume at this location.

#### workingDir
The path within the container which is to be the current working directory when the command is executed.

#### parameters
Textual information that is required by a step such as a path, a name of an object, a username etc. In a similar manner to volume Mounts, parameters are defined outside the scope of any step within a task and then they are referenced from within the step. The example below shows the definition of the TLSVERIFY parameter with a name, description, type and default value, together with the use of the parameter using the syntax :

``` yaml
$(params.<parameter-name>).
kind: Task
spec:
 params:
   - name: TLSVERIFY
     description: Verify the TLS on the registry endpoint
     type: string
     default: 'false'
 steps:
   - name: build
     command:
       - buildah
       - bud
       - '--tls-verify=$(params.TLSVERIFY)'
```

#### resources
Resources are similar to properties described above in that a reference to the resource is declared within the task and then the steps use the resources in commands. The example below shows the use of a resource called intermediate-image which is used as an output in a step within the task, meaning that the image is created by a command in the step. The example also shows the use of a Git input resource called source.

In Tekton there is no explicit Git pull command. Simply including a Git resource in a task definition will result in a Git pull action taking place, before any steps execute, which will pull the content of the Git repository to a location of `/workspace/<git-resource-name>`. In the example below the Git repository content is pulled to /workspace/source.

``` yaml
kind: Task
 resources:
   inputs:
     - name: source
       type: git
   outputs:
     - name: intermediate-image
       type: image
 steps :
   - name: build
     command:
       - buildah
       - bud
       - '-t'
       - $(resources.outputs.intermediate-image.url)
``` 

Resources may reference either an image or a Git repository and the resource entity is defined in a separate YAML file. Image resources may be defined as either input or output resources depending on whether an existing image is to be consumed by a step or whether the image is to be created by a step.

Examples of the definition of Git and image resources are shown below.

##### Git resource
``` yaml
apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
 name: liberty-rest-app-source-code
 namespace: liberty-rest
spec:
 params:
 - name: url
   value: https://github.com/marrober/pipelineBuildExample.git
 type: git
 ```

 The Git resource can also have a revision parameter which can be a reference to either a branch, tag, commit SHA or ref. If a revision is not specified, the resource inspects the remote repository to determine the correct default branch from which to pull.

 ##### Image Resource
 ``` yaml
 apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
 name: liberty-rest-app
 namespace: liberty-rest
spec:
 params:
 - name: url
   value: [image registry url]:5000/liberty-rest/liberty-rest-app
 type: image
```

The image resource does not have to point to a valid image stream on OpenShift. It is possible to create images within a local Buildah registry (stored on a shared volume as described above), manipulate the image as required and then push it to an OpenShift or Quay image repository as required. An example of an image resource that does not point to an image stream is shown below.

``` yaml
apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
 name: intermediate
 namespace: liberty-rest
spec:
 params:
 - name: url
   value: intermediate
 type: image
```

#### workspace
A workspace is similar to a volume in that it provides storage that can be shared across multiple tasks. A persistent volume claim is required to be created first and then the intent to use the volume is declared within the pipeline and task before mapping the workspace into an individual step such that it is mounted. Workspaces and volumes are similar in behaviour but are defined in slightly different places.

#### image
Since each Tekton step runs within its own image the image must be referenced as shown in the example below.

``` yaml
steps :
   - name: build
     command:
       - buildah
       - bud
       - '-t'
       - $(resources.outputs.intermediate-image.url)
     image: registry.redhat.io/rhel8/buildah
```

# Source to Image Build in a Tekton pipeline
The Red Hat OpenShift `Source to Image` (S2I) build process is a fantastic capability that allows a developer to point OpenShift at a Git source repository and OpenShift will perform the following tasks :

1. Examine the source code in the repository and identify the language used
2. Select a builder image for the identified language from the OpenShift image repository
3. Create an instance of the builder image from the image repository (green arrow on figure 3)
4. Clone the source code in the builder image and build the application (the grey box in figure 3). The entire build process including pulling in any dependencies takes place within the builder image.
5. When the build is complete push the builder image to the OpenShift image repository (the blue arrow on figure 3).
6. Create an instance of the builder image, with the built application, and execute the container in a pod (the purple arrow in figure 3).

![](/images/figure3.webp)

```Figure 3 - Source to image process```

All of the above actions take place simply by selecting a Git repository as shown in figure 4.

![](/images/figure4.webp)

```Figure 4 - Selecting a Git repository from which the source code should be built```

Note that in figure 4 the node.js language has been identified in the source code, and figure 4 also shows the full range of languages that are supported by S2I (as of OpenShift 4.5).

After a few seconds OpenShift created a number of resources as shown in figure 5, which are :

1. A build configuration to perform the build
2. A build has executed resulting in a new container image being created
3. The container has been started within a pod
4. A service has been created to communicate with the container in the pod
5. A route has been created to communicate with the service
All of the above has been created simply by pointing OpenShift at a Git repository.

![](/images/figure5.webp)

```Figure 5 - The result of a source to image build process```

## Creating a runtime image without source code
The source to image process is fantastic for creating running applications from source code quickly to accelerate development processes. However some customers want to have more control over the creation of a runtime image that is to be used in production. For example some customers don’t want the builder tools and source code in a production image, while others want to be able to create a master image into which the binary application should be injected before the image progresses through testing and pre-production environments on the way to production.

It is still possible to take advantage of the capabilities of the source to image process by treating the resulting image as an intermediate image and then extracting the binary executable and pushing it into a second runtime image. This process will be explained in the following section.

The summary of the steps performed in this stage are:

1. Create a configuration file to provide a mechanism for modifying the characteristics of the Maven build
2. Use the Source to Image process to create a dockerfile that performs the build
3. Use the Buildah image creation utility to execute the generated dockerfile which will perform the build of the example java application
4. Create a second dockerfile that will extract the deliverable and put it into the runtime image
5. Use the Buildah image creation utility to execute the generated dockerfile which will produce the runtime image containing the executable
6. Push the image to the OpenShift registry

### SOURCE TO IMAGE BUILD PROCESS
The Tekton task for this stage of the process is in the file `/build/tasks/build.yaml`

The first stage of the source to image process is to create an environment file with name and value properties such as:

``` bash
MAVEN_CLEAR_REPO=<value>
MAVEN_ARGS_APPEND=<value>
MAVEN_MIRROR_URL=<value>
```

Values are supplied as parameters to the task, from the pipeline, or they can be set as default values in the task file.

The second stage of the build task is to use the source to image ‘build’ process to create a dockerfile. The step within the task is shown below, with some parameters are resources that require explanation.

``` yaml
spec:
 params:
   - name: PATH_CONTEXT
     description: Path of the source code
     type: string
     default: .
 resources:
   inputs:
     - name: source
       type: git
 steps:
   - name: generate
     command:
       - s2i
       - build
       - $(params.PATH_CONTEXT)
       - registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
       - '--image-scripts-url'
       - 'image:///usr/local/s2i'
       - '--as-dockerfile'
       - /gen-source/Dockerfile.gen
       - '--environment-file'
       - /env-params/env-file
     image: registry.redhat.io/ocp-...-preview/source-to-image-rhel8
     volumeMounts:
       - name: gen-source
         mountPath: /gen-source
       - name: envparams
         mountPath: /env-params
     workingDir: /workspace/source
```
The reference to the Git resource at the top of the task file has a name of `source`. This ensures that the Git repository will be cloned to a directory of `/workspace/source` as shown in figure 6 labelled 1. The working directory of the step is set to this location and the S2I build process expects to find the source code in the location, identified by the parameter `$(params.PATH_CONTEXT)`, which is set to the value of ‘.’ as a default value.

![](/images/figure6.webp)

```Figure 6 - File movement in source to image build phase```

The source to image build process refers to an `openjdk18-openshift` image that is used as the builder image and identifies where the source to image binaries are to be found in that image. The next argument identifies where the dockerfile is to be located and the file name as indicated by label 2 in figure 6. This location is very important because in addition to putting the dockerfile in the location the source to image build process also copies the source code from the source code location (current working directory) to the path:

`<location-of-dockerfile>/upload/src`

This process is indicated by stage 3 of figure 6.

In this example the current working directory and the path context supplied to the S2I build command are the same thing. If the path context is given as a subdirectory of the current working directory then it is this location that will be copied to the `<location-of-dockerfile>/upload/src` location.

### CONSUMING THE DOCKERFILE - RUNNING THE BUILD
The next stage of the process is to use the buildah command to execute the dockerfile created in the last step. The yaml for this step is shown below:

``` yaml
 - name: build
     command:
       - buildah
       - bud
       - '--tls-verify=$(params.TLSVERIFY)'
       - '--layers'
       - '-f'
       - /gen-source/Dockerfile.gen
       - '-t'
       - $(resources.outputs.intermediate-image.url)
       - .
     image: registry.redhat.io/rhel8/buildah
     resources: {}
     securityContext:
       privileged: true
     volumeMounts:
       - name: pipeline-cache
         mountPath: /var/lib/containers
       - name: gen-source
         mountPath: /gen-source
     workingDir: /gen-source
```

When the dockerfile is executed it will begin by copying the source code from the location `<current-directory>/upload/src` to the location `/tmp/src` within the container image. All build activity will then take place within the image at this local directory. Source code is expected to be in a location of `/tmp/src/src` and any deliverables will be produced in the directory `/tmp/src/target` as shown by figure 7.


![](/images/figure7.webp)

```Figure 7 - Source to Image dockerfile content locations```

Two volume mounts are used in this example. The first is called gen-source which is where the dockerfile was created and the second is from a persistent volume claim which is pipeline-cache. The second volume has been mounted to `/var/lib/containers` since this is the location where Buildah expects to find the local image repository.

The result of running this step will be a new image created by the Buildah command in the local Buildah repository under the identifier of the URL for the intermediate-image resource. The intermediate image resource definition is shown in the images section above.

# Image creation in Tekton

## Creating the runtime image
At this stage the intermediate builder image contains the built asset which is a war file compiled from the java source. Figure 1 shows the progression of the assets through this stage of the process. Due to the execution of the build task the builder image has been taken from the image registry, the source code has been pulled into the builder image and the builder image has become the intermediate image containing the source code, tools, and deliverables (steps 1 to 3 in figure 8).

![](/images/figure8.webp)

```Figure 8 - Creation of the runtime image```

The Tekton task for this stage of the process is in the file `/build/tasks/createRuntimeImage.yaml`.

This task takes as an input the intermediate image and produces as an output the runtime-image which is to be stored and executed. A step is used to create a new dockerfile simply by echoing the commands and piping them to the file.

The dockerfile that is created is shown below:

```bash
FROM $(resources.inputs.intermediate-image.url) as intermediate-image
FROM docker.io/openliberty/open-liberty as runtime-image
COPY --from=intermediate-image \
/tmp/src/target/liberty-rest-app.war /config/apps/liberty-rest-app.war
COPY --from=intermediate-image \
/tmp/src/src/main/liberty/config/server.xml \ /config/server.xml
```

The dockerfile uses two FROM statements to open the intermediate image and the new runtime image (an Open Liberty image taken from docker.io - step 4 in figure 8). The instructions in the dockerfile then copy the liberty-rest-app.war file from the location /tmp/src/target in the intermediate image to the location /config/apps in the runtime image (step 5 in figure 8). This process is repeated for the server.xml file so that the required files are in the correct locations of the runtime image.

The dockerfile is executed using the same process as before and the resulting image is stored in the local Buildah repository identified by the runtime image resource which is (repeated here):

```yaml
apiVersion: tekton.dev/v1alpha1
kind: PipelineResource
metadata:
 name: liberty-rest-app
 namespace: liberty-rest
spec:
 params:
 - name: url
   value: [image registry url]:5000/liberty-rest/liberty-rest-app
 type: image
```
The url value which has been truncated here for readability is the url of an OpenShift image stream. However this is simply a tag that has been applied to an image in the Buildah repository and nothing has been copied into the OpenShift image registry at this point.

The next stage is to push the image to the OpenShift image registry (step 6 in figure 8) using the Tekton step shown below:

```yaml
- name: push-image-to-openshift
     command:
       - buildah
       - push
       - '--tls-verify=$(params.TLSVERIFY)'
       - $(resources.outputs.runtime-image.url)
       - 'docker://$(resources.outputs.runtime-image.url)'
     image: registry.redhat.io/rhel8/buildah
     resources: {}
     securityContext:
       privileged: true
     volumeMounts:
       - name: pipeline-cache
         mountPath: /var/lib/containers
```

The third argument identifies the image in the local repository (accessible through mounting the pipeline-cache persistent volume claim to the location /var/lib/containers) and the fourth argument is the identifier of the image in the OpenShift repository.

If you are following along, looking at the Tekton yaml files from the Git repository then you will see that there are also commands to list the content of the local Buildah repository in the tasks.

## Clear existing application resources
When quickly moving through the build-deploy-build-deploy cycle of development it is necessary to ensure that the runtime environment is ready to accept a new deployment of the application. To ensure the environment is not impacted by the assets or configuration of a prior build it is easier simply to remove the existing application.

### Dependent tasks in tekton
In a situation where a build fails it is sensible to leave behind the previous deployed assets so that further testing can continue against a running application. As a result the task that removes the application resources does not start until the build task has been successfully completed. This is achieved by adding a runAfter directive to the pipeline that orchestrates the whole process, which is described later.

### Clear Resources task
The clear resource task needs to execute a number of `oc` command line operations so it is sensible to put them into a shell script. An image exists within the OpenShift cluster to deliver an oc command line interface so that image can be used for this task. To view all images that are available use the command: `oc get is -A`. 

This command will list all images streams that are visible to the current user. Any of these images can be used within a step if appropriate however the URL listed in the output of the command is the public URL for the image and the image repository address is required to be used for OpenShift hosted images in steps.

Figure 9 shows an image stream in OpenShift in which the URL reported by `oc get is` is the second URL whereas the URL required to be used in the step is the first shown URL beginning image-repository.

![](/images/figure9.webp)

```Figure 9 - Image stream URL’s presented by OpenShift```

The clear resource step, taken from the file `build/tasks/clearResources.yaml` is shown below, in which a shell script is created and executed within the same step.

```yaml
- name: clear-resources
  command:
    - /bin/sh
    - '-c'
  args:
    - |-
      echo "------------------------------------------------------------"
      echo "echo $(params.appName)"
      echo "oc get all -l app=$(params.appName)" > clear-cmd.sh
      echo "oc delete all -l app=$(params.appName)" >> clear-cmd.sh
      echo "oc get all -l app=$(params.appName)" >> clear-cmd.sh
      echo "Generated script to clear resources ready for new deployment"
      cat clear-cmd.sh
      echo "------------------------------------------------------------"
      chmod u+x clear-cmd.sh
      ./clear-cmd.sh
     image: [image registry url]:5000/openshift/cli:latest
```

## Push image to quay.io
The task that pushes the image to quay.io takes a number of input parameters to define the quay.io account name, the repository within the account to which the image should be pushed and the image tag (version) for the image that is to be pushed. The task also has an input resource which is the image resource to be pushed. This enables the task to be generic enough for any user and any image.

The push image task is in the file `build/tasks/pushImageToQuay.yaml`

Any access to `quay.io`, or many other registries, requires a stage of authentication. It may appear to be reasonable to use a step to authenticate and a second step to perform an action as the authenticated user. However, since each step takes place in an isolated container the authentication action would be immediately forgotten as soon as the login step completed leaving the action step unauthenticated. The answer for this when pushing images is that the buildah command can take as an argument an authentication file. The authentication information is not stored in a parameter or in a pipeline run object; instead it is stored in an `OpenShift secret`.

Instructions for creating the secret from `quay.io` are in the section on using the example build process later.

Once the secret has been create and downloaded, create the secret using the command:

`oc create -f <filename>`

The secret data is stored as shown in the example below:

```yaml
{
    "apiVersion": "v1",
    "data": {
        ".dockerconfigjson": "ab ... n0="
    },
    "kind": "Secret",
```

When mounted into the container for the step the data is accessible from a file called `.dockerconfigjson`.

The secret is used by the Tekton task by mounting it as a volume as shown below:

```yaml
 volumes:
    - name: quay-auth-secret
      secret:
        secretName: quay-auth-secret
```

### Content in the buildah repository
Before pushing the image to quay.io the images in the local buildah repository are viewed. This will show similar to the below:

![](/images/figure10.webp)

```Figure 10 - Example of local buldah repository```

The content has been cut down on the first and last lines to avoid wrapping:

`<A> = image-registry.openshift-image-registry.svc:5000/liberty-rest`

`<B> = registry.access.redhat.com/redhat-openjdk-18`

Note that the images listed by Buildah are simply in the Buildah repository, in a similar manner to using Docker build to create a local image. The fact that the repository identifier shows the OpenShift repository or the quay.io repository does not mean that the image is in that repository. It must be pushed to actually appear in that repository.

- Image 1 is the repository on the OpenShift cluster to which the image is pushed ready to be deployed for testing.

- Image 2 is the tagged runtime image ready to be pushed to quay.io.

[!] Note that the Image ID is the same for images 1 and 2 confirming that what is being executed on OpenShift is the same as what is to be pushed to quay.io.

- Image 3 is the intermediate builder image.

- Image 4 is the runtime image pulled from docker.io before it has had the war file and server.xml files added to it.

- Image 5 is the builder image before it has performed the build operation indicating that the difference of 28 MB between image 5 and image 3 is the source code and built war file.

### Push to quay.io
The step to push the image to quay.io is shown below:

```yaml
- name: push-image-to-quay
     command:
       - buildah
       - push
       - '--authfile'
       - /etc/secret-volume/.dockerconfigjson
quay.io/$(params.quay-io-account)/$(params.quay-io-repository):$(params.quay-io-image-tag-name)
     image: registry.redhat.io/rhel8/buildah
     securityContext:
       privileged: true
     volumeMounts:   
       - name: quay-auth-secret
         mountPath: /etc/secret-volume
         readOnly: true
       - name: pipeline-cache
         mountPath: /var/lib/containers
```

The authentication secret is mounted read-only at `/etc/secret-volume`, therefore the secret data is accessible from the path `/etc/secret-volume/`.dockerconfigjson and can be used directly with the buildah push command.

The image has previously been tagged ready for pushing to quay.io so the image name and tag can simply be used in the push command.

# Application Deployment
The application deployment from the new image uses a deployment template located in `build/template/deploy-app-template.yaml`. This allows placeholders to be put in the yaml content for the deployment, service and route which can be filled in at deployment time using parameter substitution performed by the `oc process` command. A section of the deployment template is shown below:

```yaml
apiVersion: v1
kind: Template
parameters:
 - name: APP_NAME
   value:
 - name: APP_GROUP
   value:
 - name: APP_IMAGE
   value:
metadata:
 name: app-template
objects:
 - kind: Deployment
   apiVersion: apps/v1
   metadata:
     labels:
       app: ${APP_NAME}
       app.kubernetes.io/part-of: ${APP_GROUP}
     name: ${APP_NAME}
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: ${APP_NAME}
```

The deployment step shown below calls the ‘oc process’ command to provide parameters to the above template file such that the resources can be created. Note that the source code is referenced again in this task since the deployment template is located amongst the deployment assets in the Git repository.

## Generation of deployment yaml file
The Tekton task for the deployment of the application is in the file `build/tasks/ocProcessDeploymentTemplate.yaml`.

The `oc process` command result is piped to a file called `deployment-resources.yaml`, such that it can be examined if necessary before being executed with the `oc create -f` command.

```yaml
- name: gen-oc-process-script
     command:
       - /bin/sh
       - '-c'
     args:
       - |-
         echo "oc process \
         -f \ /workspace/source/$(params.templateFileName) \
         -p APP_NAME=$(params.appName) \
         -p APP_GROUP=$(params.appGroup) \
         -p APP_IMAGE=$(resources.inputs.runtime-image.url) \
         > deployment-resources.yaml" > oc-process-cmd.sh
         echo "Generated oc process script command"         
         cat oc-process-cmd.sh
         chmod a+x oc-process-cmd.sh
         ./oc-process-cmd.sh
     image: [image registry url]:5000/openshift/cli:latest
     volumeMounts:
       - name: deployment-files
         mountPath: /deployment-files
     workingDir: /deployment-files
```
## Creation of application resources
The application resources are created using the following step.

```yaml
- name: oc-create-resources
     command:
       - oc
       - create
       - '-f'
       - deployment-resources.yaml
     image: [image registry url]:5000/openshift/cli:latest
     volumeMounts:
       - name: deployment-files
         mountPath: /deployment-files
     workingDir: /deployment-files
```
# Pipeline orchestration
The pipeline resource is used to provide the overall orchestration of the process. The default behaviour of tasks referenced in the pipeline is that they will all run in parallel unless the runAfter directive is used to control the order of execution.The pipeline is used as an aggregator for the parameters and resources that are used by each task, and then the pipeline run resource is used to feed actual values into the parameters and and resource definitions.

## Pipeline
Pipeline resources have a reference to the namespace (OpenShift project) in which they are to run so this needs to be updated, or parameterised, depending on requirements.

The pipeline file is located in `build/pipelines/pipeline.yaml`.

An example of the pipeline resource is shown below:
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
 labels:
   app.kubernetes.io/instance: liberty-rest-app
 name: liberty-rest-app
 namespace: liberty-rest
spec:
 resources:
 - name: app-source
   type: git
 - name: runtime-image
   type: image
 params:
 - name: templateFileName
   type: string
   default: build/template/deploy-app-template.yaml
```

The task section of the pipeline indicates which task should be executed and the parameters and resources that the task uses, as shown below. The parameters section indicates that the pipeline will receive an incoming parameter called templateFileName from the pipeline run and it will pass the value (under the same name) to the task called `oc-process-deployment-template`. This task will not start until the two tasks named at the end of the section have completed.

```yaml
- name: deploy-application
   resources:
     inputs:
     - name: source
       resource: app-source
     - name: runtime-image
       resource: runtime-image
   params:
     - name: templateFileName
       value: $(params.templateFileName)
     - name: appName
       value: $(params.appName)
     - name: appGroup
       value: $(params.appGroup)
   taskRef:
     kind: Task
     name: oc-process-deployment-template
   runAfter:
     - create-runtime-image
     - clear-resources
```

## Pipeline run

The pipeline run resource is used to begin the execution of the pipeline. Actual values for parameters and references for resources are stored in the pipeline run. Once a pipeline and tasks are defined the only place that users need to go in order to modify the behavior of the pipeline execution should be the pipeline run.

The pipeline run file is located in `build/pipelineRun/pipelineRun.yaml`.

The pipeline run resource has a reference to the pipeline that it should execute and it also may have a generated name. This name is a prefix to a name that is generated by OpenShift when the pipeline run is executed.

An example of the pipeline run is shown below, including references for resources and real values for the parameters.

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
 generateName: liberty-rest-app-run-pr-
spec:
 pipelineRef:
   name: liberty-rest-app
 resources:
   - name: app-source
     resourceRef:
       name: liberty-rest-app-source-code
   - name: intermediate-image
     resourceRef:
       name: intermediate
   - name: runtime-image
     resourceRef:
       name: liberty-rest-app
 params:
   - name: templateFileName
     value: build/template/deploy-app-template.yaml
   - name: appName
     value: liberty-rest
   - name: appGroup
     value: Liberty
   - name: quay-io-account
     value: "marrober"
   - name: quay-io-repository
     value: "liberty-rest"
   - name: quay-io-image-tag-name
     value: "latest"
```
The pipeline run is executed using the command:

`oc create -f <pipeline-run-file.yaml>`


# Putting it all together
If you want to experiment with the build process described in this article then you can easily do so. The prerequisite is that you have an OpenShift cluster with the OpenShift Pipelines operator installed.

## Access to the source code and pipeline configuration

Although you will have a copy of the source code for the application and the yaml for the build process locally, remember that when the build runs it will clone the repository again and will use that code for the application build. The source code that you clone here is irrelevant, but it helps to keep together the source code and pipeline assets. Follow the steps below to create the content in your cluster:

Clone or fork the Git repository and cd to the root of your local copy:

`git clone https://github.com/marrober/pipelineBuildExample.git`

`cd pipelineBuildExample`

## Create the OpenShift project and assets
1. Create an OpenShift project
    1. If you want to change the project name feel free to change the references to the namespace in the yaml files.
    2. `oc new-project liberty-rest`
2. Create the resources by executing the command:
    1. `oc project liberty-rest`
    2. `cd build`
    3. `./create-tasks.sh`

## Create a quay.io authentication secret
Generate and store in OpenShift the quay.io authentication secret with the following steps...

1. Create an account on quay.io if you do not already have one.
2. Login to quay.io in the web user interface and click on the username in the top right corner.
3. Select account settings.
4. Click the blue hyperlink ‘Generate Encrypted Password’.
5. Re-enter your password when prompted.
6. Select the second option in the pop up window for `Kubernetes secret`.
7. Download the file.
8. Create a repository in the quay.io account to match the OpenShift project name. In this example the project name is `liberty-rest`
9. Edit the secret file to change the name of the secret to be: `quay-auth-secret`.
10. Create the secret using the command:
`oc create -f <filename>`

## Update parameters in the pipeline run
Update the pipeline run to match the quay.io account that you created.

Modify the file `build/pipelineRun/pipelineRun.yaml` to ensure the account name matches the quay.io account.

```yaml
   - name: quay-io-account
     value: "xxxxxxxxxxxxx"
```
## Test the pipeline
Execute the pipeline process using the command:

`oc create -f pipelineRun/pipelineRun.yaml`

Watch the build progress in the OpenShift web user interface under the pipelines section of the developer perspective, as shown in figure 11.

![](/images/figure11.webp)
```Figure 11 - Pipeline view in OpenShift web user interface```

Click on the name of the pipeline to see the tasks within the pipeline shown as a flow diagram and then click on the Pipeline Runs tab to see the status of completed or running pipeline runs as shown in figure 12.

![](/images/figure12.png)
```Figure 12 - Pipeline runs with one in progress```

Select the name link for the running pipeline to see details of how far it has progressed as shown in figure 13.

![](/images/figure13.png)
```Figure 13 - Details of running pipeline```

Each task on the running pipeline can be clicked to see the details of the steps within it.

## Test the application
When the pipeline process has completed, perform the following steps to test the application. Use the curl command below to send a rest call to the application.

```bash
curl $(oc get route liberty-rest-route -o \

jsonpath='{"http://"}{.spec.host}')/System/propertiesJavaHome
```

The response should be similar to:

``` Java Home ~~~~~> /opt/java/openjdk/jre ```