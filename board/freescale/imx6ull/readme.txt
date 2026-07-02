=========================
i.MX6ULL ATK-DL6Y2C board
=========================

This file documents the Buildroot support for the i.MX6ULL ATK-DL6Y2C board
using Upstream U-Boot and Linux.

This external tree configuration uses local source overrides for:
- Linux: ../linux/linux-7.0
- U-Boot: ../uboot/uboot-2024.10

Build
=====

First, configure Buildroot for your i.MX6ULL board:

In order to do so issue:

  make BR2_EXTERNAL=../br2-external imx6ull_defconfig

Build all components:

  make

You will find in output/images/ the following files:
  - boot.vfat
  - imx6ull-atk-dl6y2c.dtb
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
br2-external/board/freescale/imx6ull/genimage.cfg.template.

Boot the i.MX6ULL board
=======================

To boot your newly created system:
- insert the SD card in the micro SD slot of the board;
- put a micro USB cable into the Debug USB Port and connect using a terminal
  emulator at 115200 bps, 8n1;
- power on the board.


PAF / PDM debug workflow
========================

The debug Buildroot profile enables the external PAF package with
`BR2_PACKAGE_PAF_DEFCONFIG="imx6ull_debug_defconfig"`. The board-local
`local.mk` overrides PAF to `../paf`, so the image uses the workspace PAF tree.

When the PAF defconfig enables `CONFIG_PDI`, `CONFIG_PDEBUG`, and
`CONFIG_PDI_CLAIM_TEST`, the target image installs:

  - /usr/lib/libpdi.so
  - /usr/bin/pdebug
  - /usr/bin/pdi_claim_test
  - /lib/modules/<kernel>/extra/pdm/pdm.ko

The rootfs overlay starts PDM through `/etc/init.d/S03pdm`. On the board, use:

  /etc/init.d/S03pdm status
  pdebug discovery list
  module-test.sh

`module-test.sh` loads `pdm.ko`, prints manager discovery information, and runs
`pdi_claim_test` for MCU/LED devices that expose a shared ioctl endpoint.

For user-owned PDM communication endpoints, DTS keeps only stable hardware and
discovery metadata. The rootfs overlay installs runtime transport policy at:

  /etc/pdm/mcu-transports.conf

The current board CAN endpoint uses the `[mcu.can.3]` section for request and
response CAN IDs, timeout, and retry policy. UART and network sections are
provided as commented templates; enable them only after reserving the matching
user-owned PDM endpoint and adding a userspace transport owner.

KGDB over serial
================

The kernel defconfigs enable KGDB and kgdboc support, but they do not bind
kgdboc from the kernel command line. To enter KGDB at runtime, configure the
serial KGDB I/O module first, then trigger SysRq-g:

  echo ttymxc0,115200 > /sys/module/kgdboc/parameters/kgdboc
  echo g > /proc/sysrq-trigger

After kgdboc is configured, `/proc/sysrq-trigger` help should list `debug(g)`.

Enjoy!
