#!/bin/bash
set -e

START_TIME=$(date +%s)
echo "=== Starting LineageOS 23.2 (Android 16) Build for Nokia 6.1 (PL2) on ServerHive ==="

# 1. Environment & Performance Tuning
echo "--> Configuring build environment for bare-metal host..."
export GOMEMLIMIT=32GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx16g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export DISABLE_DEXPREOPT_CHECK=true
export WITH_DEXPREOPT=false
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export SELINUX_IGNORE_NEVERALLOWS=true
export SEPOLICY_IGNORE_NEVERALLOWS=true

# CCACHE setup for bare-metal
if command -v ccache &>/dev/null; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(command -v ccache)"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_EXEC" -M 75G 2>/dev/null || true
    "$CCACHE_EXEC" -o compression=true 2>/dev/null || true
fi

# 2. Base Manifest Initialization
echo "--> Initializing LineageOS 23.2 base manifest..."
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

# 3. Local Manifest Deployment
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
  <remove-project name="LineageOS/android_frameworks_native" />
  <remove-project name="LineageOS/android_system_sepolicy" />
  <remove-project name="platform/external/kotlinx.serialization" />
  <remove-project name="platform/tools/metalava" />

  <project path="device/nokia/sdm660-common" name="Zoro-15/android_device_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="device/nokia/PL2" name="Zoro-15/android_device_nokia_PL2" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/sdm660-common" name="Zoro-15/proprietary_vendor_nokia_sdm660-common" remote="github" revision="lineage-23.2" />
  <project path="vendor/nokia/PL2" name="Zoro-15/proprietary_vendor_nokia_PL2" remote="github" revision="lineage-23.2" />
  <project path="kernel/nokia/sdm660" name="Zoro-15/android_kernel_nokia_PL2_16" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/audio" name="Zoro-15/android_hardware_qcom_audio" remote="github" revision="lineage-23.2" />
  <project path="hardware/qcom-caf/sdm660/display" name="Zoro-15/android_hardware_qcom_display" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="hardware/qcom-caf/sdm660/media" name="Zoro-15/android_hardware_qcom_media" remote="github" revision="lineage-23.2-caf-msm8953" />
  <project path="device/qcom/sepolicy-legacy-um" name="Zoro-15/android_device_qcom_sepolicy" remote="github" revision="lineage-23.2" />
  <project path="hardware/lineage/compat" name="Zoro-15/android_hardware_lineage_compat" remote="github" revision="lineage-23.2" />
  <project path="frameworks/native" name="Zoro-15/android_frameworks_native" remote="github" revision="lineage-23.2" />
  <project path="system/sepolicy" name="Zoro-15/android_system_sepolicy" remote="github" revision="lineage-23.2" />
  <project path="external/kotlinx.serialization" name="Zoro-15/android_external_kotlinx.serialization" remote="github" revision="lineage-23.2" />
  <project path="tools/metalava" name="Zoro-15/android_tools_metalava" remote="github" revision="lineage-23.2" />
</manifest>
EOF

# Clean broken Windows-copied git cookie configuration if present
if git config --global --get http.cookiefile 2>/dev/null | grep -qi "USERPROFILE"; then
    echo "--> Clearing invalid Windows cookiefile from Linux git config..."
    git config --global --unset http.cookiefile || true
fi

# 4. Sync Repositories
echo "--> Aborting any stuck rebases across tree before sync..."
for d in "kernel/nokia/sdm660" "vendor/nokia/PL2" "device/nokia/PL2" "device/nokia/sdm660-common" "vendor/nokia/sdm660-common" "tools/metalava"; do
    if [ -d "$d/.git" ]; then
        git -C "$d" rebase --abort 2>/dev/null || true
        git -C "$d" merge --abort 2>/dev/null || true
    fi
done

echo "--> Syncing source repositories (ServerHive optimized flags)..."
set +e
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
set -e

