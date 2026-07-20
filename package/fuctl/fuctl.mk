################################################################################
#
# fuctl
#
################################################################################

FUCTL_VERSION = 1.0
FUCTL_SITE = $(BR2_EXTERNAL_LINUX_BSP_PATH)/package/fuctl/src
FUCTL_SITE_METHOD = local
FUCTL_LICENSE = GPL-2.0+

define FUCTL_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		-std=c11 -Wall -Wextra -Werror \
		-o $(@D)/fuctl $(@D)/fuctl.c
endef

define FUCTL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/fuctl $(TARGET_DIR)/usr/sbin/fuctl
endef

$(eval $(generic-package))
