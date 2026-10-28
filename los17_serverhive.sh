#!/bin/bash
set -e

# ==============================================================================
# Nokia 6.1 (PL2 / TA-1089) LineageOS 17.1 (Android 10 Q) ServerHive Build Script
# ==============================================================================
echo "=== Starting Nokia 6.1 (PL2) LineageOS 17.1 ServerHive Build ==="

# ------------------------------------------------------------------------------
# 1. Host Sudo Helper & Legacy Libraries (ncurses5 / tinfo5 for A10 host tools)
# ------------------------------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    fi
fi

if [ ! -f /usr/lib/x86_64-linux-gnu/libncurses.so.5 ] || [ ! -f /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ]; then
    echo "--> Checking/installing legacy libncurses5 & libtinfo5 dependencies..."
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -qq 2>/dev/null || true
        $SUDO apt-get install -y -qq libncurses5 libtinfo5 2>/dev/null || {
            echo "--> Pulling ncurses5 deb packages from archive..."
            P="http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses"
            T=$(curl -sL "$P/" | grep -oE 'libtinfo5_[^"<> ]+_amd64\.deb' | sort -V | tail -1)
            N=$(curl -sL "$P/" | grep -oE 'libncurses5_[^"<> ]+_amd64\.deb' | sort -V | tail -1)
            if [ -n "$T" ] && [ -n "$N" ]; then
                wget -q "$P/$T" -O /tmp/tinfo.deb && \
                wget -q "$P/$N" -O /tmp/ncurses.deb && \
                $SUDO apt-get install -y /tmp/tinfo.deb /tmp/ncurses.deb && \
                rm -f /tmp/tinfo.deb /tmp/ncurses.deb || true
            fi
        }
    fi
fi

# ------------------------------------------------------------------------------
# 2. Repo Tool Bootstrap (if not already installed)
# ------------------------------------------------------------------------------
if ! command -v repo >/dev/null 2>&1; then
    echo "--> Installing repo tool..."
    mkdir -p "$HOME/bin"
    curl -sL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
    chmod a+rx "$HOME/bin/repo"
    export PATH="$HOME/bin:$PATH"
fi

# ------------------------------------------------------------------------------
# 3. Environment Flags
# ------------------------------------------------------------------------------
export ALLOW_MISSING_DEPENDENCIES=true
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export SELINUX_IGNORE_NEVERALLOWS=true
export BUILD_USERNAME=Zoro-15
export BUILD_HOSTNAME=serverhive

# ------------------------------------------------------------------------------
# 4. Manifest Initialization & Local Manifest Setup
# ------------------------------------------------------------------------------
rm -rf .repo/local_manifests .repo/local_manifest.xml .repo/manifest.xml .repo/manifests .repo/manifests.git

echo "--> Initializing LineageOS 17.1 manifest..."
repo init -u https://github.com/LineageOS-Revived/android.git -b lineage-17.1 --git-lfs --depth=1

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/nokia.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="zoro" fetch="https://github.com/Zoro-15" revision="lineage-17.1"/>

  <project path="device/nokia/PL2" name="android_device_nokia_PL2" remote="zoro"/>
  <project path="device/nokia/sdm660-common" name="android_device_nokia_sdm660-common" remote="zoro"/>
  <project path="kernel/nokia/sdm660" name="android_kernel_nokia_sdm660" remote="zoro"/>
  <project path="vendor/nokia" name="proprietary_vendor_nokia" remote="zoro"/>
</manifest>
XML

# ------------------------------------------------------------------------------
# 5. Normal Repo Sync (capped to 16 jobs to avoid GitHub rate-limiting/bans)
# ------------------------------------------------------------------------------
SYNC_JOBS=$(nproc --all 2>/dev/null || echo 8)
[ "$SYNC_JOBS" -gt 16 ] && SYNC_JOBS=16
echo "--> Running repo sync (-j${SYNC_JOBS})..."
repo sync -c -j"${SYNC_JOBS}" --force-sync --no-clone-bundle --no-tags

# ------------------------------------------------------------------------------
# 6. Hardware Firmware Check (TAS2557 SmartAmp DSP)
# ------------------------------------------------------------------------------
FIRMWARE_TARGET="vendor/nokia/sdm660-common/proprietary/vendor/firmware/TAS2557MSSMono.bin"
if [ ! -f "$FIRMWARE_TARGET" ] && [ -f "device/nokia/PL2/TAS2557MSSMono.bin" ]; then
    echo "--> Copying TAS2557 SmartAmp DSP firmware..."
    mkdir -p "$(dirname "$FIRMWARE_TARGET")"
    cp device/nokia/PL2/TAS2557MSSMono.bin "$FIRMWARE_TARGET"
fi

# ------------------------------------------------------------------------------
# 6.5. Status Bar Battery & Icon Spacing Patches
# ------------------------------------------------------------------------------
if [ -f "device/nokia/PL2/patches/apply_battery_patch.sh" ]; then
    echo "--> Applying Status Bar Battery & Icon Spacing patches to frameworks/base..."
    sed -i 's/\r$//' device/nokia/PL2/patches/apply_battery_patch.sh 2>/dev/null || true
    sed -i 's/\r$//' device/nokia/PL2/patches/*.patch 2>/dev/null || true
    bash device/nokia/PL2/patches/apply_battery_patch.sh . || true
fi

# ------------------------------------------------------------------------------
# 7. Ccache Setup
# ------------------------------------------------------------------------------
export USE_CCACHE=1
export CCACHE_EXEC="$(command -v ccache 2>/dev/null || echo "$PWD/prebuilts/misc/linux-x86/ccache/ccache")"
export CCACHE_DIR="$HOME/.ccache"
if [ -x "$CCACHE_EXEC" ]; then
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 8. Build Environment & Compilation
# ------------------------------------------------------------------------------
set +e
source build/envsetup.sh
set -e

lunch lineage_PL2-userdebug
mka bacon -j$(nproc --all)

# ------------------------------------------------------------------------------
# 9. Completion Summary
# ------------------------------------------------------------------------------
echo "========================================================"
echo "--> LineageOS 17.1 Build Completed Successfully!"
echo "========================================================"
PRODUCT_OUT="$PWD/out/target/product/PL2"
if [ -d "$PRODUCT_OUT" ]; then
    echo "Output files:"
    ls -lh "$PRODUCT_OUT"/*.zip 2>/dev/null || true
fi
echo "========================================================"
