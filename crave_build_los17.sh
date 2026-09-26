#!/bin/bash
set -e -x

WORKDIR="/crave-devspaces/los17_build"
mkdir -p "$WORKDIR" && cd "$WORKDIR"

# Repo
if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$HOME/bin" && curl -L https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo" && chmod a+rx "$HOME/bin/repo" && export PATH="$HOME/bin:$PATH"
fi

# Environment
export GOMEMLIMIT=8GiB GOGC=50 _JAVA_OPTIONS="-Xmx6g"
export ALLOW_MISSING_DEPENDENCIES=true WITHOUT_CHECK_API=true SKIP_ABI_CHECKS=true
export BUILD_USERNAME=Zoro-15 BUILD_HOSTNAME=crave

# Clean previous device manifests/repos
rm -rf .repo/local_manifests device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia

# Init + local manifest
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

# Crave resync + source sync
if [ -f /usr/bin/resync ]; then /usr/bin/resync; else /opt/crave/resync.sh; fi
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle -j"$(nproc)"

# Legacy ncurses dependencies
if [ ! -f /usr/lib/x86_64-linux-gnu/libncurses.so.5 ] || [ ! -f /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ]; then
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y -qq wget curl 2>/dev/null || true
    P="http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses"
    T=$(curl -sL "$P/" | grep -oE 'libtinfo5_[^"<> ]+_amd64\.deb' | sort -V | tail -1)
    N=$(curl -sL "$P/" | grep -oE 'libncurses5_[^"<> ]+_amd64\.deb' | sort -V | tail -1)
    [ -n "$T" ] && [ -n "$N" ] && wget -q "$P/$T" -O /tmp/tinfo.deb && wget -q "$P/$N" -O /tmp/ncurses.deb && sudo apt-get install -y /tmp/tinfo.deb /tmp/ncurses.deb && rm -f /tmp/tinfo.deb /tmp/ncurses.deb || true
fi

# Verify required repos
test -d device/nokia/PL2 && test -d device/nokia/sdm660-common && test -d kernel/nokia/sdm660 && test -d vendor/nokia

# ccache
if [ -x prebuilts/misc/linux-x86/ccache/ccache ]; then
    export USE_CCACHE=1 CCACHE_EXEC="$PWD/prebuilts/misc/linux-x86/ccache/ccache" CCACHE_DIR="$HOME/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
fi

# Build
set +e
source build/envsetup.sh
set -e

lunch lineage_PL2-userdebug
make installclean
mka bacon

# Result
Z=$(find out/target/product/PL2 -maxdepth 1 -type f -name 'lineage-17.1-*.zip' 2>/dev/null | head -n1)
if [ -f "$Z" ]; then echo "=== BUILD OK: $Z ($(du -h "$Z" | cut -f1)) ==="; md5sum "$Z"; curl -s bashupload.com -T "$Z" || curl -s --upload-file "$Z" https://transfer.sh/ || true; fi
