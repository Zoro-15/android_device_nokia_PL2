# Device Tree for Nokia 6.1 (PL2)

The Nokia 6.1 (codenamed _"plate2"_ , TLA _"PL2"_) is a mid-range smartphone from Nokia.
It was released in April 2018.

| Basic                   | Spec Sheet                                                                                                                     |
| -----------------------:|:------------------------------------------------------------------------------------------------------------------------------ |
| CPU                     | Octa-core 2.2 GHz Cortex-A53                                                                                                   |
| Chipset                 | Qualcomm SDM630 Snapdragon 660                                                                                                 |
| GPU                     | Adreno 508                                                                                                                     |
| Memory                  | 3/4 GB RAM                                                                                                                     |
| Shipped Android Version | 8.1                                                                                                                            |
| Storage                 | 32/64 GB                                                                                                                       |
| Battery                 | Non-removable Li-Po 3000 mAh battery                                                                                           |
| Display                 | 1080 x 1920 pixels, 16:9 ratio (~403 ppi density)                                                                              |
| Camera (Back)           | 16 MP, f/2.0, 27mm (wide), 1.0µm, PDAF, Zeiss optics, dual-LED dual-tone flash, panorama, HDR, 2160p@30fps, 1080p@30fps        |
| Camera (Front)          | 8 MP, f/2.0, 1/4", 1.12µm, 1080p@30fps                                                                                         |

![Nokia 6.1](https://cdn2.gsmarena.com/vv/pics/nokia/nokia-6-2018-1.jpg)

## Build Instructions (CloverOS)

1. Initialize the CloverOS source tree (shallow clone with `--depth=1`):

```bash
repo init -u https://github.com/The-Clover-Project/manifest.git -b 17 --git-lfs --depth=1
```

2. Add the local manifest for Nokia 6.1 (`PL2`):

```bash
mkdir -p .repo/local_manifests
curl -fsSL https://raw.githubusercontent.com/Nokia-Playground/android_device_nokia_PL2/Clover-4.x/pl2.xml -o .repo/local_manifests/pl2.xml
```

3. Sync the CloverOS source along with the device, common, kernel, vendor, and NFC repositories:

```bash
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j$(nproc --all)
```

4. Set up the build environment, select the target, and start the build:

```bash
source build/envsetup.sh
lunch clover_PL2-cp2a-userdebug
m clover
```

```
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
```
