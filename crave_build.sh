#!/bin/bash
# ==============================================================================
# LineageOS 23.2 (Android 16 / Baklava) Cloud Build Script for Nokia 6.1 (PL2)
# Tailored for Crave.io Devspace Execution (Project ID: 85)
# Hosted in Zoro-15/android_device_nokia_PL2 (branch: lineage-23.2)
# ==============================================================================
set -e

START_TIME=$(date +%s)
echo "========================================================================"
echo " Starting LineageOS 23.2 (Android 16) Build for Nokia 6.1 (PL2)"
echo " Build Host: Crave.io Devspace Node"
echo " Date: $(date)"
echo "========================================================================"

# ------------------------------------------------------------------------------
# PHASE 1: EXECUTION & MEMORY GUARDS
# ------------------------------------------------------------------------------
echo "--> [1/8] Configuring runtime environment and memory guards..."
export GOMEMLIMIT=12GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx8g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export SOONG_UI_TABLET=always

# ------------------------------------------------------------------------------
# PHASE 2: PRE-FLIGHT CLEANUP (CRAVE SAFE - NEVER TOUCH PREBUILTS OR SOONG CACHE)
# ------------------------------------------------------------------------------
echo "--> [2/8] Cleaning stale device trees and local manifests..."
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common
rm -rf vendor/nokia/PL2 vendor/nokia/sdm660-common
rm -rf kernel/nokia/sdm660
rm -rf hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
rm -rf device/qcom/sepolicy-legacy-um hardware/lineage/compat

# ------------------------------------------------------------------------------
# PHASE 3: ROM MANIFEST INITIALIZATION & RESYNC
# ------------------------------------------------------------------------------
echo "--> [3/8] Initializing LineageOS 23.2 base manifest..."
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

if [ -f "/opt/crave/resync.sh" ]; then
    echo "--> Running Crave accelerated resync mirror..."
    /opt/crave/resync.sh
fi

# ------------------------------------------------------------------------------
# PHASE 4: DEPLOYING NOKIA 6.1 (PL2) LOCAL MANIFEST & SYNCING
# ------------------------------------------------------------------------------
echo "--> [4/8] Deploying 10-repository local manifest for PL2..."
mkdir -p .repo/local_manifests
cat << "EOF" > .repo/local_manifests/PL2.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Device Trees -->
  <project path="device/nokia/sdm660-common" name="log1cs/android_device_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="device/nokia/PL2" name="Zoro-15/android_device_nokia_PL2" remote="github" revision="lineage-23.2" />

  <!-- Vendor Trees -->
  <project path="vendor/nokia/sdm660-common" name="log1cs/proprietary_vendor_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/PL2" name="Zoro-15/proprietary_vendor_nokia_PL2" remote="github" revision="lineage-23.2" />

  <!-- Kernel Tree (eBPF 5.10 Backport) -->
  <project path="kernel/nokia/sdm660" name="Zoro-15/android_kernel_nokia_PL2_16" remote="github" revision="lineage-23.2" />

  <!-- Qualcomm Hardware HALs & Compatibility Layer -->
  <project path="hardware/qcom-caf/sdm660/audio" name="Zoro-15/android_hardware_qcom_audio" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/display" name="Zoro-15/android_hardware_qcom_display" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="hardware/qcom-caf/sdm660/media" name="Zoro-15/android_hardware_qcom_media" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="device/qcom/sepolicy-legacy-um" name="Zoro-15/android_device_qcom_sepolicy" remote="github" revision="lineage-23.2" />
  <project path="hardware/lineage/compat" name="log1cs/android_hardware_lineage_compat" remote="github" revision="lineage-23.2" />
</manifest>
EOF

echo "--> Syncing source repositories..."
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty

