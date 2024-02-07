# Connectivity Proxy Migrator


## Overview

The _Connectivity Proxy Migrator_ repo contains all the necessary components to perform the migration of the old `Connectivity Proxy Kyma component` (currently in version 2.9.3) into new `Kyma Connectivity Proxy module`.

The repository contains following components:

- **Migrator** - Go Application to performs the main migration operation 
- **Backup** - Bash script that performs the backup of the user configuration
- **Cleaner** - Bash script that performs the cleanup of the old CP Kubernetes objects

Each component is built as a separate Docker image and stored in Kyma Project artifactory.

## Prerequisites

- Kyma Cluster with installed Connectivity Proxy component in version 2.9.3
- New Connectivity Proxy Kyma module ready available to be enabled on Kyma cluster
- Modified Connectivity Proxy Operator deployment to run migration components as init containers in following order:

1. Migrator
2. Backup
3. Cleaner

**Note:** 
> - Correct RBACs object must be installed on the cluster to allow for execution of init containers. 
> - Init containers must be configured to communicate over the network without Istio sidecar. This can be done with special UID: 1337 \
> For details see [this file](hack/test-deployment/connectivity-proxy-operator-all.yaml)

Example part of Deployment that implements migration process:

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

## Usage

The migration process consists of three steps executed in following order:

- **Step 1**: Extract the user configuration from config maps and save it into `ConnectivityProxy CR`. 
- **Step 2**: Backup the user configuration into separate namespcace `connectivity-proxy-backup`.
- **Step 3**: Delete previous installation of connectivity proxy. 

When migration is completed successfully, the Connectivity Proxy Operator pod should remain be in running state and new Connectivity Proxy module should be installed.
The connectivyproxy CR should be annotated

## Migrator
Implements following logic: 

Stores into `connectivityproxy CR`:

All fields under the key `connectivity-proxy-config.yml`  of the config map `connectivity-proxy` .

Following fields from config map `connectivity-proxy-info`:  `onpremise_proxy_http_port`, `onpremise_proxy_ldap_port`, `onpremise_socks5_proxy_port`

In shared tenant mode, the value _`connectivity-service-service-key`_ is saved as Spec.SecretConfig.Integration.ConnectivityService.SecretName 

## Backup

The backup consist of copies of two config maps: `connectivity-proxy` and `connectivity-proxy-info`,
When migration is completed the backup of the user configuration is stored in the namespace `connectivity-proxy-backup` and allows to restore. 

### backup restore process



## Cleaner 



## Troubleshooting

That the Connectivity Proxy service will not be available for a couple of minutes during the migration process.
This time is required to start new Connectivity Proxy Kyma module.
When for any reason the service is not available after the migration process, the backup can be restored to the previous state (see Restore section). 
Please contact the Kyma team for support.


## Contributing
<!--- mandatory section - do not change this! --->

See the [Contributing Rules](CONTRIBUTING.md).

## Code of Conduct
<!--- mandatory section - do not change this! --->

See the [Code of Conduct](CODE_OF_CONDUCT.md) document.

## Licensing
See the [license](./LICENSE) file.
