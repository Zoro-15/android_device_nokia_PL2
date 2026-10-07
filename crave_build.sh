#!/bin/bash
set -e

START_TIME=$(date +%s)
echo "=== Starting LineageOS 23.2 (Android 16) Build for Nokia 6.1 (PL2) ==="

# Environment & Memory Guards
echo "--> Configuring build environment..."
export GOMEMLIMIT=12GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx8g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export DISABLE_DEXPREOPT_CHECK=true
unset WITHOUT_CHECK_API
export WITHOUT_CHECK_API=false
unset SKIP_ABI_CHECKS

# Pre-flight tree cleanup
echo "--> Cleaning stale device trees and manifests..."
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common
rm -rf vendor/nokia/PL2 vendor/nokia/sdm660-common
rm -rf kernel/nokia/sdm660
rm -rf hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
rm -rf device/qcom/sepolicy-legacy-um hardware/lineage/compat

# Manifest initialization & Local manifest deployment
echo "--> Initializing LineageOS 23.2 base manifest..."
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

echo "--> Deploying PL2 local manifest..."
mkdir -p .repo/local_manifests
cat << "EOF" > .repo/local_manifests/PL2.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remove-project name="LineageOS/android_hardware_qcom_audio" />
  <remove-project name="LineageOS/android_hardware_qcom_display" />
  <remove-project name="LineageOS/android_hardware_qcom_media" />
  <remove-project name="LineageOS/android_device_qcom_sepolicy" />
  <remove-project name="LineageOS/android_hardware_lineage_compat" />

  <project path="device/nokia/sdm660-common" name="Zoro-15/android_device_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="device/nokia/PL2" name="Zoro-15/android_device_nokia_PL2" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/sdm660-common" name="Zoro-15/proprietary_vendor_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/PL2" name="Zoro-15/proprietary_vendor_nokia_PL2" remote="github" revision="lineage-23.2" />
  <project path="kernel/nokia/sdm660" name="Zoro-15/android_kernel_nokia_PL2_16" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/audio" name="Zoro-15/android_hardware_qcom_audio" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/display" name="Zoro-15/android_hardware_qcom_display" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="hardware/qcom-caf/sdm660/media" name="Zoro-15/android_hardware_qcom_media" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="device/qcom/sepolicy-legacy-um" name="Zoro-15/android_device_qcom_sepolicy" remote="github" revision="lineage-23.2" />
  <project path="hardware/lineage/compat" name="log1cs/android_hardware_lineage_compat" remote="github" revision="lineage-23.2" />
</manifest>
EOF

# Sync repositories
echo "--> Syncing source repositories..."
set +e
if [ -f "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
else
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --force-remove-dirty
fi
set -e

# Fallback clones
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

# Soong namespaces
mkdir -p hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
[ ! -f "hardware/qcom-caf/sdm660/Android.bp" ] && echo "soong_namespace {}" > hardware/qcom-caf/sdm660/Android.bp
[ ! -f "hardware/qcom-caf/msm8998/Android.bp" ] && echo "soong_namespace {}" > hardware/qcom-caf/msm8998/Android.bp

# CCACHE setup
if command -v ccache &>/dev/null; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(command -v ccache)"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
    "$CCACHE_EXEC" -o compression=true 2>/dev/null || true
elif [ -x "prebuilts/misc/linux-x86/ccache/ccache" ]; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(pwd)/prebuilts/misc/linux-x86/ccache/ccache"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
    "$CCACHE_EXEC" -o compression=true 2>/dev/null || true
fi

# Environment & Lunch
source build/envsetup.sh
if lunch lineage_PL2-ap4a-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-ap4a-userdebug"
elif lunch lineage_PL2-bp1a-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-bp1a-userdebug"
elif lunch lineage_PL2-userdebug; then
    echo "--> Selected lunch target: lineage_PL2-userdebug"
else
    echo "--> Lunch failed!"
    exit 1
fi

# Verify Soong analysis & clean target outputs
echo "--> Verifying Soong analysis..."
m nothing -j$(nproc --all)
make installclean

# Compilation
echo "--> Compiling LineageOS 23.2..."
mka bacon -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
BUILD_STATUS=${PIPESTATUS[0]}
if [ $BUILD_STATUS -ne 0 ]; then
    echo "[FATAL] Compilation failed with exit code $BUILD_STATUS"
fi

# Artifact verification & upload
OUT_ZIP=$(ls out/target/product/PL2/lineage-23.2-*-UNOFFICIAL-PL2.zip 2>/dev/null | head -n 1 || true)
if [ -n "$OUT_ZIP" ] && [ -f "$OUT_ZIP" ]; then
    echo "=== COMPILATION SUCCEEDED: $OUT_ZIP ==="
    md5sum "$OUT_ZIP"
    echo "Uploading to BashUpload..."
    curl -fL --retry 3 https://bashupload.com/ -T "$OUT_ZIP" || echo "ROM upload failed"
    echo ""
    if [ -f "out/target/product/PL2/boot.img" ]; then
        echo "Uploading boot.img..."
        curl -fL --retry 3 https://bashupload.com/ -T "out/target/product/PL2/boot.img" || echo "boot.img upload failed"
        echo ""
    fi
else
    echo "=== BUILD FAILED ==="
    ls -lh out/target/product/PL2/*.zip 2>/dev/null || echo "No ROM zip found."
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Finished in $((ELAPSED / 60))m $((ELAPSED % 60))s ==="
