#!/usr/bin/env bash
failTask="false"

roxctl image check --image quay.io/marrober/open-liberty-base:2 --insecure-skip-tls-verify -e $ROX_CENTRAL_ENDPOINT -o table > imageScanResult  2>&1
        
cat imageScanResult

imageScanResultNewVar=`cat imageScanResult`

if [[ "$imageScanResultNewVar" == *"failed policies found:"* ]]; then
  failTask=true
fi

if [[ "$failTask" == "true" ]]; then

  echo "Setting overall result to fail"

  echo -n "fail" | tee result >> /dev/null

else

  echo "Setting overall result to pass"

#  echo -n "pass" | tee result >> /dev/null

fi



