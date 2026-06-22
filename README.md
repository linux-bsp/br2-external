# Buildroot External Tree

This repository contains the Buildroot external tree used by the BSP workspace.
It is intended to host board-specific Buildroot integration for multiple boards,
not only the NXP i.MX6ULL EVK.

Each board should keep its Buildroot defconfig, board files, post-image scripts,
root filesystem overlays, and package overrides under a board-specific directory.
Existing i.MX6ULL EVK support is one board configuration in this external tree.

## Current Board Support

- `configs/imx6ullevk_defconfig` for the NXP i.MX6ULL EVK
- `configs/imx6ullevk_debug_study_defconfig` for the i.MX6ULL EVK debug/study profile
- `board/freescale/imx6ull-evk/` for i.MX6ULL EVK board files
- `package/lpf/` for LPF integration

## Build

From the BSP workspace root, run Buildroot with this external tree:

```sh
cd buildroot
make BR2_EXTERNAL=../br2-external imx6ullevk_defconfig
make
```

The i.MX6ULL EVK defconfig is derived from Buildroot's upstream
`configs/imx6ullevk_defconfig`, with board-specific paths redirected to this
external tree.

The current board configuration uses local source overrides from the BSP
workspace:

- `../linux-7.0`
- `../uboot-2024.10`
- `../lpf`

## Adding Board Support

When adding another board, keep the layout predictable:

- Add the board defconfig under `configs/`.
- Add board files under `board/<vendor>/<board>/`.
- Keep root filesystem overlays, kernel config fragments, post-image scripts,
  and image layout files inside the board directory.
- Add board-specific package overrides through `local.mk` or another clearly
  named board-local makefile.
- Document board-specific build and boot steps in the board directory.

Use the i.MX6ULL EVK files as a reference for the current structure, but avoid
hard-coding new board support to i.MX6ULL-specific paths or names unless the
configuration is genuinely i.MX6ULL-specific.
