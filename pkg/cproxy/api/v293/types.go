package v293

const (
	CProxyCMName                        = "connectivity-proxy"
	CProxyCMNamespace                   = "kyma-system"
	CProxyConfigFilename                = "connectivity-proxy-config.yml"
	CProxyCMInfoName                    = "connectivity-proxy-info"
	CProxyCMInfoNamespace               = CProxyCMNamespace
	CProxyOnpremiseProxyHost            = "onpremise_proxy_host"
	CProxyOnpremiseProxyHttpPort        = "onpremise_proxy_http_port"
	CProxyOnpremiseProxyLdapPort        = "onpremise_proxy_ldap_port"
	CProxyOnpremiseProxyPort            = "onpremise_proxy_port"
	CProxyOnpremiseProxyRfcPort         = "onpremise_proxy_rfc_port"
	CProxyOnpremiseSocks5ProxyPort      = "onpremise_socks5_proxy_port"
	CProxyConnectivityServiceSecretName = "connectivity-proxy-service-key"
	AnnotationKeyManagedByReconciler    = "reconciler.kyma-project.io/managed-by-reconciler-disclaimer"
)
