#!/bin/bash
set -e

# ========================================================
# keepQASSA 2.4 (Android 10 Q) Crave Build Script for Nokia PL2
# ========================================================

# Clean old local manifests
rm -rf .repo/local_manifests
repo init -u https://github.com/keepQASSA/manifest -b Q --depth=1 --git-lfs

# Pull public local manifest for Nokia PL2
mkdir -p .repo/local_manifests
curl -sL https://raw.githubusercontent.com/Zoro-15/android_device_nokia_PL2/lineage-17.1/qassa_pl2.xml -o .repo/local_manifests/qassa_pl2.xml

# Accelerated sync
if [ -f "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
fi
repo sync -c -j$(nproc --all) --force-sync --force-remove-dirty --no-clone-bundle --no-tags --optimized-fetch --prune

# Fallback tree check
if [ ! -f "device/nokia/PL2/device.mk" ]; then
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_PL2 device/nokia/PL2
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_sdm660-common device/nokia/sdm660-common
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_kernel_nokia_sdm660 kernel/nokia/sdm660
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/proprietary_vendor_nokia vendor/nokia
fi

# Build environment setup
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export WITH_GAPPS=false

source build/envsetup.sh
lunch qassa_PL2-userdebug

# Compile keepQASSA
mka qassa -j$(nproc --all)
