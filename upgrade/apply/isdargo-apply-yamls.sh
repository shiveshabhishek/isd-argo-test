#!/bin/bash
helm version
cd /repo/
################################################################
echo "##########Replacing Secrets#########"
grep -ir encrypted: /repo/isdargo | sort -t: -u -k1,1 |cut -d : -f1 > tmp.list
cat tmp.list | grep -v secret-decoder.yaml > tmp1.list
cat tmp.list
#######replacing with undecoded string for secrets that have data and not stringdata#########################
while read file
do
     if grep ^data: $file
     then
          if grep ^"kind: Secret" $file
          then
           cat $file | grep -oE "encrypted:[^'\"[:space:]]+" > secret-strings.list
               while read -r secret ; do
                    #keyName=$(echo $secret | sed 's/:/ /g' | awk -F'encrypted' '{print $2}' | awk '{print $1}')
                    keyName=$(echo $secret | grep 'encrypted:' | sed -E 's/.*encrypted:([^:]+):.*/\1/')
                    echo "secretKeyName  $keyName"
                    keyVal=$(echo $secret | grep 'encrypted:' | sed -E "s/.*encrypted:[^:]+:([^@\"':]+).*/\1/")
                    keyVal="${keyVal##*:}"; val="${keyVal%%[@:]*}"; val="${keyVal//\'/}"
                    echo "secretKeyval  $keyVal"
                    #value=$(kubectl -n $namespace  get secret $keyName -o jsonpath="{.data.$keyVal}" )
                    value=$(cat /secrets/$keyVal | tr -d '\n' | base64)
                    cat 
                    sed -i "s/encrypted:$keyName:$keyVal/$value/g" $file
               done < secret-strings.list
               
            echo $file is secret and has data
          fi
     fi
done < tmp1.list

echo "############################ replace secrets with decoded values stringdata or configmaps#####################################"
     while IFS= read -r file; do
          cat $file | grep -oE "encrypted:[^'\"[:space:]]+" > secret-strings.list
          cat secret-strings.list
               while read -r secret ; do
                    keyName=$(echo $secret | grep 'encrypted:' | sed -E 's/.*encrypted:([^:]+):.*/\1/')
                    echo "secretKeyName  $keyName"
                    #keyVal=$(echo $secret | sed 's/:/ /g' | awk -F'encrypted' '{print $2}' | awk '{print $2}')
                    keyVal=$(echo $secret | grep 'encrypted:' | sed -E "s/.*encrypted:[^:]+:([^@\"':]+).*/\1/")
                    keyVal="${keyVal##*:}"; val="${keyVal%%[@:]*}"; val="${keyVal//\'/}"
                    echo "secretKeyval  $keyVal"
                    
                    #value=$(kubectl -n $namespace  get secret $keyName -o jsonpath="{.data.$keyVal}" | base64 -d)
                    value=$(cat /secrets/$keyVal)
                    sed -i "s/encrypted:$keyName:$keyVal/$value/g" $file
               done < secret-strings.list
     done < tmp1.list

echo "applying the changes"
kubectl apply -R -f /repo/isdargo/ -n $namespace
if [ $? -eq 0 ]; then  
     echo "#################################Kubernetes manifest sucessfully applied into the $namespace#################################"
else
   echo "#################################Kubernetes manifest not applied sucesfully into the $namespace#################################"
   exit 1
fi