# Fallback check: Ensure all 10 repositories exist
[ ! -d "device/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/log1cs/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
[ ! -d "device/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
[ ! -d "vendor/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/log1cs/proprietary_vendor_nokia_sdm660-common.git vendor/nokia/sdm660-common
[ ! -d "vendor/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_PL2.git vendor/nokia/PL2
[ ! -d "kernel/nokia/sdm660" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_kernel_nokia_PL2_16.git kernel/nokia/sdm660
[ ! -d "hardware/qcom-caf/sdm660/audio" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_hardware_qcom_audio.git hardware/qcom-caf/sdm660/audio
[ ! -d "hardware/qcom-caf/sdm660/display" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_display.git hardware/qcom-caf/sdm660/display
[ ! -d "hardware/qcom-caf/sdm660/media" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_media.git hardware/qcom-caf/sdm660/media
[ ! -d "device/qcom/sepolicy-legacy-um" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_qcom_sepolicy.git device/qcom/sepolicy-legacy-um
[ ! -d "hardware/lineage/compat" ] && git clone --depth=1 -b lineage-23.2 https://github.com/log1cs/android_hardware_lineage_compat.git hardware/lineage/compat

# ------------------------------------------------------------------------------
# PHASE 5: FORENSIC BSP PRE-FLIGHT COMPLIANCE FIXES
# ------------------------------------------------------------------------------
echo "--> [5/8] Applying Android 16 BSP compatibility shims..."

# Fix 1: Soong Namespace & File-Copy Bridge (msm8998 <-> sdm660)
mkdir -p hardware/qcom-caf
ln -sfn $(pwd)/hardware/qcom-caf/sdm660 $(pwd)/hardware/qcom-caf/msm8998
echo "    [OK] Linked hardware/qcom-caf/msm8998 -> sdm660"

# Fix 2: Remove deprecated VNDK definition from BoardConfigCommon
sed -i "/BOARD_VNDK_VERSION/d" device/nokia/sdm660-common/BoardConfigCommon.mk 2>/dev/null || true
echo "    [OK] Stripped obsolete BOARD_VNDK_VERSION"

# Fix 3: Ensure TI TAS2557 SmartAmp DSP firmware is staged and registered
mkdir -p vendor/nokia/PL2/proprietary/vendor/firmware
if [ ! -f "vendor/nokia/PL2/proprietary/vendor/firmware/TAS2557MSSMono.bin" ]; then
    echo "    [FETCH] Downloading TAS2557MSSMono.bin DSP firmware..."
    curl -sL "https://raw.githubusercontent.com/Zoro-15/proprietary_vendor_nokia_PL2/lineage-22.2/proprietary/vendor/firmware/TAS2557MSSMono.bin" \
        -o vendor/nokia/PL2/proprietary/vendor/firmware/TAS2557MSSMono.bin
fi
if ! grep -q "TAS2557MSSMono.bin" vendor/nokia/PL2/PL2-vendor.mk 2>/dev/null; then
    echo "    [PATCH] Appending TAS2557 copy rule to PL2-vendor.mk..."
    printf "\n# Texas Instruments TAS2557 SmartAmp DSP Firmware\nPRODUCT_COPY_FILES += \\\n    vendor/nokia/PL2/proprietary/vendor/firmware/TAS2557MSSMono.bin:\$(TARGET_COPY_OUT_VENDOR)/firmware/TAS2557MSSMono.bin\n" >> vendor/nokia/PL2/PL2-vendor.mk
fi
echo "    [OK] TAS2557 SmartAmp DSP firmware deployed"

# Fix 4: Relax Clang 18/19 Werror aborts on legacy display HAL
sed -i "s/-Werror//g" hardware/qcom-caf/sdm660/display/Android.bp 2>/dev/null || true
echo "    [OK] Relaxed display HAL -Werror flags"

# ------------------------------------------------------------------------------
# PHASE 6: CCACHE CONFIGURATION
# ------------------------------------------------------------------------------
echo "--> [6/8] Configuring CCACHE..."
CCACHE_BIN=""
if command -v ccache &>/dev/null; then
    CCACHE_BIN="$(command -v ccache)"
elif [ -x "prebuilts/misc/linux-x86/ccache/ccache" ]; then
    CCACHE_BIN="$(pwd)/prebuilts/misc/linux-x86/ccache/ccache"
fi

if [ -n "$CCACHE_BIN" ]; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$CCACHE_BIN"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_BIN" -M 50G 2>/dev/null || true
    "$CCACHE_BIN" -o compression=true 2>/dev/null || true
    echo "    [OK] CCACHE active: 50GB cache"
else
    echo "    [INFO] CCACHE not found; compiling without cache."
    unset USE_CCACHE
    unset CCACHE_EXEC
fi

# ------------------------------------------------------------------------------
# PHASE 7: ENVIRONMENT SETUP, LUNCH TARGET & COMPILATION
# ------------------------------------------------------------------------------
echo "--> [7/8] Sourcing build environment & selecting lunch target..."
source build/envsetup.sh

# Select appropriate LineageOS 23.2 lunch target
if lunch lineage_PL2-ap4a-userdebug 2>/dev/null; then
    echo "    [OK] Target selected: lineage_PL2-ap4a-userdebug"
elif lunch lineage_PL2-bp1a-userdebug 2>/dev/null; then
    echo "    [OK] Target selected: lineage_PL2-bp1a-userdebug"
elif lunch lineage_PL2-userdebug 2>/dev/null; then
    echo "    [OK] Target selected: lineage_PL2-userdebug"
else
    echo "    [FALLBACK] Using brunch PL2..."
    brunch PL2
    exit 0
fi

echo "--> Cleaning stale intermediate build artifacts (installclean)..."
make installclean

echo "--> Launching parallel compilation..."
mka bacon -j$(nproc --all) 2>&1 | tee build_a16_PL2.log

# ------------------------------------------------------------------------------
# PHASE 8: ARTIFACT RETRIEVAL & CLOUD EXPORT
# ------------------------------------------------------------------------------
echo "--> [8/8] Verifying build artifacts..."
OUT_ZIP=$(ls out/target/product/PL2/lineage-23.2-*-UNOFFICIAL-PL2.zip 2>/dev/null | head -n 1)

if [ -f "$OUT_ZIP" ]; then
    echo "========================================================================"
    echo " COMPILATION SUCCEEDED!"
    echo " Output ROM: $OUT_ZIP"
    echo " File Size:  $(du -h "$OUT_ZIP" | cut -f1)"
    echo " MD5:        $(md5sum "$OUT_ZIP")"
    echo "========================================================================"
    echo "Uploading to BashUpload for instant high-speed download..."
    curl -s bashupload.com -T "$OUT_ZIP" || true
    echo ""
    if [ -f "out/target/product/PL2/boot.img" ]; then
        echo "Uploading boot.img (Fastboot Recovery)..."
        curl -s bashupload.com -T "out/target/product/PL2/boot.img" || true
        echo ""
    fi
else
    echo "========================================================================"
    echo " BUILD COMPLETED (Checking output files in out/target/product/PL2/):"
    ls -lh out/target/product/PL2/*.zip 2>/dev/null || echo "No zip produced yet. Check build_a16_PL2.log for errors."
    echo "========================================================================"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Script finished in $((ELAPSED / 60)) minutes and $((ELAPSED % 60)) seconds ==="
