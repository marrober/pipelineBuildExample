#!/usr/bin/env bash
failTask="false"


var1="f1c51b41a1bcc233519647e5c487412f751163f9"

var2=${var1:0:4}

var3="liberty-rest-app-run-pr-g8ngz"

var4=${var3:${#var3}-5:${#var3}}

tag=$var2-$var4

echo $tag

`roxctl image check --image quay.io/marrober/open-liberty-base:2 --insecure-skip-tls-verify -e $ROX_CENTRAL_ENDPOINT  -o table`
        
cat imageScanResult

imageScanResultNewVar=`cat imageScanResult | sed ':a;N;$!ba;s/\n/ /g'`

if [[ "$imageScanResultNewVar" == *"ERROR: failed policies found:"* ]]; then
  failTask=true
fi

if [[ "$failTask" == "true" ]]; then

  echo "Setting overall result to fail"

  echo -n "fail" | tee result >> /dev/null

else

  echo "Setting overall result to pass"

  echo -n "pass" | tee result >> /dev/null

fi



