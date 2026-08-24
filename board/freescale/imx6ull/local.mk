# Local source overrides for the i.MX6ULL board.
#
# Keep product-specific source-tree selections in the external tree instead of
# relying on an untracked local.mk in the Buildroot root directory.

UBOOT_OVERRIDE_SRCDIR = $(TOPDIR)/../uboot/uboot-2024.10
LINUX_OVERRIDE_SRCDIR = $(TOPDIR)/../linux/linux-7.0

# PAF local source used when BR2_PACKAGE_PAF is enabled.
PAF_OVERRIDE_SRCDIR = $(TOPDIR)/../paf
SYSTOOLS_OVERRIDE_SRCDIR = $(TOPDIR)/../systools
