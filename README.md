# Connectivity Proxy Migrator

## Overview

This repository contains the source code of components that are necessary to perform the migration from the legacy Kyma Connectivity Proxy component (currently in version 2.9.3) into the new Kyma Connectivity Proxy module.

The migration is designed as a three-step process where each step is executed by a separate component.

The migrator components are:

- **Configuration Migrator** - Go Application that performs the main migration operation 
- **Backup** - Bash script that performs the backup of the user configuration
- **Cleaner** - Bash script that performs the cleanup of the old CP Kubernetes objects

They are built as separate Docker images and stored in the Kyma Project artifactory. \
Docker images are executed during the startup of the newly installed Kyma Connectivity Proxy module as init containers included in the Connectivity Proxy Operator Deployment. \
The migration process is designed to be idempotent and can be repeated without any side effects.

### Configuration Migrator

It performs the following steps:

1. Finds the default ConnectivityProxy custom resource (CR)
2. Exits with an error if the ConnectivityProxy CR doesn't exist
3. Exits with success if one of the following conditions is true:
    - The Connectivity Proxy 2.9.3 is not installed
    - The ConnectivityProxy CR exists and has the `connectivityproxy.sap.com/migrated` annotation set (migration was performed already)
4. Reads the current user configuration from the `connectivity-proxy` and `connectivity-proxy-info` ConfigMaps
5. Updates the ConnectivityProxy CR with the configuration read from the cluster
6. Adds the `migrator.kyma-project.io/migrated="true"` annotation to the CR.

The migrator transfers the data in the following way:
- All fields under the key `connectivity-proxy-config.yml` of the `connectivity-proxy` ConfigMap are written under the `spec.config` key in the CR
- The keys from the `connectivity-proxy-info` are mapped as follows:
    - `onpremise_proxy_http_port` is written into `spec.config.servers.proxy.http.port`
    - `onpremise_proxy_ldap_port` is written into `spec.config.servers.proxy.rfcandldap.port`
    - `onpremise_socks5_proxy_port` is written into `spec.config.servers.proxy.socks5.port`
- if tenant mode is shared, the `spec.secretconfig.integration.connectivityservice.secretname` key is set with the `connectivity-proxy-service-key` value

### Backup

It performs the following steps:
1. Checks if the ConnectivityProxy CR is installed on the cluster and exits with success if it's not
2. Finds the default ConnectivityProxy CR
3. Exits with success if the ConnectivityProxy CR doesn't exist
4. Exits with success if the ConnectivityProxy CR has the `migrator.kyma-project.io/backed-up="true"` annotation (backup was completed already)
5. Creates the `connectivity-proxy-backup` namespace if it doesn't exist
6. Copies the `connectivity-proxy` and `connectivity-proxy-info` ConfigMaps into the `connectivity-proxy-backup` namespace
7. Adds the `migrator.kyma-project.io/backed-up="true"` annotation to the CR.

### Cleaner

1. Checks if ConnectivityProxy CR is installed on the cluster and exits with success if it's not
2. Finds the default ConnectivityProxy CR
3. Exits with success if the ConnectivityProxy CR doesn't exist
4. Exits with success if the ConnectivityProxy CR has the `migrator.kyma-project.io/cleaned="true` annotation (cleanup was completed already)
5. Migrates preexisting instances and definition of custom resources of type `servicemappings.connectivityproxy.sap.com` by adding:
   - Annotations `io.javaoperatorsdk/primary-name=connectivity-proxy` and `io.javaoperatorsdk/primary-namespace=kyma-system`
   - Label `app.kubernetes.io/managed-by=sap.connectivity.proxy.operator`
6. Removes the legacy Connectivity Proxy 2.9.3 Kubernetes objects from the cluster (Deployments, StatefulSets, Services, ConfigMaps, etc.)
7. Adds the `migrator.kyma-project.io/cleaned="true"` annotation to the CR.


## Migration process
### Prerequisites

  - Kyma cluster with the legacy Connectivity Proxy component installed 
  - New Connectivity Proxy Kyma module ready to be enabled on Kyma cluster
  - Module configured to include Connectivity Proxy init containers.

### Implementation details

The migration task is automatically completed during the startup of the Connectivity Proxy Operator Pod and implemented with init containers. \
This Deployment and the default ConnectivityProxy CR are installed on the Kyma cluster when the new Kyma Connectivity Proxy module is enabled by the user.

The Connectivity Proxy Operator Pod runs the Connectivity Proxy Migrator components as init containers in the following order:

