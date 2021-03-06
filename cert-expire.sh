#!/bin/bash

##
## cert-expire.sh  - OpenShift script to print all TLS cert expire date
##
##
RED='\033[0;31m'
duration=0
re='^[0-9]+$'
if [ $# -ne 0 ]; then
   if [[ $1 =~ $re ]] ; then
      duration=$(( 60*60*24*$1 ))
   else
      echo "Argument is not a number"
      exit 1
   fi
fi


function show_cert() {
   if openssl x509 -checkend $duration -noout -enddate
   then
      echo ""
   else
      echo "${RED}Certificate will expire${RED}"
   fi
}

echo "------------------------- kubeconfig TLS certificate -------------------------"
if [ -f "$KUBECONFIG" ]; then
  KUBECONFIG_FILES=$KUBECONFIG
else
  KUBECONFIG_FILES=~/.kube/config
fi
for f in $KUBECONFIG_FILES; do
  echo "- $f"
  awk '/cert/ {print $2}' $f | base64 -d | show_cert
done

## Process all service serving cert secrets

echo "------------------------- all service serving cert secrets TLS certificate -------------------------"
oc get secrets -A -o go-template='{{range .items}}{{if eq .type "kubernetes.io/tls"}}{{.metadata.namespace}}{{" "}}{{.metadata.name}}{{" "}}{{index .data "tls.crt"}}{{"\n"}}{{end}}{{end}}' | while read namespace name cert; do echo -en "$namespace\t$name\t"; echo $cert | base64 -d | show_cert; done


## Process all cert files under /etc/kubernetes directories in the Master node
echo "------------------------- all nodes' kubelet TLS certificate -------------------------"
for node in `oc get nodes |awk 'NR>1'|grep master | awk '{print $1}'`; do
    oc debug -q node/$node -- sh -c 'tar --transform "s/.*\///g" -zcf /host/tmp/etcd.tar.gz $(ls -A /host/etc/kubernetes/static-pod-resources/etcd-*/secrets/*/*.crt) 2>/dev/null '
    oc debug -q node/$node -- sh -c 'tar --transform "s/.*\///g" -zcf /host/tmp/kube.tar.gz $(ls -A /host/etc/kubernetes/static-pod-resources/kube-*/secrets/*/*.crt) 2>/dev/null'
    oc debug -q node/$node -- sh -c 'cat /host/tmp/etcd.tar.gz' > $node-etcd.tar.gz
    oc debug -q node/$node -- sh -c 'cat /host/tmp/kube.tar.gz' > $node-kube.tar.gz
    mkdir $node-etcd
    mkdir $node-kube
    tar -C $node-etcd -xzf $node-etcd.tar.gz
    tar -C $node-kube -xzf $node-kube.tar.gz
    for cert in `ls $node-etcd`; do
        echo -n "$cert     "
        cat $node-etcd/$cert | show_cert
    done
    for cert in `ls $node-kube`; do
        echo -n "$cert     "
        cat $node-kube/$cert | show_cert
    done
    rm -rf $node-etcd
    rm -rf $node-etcd.tar.gz
    rm -rf $node-kube
    rm -rf $node-kube.tar.gz
done
