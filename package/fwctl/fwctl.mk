################################################################################
#
# fwctl
#
################################################################################

FWCTL_VERSION = 1.0
FWCTL_SITE = $(BR2_EXTERNAL_LINUX_BSP_PATH)/package/fwctl/src
FWCTL_SITE_METHOD = local
FWCTL_LICENSE = GPL-2.0+

define FWCTL_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-std=c11 -Wall -Wextra -Werror \
		-o $(@D)/fwctl $(@D)/fwctl.c
endef

define FWCTL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/fwctl $(TARGET_DIR)/usr/sbin/fwctl
endef

$(eval $(generic-package))
