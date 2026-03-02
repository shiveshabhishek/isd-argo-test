#!/bin/bash
helm version
git --version
cd /repo/
ls -ltr

sleep 10
echo $version

helm repo add isdargo https://opsmx.github.io/enterprise-argo/
if [ $? != 0 ]; then
  n=0
  until [ "$n" -ge 3 ]
  do
  echo Retrying.....
  helm repo add isdargo https://opsmx.github.io/enterprise-argo/
  if [ $? != 0 ]; then
    echo "ERROR: Failed to add helm repo"
  else
    echo "Repo added successfully.."
    break
  fi
  n=$((n+1))
  sleep 5
  done
else
  echo "Repo added successfully.."
fi
helm repo list
helm repo update
#helm search repo --versions
chartVersion=$(helm search repo isdargo/isdargo --versions | awk '{print $2,$3}' | grep "${version}" | head -1 | awk -F ' ' '{print $1}')
version=$chartVersion
helm pull isdargo/isdargo --version="$version"

tar -xf isdargo-"$version".tgz
if [ $? -eq 0 ]; then  
     echo "#################################Sucessfully downloaded the helm chart#################################"
else
   echo "#################################Failed to downlaod the helm chart#################################"
   exit 1
fi

############################ special cases removing b64enc###################################################
sed -i 's/| *b64enc *//g' /repo/isdargo/charts/minio/templates/secrets.yaml
sed -i 's/| *b64enc *//g' /repo/isdargo/charts/redis/templates/secret.yaml
sed -i 's/| *b64enc *//g' /repo/isdargo/charts/openldap/templates/secret.yaml
sed -i 's/| *b64enc *//' /repo/isdargo/templates/sapor-gate/sapor-gate-secret.yaml
sed -i 's/^data:/stringData:/' /repo/isdargo/templates/sapor-gate/sapor-gate-secret.yaml
sed -i 's/{{ .Values.saporgate.config.password }}/encrypted:saporpassword:saporpassword/' /repo/isdargo/config/sapor-gate/gate-local.yml
####################################################################################################################
#helm template ${release} /repo/isdargo -f values.yaml --output-dir=/tmp/isdargo
helm template ${release} /repo/isdargo -f /repo/values/isdargo/values-overrides.yaml --output-dir=/tmp/isdargo

if [ $? -eq 0 ]; then
     echo "#################################Helm template is sucessfull into  isdargo directory#################################"
else
   echo "#################################Helm template failed to isdargo directory#################################"
   exit 1
fi

rm -rf isdargo-"$version".tgz
rm -rf /repo/isdargo/
#####################################committing tempates to github repo################################
git branch -a > branch
checkbranch=$(cat branch | grep "$version" | awk -F "/" '{print $3}')
if [ -z "$checkbranch" ]; then
   echo "#################################Sucesfully created a branch in github###########################"
   git checkout -b "$version"
   git rm -rf /repo/isdargo/
   
   cp -r /tmp/isdargo/isdargo  /repo/
   
   rm -rf /repo/branch
   git status
   git add .
   git config --global user.email "${gitemail}"
   git config --global user.name "${username}"
   git commit -m "Manifest file dir of helm chart with ISDARGO ${version}"
   git push origin "$version"
   if [ $? -eq 0 ]; then
     echo "#######################Sucessfully pushed helm template to github#################################"
   else
     echo "#########################Failed to pushed helm template to github#################################"
     exit 1
   fi
 else
   echo "#################################create a branch in github with hipens###############################"
   cat branch | grep "$version"| awk -F "/" '{print $3}' | grep "-"
   if [ $? == 0 ]; then
      echo "######### Creating a new branch with hipens because already exists with $version #####################"
      i=$(cat branch | grep "$version"| awk -F "/" '{print $3}' | grep -v HEAD | grep "-" | awk -F "-" '{print $2}'| tail -1)
      i=$((i+1))
      newbranch="$version-$i"
      echo $newbranch
      echo "Incremented the branch with hipens $newbranch"
   else
     echo "############ Creating a new branch with $version-1 since $version branch exists##############"
     newbranch="$version-1"
   fi
   git checkout -b "$newbranch"
   rm -rf /repo/branch
   
   cp -r /tmp/isdargo/isdargo  /repo/
   
   git status
   git add .
   git config --global user.email "${gitemail}"
   git config --global user.name "${username}"
   git commit -m "Manifest file dir of helm chart with $newbranch since branch with ISDARGO ${version} exists"
   git push origin "$newbranch"
   if [ $? -eq 0 ]; then
     echo "#######################Sucessfully pushed helm template to github#################################"
   else
     echo "#########################Failed to pushed helm template to github#################################"
     exit 1
   fi
fi
#############################################################
