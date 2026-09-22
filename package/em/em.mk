################################################################################
#
# em
#
################################################################################

# Default: use the canonical EM git repository.
# Product trees can set EM_OVERRIDE_SRCDIR in BR2_PACKAGE_OVERRIDE_FILE for
# local development or board integration testing.
EM_VERSION = v1.0.0
EM_SITE = git@github.com:linux-bsp/em.git
EM_SITE_METHOD = git
EM_LICENSE = Proprietary
EM_INSTALL_TARGET = YES
EM_ADD_TOOLCHAIN_DEPENDENCY = NO

# Dependencies - Kconfig + CMake/Kbuild build system
EM_DEPENDENCIES = host-pkgconf host-cmake host-flex host-bison linux

ifeq ($(BR2_PACKAGE_EM_PDI_BMC_REDFISH),y)
EM_DEPENDENCIES += libcurl cjson
endif

ifeq ($(BR2_PACKAGE_EM_PDI_BMC_IPMI),y)
EM_DEPENDENCIES += freeipmi
endif

ifeq ($(BR2_PACKAGE_EM_PDI_FW),y)
EM_DEPENDENCIES += dtc libcurl openssl
EM_LICENSE += , GPL-2.0+
EM_LICENSE_FILES += LICENSE.GPL-2.0
endif

ifeq ($(BR2_PACKAGE_EM_PDI_FW_FIT_SIGNATURE),y)
EM_DEPENDENCIES += uboot-tools
endif

# Local override builds must not sync generated build directories or stale
# Kbuild products from the EM workspace into Buildroot. Linux refuses external
# modules when modules.order exists in the module source tree.
EM_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = \
	--exclude='.build' \
	--exclude='_build' \
	--exclude='*.o' \
	--exclude='*.o.d' \
	--exclude='*.ko' \
	--exclude='*.mod' \
	--exclude='*.mod.c' \
	--exclude='.*.cmd' \
	--exclude='Module.symvers' \
	--exclude='modules.order' \
	--exclude='.tmp_versions'

# Kconfig configuration to use (from Buildroot config)
EM_KCONFIG_DEFCONFIG = $(call qstrip,$(BR2_PACKAGE_EM_DEFCONFIG))

# Build type from Buildroot configuration
EM_BUILD_TYPE = $(call qstrip,$(BR2_PACKAGE_EM_BUILD_TYPE))

# Build in-tree for Buildroot (output/build/em/.build)
EM_BUILD_OUTPUT = $(@D)/.build
EM_MODULES_OUTPUT = $(@D)/.build/modules
EM_MODULE_EXTRA_DIR = extra/pdm

EM_MAKE_OPTS = \
	BUILD_DIR="$(EM_BUILD_OUTPUT)" \
	MODULES_BUILD_DIR="$(EM_MODULES_OUTPUT)" \
	BR2_EXTERNAL=1 \
	KERNEL_SRC="$(LINUX_DIR)" \
	ARCH="$(KERNEL_ARCH)" \
	CROSS_COMPILE="$(TARGET_CROSS)" \
	CC="$(TARGET_CC)" \
	CMAKE_BUILD_TYPE="$(EM_BUILD_TYPE)" \
	CMAKE_TOOLCHAIN_FILE="$(HOST_DIR)/share/buildroot/toolchainfile.cmake" \
	CMAKE_EXTRA_FLAGS='-DCMAKE_C_COMPILER="$(TARGET_CC)" -DCMAKE_C_FLAGS="$(TARGET_CFLAGS)" -DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS)"' \
	CMAKE_INSTALL_PREFIX="/usr"

# Configure using make (kernel-style interface)
# This loads the defconfig and generates .config + autoconf.h
define EM_CONFIGURE_CMDS
	@test -n "$(EM_KCONFIG_DEFCONFIG)" || { \
		echo "EM: BR2_PACKAGE_EM_DEFCONFIG must be set"; \
		exit 1; \
	}
	@echo "EM: Loading defconfig $(EM_KCONFIG_DEFCONFIG)"
	$(MAKE) -C $(@D) $(EM_MAKE_OPTS) $(EM_KCONFIG_DEFCONFIG)
	@echo "EM: Configuration loaded successfully"
endef

# Build userspace libraries and kernel modules.
define EM_BUILD_CMDS
	@echo "EM: Building with configuration $(EM_KCONFIG_DEFCONFIG)"
	rm -f "$(EM_BUILD_OUTPUT)/CMakeCache.txt"
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(EM_MAKE_OPTS) all
endef

# Clean build artifacts (keep configuration)
define EM_CLEAN_CMDS
	@echo "EM: Cleaning build artifacts"
	-$(MAKE) -C $(@D) clean
endef

# Complete clean (remove configuration and build directory)
define EM_DISTCLEAN_CMDS
	@echo "EM: Complete clean"
	-$(MAKE) -C $(@D) distclean
endef

# Install userspace shared libraries, tools, and kernel modules to target.
define EM_INSTALL_TARGET_CMDS
	@echo "EM: Installing to target"
	$(MAKE) -C $(@D) \
		BUILD_DIR="$(EM_BUILD_OUTPUT)" \
		CMAKE_INSTALL_PREFIX="/usr" \
		install DESTDIR=$(TARGET_DIR)
	kernel_release="$(LINUX_VERSION_PROBED)"; \
	if [ -z "$$kernel_release" ]; then \
		kernel_release="$$($(MAKE) -C "$(LINUX_DIR)" \
			ARCH="$(KERNEL_ARCH)" \
			CROSS_COMPILE="$(TARGET_CROSS)" \
			--no-print-directory -s kernelrelease)"; \
	fi; \
	module_install_dir="$(TARGET_DIR)/lib/modules/$$kernel_release/$(EM_MODULE_EXTRA_DIR)"; \
	$(INSTALL) -d "$$module_install_dir"; \
	modules_found=0; \
	for module in "$(EM_MODULES_OUTPUT)"/*.ko; do \
		[ -e "$$module" ] || continue; \
		modules_found=1; \
		$(INSTALL) -m 0644 "$$module" "$$module_install_dir/$$(basename "$$module")"; \
	done; \
	if [ "$$modules_found" -eq 0 ]; then \
		echo "EM: no kernel modules found in $(EM_MODULES_OUTPUT)"; \
		exit 1; \
	fi
	@echo "EM: Target installation complete"
endef

# Optional: Install development headers and userspace shared libraries to staging.
ifeq ($(BR2_PACKAGE_EM_INSTALL_HEADERS),y)
EM_INSTALL_STAGING = YES
define EM_INSTALL_STAGING_CMDS
	@echo "EM: Installing libraries to staging"
	$(MAKE) -C $(@D) \
		BUILD_DIR="$(EM_BUILD_OUTPUT)" \
		CMAKE_INSTALL_PREFIX="/usr" \
		install DESTDIR=$(STAGING_DIR)
	@echo "EM: Installing development headers to staging"
	$(MAKE) -C $(@D) \
		BUILD_DIR="$(EM_BUILD_OUTPUT)" \
		CMAKE_INSTALL_PREFIX="/usr" \
		install_headers DESTDIR=$(STAGING_DIR)
	@echo "EM: Staging installation complete"
endef
endif

$(eval $(generic-package))
