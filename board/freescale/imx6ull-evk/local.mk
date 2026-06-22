# Local source overrides for the i.MX6ULL EVK board.
#
# Keep product-specific source-tree selections in the external tree instead of
# relying on an untracked local.mk in the Buildroot root directory.

UBOOT_OVERRIDE_SRCDIR = $(TOPDIR)/../uboot/uboot-2024.10
LINUX_OVERRIDE_SRCDIR = $(TOPDIR)/../linux/linux-7.0

# LPF local source used when BR2_PACKAGE_LPF is enabled.
LPF_OVERRIDE_SRCDIR = $(TOPDIR)/../lpf
