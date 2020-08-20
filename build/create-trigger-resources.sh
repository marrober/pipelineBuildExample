oc create --save-config=true -f triggers/eventListener.yaml 
oc create --save-config=true -f triggers/eventListenerRoute.yaml 
oc create --save-config=true -f triggers/triggerBinding.yaml 
oc create --save-config=true -f triggers/triggerTemplate.yaml 
