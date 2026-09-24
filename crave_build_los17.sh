#!/bin/bash
set -e

# ========================================================
# PHASE 1: EXECUTION & MEMORY GUARDS
# ========================================================
START_TIME=$(date +%s)
echo "=== Starting Nokia 6.1 (PL2) LineageOS-Revived 17.1 Build ==="

export GOMEMLIMIT=8GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx6g"
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true

# ========================================================
# PHASE 2: PRE-FLIGHT CLEANUP (PREVENT DIRTY CONFLICTS)
# ========================================================
echo "--> Cleaning stale manifests and device trees..."
rm -rf .repo/local_manifests/
rm -rf device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia

# ========================================================
# PHASE 3: BASE ROM INITIALIZATION & RESYNC
# ========================================================
echo "--> Initializing LineageOS-Revived 17.1 manifest..."
repo init -u https://github.com/LineageOS-Revived/android.git -b lineage-17.1 --git-lfs --depth=1

if [ -f "/opt/crave/resync.sh" ]; then
    echo "--> Running Crave accelerated resync..."
    /opt/crave/resync.sh
fi

echo "--> Finalizing sync with dirty protections..."
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle -j$(nproc --all)

# ========================================================
# PHASE 4: CLONING NOKIA 6.1 (PL2) SOURCE TREES (ZORO-15)
# ========================================================
echo "--> Fetching Nokia 6.1 (PL2) trees from Zoro-15..."
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_kernel_nokia_sdm660.git kernel/nokia/sdm660
git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/proprietary_vendor_nokia.git vendor/nokia

# ========================================================
# PHASE 5: HARDWARE INTEGRITY CHECKS (SMARTAMP & FIRMWARE)
# ========================================================
echo "--> Verifying TAS2557 SmartAmp DSP firmware..."
FIRMWARE_TARGET="vendor/nokia/sdm660-common/proprietary/vendor/firmware/TAS2557MSSMono.bin"
if [ ! -f "$FIRMWARE_TARGET" ]; then
    echo "Staging TAS2557MSSMono.bin into vendor tree..."
    mkdir -p "$(dirname "$FIRMWARE_TARGET")"
    if [ -f "device/nokia/PL2/TAS2557MSSMono.bin" ]; then
        cp device/nokia/PL2/TAS2557MSSMono.bin "$FIRMWARE_TARGET"
    fi
fi

# ========================================================
# PHASE 6: CCACHE, LUNCH & COMPILATION
# ========================================================
CCACHE_BIN=""
if command -v ccache &>/dev/null; then
    CCACHE_BIN="$(command -v ccache)"
elif [ -x "prebuilts/misc/linux-x86/ccache/ccache" ]; then
    CCACHE_BIN="$(pwd)/prebuilts/misc/linux-x86/ccache/ccache"
fi

if [ -n "$CCACHE_BIN" ]; then
    echo "--> Configuring CCACHE using $CCACHE_BIN..."
    export USE_CCACHE=1
    export CCACHE_EXEC="$CCACHE_BIN"
    export CCACHE_DIR="${HOME}/.ccache"
    "$CCACHE_BIN" -M 50G 2>/dev/null || true
    "$CCACHE_BIN" -o compression=true 2>/dev/null || true
else
    echo "--> ccache binary not found in container or prebuilts; proceeding without ccache."
    unset USE_CCACHE
    unset CCACHE_EXEC
fi

source build/envsetup.sh
lunch lineage_PL2-userdebug

echo "--> Cleaning stale intermediates (installclean)..."
make installclean

echo "--> Compiling LineageOS-Revived 17.1 flashable zip..."
mka bacon -j$(nproc --all)

# ========================================================
# PHASE 7: AUTOMATIC ARTIFACT UPLOAD (SAFEGUARD FOR EXPIRING DEVSPACES)
# ========================================================
OUT_ZIP=$(ls out/target/product/PL2/lineage-17.1-*.zip 2>/dev/null | head -n 1)
if [ -f "$OUT_ZIP" ]; then
    echo "========================================================"
    echo "BUILD SUCCEEDED: $OUT_ZIP"
    echo "File Size: $(du -h "$OUT_ZIP" | cut -f1)"
    echo "Uploading to BashUpload (Download link is logged below)..."
    curl -s bashupload.com -T "$OUT_ZIP"
    echo ""
    echo "MD5 Checksum:"
    md5sum "$OUT_ZIP"
    echo "========================================================"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Build Finished in $((ELAPSED / 60)) minutes! ==="