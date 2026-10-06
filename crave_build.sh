#!/bin/bash
# ==============================================================================
# LineageOS 23.2 (Android 16 / Baklava) Cloud Build Script for Nokia 6.1 (PL2)
# Optimized for Crave.io Devspace Execution (Project ID: 85)
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
# PHASE 1: EXECUTION & MEMORY GUARDS (ANDROID 16 COMPLIANT)
# ------------------------------------------------------------------------------
echo "--> [1/7] Configuring runtime environment and memory guards..."
export GOMEMLIMIT=12GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx8g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true

# CRITICAL FOR ANDROID 16:
# Never export SKIP_ABI_CHECKS=true or WITHOUT_CHECK_API=true.
# In AOSP/LineageOS makefiles, SKIP_ABI_CHECKS=true re-derives WITHOUT_CHECK_API=true,
# which breaks Soong stub generation from signature files (libcore/openjdk_java_files.bp).
unset WITHOUT_CHECK_API
export WITHOUT_CHECK_API=false
unset SKIP_ABI_CHECKS

# ------------------------------------------------------------------------------
# PHASE 2: PRE-FLIGHT CLEANUP (CRAVE SAFE - NEVER TOUCH PREBUILTS OR SOONG CACHE)
# ------------------------------------------------------------------------------
echo "--> [2/7] Cleaning stale device trees and local manifests..."
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common
rm -rf vendor/nokia/PL2 vendor/nokia/sdm660-common
rm -rf kernel/nokia/sdm660
rm -rf hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
rm -rf device/qcom/sepolicy-legacy-um hardware/lineage/compat

# ------------------------------------------------------------------------------
# PHASE 3: ROM MANIFEST INITIALIZATION & LOCAL MANIFEST DEPLOYMENT
# ------------------------------------------------------------------------------
echo "--> [3/7] Initializing LineageOS 23.2 base manifest..."
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

echo "--> Deploying local manifest for PL2 (with upstream project removals)..."
mkdir -p .repo/local_manifests
cat << "EOF" > .repo/local_manifests/PL2.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Remove Upstream Base Projects Before Overriding Paths -->
  <remove-project name="LineageOS/android_hardware_qcom_audio" />
  <remove-project name="LineageOS/android_hardware_qcom_display" />
  <remove-project name="LineageOS/android_hardware_qcom_media" />
  <remove-project name="LineageOS/android_device_qcom_sepolicy" />
  <remove-project name="LineageOS/android_hardware_lineage_compat" />

  <!-- Device Trees -->
  <project path="device/nokia/sdm660-common" name="Zoro-15/android_device_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="device/nokia/PL2" name="Zoro-15/android_device_nokia_PL2" remote="github" revision="lineage-23.2" />

  <!-- Vendor Trees -->
  <project path="vendor/nokia/sdm660-common" name="Zoro-15/proprietary_vendor_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
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

# ------------------------------------------------------------------------------
# PHASE 4: REPOSITORY SYNC (ACCELERATED MIRROR / FAILOVER)
# ------------------------------------------------------------------------------
echo "--> [4/7] Syncing source repositories..."
# Disable set -e temporarily so failure-tolerant fallbacks can execute if sync returns non-zero
set +e
if [ -f "/opt/crave/resync.sh" ]; then
    echo "--> Running Crave accelerated resync mirror..."
    /opt/crave/resync.sh
else
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
fi
set -e

