# Local source overrides for the TI AM62x board.
#
# Keep product-specific source-tree selections in the external tree instead of
# relying on an untracked local.mk in the Buildroot root directory.

UBOOT_OVERRIDE_SRCDIR = $(TOPDIR)/../uboot/ti-u-boot-2025.10
LINUX_OVERRIDE_SRCDIR = $(TOPDIR)/../linux/ti-linux-kernel-6.18.13

# TI K3 R5 Loader uses the same U-Boot source tree as the A53 U-Boot
TI_K3_R5_LOADER_OVERRIDE_SRCDIR = $(TOPDIR)/../uboot/ti-u-boot-2025.10

