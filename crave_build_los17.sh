#!/bin/bash
set -e

# Setup working directory if CRAVE_WORKDIR is provided
WORKDIR="${CRAVE_WORKDIR:-$PWD}"
mkdir -p "$WORKDIR" 2>/dev/null || true
cd "$WORKDIR"

# Repo tool bootstrap if missing
if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$HOME/bin"
    curl -sL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
    chmod a+rx "$HOME/bin/repo"
    export PATH="$HOME/bin:$PATH"
fi

# Environment setup
export GOMEMLIMIT=10GiB
export GOGC=50
export _JAVA_OPTIONS="-Xmx10g"
export ALLOW_MISSING_DEPENDENCIES=true
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true
export SELINUX_IGNORE_NEVERALLOWS=true
export BUILD_USERNAME=Zoro-15
export BUILD_HOSTNAME=crave

# Clean stale manifests and trees
rm -rf .repo/local_manifests device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia vendor/dolby .repo/projects/vendor/dolby.git .repo/project-objects/*dolby*

# Reset modified frameworks/base files if dirty
[ -d "frameworks/base/.git" ] && (cd frameworks/base && git checkout -- . 2>/dev/null && git clean -fd 2>/dev/null || true)

# Remove stale git hooks
find .repo/projects/ -type d -name "hooks" -exec rm -rf {} + 2>/dev/null || true
find .repo/project-objects/ -type d -name "hooks" -exec rm -rf {} + 2>/dev/null || true

# Initialize LineageOS 17.1 manifest
repo init -u https://github.com/LineageOS-Revived/android.git -b lineage-17.1 --git-lfs --depth=1

# Configure PL2 local manifest
mkdir -p .repo/local_manifests
if [ -f "device/nokia/PL2/lineage_pl2.xml" ]; then
    cp device/nokia/PL2/lineage_pl2.xml .repo/local_manifests/nokia.xml
else
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
fi

# Sync sources
if [ -f /usr/bin/resync ]; then /usr/bin/resync; else /opt/crave/resync.sh; fi
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle --prune -j$(nproc)

# Fallback clones if sync missed any repo
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

# Fallback check for Qualcomm sepolicy legacy dependency
if [ ! -d "device/qcom/sepolicy-legacy-um" ]; then
    git clone --depth=1 -b lineage-17.1 https://github.com/LineageOS-Revived/android_device_qcom_sepolicy-legacy-um.git device/qcom/sepolicy-legacy-um
fi

# TAS2557 SmartAmp DSP firmware check
FIRMWARE_TARGET="vendor/nokia/sdm660-common/proprietary/vendor/firmware/TAS2557MSSMono.bin"
if [ ! -f "$FIRMWARE_TARGET" ]; then
    mkdir -p "$(dirname "$FIRMWARE_TARGET")"
    [ -f "device/nokia/PL2/TAS2557MSSMono.bin" ] && cp device/nokia/PL2/TAS2557MSSMono.bin "$FIRMWARE_TARGET"
fi

# Verify required trees exist
test -d device/nokia/PL2 && test -d device/nokia/sdm660-common && test -d kernel/nokia/sdm660 && test -d vendor/nokia

# Apply status bar battery and icon spacing patches
if [ -f "device/nokia/PL2/patches/apply_battery_patch.sh" ]; then
    sed -i 's/\r$//' device/nokia/PL2/patches/apply_battery_patch.sh 2>/dev/null || true
    sed -i 's/\r$//' device/nokia/PL2/patches/*.patch 2>/dev/null || true
    bash device/nokia/PL2/patches/apply_battery_patch.sh . || true
fi

# Clean prior intermediate files
rm -rf out/target/product/PL2/obj/KERNEL_OBJ
rm -rf out/target/product/PL2/boot.img out/target/product/PL2/recovery.img

# Setup build environment and compile
source build/envsetup.sh
lunch lineage_PL2-userdebug
make installclean
mka bacon -j$(nproc --all)

# Locate final ROM zip
PRODUCT_OUT="out/target/product/PL2"
ROM_ZIP=$(ls -t "$PRODUCT_OUT"/lineage-17.1-*.zip 2>/dev/null | head -n 1)
[ -z "$ROM_ZIP" ] && ROM_ZIP=$(ls -t "$PRODUCT_OUT"/*.zip 2>/dev/null | grep -ivE 'ota|target_files' | head -n 1)

if [ -z "$ROM_ZIP" ] || [ ! -f "$ROM_ZIP" ]; then
    echo "Build failed: ROM zip not found in $PRODUCT_OUT"
    exit 1
fi

echo "ROM build complete: $(basename "$ROM_ZIP")"
sha256sum "$ROM_ZIP" | tee "${ROM_ZIP}.sha256sum"

# Upload ROM artifact to temp.sh
TEMP_URL=$(curl -s --fail --max-time 1800 -F "file=@${ROM_ZIP}" https://temp.sh/upload 2>/dev/null || true)

if [ -n "$TEMP_URL" ] && [[ "$TEMP_URL" == *"http"* ]]; then
    echo "$TEMP_URL" > "${ROM_ZIP}.download-url.txt"
    echo "========================================================"
    echo "DOWNLOAD URL: $TEMP_URL"
    echo "========================================================"
else
    echo "Upload failed or timed out. Pull manually with:"
    echo "crave pull out/target/product/PL2/*.zip"
fi
