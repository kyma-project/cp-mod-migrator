package migration_test

import (
	"context"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	migration "github.tools.sap/framefrog/cp-mod-migrator/pkg"
)

var _ = Describe("GetStatus function", func() {
	ctx := context.Background()

	It("should return error if CP CR was not found on cluster", func() {
		_, _, err := migration.GetStatus(ctx, clientCpCrNotFound)
		Expect(err).Should(HaveOccurred())
	})

	It("should return SKIPPED status if module is installed", func() {
		result, _, err := migration.GetStatus(ctx, clientCpCrFound)
		Expect(err).ShouldNot(HaveOccurred())
		Expect(result).Should(Equal(migration.StatusMigrationSkipped))
	})

	It("should return client error", func() {
		_, _, err := migration.GetStatus(ctx, clientCpCrErr)
		Expect(err).Should(MatchError(ErrNotFoundTest))
	})
})

var _ = Describe("OldConnProxyInstalled function", func() {
	ctx := context.Background()

	It("should return false if connectivity-proxy stateful-set was not found", func() {
		result, err := migration.OldConnProxyInstalled(ctx, clientSsNotFound)
		Expect(err).ShouldNot(HaveOccurred())
		Expect(result).Should(BeFalse())
	})

	It("should return true if connectivity-proxy stateful-set was found", func() {
		result, err := migration.OldConnProxyInstalled(ctx, clientSsFound)
		Expect(err).ShouldNot(HaveOccurred())
		Expect(result).Should(BeTrue())
	})

	It("should return client error", func() {
		_, err := migration.OldConnProxyInstalled(ctx, clientSsErr)
		Expect(err).Should(MatchError(ErrTest))
	})
})
