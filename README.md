# IMX6ULL Buildroot External Tree

This external tree contains board support for the NXP i.MX6ULL EVK.

## Build

```sh
cd /home/wanguo/IMX6ULL/buildroot
make BR2_EXTERNAL=/home/wanguo/IMX6ULL/buildroot-external-tree imx6ullevk_defconfig
make
```

The board defconfig is derived from Buildroot's upstream
`configs/imx6ullevk_defconfig`, with board-specific paths redirected to this
external tree.

The board configuration uses local Linux and U-Boot source overrides:

- `/home/wanguo/IMX6ULL/linux-7.0`
- `/home/wanguo/IMX6ULL/u-boot-v2024.10`

LPF is enabled through the external `package/lpf` package and uses the local
`/home/wanguo/LPF` source override with the `imx6ull_modules_defconfig` LPF
target.
