#!/bin/bash

##
## print-all-cert-expire-date.sh  - OpenShift script to print all TLS cert expire date
##
## - Do not use `openssl x509 -in` command which can only handle first cert in a given input
##

VERBOSE=false
if [ "$1" == "-v" ]; then
    VERBOSE=true
fi

function show_cert() {
  if [ "$VERBOSE" == "true" ]; then
    openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -text | egrep -A9 ^Cert
  else
    openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -text | grep Validity -A2
  fi
}

## Process all kubeconfig files under /etc/origin/{master,node} directories

echo "------------------------- kubeconfig TLS certificate -------------------------"
KUBECONFIG_FILES=~/.kube/config
for f in $KUBECONFIG_FILES; do
  echo "- $f"
  awk '/cert/ {print $2}' $f | base64 -d | show_cert
done

## Process all service serving cert secrets

echo "------------------------- all service serving cert secrets TLS certificate -------------------------"
oc get secrets -A -o go-template='{{range .items}}{{if eq .type "kubernetes.io/tls"}}{{.metadata.namespace}}{{" "}}{{.metadata.name}}{{" "}}{{index .data "tls.crt"}}{{"\n"}}{{end}}{{end}}' | while read namespace name cert; do echo -en "$namespace\t$name\t"; echo $cert | base64 -d | show_cert; done 


## Process all cert files under /etc/origin/node directories --> Each node
### The following sections
### Script execution machine require password-less SSH access to all nodes
echo "------------------------- all nodes' kubelet TLS certificate -------------------------"
for node in `oc get nodes |awk 'NR>1'|awk '{print $1}'`; do
  for f in `oc debug node/$node -- chroot /host sh -c "find /etc/kubernetes/static-pod-resources -type f \( -name '*.crt' -o -name '*pem' \)"`; do
    echo "$node - $f"
    oc debug --preserve-pod=true node/$node -- chroot /host sh -c "cat $f" | show_cert
  done
done
