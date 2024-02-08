# Connectivity Proxy Migrator

## Overview

This repository contains source code of components which are necessary to perform the migration from the legacy `Connectivity Proxy Kyma component` (currently in version 2.9.3) into new `Kyma Connectivity Proxy module`.

The migration is designed as a three-step process where each step is executed by a separate component.

The migrator components are:

- **Configuration Migrator** - Go Application to performs the main migration operation 
- **Backup** - Bash script that performs the backup of the user configuration
- **Cleaner** - Bash script that performs the cleanup of the old CP Kubernetes objects

They are built as separate Docker images and stored in the Kyma Project artifactory. \
Docker Images are executed during startup of newly installed Kyma Connectivity Proxy module as init containers included into the Connectivity Proxy Operator Deployment. \
The migration process is designed to be idempotent and can be repeated without any side effects.

### Configuration Migrator

It performs the following steps:

1. Finds default `connectivityproxy CR`
2. Exits with error if the `connectivityproxy CR` doesn't exist
3. Exits with success if one of the following conditions is true:
    - The Connectivity Proxy 2.9.3 is not installed
    - The `connectivityproxy CR` exists, and have `connectivityproxy.sap.com/migrated` annotation set (migration was performed already)
4. Reads the current user configuration from `connectivity-proxy`, and `connectivity-proxy-info` config maps
5. Updates the `connectivityproxy CR` with configuration read from the cluster
6. Adds `migrator.kyma-project.io/migrated="true"` annotation on the CR.

The migrator transfers the data in the following way:
- All fields under the key `connectivity-proxy-config.yml` of the config map `connectivity-proxy` are written under `spec.config` key in the CR
- The keys from the `connectivity-proxy-info` are mapped as follows:
    - `onpremise_proxy_http_port` is written into `spec.config.servers.proxy.http.port`
    - `onpremise_proxy_ldap_port` is written into `spec.config.servers.proxy.rfcandldap.port`
    - `onpremise_socks5_proxy_port` is written into `spec.config.servers.proxy.socks5.port`
- if tenant mode is shared `spec.secretconfig.integration.connectivityservice.secretname` key is set with `connectivity-proxy-service-key` value

### Backup

It performs the following steps:
1. Checks if `connectivityproxy` CRD is installed on the cluster, and exits with success if it is not the case
2. Finds default `connectivityproxy CR`
3. Exits with success if the `connectivityproxy CR` doesn't exist
4. Exits with success if the `connectivityproxy CR` `migrator.kyma-project.io/backed-up="true"` annotation (backup was completed already)
5. Creates `connectivity-proxy-backup` namespace if it doesn't exist
6. Copies `connectivity-proxy`, and `connectivity-proxy-info` config maps into `connectivity-proxy-backup` namespace
7. Adds `migrator.kyma-project.io/backed-up="true"` annotation on the CR.

### Cleaner

1. Checks if `connectivityproxy` CRD is installed on the cluster, and exits with success if it is not the case
2. Finds default `connectivityproxy CR`
3. Exits with success if the `connectivityproxy CR` doesn't exist
4. Exits with success if the `connectivityproxy CR` `migrator.kyma-project.io/cleaned="true` annotation (cleanup was completed already)
5. Removes the legacy Connectivity Proxy 2.9.3 Kubernetes objects from the cluster (`deployments`, `statuefulsets`, `services`, `configmaps` etc.)
6. Adds `migrator.kyma-project.io/cleaned="true"` annotation on the CR.


## Migration process
### Prerequisites

  - Kyma Cluster with legacy Connectivity Proxy component installed 
  - New Connectivity Proxy Kyma module ready to be enabled on Kyma cluster
  - Module configured to include Connectivity Proxy init containers.

### Implementation details

The migration task will be automatically completed during startup of the `Connectivity Proxy Operator` pod, and implemented with init containers. \
This Deployment and the default `ConnectivityProxy custom resource (CR)` will be installed on the Kyma cluster when new `Connectivity Proxy Kyma module` is enabled by the user.

The Connectivity Proxy Operator pod runs Connectivity Proxy Migrator components as init containers in following order:

1. **Configuration Migrator** - Extracts the user configuration from config maps and saves it into `ConnectivityProxy CR`.
2. **Backup** - Backup of the user configuration into separate namespcace `connectivity-proxy-backup`.
3. **Cleaner** - Deletes previous installation of connectivity proxy.

**Note:**
> - Correct RBACs object must be installed on the cluster to allow for execution of init containers.
> - Init containers must be configured to communicate over the network without Istio sidecar. This can be done by using special **UID: 1337** \
>
>   For details see [this file](hack/test-deployment/connectivity-proxy-operator-all.yaml)

Example part of Deployment that fully implements the migration process with init containers in the correct order is shown below:

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

When completed each migration step is marked with by its own annotation on the `ConnectivityProxy CR` object. \
This ensures that it will not be repeated in case of the Pod restart. \
After successful migration, the Connectivity Proxy Operator pod should remain be in running state and all required Connectivity Proxy module parts should be running on the cluster.

### Troubleshooting

It is expected that the `Connectivity Proxy` service will not be available about a minute during migration process. \
When for any reason the service is not available for a longer time some actions are required to fix the situation. \
You can try to fix Connectivity Proxy Operator pod or restore the old installation. \

If you want to fully restore the previous state use backup of user configuration from the `connectivity-proxy-backup` namespace. \
Please make sure to contact the Kyma team for support and assistance.

### Restoring old installation

The goal is to restore the previous state of the `Connectivity Proxy` in case of any issues during the migration process.

Make sure that the `Connectivity Proxy Operator` pod is running, in such a case disable `Connectivity Proxy` module in Busola or by editing Kyma resource. \
Wait some time for uninstallation of the `Connectivity Proxy` module. \
After the `Connectivity Proxy Module` is removed please wait about one hour Kyma Control Plane to restore legacy `Connectivity Proxy` objects on the cluster

### Fixing operator pod

When `Connectivity Proxy Operator` pod is in Error or CrashLoopBackOff state, annotate ConnectivityProxy CR to ensure init containers will not run again:

```bash
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/migrated=true
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/backed-up=true
kubectl annotate connectivityproxies.connectivityproxy.sap.com connectivity-proxy -n kyma-system connectivityproxy\.sap\.com/cleaned-up=true
```
Then reboot the `Connectivity Proxy Operator` pod.

### Restore user configuration from backup

Please run the following script to restore the user configuration from the backup:

```bash
if kubectl get cm -n connectivity-proxy-backup connectivity-proxy &> /dev/null; then
  kubectl get cm -n kyma-system connectivity-proxy-backup -o yaml | sed s/"namespace: connectivity-proxy-backup"/"namespace: kyma-system"/ | kubectl apply -f -
  echo "connectivity-proxy config map restored successfully from backup"
else
  echo "Warning! connectivity-proxy config map does not exist in connectivity-proxy-backup namespace, operation skipped"
fi

if kubectl get cm -n connectivity-proxy-backup connectivity-proxy-info &> /dev/null; then
  kubectl get cm -n connectivity-proxy-backup connectivity-proxy-info -o yaml | sed s/"namespace: connectivity-proxy-backup"/"namespace: kyma-system"/ | kubectl apply -f -
  echo "connectivity-proxy-info config map restored successfully from backup"
else
  echo "Warning! connectivity-proxy-info config map does not exist in connectivity-proxy-backup namespace, operation skipped"
fi
```
