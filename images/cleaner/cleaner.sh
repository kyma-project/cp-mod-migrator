#!/bin/sh

echo "Running Connectivity Proxy Cleanup script"

kubectl delete statefulset -n kyma-system connectivity-proxy
kubectl delete deployment -n kyma-system connectivity-proxy-restart-watcher
kubectl delete deployment -n kyma-system connectivity-proxy-sm-operator

kubectl delete service -n kyma-system connectivity-proxy
kubectl delete service -n kyma-system connectivity-proxy-smv
kubectl delete service -n kyma-system connectivity-proxy-tunnel
kubectl delete service -n kyma-system connectivity-proxy-tunnel-0
kubectl delete service -n kyma-system connectivity-proxy-tunnel-healthcheck

kubectl delete serviceaccount -n kyma-system connectivity-proxy-restart-watcher
kubectl delete clusterrole -n kyma-system connectivity-proxy-restart-watcher
kubectl delete clusterrolebinding -n kyma-system connectivity-proxy-restart-watcher

kubectl delete serviceaccount -n kyma-system connectivity-proxy-sm-operator
kubectl delete clusterrole -n kyma-system connectivity-proxy-service-mappings
kubectl delete clusterrolebinding -n kyma-system connectivity-proxy-service-mappings
kubectl delete mutatingwebhookconfiguration -n kyma-system connectivity-proxy-mutating-webhook-configuration

kubectl delete configmap -n kyma-system connectivity-proxy
kubectl delete configmap -n kyma-system connectivity-proxy-info

# Delete all istio resources created by connectivity-proxy

kubectl delete envoyfilter -n istio-system connectivity-proxy-custom-protocol
kubectl delete certificate -n istio-system cc-certs
kubectl delete gateway -n kyma-system kyma-gateway-cc
kubectl delete virtualservice -n kyma-system cc-proxy
kubectl delete virtualservice -n kyma-system cc-proxy-healthcheck
kubectl delete destinationrule -n kyma-system connectivity-proxy-tunnel-0
kubectl delete destinationrule -n kyma-system connectivity-proxy
kubectl delete peerauthentication -n enable-permissive-mode-for-cp

# Annotate all existing Connectivity Proxy Service Mappings

mappings=$(kubectl get servicemappings.connectivityproxy.sap.com -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

for mapping in mappings; do

  echo "Applying annotations to service mapping $mapping"

  kubectl annotate servicemappings.connectivityproxy.sap.com "$mapping" \
    io.javaoperatorsdk/primary-name=connectivity-proxy \
    io.javaoperatorsdk/primary-namespace=kyma-system \

done



exit 0