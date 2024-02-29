#!/bin/bash

# Expected label value
expectedReconcilerLabelValue="reconciler"
expectedOperatorLabelValue="sap.connectivity.proxy.operator"

cpExists=false
operatorExists=false
crdExists=false
crExists=false
cpInstalledWithReconciler=false
cpInstalledWithOperator=false 
crStatus=""

statefulSetExists=$(kubectl get statefulset connectivity-proxy -n kyma-system --ignore-not-found)
echo "**COMPONENTS STATUS**"

if [[ -z "$statefulSetExists" ]]; then
    echo "Connectivity Proxy StatefulSet NOT FOUND."
else
    cpExists=true

    echo "Connectivity Proxy StatefulSet found."
    actualLabelValue=$(kubectl get statefulset connectivity-proxy -n kyma-system -o=jsonpath="{.metadata.labels.reconciler\.kyma-project\.io\/managed-by}" --ignore-not-found)
    if [[ "$actualLabelValue" == "$expectedReconcilerLabelValue" ]]; then
       cpInstalledWithReconciler=true 
       echo "The Connectivity Proxy StatefulSet is managed by the Reconciler"
    fi

    actualLabelValue=$(kubectl get statefulset connectivity-proxy -n kyma-system -o=jsonpath="{.metadata.labels.app\.kubernetes\.io\/managed-by}" --ignore-not-found)
    if [[ "$actualLabelValue" == "$expectedOperatorLabelValue" ]]; then
       cpInstalledWithOperator=true 
       echo "The Connectivity Proxy StatefulSet is managed by the Connectivity Proxy Operator"
    fi
    
    stateful_set_status=$(kubectl rollout status statefulset connectivity-proxy -n kyma-system)
    echo "Connectivity Proxy Stateful Set status: $stateful_set_status"
fi


if kubectl get crd connectivityproxies.connectivityproxy.sap.com &> /dev/null; then
   crdExists=true
   echo "The Connectivity Proxy CRD found."
else
   echo "The Connectivity Proxy CRD NOT FOUND."
fi
 
if kubectl get connectivityproxies.connectivityproxy.sap.com/connectivity-proxy -n kyma-system &> /dev/null; then
   crExists=true
   crStatus=$(kubectl get connectivityproxies.connectivityproxy.sap.com/connectivity-proxy -n kyma-system -ojsonpath={.status.state})
   echo "Connectivity Proxy CR state: $crStatus"
else
   echo "The Connectivity Proxy CR NOT FOUND."
fi

if kubectl get deployment connectivity-proxy-operator -n kyma-system &> /dev/null; then
   operatorExists=true
   operator_deployment_state=$(kubectl rollout status deploy connectivity-proxy-operator -n kyma-system)
   echo "Operator deployment state: $operator_deployment_state"
else
   echo "Connectivity Proxy Operator NOT FOUND."
fi 

echo ""

echo "**SERVICE INSTANCES**"
kubectl get serviceinstance.services.cloud.sap.com -A
echo ""

echo "**SERVICE BINDINGS**"
kubectl get servicebinding.services.cloud.sap.com -A
echo ""

# Check status
printf "\n**SUMMARY**\n"
if [[ "$cpExists" = false && "$operatorExists" = false  && "$crdExists" = false && "$crExists" = false ]] ; then
   echo "Connectivity Proxy is not installed on the runtime. Status is OK"
elif [[ "$cpExists" = true && "$operatorExists" = false && "$crdExists" = false && "$crExists" = false ]] ; then
   echo "Connectivity Proxy is installed with the Reconciler"
elif [[ "$cpExists" = true && "$operatorExists" = true && "$crdExists" = true && "$crExists" = true ]] ; then
   if [[ "$crStatus" = Ready  ]] ; then
     echo "Connectivity Proxy is installed with the Operator. The CR is in Ready state."
   else
    echo "WARNING!Connectivity Proxy is installed with the Operator. The CR has unexpected state: $crStatus"    
  fi
else
   echo "ERROR! The status of the runtime is inconsistent. " 
fi

