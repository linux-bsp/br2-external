Texas Instuments SK-AM62 Test and Development Board

Description
===========

This configuration will build a complete image for the TI SK-AM62
board using TI sources: https://www.ti.com/tool/SK-AM62.

How to Build
============

Select the default configuration for the target:

For non-RT linux build
$ make ti_release_am62x_sk_defconfig

For RT linux build
$ make ti_release_am62x_sk_rt_defconfig

Optional: modify the configuration:

$ make menuconfig

IMPORTANT: make sure to use the tiboot3 firmware that match with the TI
K3 SoC boot ROM (tiboot3-am62x-{gp/hs-fs/hs}-*.bin) used on the board.

HS-FS should be the default for all TI AM6x devices but earlier version
of TI starter kit EVMs for AM6x was produced with a GP device.

See further details on e2e Forum [1] :

   "Unfortunately with this transition any existing GP device based AM62x
   (and AM64x) boards will no longer boot with MMC/SD card images generated"

For such existing GP device based AM62x boards, users have to provide the
tiboot3.bin name using BR2_TARGET_TI_K3_R5_LOADER_TIBOOT3_BIN.

[1]: https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1210443/faq-am625-generating-sitara-am62x-am62ax-am64x-gp-device-bootable-mmc-sd-card-images-using-sdk-v8-6-and-yocto

Build:

$ make

To copy the resultimg output image file to an SD card use dd:

$ dd if=output/images/sdcard.img of=/dev/sdX bs=1M

How to Run
==========

Insert the SD card into the SK-AM62 board, and power it up through the
USB Type-C connector. The system should come up. You can use a
micro-USB cable to connect to the connector labeled UART to
communicate with the board.


Unified Image Generation
========================

The reusable post-image entry point is:

  support/scripts/firmware-image.sh

Each board passes its genimage configuration directly:

  board/ti/am62x/layout/genimage_ti.cfg

The layout directory keeps the physical image layout and one small ITS file per
component:

  board/ti/am62x/layout/genimage_ti.cfg
  board/ti/am62x/layout/boot.its
  board/ti/am62x/layout/kernel.its
  board/ti/am62x/layout/rootfs.its

genimage_ti.cfg defines the FIT outputs, their input images, and the final RAW
media layout. The generic script reads every its entry from this file, copies
the matching ITS from the same directory to output/images, and invokes genimage
once. genimage injects the partition payloads, calls mkimage, and creates both
the component FIT files and the RAW media image. Temporary ITS copies are
removed after a successful build.

Adding a component requires one image fit block in genimage_ti.cfg and one ITS
with the same basename. The generic script does not need to change.

Buildroot keeps its normal artifacts and adds:

  output/images/release/boot.itb
  output/images/release/kernel.itb
  output/images/release/rootfs.itb
  output/images/sdcard.img

The first configured Buildroot DTB is exported as FW_DTB_FILE. A board can
override FW_DTB_FILE in the post-image environment when automatic selection is
not appropriate.

The component FIT files currently include SHA-256 hashes. Production firmware
must add FIT signatures and provision the corresponding required public key in
the U-Boot control device tree.
