package migration

import (
	"context"

	v211 "github.tools.sap/framefrog/cp-mod-migrator/pkg/cproxy/api/v211"
	v293 "github.tools.sap/framefrog/cp-mod-migrator/pkg/cproxy/api/v293"
	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

type Status string

const (
	StatusUnknown           Status = "UNKNOWN"
	StatusMigrationRequired Status = "REQUIRED"
	StatusMigrationSkipped  Status = "SKIPPED"
)

//go:generate mockery --name=Client
type Client interface {
	client.Client
}

func GetStatus(ctx context.Context, c Client) (Status, v211.ConnectivityProxy, error) {
	var cp v211.ConnectivityProxy
	// get connectivity proxy
	key := client.ObjectKey{
		Namespace: v211.CProxyDefaultCRNamespace,
		Name:      v211.CProxyDefaultCRName,
	}
	if err := c.Get(ctx, key, &cp); err != nil {
		return StatusUnknown, cp, err
	}
	// check if migration was not already performed
	if cp.Migrated() {
		return StatusMigrationSkipped, cp, nil
	}
	// check if old connectivity proxy is installed
	installed, err := OldConnProxyInstalled(ctx, c)
	// status unknown
	if err != nil {
		return StatusUnknown, cp, err
	}
	// migration is not required
	if !installed {
		return StatusMigrationSkipped, cp, nil
	}
	// migration is required
	return StatusMigrationRequired, cp, nil
}

func OldConnProxyInstalled(ctx context.Context, c Client) (bool, error) {
	var cp appsv1.StatefulSet
	err := c.Get(ctx, client.ObjectKey{
		Namespace: "kyma-system",
		Name:      "connectivity-proxy",
	}, &cp)
	if errors.IsNotFound(err) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if _, found := cp.Annotations[v293.AnnotationKeyManagedByReconciler]; !found {
		return false, nil
	}
	return true, nil
}
