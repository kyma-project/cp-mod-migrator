#!/bin/sh

set -e
set -x

echo "Running Connectivity Proxy Cleanup script"

echo "Checking if Connectivity Proxy CRD exists on the cluster"
if ! kubectl get crd connectivityproxies.connectivityproxy.sap.com &> /dev/null; then
  echo "Connectivity Proxy CRD does not exist on the cluster - exiting"
  exit 0
fi

if ! kubectl get connectivityproxies.connectivityproxy.sap.com -n kyma-system connectivity-proxy &> /dev/null; then
   echo "Connectivity Proxy CR is missing on the cluster - exiting"
  exit 0
fi

echo "Connectivity Proxy CR detected... checking annotations"

if ! kubectl get connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system -o jsonpath='{.metadata.annotations.connectivityproxy\.sap\.com/migrated}' | grep -q "true"; then
  echo "Connectivity Proxy CR is not annotated as migrated - exiting"
  exit 0
fi

if kubectl get connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system -o jsonpath='{.metadata.annotations.connectivityproxy\.sap\.com/cleaned}' | grep -q "true"; then
  echo "Connectivity Proxy CR is already annotated as cleaned up after migration - exiting"
  exit 0
fi

echo "Connectivity Proxy CR is marked as successfully migrated and ready for cleanup"

if kubectl get crd servicemappings.connectivityproxy.sap.com &> /dev/null; then
  echo "CRD servicemappings.connectivityproxy.sap.com exists on the cluster"
  echo "Annotate all existing Connectivity Proxy Service Mappings instances"

  mappings=$(kubectl get servicemappings.connectivityproxy.sap.com --ignore-not-found -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

  for mapping in $mappings; do

    echo "Applying annotations and label to service mapping $mapping"

    kubectl annotate servicemappings.connectivityproxy.sap.com "$mapping" \
      io.javaoperatorsdk/primary-name=connectivity-proxy \
      io.javaoperatorsdk/primary-namespace=kyma-system

    kubectl label servicemappings.connectivityproxy.sap.com "$mapping" app.kubernetes.io/managed-by=sap.connectivity.proxy.operator

  done

  echo "Applying annotations and label to service mapping CRD"

  kubectl annotate crd servicemappings.connectivityproxy.sap.com \
     io.javaoperatorsdk/primary-name=connectivity-proxy \
     io.javaoperatorsdk/primary-namespace=kyma-system

  kubectl label crd servicemappings.connectivityproxy.sap.com app.kubernetes.io/managed-by=sap.connectivity.proxy.operator

fi

echo "Removing Deployments, and Statefulsets"

kubectl delete statefulset -n kyma-system connectivity-proxy --ignore-not-found
kubectl delete deployment -n kyma-system connectivity-proxy-restart-watcher --ignore-not-found
kubectl delete deployment -n kyma-system connectivity-proxy-sm-operator --ignore-not-found

echo "Removing Services"

kubectl delete service -n kyma-system connectivity-proxy --ignore-not-found
kubectl delete service -n kyma-system connectivity-proxy-smv --ignore-not-found
kubectl delete service -n kyma-system connectivity-proxy-tunnel --ignore-not-found
kubectl delete service -n kyma-system connectivity-proxy-tunnel-0 --ignore-not-found
kubectl delete service -n kyma-system connectivity-proxy-tunnel-healthcheck --ignore-not-found

echo "Removing RBAC resources"

kubectl delete clusterrolebinding connectivity-proxy-restart-watcher --ignore-not-found
kubectl delete clusterrole connectivity-proxy-restart-watcher --ignore-not-found
kubectl delete serviceaccount -n kyma-system connectivity-proxy-restart-watcher --ignore-not-found

kubectl delete clusterrolebinding connectivity-proxy-service-mappings --ignore-not-found
kubectl delete clusterrole connectivity-proxy-service-mappings --ignore-not-found
kubectl delete serviceaccount -n kyma-system connectivity-proxy-sm-operator --ignore-not-found

echo "Removing Webhook"
kubectl delete validatingwebhookconfiguration webhook-secret --ignore-not-found

echo "Removing Config Maps"

kubectl delete configmap -n kyma-system connectivity-proxy --ignore-not-found
kubectl delete configmap -n kyma-system connectivity-proxy-info --ignore-not-found
kubectl delete configmap -n kyma-system connectivity-proxy-service-mappings --ignore-not-found

echo "Removing Istio resources"

kubectl delete envoyfilter -n istio-system connectivity-proxy-custom-protocol --ignore-not-found
kubectl delete gateways.networking.istio.io -n kyma-system kyma-gateway-cc --ignore-not-found
kubectl delete virtualservice -n kyma-system cc-proxy --ignore-not-found
kubectl delete virtualservice -n kyma-system cc-proxy-healthcheck --ignore-not-found
kubectl delete destinationrule -n kyma-system connectivity-proxy-tunnel-0 --ignore-not-found
kubectl delete destinationrule -n kyma-system connectivity-proxy --ignore-not-found
kubectl delete peerauthentication -n kyma-system enable-permissive-mode-for-cp --ignore-not-found
kubectl delete certificates.cert.gardener.cloud -n istio-system cc-certs --ignore-not-found


echo "Removing Secrets"
kubectl delete secret -n istio-system cc-certs-cacert --ignore-not-found
kubectl delete secret -n istio-system cc-certs --ignore-not-found
kubectl delete secret -n kyma-system connectivity-sm-operator-secrets-tls --ignore-not-found

echo "Removing PriorityClass resources"
kubectl delete priorityclass connectivity-proxy-priority-class --ignore-not-found

echo "Annotate CR that clean up is completed after migration"
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/cleaned="true"
