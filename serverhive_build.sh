#!/bin/bash
set -e

START_TIME=$(date +%s)
echo "=== Starting LineageOS 23.2 (Android 16) Build for Nokia 6.1 (PL2) on ServerHive ==="

# 1. Clean Stale Shell Environment
unset WITHOUT_CHECK_API
unset BUILD_FROM_SOURCE_STUB

# 2. CCACHE Configuration
if command -v ccache &>/dev/null; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(command -v ccache)"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_EXEC" -M 75G 2>/dev/null || true
    "$CCACHE_EXEC" -o compression=true 2>/dev/null || true
fi

# 3. Clean Corrupted Ninja Graphs, Cached Environment, & Stale Intermediates
echo "--> Cleaning stale build graphs and cached environments..."
rm -rf out/.module_paths out/*.ninja out/soong/*.ninja out/soong/build.* out/soong/.ninja* out/.ninja*
rm -rf out/soong/soong.environment.* out/soong/soong.*.variables out/soong/soong.variables
rm -rf out/soong/Android-*.mk out/soong/installs-*.mk out/soong/system_server_dexjars
rm -rf out/soong/.intermediates/tools/metalava \
       out/soong/.intermediates/frameworks/base/api \
       out/soong/.intermediates/frameworks/base/libs/hwui \
       out/soong/.intermediates/system/sepolicy \
       out/soong/.intermediates/hardware/qcom-caf/sdm660 \
       out/soong/.intermediates/vendor/qcom/opensource/display \
       out/soong/.intermediates/vendor/nokia/sdm660-common \
       out/soong/.intermediates/vendor/nokia/PL2 \
       out/target/product/PL2/system/product/etc/build-manifest.xml

# 4. Ensure Repositories for libqdMetaData and Vendor Blobs
if [ -d "tools/metalava/.git" ]; then
    echo "--> Updating tools/metalava..."
    git -C tools/metalava fetch --all 2>/dev/null || true
    git -C tools/metalava checkout -B lineage-23.2 github/lineage-23.2 2>/dev/null || \
    git -C tools/metalava checkout -B lineage-23.2 origin/lineage-23.2 2>/dev/null || true
fi

if [ -d "hardware/qcom-caf/sdm660/display" ]; then
    echo "--> Updating hardware/qcom-caf/sdm660/display..."
    git -C hardware/qcom-caf/sdm660/display fetch --all 2>/dev/null || true
    git -C hardware/qcom-caf/sdm660/display checkout -B lineage-23.2-caf-msm8953 github/lineage-23.2-caf-msm8953 2>/dev/null || \
    git -C hardware/qcom-caf/sdm660/display checkout -B lineage-23.2-caf-msm8953 origin/lineage-23.2-caf-msm8953 2>/dev/null || true
fi

if [ -d "device/nokia/sdm660-common/.git" ]; then
    echo "--> Updating device/nokia/sdm660-common..."
    git -C device/nokia/sdm660-common fetch --all 2>/dev/null || true
    git -C device/nokia/sdm660-common checkout -B lineage-23.2 github/lineage-23.2 2>/dev/null || \
    git -C device/nokia/sdm660-common checkout -B lineage-23.2 origin/lineage-23.2 2>/dev/null || true
fi

if [ -d "vendor/nokia/PL2/.git" ]; then
    echo "--> Updating vendor/nokia/PL2..."
    git -C vendor/nokia/PL2 fetch --all 2>/dev/null || true
    git -C vendor/nokia/PL2 checkout -B lineage-23.2 github/lineage-23.2 2>/dev/null || \
    git -C vendor/nokia/PL2 checkout -B lineage-23.2 origin/lineage-23.2 2>/dev/null || true
fi

if [ ! -d "vendor/qcom/opensource/commonsys-intf/display" ]; then
    echo "--> Cloning vendor/qcom/opensource/commonsys-intf/display..."
    git clone --depth=1 -b lineage-23.2 https://github.com/LineageOS/android_vendor_qcom_opensource_display-commonsys-intf.git vendor/qcom/opensource/commonsys-intf/display
else
    git -C vendor/qcom/opensource/commonsys-intf/display checkout -- . 2>/dev/null || true
fi

# 5. Ensure Hardware CAF Soong Namespaces & Repo Worktrees
# Restore missing repo worktrees so build-manifest generation succeeds
if [ ! -d "hardware/qcom-caf/sm8450/audio/primary-hal" ]; then
    echo "--> Restoring missing repo worktrees for manifest generation..."
    repo sync -l -d hardware/qcom-caf/sm8450/audio/primary-hal 2>/dev/null || true
fi

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

# 6. Environment & Lunch Selection
source build/envsetup.sh
echo "--> Selecting lunch target..."
if lunch lineage_PL2-bp4a-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-bp4a-userdebug"
elif lunch lineage_PL2-bp1a-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-bp1a-userdebug"
elif lunch lineage_PL2-trunk_staging-userdebug 2>/dev/null; then
    echo "--> Selected lunch target: lineage_PL2-trunk_staging-userdebug"
else
    echo "--> Selecting legacy lunch target: lineage_PL2-userdebug"
    lunch lineage_PL2-userdebug || { echo "[FATAL] Lunch failed!"; exit 1; }
fi

# 7. Direct Compilation
echo "--> Compiling LineageOS 23.2 with all $(nproc --all) cores..."
mka bacon -k -j$(nproc --all) 2>&1 | tee build_a16_PL2.log
BUILD_STATUS=${PIPESTATUS[0]}

# 8. Output Artifact Handling & Cloud Upload
OUT_ZIP=$(ls out/target/product/PL2/lineage-23.2-*-UNOFFICIAL-PL2.zip 2>/dev/null | head -n 1 || true)
if [ -n "$OUT_ZIP" ] && [ -f "$OUT_ZIP" ]; then
    echo "=== COMPILATION SUCCEEDED: $OUT_ZIP ==="
    md5sum "$OUT_ZIP"
    echo "Uploading ROM to BashUpload..."
    curl -fL --retry 3 https://bashupload.com/ -T "$OUT_ZIP" || true
    echo ""
    if [ -f "out/target/product/PL2/boot.img" ]; then
        echo "Uploading boot.img to BashUpload..."
        curl -fL --retry 3 https://bashupload.com/ -T "out/target/product/PL2/boot.img" || true
        echo ""
    fi
else
    echo "=== BUILD FAILED (Status: $BUILD_STATUS) ==="
    if [ -f "build_a16_PL2.log" ]; then
        echo "Uploading build log to BashUpload..."
        curl -fL --retry 3 https://bashupload.com/ -T "build_a16_PL2.log" || true
        echo ""
    fi
    exit $BUILD_STATUS
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Build finished in $((ELAPSED / 60))m $((ELAPSED % 60))s ==="
