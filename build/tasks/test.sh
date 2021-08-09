fileList=`ls /home/mark/data/git-repos/pipelineBuildExample/deployment/*.y*ml`

failTask="false"

for file in $fileList

do

  echo $file

  if (grep -q "apiVersion: route.openshift.io" "$file") || (grep -q "apiVersion: kustomize.config.k8s.io" "$file"); then
    echo "this is a route or kustomize"
  fi

done
