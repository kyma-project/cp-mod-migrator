package migration_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/mock"
	migration "github.tools.sap/framefrog/cp-mod-migrator/pkg"
	v211 "github.tools.sap/framefrog/cp-mod-migrator/pkg/cproxy/api/v211"
	v293 "github.tools.sap/framefrog/cp-mod-migrator/pkg/cproxy/api/v293"
	"github.tools.sap/framefrog/cp-mod-migrator/pkg/mocks"
	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

var (
	clientCpCrNotFound migration.Client
	clientCpCrFound    migration.Client
	clientCpCrErr      migration.Client
	clientSsNotFound   migration.Client
	clientSsFound      migration.Client
	clientSsErr        migration.Client

	ErrNotFoundTest = errors.NewNotFound(schema.GroupResource{}, "test not found")
	ErrTest         = errors.NewUnauthorized("test error")
	mockArgsAny     = []interface{}{mock.Anything, mock.Anything, mock.Anything}
)

func setupClientCpCR(t *testing.T, cp v211.ConnectivityProxy) (migration.Client, error) {
	runFn := func(args mock.Arguments) {
		_cp := args.Get(2).(*v211.ConnectivityProxy)
		*_cp = cp
	}

	mockClient := mocks.NewClient(t)
	mockClient.On("Get", mockArgsAny...).Return(nil).Run(runFn)

	return mockClient, nil
}

func setupClientCpCRErr(t *testing.T) error {
	mockClient := mocks.NewClient(t)
	mockClient.On("Get", mockArgsAny...).Return(ErrNotFoundTest)

	clientCpCrErr = mockClient
	return nil
}

func setupClientCpCRFound(t *testing.T) (err error) {
	clientCpCrFound, err = setupClientCpCR(t, v211.ConnectivityProxy{
		ObjectMeta: metav1.ObjectMeta{
			Annotations: map[string]string{v211.CProxyMigratedAnnotation: ""},
		},
	})
	return err
}

func setupClientCpCRNotFound(t *testing.T) (err error) {
	mockedClient := mocks.NewClient(t)
	mockedClient.On("Get", mockArgsAny...).Return(ErrNotFoundTest)

	clientCpCrNotFound = mockedClient
	return
}

func setupClientSsNotFound(t *testing.T) (err error) {
	mockedClient := mocks.NewClient(t)
	mockedClient.On("Get", mockArgsAny...).Return(ErrNotFoundTest)

	clientSsNotFound = mockedClient
	return
}

func setupClientSsFound(t *testing.T) (err error) {
	runFn := func(args mock.Arguments) {
		cps := args.Get(2).(*appsv1.StatefulSet)
		*cps = appsv1.StatefulSet{
			ObjectMeta: metav1.ObjectMeta{
				Annotations: map[string]string{v293.AnnotationKeyManagedByReconciler: "test"},
			},
		}
	}

	mockedClient := mocks.NewClient(t)
	mockedClient.On("Get", mockArgsAny...).Return(nil).Run(runFn)

	clientSsFound = mockedClient
	return
}

func setupClientSsErr(t *testing.T) error {
	mockClient := mocks.NewClient(t)
	mockClient.On("Get", mockArgsAny...).Return(ErrTest)

	clientSsErr = mockClient
	return nil
}

type setupMockClient func(*testing.T) error

func TestPkg(t *testing.T) {
	RegisterFailHandler(Fail)

	BeforeSuite(func() {
		for _, setupClient := range []setupMockClient{
			setupClientCpCRFound,
			setupClientCpCRNotFound,
			setupClientCpCRErr,
			setupClientSsNotFound,
			setupClientSsFound,
			setupClientSsErr,
		} {
			err := setupClient(t)
			Expect(err).ShouldNot(HaveOccurred(), "unable to setup mock client")
		}
	})

	RunSpecs(t, "Pkg Suite")
}
