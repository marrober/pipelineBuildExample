oc apply -f image-streams/imageStream-liberty-rest-app.yaml
oc apply -f tasks/build.yaml
oc apply -f tasks/clearBuildahRepo.yaml
oc apply -f tasks/clearResources.yaml
oc apply -f tasks/createRuntimeImage.yaml
oc apply -f tasks/ocDeployApplication.yaml
oc apply -f tasks/pushImageToQuay.yaml
oc apply -f pipelines/pipeline.yaml
