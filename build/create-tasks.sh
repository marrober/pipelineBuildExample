<<<<<<< Updated upstream
oc create --save-config=true -f image-streams/imageStream-liberty-rest-app.yaml 
oc create --save-config=true -f persistentVolumes/task-cache-pvc.yaml 
oc create --save-config=true -f resources/imageStreamResource-intermediate.yaml 
oc create --save-config=true -f resources/imageStreamResource-liberty-rest-app.yaml 
oc create --save-config=true -f resources/sourceCode-GitResource.yaml 
oc create --save-config=true -f tasks/build.yaml 
oc create --save-config=true -f tasks/clearBuildahRepo.yaml 
oc create --save-config=true -f tasks/clearResources.yaml 
oc create --save-config=true -f tasks/createRuntimeImage.yaml 
oc create --save-config=true -f tasks/generate-runtime-image-dockerfile.yaml
oc create --save-config=true -f tasks/ocProcessDeploymentTemplate.yaml 
oc create --save-config=true -f tasks/pushImageToQuay.yaml
oc create --save-config=true -f pipelines/pipeline.yaml
=======
oc apply -f tasks/build.yaml
oc apply -f tasks/clearBuildahRepo.yaml
oc apply -f tasks/clearResources.yaml
oc apply -f tasks/createRuntimeImage.yaml
oc apply -f tasks/ocDeployApplication.yaml
oc apply -f tasks/pushImageToQuay.yaml
oc apply -f pipelines/pipeline.yaml
>>>>>>> Stashed changes
