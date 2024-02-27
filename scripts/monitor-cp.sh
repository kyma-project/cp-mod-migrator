#!/bin/bash

# Expected label value
expectedReconcilerLabelValue="reconciler"
expectedOperatorLabelValue="sap.connectivity.proxy.operator"

# Check if the StatefulSet exists in the specified namespace
statefulSetExists=$(kubectl get statefulset connectivity-proxy -n kyma-system --ignore-not-found)

if [[ -z "$statefulSetExists" ]]; then
    echo "Connectivity Proxy is not installed on this cluster"
    exit 1
else
    echo "Connectivity Proxy is installed on this cluster"
    actualLabelValue=$(kubectl get statefulset connectivity-proxy -n kyma-system -o=jsonpath="{.metadata.labels.reconciler\.kyma-project\.io\/managed-by}" --ignore-not-found)
    if [[ "$actualLabelValue" == "$expectedReconcilerLabelValue" ]]; then
        echo "This Connectivity Proxy installation is managed by the Reconciler"
    fi

    actualLabelValue=$(kubectl get statefulset connectivity-proxy -n kyma-system -o=jsonpath="{.metadata.labels.app\.kubernetes\.io\/managed-by}" --ignore-not-found)
    if [[ "$actualLabelValue" == "$expectedOperatorLabelValue" ]]; then
        echo "This Connectivity Proxy installation is managed by the Connectivity Proxy Operator"
    fi
    
    stateful_set_status=$(kubectl get statefulset connectivity-proxy -n kyma-system -ojsonpath={.status})
    echo "Connectivity Proxy Stateful Set status: $stateful_set_status"
fi


if kubectl get crd connectivityproxies.connectivityproxy.sap.com &> /dev/null; then
   echo "The Connectivity Proxy CRD is installed on the cluster"
fi
 
if kubectl get connectivityproxies.connectivityproxy.sap.com/connectivity-proxy -n kyma-system &> /dev/null; then
   operator_state=$(kubectl get connectivityproxies.connectivityproxy.sap.com/connectivity-proxy -n kyma-system -ojsonpath={.status.state})
   echo "Operator state: $operator_state"
fi

if kubectl get deployment connectivity-proxy-operator -n kyma-system &> /dev/null; then
   operator_deployment_state=$(kubectl get deploy connectivity-proxy-operator -n kyma-system -ojsonpath={.status.conditions})
   echo "Operator deployment state: $operator_deployment_state"
fi 
