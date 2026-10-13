#!/bin/bash
set -e -x

# ==============================================================================
# Nokia 6.1 (PL2 / TA-1089) ArrowOS 10.0 (Android 10 Q) Crave Build Script
# Hosted in: Zoro-15/android_device_nokia_PL2 (branch: lineage-17.1)
# ==============================================================================
WORKDIR="${CRAVE_WORKDIR:-$PWD}"
mkdir -p "$WORKDIR" 2>/dev/null || true
cd "$WORKDIR"
echo "=== Starting Nokia 6.1 (PL2) ArrowOS 10.0 (Android 10 Q) Build ==="

# Repo Tool bootstrap if missing
if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$HOME/bin" && curl -L https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo" && chmod a+rx "$HOME/bin/repo" && export PATH="$HOME/bin:$PATH"
fi

# ==============================================================================
# PHASE 1: EXECUTION, MEMORY & COMPILER GUARDS
# ==============================================================================
export GOMEMLIMIT=10GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx10g"
export ALLOW_MISSING_DEPENDENCIES=true
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export SELINUX_IGNORE_NEVERALLOWS=true
export BUILD_USERNAME=Zoro-15 BUILD_HOSTNAME=crave

# ==============================================================================
# PHASE 2: PRE-FLIGHT CLEANUP (SAFE FOR CRAVE)
# ==============================================================================
echo "--> Cleaning stale local manifests and device trees..."
rm -rf .repo/local_manifests device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia

find .repo/projects/ -type d -name "hooks" -exec rm -rf {} + 2>/dev/null || true
find .repo/project-objects/ -type d -name "hooks" -exec rm -rf {} + 2>/dev/null || true

# ==============================================================================
# PHASE 3: MANIFEST INITIALIZATION & CRAVE ACCELERATED RESYNC
# ==============================================================================
echo "--> Initializing ArrowOS 10.0 manifest..."
repo init -u https://github.com/ArrowOS/android_manifest.git -b arrow-10.0 --git-lfs --depth=1

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

# Crave resync + source sync
if [ -f /usr/bin/resync ]; then /usr/bin/resync; else /opt/crave/resync.sh; fi
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle --prune -j$(nproc)

# Fallback direct clones if not synced
[ ! -d "device/nokia/PL2" ] && git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_PL2.git device/nokia/PL2
[ ! -d "device/nokia/sdm660-common" ] && git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_sdm660-common.git device/nokia/sdm660-common
[ ! -d "kernel/nokia/sdm660" ] && git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_kernel_nokia_sdm660.git kernel/nokia/sdm660
[ ! -d "vendor/nokia" ] && git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/proprietary_vendor_nokia.git vendor/nokia

# Legacy ncurses dependencies for Android 10 host tools
if [ ! -f /usr/lib/x86_64-linux-gnu/libncurses.so.5 ] || [ ! -f /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ]; then
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y -qq wget curl 2>/dev/null || true
    P="http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses"
    T=$(curl -sL "$P/" | grep -oE 'libtinfo5_[^"<> ]+_amd64\.deb' | sort -V | tail -1)
    N=$(curl -sL "$P/" | grep -oE 'libncurses5_[^"<> ]+_amd64\.deb' | sort -V | tail -1)
    [ -n "$T" ] && [ -n "$N" ] && wget -q "$P/$T" -O /tmp/tinfo.deb && wget -q "$P/$N" -O /tmp/ncurses.deb && sudo apt-get install -y /tmp/tinfo.deb /tmp/ncurses.deb && rm -f /tmp/tinfo.deb /tmp/ncurses.deb || true
fi

# Fallback check for Qualcomm SEPolicy legacy dependency
if [ ! -d "device/qcom/sepolicy-legacy-um" ]; then
    echo "--> Pulling missing device/qcom/sepolicy-legacy-um..."
    git clone --depth=1 -b lineage-17.1 https://github.com/LineageOS-Revived/android_device_qcom_sepolicy-legacy-um.git device/qcom/sepolicy-legacy-um
fi

# ==============================================================================
# PHASE 4: HARDWARE INTEGRITY & DSP FIRMWARE
# ==============================================================================
echo "--> Verifying TAS2557 SmartAmp DSP firmware..."
FIRMWARE_TARGET="vendor/nokia/sdm660-common/proprietary/vendor/firmware/TAS2557MSSMono.bin"
if [ ! -f "$FIRMWARE_TARGET" ]; then
    mkdir -p "$(dirname "$FIRMWARE_TARGET")"
    [ -f "device/nokia/PL2/TAS2557MSSMono.bin" ] && cp device/nokia/PL2/TAS2557MSSMono.bin "$FIRMWARE_TARGET"
fi

# ==============================================================================
# PHASE 5: CCACHE & BUILD TARGET SETUP
# ==============================================================================
if [ -x prebuilts/misc/linux-x86/ccache/ccache ]; then
    export USE_CCACHE=1 CCACHE_EXEC="$PWD/prebuilts/misc/linux-x86/ccache/ccache" CCACHE_DIR="$HOME/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
fi

set +e
source build/envsetup.sh
set -e

# Clean cached kernel objects and boot images
echo "--> Cleaning cached KERNEL_OBJ and boot image artifacts..."
rm -rf out/target/product/PL2/obj/KERNEL_OBJ
rm -rf out/target/product/PL2/boot.img out/target/product/PL2/recovery.img

lunch arrow_PL2-userdebug
make installclean
echo "--> Compiling ArrowOS 10.0 target image..."
mka arrow -j$(nproc --all) || mka bacon -j$(nproc --all)


echo "========================================================"
echo "Uploading artifact to temp.sh..."
TEMP_URL=$(curl --fail --silent --show-error --max-time 1800 \
    -F "file=@${ROM_ZIP}" https://temp.sh/upload 2>&1) || {
    echo "ERROR: temp.sh upload failed"
    echo "$TEMP_URL"
    exit 1
}
echo "$TEMP_URL"
echo "$TEMP_URL" > "${ROM_ZIP}.temp.sh.url"
echo "========================================================"
echo "=== ArrowOS 10.0 Build Finished Successfully! ==="
