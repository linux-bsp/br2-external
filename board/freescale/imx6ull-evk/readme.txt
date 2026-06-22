****************************
Freescale i.MX6ULL EVK board
****************************

This file documents the Buildroot support for the Freescale i.MX6ULL EVK board
using Upstream U-Boot and Linux.

This external tree configuration uses local source overrides for:
- Linux: ../linux/linux-7.0
- U-Boot: ../uboot/uboot-2024.10

Build
=====

First, configure Buildroot for your i.MX6ULL EVK board:

In order to do so issue:

  make BR2_EXTERNAL=../br2-external imx6ullevk_defconfig

Build all components:

  make

You will find in output/images/ the following files:
  - boot.vfat
  - imx6ull-14x14-evk.dtb
  - rootfs.ext2
  - rootfs.ext4
  - rootfs.tar
  - sdcard.img
  - u-boot.bin
  - u-boot-dtb.imx
  - zImage

Create a bootable SD card
=========================

To determine the device associated to the SD card have a look in the
/proc/partitions file:

  cat /proc/partitions

Buildroot prepares a bootable "sdcard.img" image in the output/images/
directory, ready to be dumped on a SD card. Launch the following
command as root:

  dd if=./output/images/sdcard.img of=/dev/<your-sd-device>

*** WARNING! This will destroy all the card content. Use with care! ***

For details about the medium image layout, see the definition in
br2-external/board/freescale/imx6ull-evk/genimage.cfg.template.

Boot the i.MX6ULL EVK board
===========================

To boot your newly created system (refer to the i.MX 6ULL EVK Quick Start Guide [1] for guidance):
- insert the SD card in the micro SD slot of the board;
- put a micro USB cable into the Debug USB Port and connect using a terminal
  emulator at 115200 bps, 8n1;
- power on the board.

KGDB over serial
================

The kernel defconfigs enable KGDB and kgdboc support, but they do not bind
kgdboc from the kernel command line. To enter KGDB at runtime, configure the
serial KGDB I/O module first, then trigger SysRq-g:

  echo ttymxc0,115200 > /sys/module/kgdboc/parameters/kgdboc
  echo g > /proc/sysrq-trigger

After kgdboc is configured, `/proc/sysrq-trigger` help should list `debug(g)`.

Enjoy!

References
==========
[1] https://www.nxp.com/webapp/Download?colCode=IMX6ULLQSG