# 5. Fallback Clones & Fast Updates (Guarantees all 15 repositories exist & are up to date)
echo "--> Verifying and updating custom repository checkouts..."
REPOS_TO_SYNC=(
    "device/nokia/sdm660-common:lineage-23.2"
    "device/nokia/PL2:lineage-23.2"
    "vendor/nokia/sdm660-common:lineage-23.2"
    "vendor/nokia/PL2:lineage-23.2"
    "kernel/nokia/sdm660:lineage-23.2"
    "hardware/qcom-caf/sdm660/audio:lineage-23.2"
    "hardware/qcom-caf/sdm660/display:lineage-23.2-caf-msm8953"
    "hardware/qcom-caf/sdm660/media:lineage-23.2-caf-msm8953"
    "device/qcom/sepolicy-legacy-um:lineage-23.2"
    "hardware/lineage/compat:lineage-23.2"
    "frameworks/native:lineage-23.2"
    "system/sepolicy:lineage-23.2"
    "external/kotlinx.serialization:lineage-23.2"
    "tools/metalava:lineage-23.2"
)
for entry in "${REPOS_TO_SYNC[@]}"; do
    r="${entry%%:*}"
    target_branch="${entry##*:}"
    if [ -d "$r/.git" ]; then
        git -C "$r" rebase --abort 2>/dev/null || true
        git -C "$r" merge --abort 2>/dev/null || true
        REMOTE_NAME=$(git -C "$r" remote 2>/dev/null | head -n 1)
        if [ -n "$REMOTE_NAME" ]; then
            echo "--> Syncing $r to $REMOTE_NAME/$target_branch..."
            git -C "$r" fetch "$REMOTE_NAME" "$target_branch" --depth=1 2>/dev/null || true
            git -C "$r" reset --hard "FETCH_HEAD" 2>/dev/null || true
        fi
    fi
done

