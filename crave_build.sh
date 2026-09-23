#!/bin/bash
set -e

echo "=== Starting Nokia 6.1 (PL2) keepQASSA 2.4 (Android 10 Q) Build ==="

# 1. Clean stale device trees & manifests (Safe for Crave)
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia

# 2. Initialize ROM manifest
repo init -u https://github.com/keepQASSA/manifest.git -b Q --git-lfs --depth=1

# 3. Crave accelerated resync
if [ -f "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
fi
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle -j$(nproc --all)

# 4. Fetch Nokia PL2 trees (Zoro-15)
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_kernel_nokia_sdm660.git kernel/nokia/sdm660
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/proprietary_vendor_nokia.git vendor/nokia

# 5. Hardware integrity check (TAS2557 SmartAmp DSP Firmware)
FIRMWARE_TARGET="vendor/nokia/sdm660-common/proprietary/vendor/firmware/TAS2557MSSMono.bin"
if [ ! -f "$FIRMWARE_TARGET" ] && [ -f "device/nokia/PL2/TAS2557MSSMono.bin" ]; then
    mkdir -p "$(dirname "$FIRMWARE_TARGET")"
    cp device/nokia/PL2/TAS2557MSSMono.bin "$FIRMWARE_TARGET"
fi

# 6. Build environment setup & installclean
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export WITH_GAPPS=false

source build/envsetup.sh
lunch qassa_PL2-userdebug
make installclean

# 7. Compile keepQASSA
mka qassa -j$(nproc --all)

# 8. Upload ROM artifact
OUT_ZIP=$(ls out/target/product/PL2/qassa_*.zip 2>/dev/null | head -n 1)
if [ -z "$OUT_ZIP" ]; then
    OUT_ZIP=$(ls out/target/product/PL2/*.zip 2>/dev/null | head -n 1)
fi

if [ -f "$OUT_ZIP" ]; then
    echo "========================================================"
    echo "BUILD SUCCEEDED: $OUT_ZIP"
    echo "File Size: $(du -h "$OUT_ZIP" | cut -f1)"
    echo "Uploading to BashUpload (Download link is logged below)..."
    curl -s bashupload.com -T "$OUT_ZIP"
    echo ""
    echo "MD5 Checksum:"
    if [ -f "${OUT_ZIP}.md5sum" ]; then
        cat "${OUT_ZIP}.md5sum"
    else
        md5sum "$OUT_ZIP"
    fi
    echo "========================================================"
fi