# Fallback check: Ensure all 10 repositories exist
[ ! -d "device/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
[ ! -d "device/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
[ ! -d "vendor/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_sdm660-common.git vendor/nokia/sdm660-common
[ ! -d "vendor/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_PL2.git vendor/nokia/PL2
[ ! -d "kernel/nokia/sdm660" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_kernel_nokia_PL2_16.git kernel/nokia/sdm660
[ ! -d "hardware/qcom-caf/sdm660/audio" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_hardware_qcom_audio.git hardware/qcom-caf/sdm660/audio
[ ! -d "hardware/qcom-caf/sdm660/display" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_display.git hardware/qcom-caf/sdm660/display
[ ! -d "hardware/qcom-caf/sdm660/media" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_media.git hardware/qcom-caf/sdm660/media
[ ! -d "device/qcom/sepolicy-legacy-um" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_qcom_sepolicy.git device/qcom/sepolicy-legacy-um
[ ! -d "hardware/lineage/compat" ] && git clone --depth=1 -b lineage-23.2 https://github.com/log1cs/android_hardware_lineage_compat.git hardware/lineage/compat

# ------------------------------------------------------------------------------
# PHASE 5: SOONG NAMESPACE REGISTRATION (SDM660 & MSM8998 SAFEGUARDS)
# ------------------------------------------------------------------------------
echo "--> [5/7] Ensuring Soong namespace roots..."
mkdir -p hardware/qcom-caf/sdm660
if [ ! -f "hardware/qcom-caf/sdm660/Android.bp" ]; then
    echo "soong_namespace {}" > hardware/qcom-caf/sdm660/Android.bp
fi

mkdir -p hardware/qcom-caf/msm8998
if [ ! -f "hardware/qcom-caf/msm8998/Android.bp" ]; then
    echo "soong_namespace {}" > hardware/qcom-caf/msm8998/Android.bp
fi

# ------------------------------------------------------------------------------
# PHASE 6: CCACHE & BUILD ENVIRONMENT
# ------------------------------------------------------------------------------
echo "--> [6/7] Configuring CCACHE and build environment..."
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

source build/envsetup.sh

# Select appropriate LineageOS 23.2 lunch target
if lunch lineage_PL2-ap4a-userdebug 2>/dev/null; then
    echo "    [OK] Target selected: lineage_PL2-ap4a-userdebug"
elif lunch lineage_PL2-bp1a-userdebug 2>/dev/null; then
    echo "    [OK] Target selected: lineage_PL2-bp1a-userdebug"
elif lunch lineage_PL2-userdebug; then
    echo "    [OK] Target selected: lineage_PL2-userdebug"
else
    echo "    [ERROR] lunch failed to select target lineage_PL2."
    exit 1
fi

# Verify Soong analysis / ninja generation prior to full compile
echo "--> [VERIFY] Running Soong analysis check (m nothing)..."
m nothing -j$(nproc --all)

echo "--> [CLEAN] Running make installclean..."
make installclean

# ------------------------------------------------------------------------------
# PHASE 7: COMPILATION & ARTIFACT EXPORT
# ------------------------------------------------------------------------------
echo "--> [7/7] Launching parallel compilation..."
mka bacon -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
BUILD_STATUS=${PIPESTATUS[0]}
if [ $BUILD_STATUS -ne 0 ]; then
    echo "========================================================================"
    echo " [FATAL] mka bacon failed with exit code $BUILD_STATUS"
    echo "========================================================================"
fi

echo "--> Verifying build artifacts..."
OUT_ZIP=$(ls out/target/product/PL2/lineage-23.2-*-UNOFFICIAL-PL2.zip 2>/dev/null | head -n 1 || true)

if [ -n "$OUT_ZIP" ] && [ -f "$OUT_ZIP" ]; then
    echo "========================================================================"
    echo " COMPILATION SUCCEEDED!"
    echo " Output ROM: $OUT_ZIP"
    echo " File Size:  $(du -h "$OUT_ZIP" | cut -f1)"
    echo " MD5:        $(md5sum "$OUT_ZIP")"
    echo "========================================================================"
    echo "Uploading to BashUpload for instant high-speed download..."
    curl -fL --retry 3 https://bashupload.com/ -T "$OUT_ZIP" || echo "ROM zip upload failed"
    echo ""
    if [ -f "out/target/product/PL2/boot.img" ]; then
        echo "Uploading boot.img (Fastboot Recovery)..."
        curl -fL --retry 3 https://bashupload.com/ -T "out/target/product/PL2/boot.img" || echo "boot.img upload failed"
        echo ""
    fi
else
    echo "========================================================================"
    echo " BUILD FAILED (Checking output files in out/target/product/PL2/):"
    ls -lh out/target/product/PL2/*.zip 2>/dev/null || echo "No zip produced. Check build_a16_PL2.log for errors."
    echo "========================================================================"
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Script finished in $((ELAPSED / 60)) minutes and $((ELAPSED % 60)) seconds ==="
