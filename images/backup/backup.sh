#!/bin/sh

#Backups connectivity-proxy, and connectivity-proxy-info config map.
set -e
set -x

BACKUP_NS=connectivity-proxy-backup

echo "Running Connectivity Proxy user configuration backup script"

echo "Checking if Connectivity Proxy CRD exists on the cluster"
if ! kubectl get crd connectivityproxies.connectivityproxy.sap.com &> /dev/null; then
  echo "Connectivity Proxy CRD does not exist on the cluster - exiting"
  exit 0
fi

if ! kubectl get connectivityproxies.connectivityproxy.sap.com -n kyma-system connectivity-proxy &> /dev/null; then
   echo "Connectivity Proxy CR is missing on the cluster - exiting"
  exit 0
fi

echo "Connectivity Proxy CR detected... checking backup annotation"

if ! kubectl get connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system -o jsonpath='{.metadata.annotations.connectivityproxy\.sap\.com/migrated}' | grep -q "true"; then
  echo "Connectivity Proxy CR is not annotated as migrated - exiting"
  exit 0
fi

if kubectl get connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system -o jsonpath='{.metadata.annotations.connectivityproxy\.sap\.com/backed-up}' | grep -q "true"; then
  echo "Connectivity Proxy CR is already annotated as backed after migration - exiting"
  exit 0
fi


echo "Checking if destination backup namespace for backup exist"
# check if namespace from variable BACKUP_NS exists and if not create it in the same cluster
if ! kubectl get namespace $BACKUP_NS &> /dev/null; then
  echo "Namespace $BACKUP_NS does not exist, creating it"
  kubectl create namespace $BACKUP_NS
fi

echo "Removing old backup config maps if exist"

#ensure that old backup is deleted before creating a new one
kubectl delete cm -n $BACKUP_NS connectivity-proxy --ignore-not-found
kubectl delete cm -n $BACKUP_NS connectivity-proxy-info --ignore-not-found

echo "Copying Connectivity Proxy config maps with user configuration to target backup namespace $BACKUP_NS"

# read config maps connectivity-proxy and connectivity-proxy-info config maps from kyma-system namespace and store them in a backup namespace

if kubectl get cm -n kyma-system connectivity-proxy &> /dev/null; then
  kubectl get cm -n kyma-system connectivity-proxy -o yaml | sed s/"namespace: kyma-system"/"namespace: $BACKUP_NS"/ | kubectl apply -f -
  echo "connectivity-proxy config map backed up successfully"
else
  echo "Warning! connectivity-proxy config map does not exist in kyma-system namespace, skipping backup"
fi

if kubectl get cm -n kyma-system connectivity-proxy-info &> /dev/null; then
  kubectl get cm -n kyma-system connectivity-proxy-info -o yaml | sed s/"namespace: kyma-system"/"namespace: $BACKUP_NS"/ | kubectl apply -f -
  echo "connectivity-proxy-info config map backed up successfully"
else
  echo "Warning! connectivity-proxy-info config map does not exist in kyma-system namespace, skipping backup"
fi

echo "Annotate CR that backup is completed after migration"
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/backed-up="true"

echo "Connectivity Proxy Backup script completed successfully"