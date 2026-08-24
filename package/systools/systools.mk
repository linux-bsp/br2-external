################################################################################
#
# systools
#
################################################################################

SYSTOOLS_VERSION = master
SYSTOOLS_SITE = https://github.com/linux-bsp/systools.git
SYSTOOLS_SITE_METHOD = git
SYSTOOLS_LICENSE = MIT
SYSTOOLS_LICENSE_FILES = LICENSE
SYSTOOLS_INSTALL_TARGET = YES
SYSTOOLS_DEPENDENCIES = host-cmake

$(eval $(cmake-package))
