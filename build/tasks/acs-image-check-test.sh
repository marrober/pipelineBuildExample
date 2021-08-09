#!/usr/bin/env bash
failTask="false"

roxctl image check --image quay.io/marrober/layers:latest --insecure-skip-tls-verify -e $ROX_CENTRAL_ENDPOINT --json > image-scan-result

cat image-scan-result | wc -c > image-scan-result.wc

read charCount < image-scan-result.wc

if test $charCount -gt 10 ; then

  numberAlerts=`jq '.alerts' image-scan-result | jq length`

  if test $numberAlerts -gt 1; then

    echo "$numberAlerts alerts found ..."

  else

    echo "1 alert found ..."

  fi

  counter=0

  while [ $counter -lt $numberAlerts ]; do

    jqCommandPolicyEnforcementCmd="jq --argjson index "$counter" '.alerts[\$index].policy.enforcementActions[] | select (. | contains(\"FAIL_BUILD_ENFORCEMENT\"))' image-scan-result 2>/dev/null | wc -c > image-scan-result.wc"

    eval $jqCommandPolicyEnforcementCmd > /dev/null

    jqCommandPolicyName="jq --argjson index "$counter" '.alerts[\$index].policy.name' image-scan-result"

    alertPolicyName=`eval $jqCommandPolicyName` > /dev/null

    alertPolicyName=`echo "$alertPolicyName" | sed s/\"//g`

    echo "Alert policy name : $alertPolicyName"

    read charCount < image-scan-result.wc

    if test $charCount -gt 2; then

      ## Issue found is enough to stop the deployment

      failTask="true"

      echo "-- Build will be halted --"

    else

      echo "-- Policy violations will not stop the build process --"

    fi

    echo "- - - - - - - - - - - - - - - - - - - - - - - - - -"

    numberViolationsCmd="jq --argjson index \"$counter\" '.alerts[\$index].violations' image-scan-result | jq length"

    numberViolations=`eval $numberViolationsCmd` >> /dev/null

    if test $numberViolations -eq 1; then

      echo "1 violation found ..."

    else

      echo "$numberViolations violations found ..."

    fi

    violationCounter=0

    while [ "$violationCounter" -lt "$numberViolations" ];  do

      jqCommand="jq --argjson index "$counter" --argjson violationIndex "$violationCounter" '.alerts[\$index].violations[\$violationIndex].message' image-scan-result"

      violation=`eval $jqCommand` >> /dev/null

      violation=`echo "$violation" | sed s/\"//g`

      echo "violation : -- $violation"

      violationCounter=`expr $violationCounter + 1`

    done

    echo "-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -"

    echo ""

    counter=`expr $counter + 1`

  done

  echo "-----------------------------------------------------"

else

  echo "-- No errors found in this file --"

  echo ""

fi

if [[ "$failTask" == "true" ]]; then

  echo "Setting overall result to fail"

  echo -n "fail" | tee result >> /dev/null

else

  echo "Setting overall result to pass"

  echo -n "pass" | tee result >> /dev/null

fi