1. **Configuration Migrator** - Extracts the user configuration from ConfigMaps and saves it in the ConnectivityProxy CR.
2. **Backup** - Backup of the user configuration in the separate `connectivity-proxy-backup` namespace.
3. **Cleaner** - Deletes the previous installation of Connectivity Proxy.

**Note:**
> - Correct RBACs object must be installed on the cluster to allow for the execution of init containers.
> - Init containers must be configured to communicate over the network without the Istio sidecar. This can be done by using special **UID: 1337** \
>
>   For details see [this YAML file](hack/test-deployment/connectivity-proxy-operator-all.yaml).

An example of Deployment that fully implements the migration process with init containers in the correct order is shown below:

```yaml
      initContainers:
        - name: init-migrator
          image: europe-docker.pkg.dev/kyma-project/prod/cp-mod-migrator:latest
          imagePullPolicy: Always
          securityContext:
            runAsUser: 1337
        - name: init-backup
          image: europe-docker.pkg.dev/kyma-project/prod/cp-mod-backup:latest
          imagePullPolicy: Always
          securityContext:
            runAsUser: 1337
        - name: init-cleaner
          image: europe-docker.pkg.dev/kyma-project/prod/cp-mod-cleaner:latest
          imagePullPolicy: Always
          securityContext:
            runAsUser: 1337
```

When completed, each migration step is marked with its own annotation on the `ConnectivityProxy CR` object. \
This ensures that it is not repeated in case of the Pod restart. \
After successful migration, the Connectivity Proxy Operator Pod should remain in the running state, and all required Connectivity Proxy module parts should be running on the cluster.

### Troubleshooting

It is expected that the Connectivity Proxy service will not be available for about a minute during the migration process. \
When for any reason the service is not available for a longer time some actions are required to fix the situation. \
You can try to fix the Connectivity Proxy Operator Pod or restore the old installation. \

If you want to fully restore the previous state use backup of user configuration from the `connectivity-proxy-backup` namespace. \
Please make sure to contact the Kyma team for support and assistance.

### Restoring old installation

The goal is to restore the previous state of the Connectivity Proxy in case of any issues during the migration process.

Check if the Connectivity Proxy Operator Pod is running. In such a case, disable the Connectivity Proxy module using Busola or by editing the Kyma resource. \
Wait some time for the uninstallation of the Connectivity Proxy module. \
After the Connectivity Proxy module is uninstalled, wait about one hour for the Kyma Control Plane to restore the legacy Connectivity Proxy objects on the cluster.

### Fixing operator Pod

Follow these steps if the Connectivity Proxy Operator Pod is in the `Error` or `CrashLoopBackOff` state: 
1. Annotate the ConnectivityProxy CR to ensure init containers will not run again

```bash
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/migrated=true
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/backed-up=true
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/cleaned-up=true
```
2. Reboot the Connectivity Proxy Operator Pod.

### Restore user configuration from backup

1. Make sure that connectivity-proxy module is already disabled and all components have been removed from the cluster.
2. Run following commands to remove the remaining Connectivity Proxy Operator Deployment and Custom Resource Definition if necessary (see [this issue](https://github.com/kyma-project/lifecycle-manager/issues/1319) for more details:):

```bash
kubectl delete deployment -n kyma-system connectivity-proxy-operator
kubectl delete crd connectivityproxies.connectivityproxy.sap.com
````

3. Wait about half an hour for the Kyma Control Plane to restore the legacy Connectivity Proxy objects on the cluster.
4. Run the following script to restore the user configuration from the backup:

```bash
if kubectl get cm -n connectivity-proxy-backup connectivity-proxy &> /dev/null; then
  kubectl get cm -n connectivity-proxy-backup connectivity-proxy -o yaml | sed -e s/"namespace: connectivity-proxy-backup"/"namespace: kyma-system"/ -e "/uid:/d" -e "/resourceVersion:/d" | kubectl apply -f -
  echo "connectivity-proxy config map restored successfully from backup"
else
  echo "Warning! connectivity-proxy config map does not exist in connectivity-proxy-backup namespace, operation skipped"
fi

if kubectl get cm -n connectivity-proxy-backup connectivity-proxy-info &> /dev/null; then
  kubectl get cm -n connectivity-proxy-backup connectivity-proxy-info -o yaml | sed -e s/"namespace: connectivity-proxy-backup"/"namespace: kyma-system"/ -e "/uid:/d" -e "/resourceVersion:/d" | kubectl apply -f -
  echo "connectivity-proxy-info config map restored successfully from backup"
else
  echo "Warning! connectivity-proxy-info config map does not exist in connectivity-proxy-backup namespace, operation skipped"
fi
```
