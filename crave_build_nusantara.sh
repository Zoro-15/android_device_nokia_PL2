#!/bin/bash
# ==============================================================================
# NusantaraProject Android 10 (Q) Cloud Build Script for Nokia 6.1 (PL2)
# Architecture: 7-Phase Crave.io Golden Architecture
# Manifest: https://github.com/NusantaraProject-ROM/android_manifest/tree/10
# Target: PL2 (Nokia 6.1 - SDM660)
# ==============================================================================
set -e

START_TIME=$(date +%s)
echo "========================================================================"
echo " Starting NusantaraProject Android 10 (Q) Build for Nokia 6.1 (PL2)"
echo " Build Platform: Crave.io Devspace Node"
echo " Date: $(date)"
echo "========================================================================"

# ==============================================================================
# PHASE 1: EXECUTION & MEMORY GUARDS
# ==============================================================================
echo "--> [1/7] Configuring runtime memory guards and build flags..."
export GOMEMLIMIT=8GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx6g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export USE_GAPPS=false

# ==============================================================================
# PHASE 2: PRE-FLIGHT CLEANUP (CRAVE SAFE - NEVER TOUCH PREBUILTS/SOONG CACHE)
# ==============================================================================
echo "--> [2/7] Cleaning stale manifests and device trees..."
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia

# ==============================================================================
# PHASE 3: BASE ROM MANIFEST INITIALIZATION & ACCELERATED RESYNC
# ==============================================================================
echo "--> [3/7] Initializing NusantaraProject Android 10 manifest..."
repo init -u https://github.com/NusantaraProject-ROM/android_manifest.git -b 10 --git-lfs --depth=1

if [ -f "/opt/crave/resync.sh" ]; then
    echo "--> Running Crave accelerated resync cache mirror..."
    /opt/crave/resync.sh
fi

echo "--> Syncing source tree..."
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle -j$(nproc --all)

# ==============================================================================
# PHASE 4: CLONING NOKIA 6.1 (PL2) SOURCE TREES (Zoro-15)
# ==============================================================================
echo "--> [4/7] Fetching Nokia 6.1 (PL2) trees from Zoro-15..."
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_kernel_nokia_sdm660.git kernel/nokia/sdm660
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/proprietary_vendor_nokia.git vendor/nokia

# Generate nad_PL2.mk & update AndroidProducts.mk for Nusantara lunch target
if [ ! -f "device/nokia/PL2/nad_PL2.mk" ]; then
    echo "--> Generating nad_PL2.mk makefile..."
    cat << 'EOF' > device/nokia/PL2/nad_PL2.mk
# Inherit common Nusantara configurations
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, vendor/nusantara/config/common_full_phone.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Device configs
$(call inherit-product, device/nokia/PL2/device.mk)

PRODUCT_BRAND := Nokia
PRODUCT_DEVICE := PL2
PRODUCT_MANUFACTURER := HMD Global
PRODUCT_MODEL := Nokia 6.1
PRODUCT_NAME := nad_PL2

# Ensure Launcher is included in Vanilla build
PRODUCT_PACKAGES += \
    Launcher3QuickStep

PRODUCT_PROPERTY_OVERRIDES += \
    ro.setupwizard.mode=DISABLED

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="Plate2_00WW-user 10 QKQ1.190828.002 00WW_4_15O release-keys" \
    BuildFingerprint=Nokia/Plate2_00WW/PL2_sprout:10/QKQ1.190828.002/00WW_4_15O:user/release-keys \
    DeviceProduct=PL2_sprout
EOF

    cat << 'EOF' > device/nokia/PL2/AndroidProducts.mk
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/nad_PL2.mk

COMMON_LUNCH_CHOICES := \
    nad_PL2-userdebug \
    nad_PL2-user
EOF
fi

# ==============================================================================
# PHASE 5: HARDWARE INTEGRITY CHECKS (SMARTAMP DSP FIRMWARE)
# ==============================================================================
echo "--> [5/7] Verifying TAS2557 SmartAmp DSP firmware..."
FIRMWARE_TARGET="vendor/nokia/sdm660-common/proprietary/vendor/firmware/TAS2557MSSMono.bin"
if [ ! -f "$FIRMWARE_TARGET" ]; then
    echo "Warning: Staging TAS2557MSSMono.bin into vendor tree..."
    mkdir -p "$(dirname "$FIRMWARE_TARGET")"
    if [ -f "device/nokia/PL2/TAS2557MSSMono.bin" ]; then
        cp device/nokia/PL2/TAS2557MSSMono.bin "$FIRMWARE_TARGET"
    fi
fi

# ==============================================================================
# PHASE 6: CCACHE, LUNCH & COMPILATION
# ==============================================================================
echo "--> [6/7] Setting up build environment..."
source build/envsetup.sh
lunch nad_PL2-userdebug

echo "--> Cleaning stale intermediates (installclean)..."
make installclean

echo "--> Starting compilation..."
mka nad -j$(nproc --all) || mka bacon -j$(nproc --all)

# ==============================================================================
# PHASE 7: AUTOMATIC ARTIFACT UPLOAD & VERIFICATION
# ==============================================================================
echo "--> [7/7] Checking build output artifacts..."
OUT_ZIP=$(ls out/target/product/PL2/Nusantara*.zip out/target/product/PL2/nad_*.zip out/target/product/PL2/*.zip 2>/dev/null | head -n 1)

if [ -f "$OUT_ZIP" ]; then
    echo "========================================================"
    echo "BUILD SUCCEEDED: $OUT_ZIP"
    ROM_NAME="$(basename "$OUT_ZIP")"
    SHA_FILE="${OUT_ZIP}.sha256sum"
    sha256sum "$OUT_ZIP" > "$SHA_FILE"
    echo "--> SHA-256:"
    cat "$SHA_FILE"

    echo
    echo "========================================================"
    echo "--> Uploading ROM artifact to temp.sh..."
    echo "========================================================"

    set +e
    TEMP_URL=$(
        curl --fail --silent --show-error --max-time 1800 \
            -F "file=@${OUT_ZIP}" \
            https://temp.sh/upload 2>/dev/null
    )
    set -e

    if [ -n "$TEMP_URL" ] && [[ "$TEMP_URL" == *"http"* ]]; then
        echo "$TEMP_URL" > "${OUT_ZIP}.temp.sh.url"
        echo
        echo "========================================================"
        echo "--> DOWNLOAD URL:"
        echo "$TEMP_URL"
        echo "========================================================"
    else
        echo "WARNING: temp.sh upload failed or timed out."
        echo "Retrieve the file from devspace using: crave pull out/target/product/PL2/*.zip"
    fi
else
    echo "ERROR: ROM flashable zip not found in out/target/product/PL2/"
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Nusantara Android 10 Build Finished in $((ELAPSED / 60)) minutes! ==="