[ ! -d "device/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
[ ! -d "device/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
[ ! -d "vendor/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_sdm660-common.git vendor/nokia/sdm660-common
[ ! -d "vendor/nokia/PL2" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/proprietary_vendor_nokia_PL2.git vendor/nokia/PL2
[ ! -d "kernel/nokia/sdm660" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_kernel_nokia_PL2_16.git kernel/nokia/sdm660
[ ! -d "hardware/qcom-caf/sdm660/audio" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_hardware_qcom_audio.git hardware/qcom-caf/sdm660/audio
[ ! -d "hardware/qcom-caf/sdm660/display" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_display.git hardware/qcom-caf/sdm660/display
[ ! -d "hardware/qcom-caf/sdm660/media" ] && git clone --depth=1 -b lineage-23.2-caf-msm8953 https://github.com/Zoro-15/android_hardware_qcom_media.git hardware/qcom-caf/sdm660/media
[ ! -d "device/qcom/sepolicy-legacy-um" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_device_qcom_sepolicy.git device/qcom/sepolicy-legacy-um
[ ! -d "hardware/lineage/compat" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_hardware_lineage_compat.git hardware/lineage/compat
[ ! -d "frameworks/native" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_frameworks_native.git frameworks/native
[ ! -d "system/sepolicy" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_system_sepolicy.git system/sepolicy
[ ! -d "external/kotlinx.serialization" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_external_kotlinx.serialization.git external/kotlinx.serialization
[ ! -d "tools/metalava" ] && git clone --depth=1 -b lineage-23.2 https://github.com/Zoro-15/android_tools_metalava.git tools/metalava
[ ! -d "vendor/qcom/opensource/display" ] && git clone --depth=1 -b lineage-23.2 https://github.com/LineageOS/android_vendor_qcom_opensource_display.git vendor/qcom/opensource/display
[ ! -d "vendor/qcom/opensource/commonsys-intf/display" ] && git clone --depth=1 -b lineage-23.2 https://github.com/LineageOS/android_vendor_qcom_opensource_display-commonsys-intf.git vendor/qcom/opensource/commonsys-intf/display

# 6. Ensure Dummy Soong Namespaces
mkdir -p hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
cat << "EOF" > hardware/qcom-caf/sdm660/Android.bp
soong_namespace {
    imports: [
        "vendor/qcom/opensource/display",
        "vendor/qcom/opensource/commonsys-intf/display",
        "vendor/nokia/sdm660-common",
    ],
}
EOF
echo "soong_namespace {}" > hardware/qcom-caf/msm8998/Android.bp

# 7. Environment & Lunch Target Selection
rm -f .repo/local_manifests/roomservice.xml
source build/envsetup.sh

LUNCH_TARGET=""
for candidate in "lineage_PL2-bp4a-userdebug" "lineage_PL2-bp1a-userdebug" "lineage_PL2-trunk_staging-userdebug" "lineage_PL2-ap4a-userdebug"; do
    echo "--> Probing lunch target: $candidate..."
    if lunch "$candidate" 2>/dev/null; then
        LUNCH_TARGET="$candidate"
        echo "--> Successfully selected: $LUNCH_TARGET"
        break
    fi
done

if [ -z "$LUNCH_TARGET" ]; then
    echo "--> Falling back to legacy lunch..."
    lunch lineage_PL2-userdebug || { echo "[FATAL] Lunch failed!"; exit 1; }
fi

# 8. Clean Stale Intermediate Targets & Verify Soong Analysis
echo "--> Purging corrupted/stale Ninja graphs and intermediate targets..."
rm -rf out/*.ninja out/soong/*.ninja out/soong/build.* out/soong/Android-*.mk out/soong/installs-*.mk out/soong/system_server_dexjars out/soong/.ninja_deps out/soong/.ninja_log
rm -rf out/soong/.intermediates/tools/metalava \
       out/soong/.intermediates/frameworks/base/api \
       out/soong/.intermediates/system/sepolicy \
       out/soong/.intermediates/hardware/qcom-caf/sdm660

echo "--> Verifying Blueprint/Soong graph analysis..."
m nothing -j$(nproc --all)

# 9. Full ROM Compilation
echo "--> Compiling LineageOS 23.2 with all $(nproc --all) cores..."
mka bacon -k -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
BUILD_STATUS=${PIPESTATUS[0]}
if [ $BUILD_STATUS -ne 0 ]; then
    echo "[FATAL] Compilation failed with exit code $BUILD_STATUS"
fi

# 10. Artifact Verification & Cloud Deployment
OUT_ZIP=$(ls out/target/product/PL2/lineage-23.2-*-UNOFFICIAL-PL2.zip 2>/dev/null | head -n 1 || true)
if [ -n "$OUT_ZIP" ] && [ -f "$OUT_ZIP" ]; then
    echo "=== COMPILATION SUCCEEDED: $OUT_ZIP ==="
    md5sum "$OUT_ZIP"
    echo "Uploading ROM to BashUpload..."
    curl -fL --retry 3 https://bashupload.com/ -T "$OUT_ZIP" || echo "ROM upload failed"
    echo ""
    if [ -f "out/target/product/PL2/boot.img" ]; then
        echo "Uploading boot.img to BashUpload..."
        curl -fL --retry 3 https://bashupload.com/ -T "out/target/product/PL2/boot.img" || echo "boot.img upload failed"
        echo ""
    fi
else
    echo "=== BUILD FAILED ==="
    ls -lh out/target/product/PL2/*.zip 2>/dev/null || echo "No ROM zip found."
    if [ -f "build_a16_PL2.log" ]; then
        echo "Uploading full build log to BashUpload..."
        curl -fL --retry 3 https://bashupload.com/ -T "build_a16_PL2.log" || true
        echo ""
    fi
    exit 1
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Build finished in $((ELAPSED / 60))m $((ELAPSED % 60))s ==="
