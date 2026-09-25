#!/bin/bash
set -e 
cd /crave-devspaces/los17_build

# ── env guards ──
export GOMEMLIMIT=8GiB GOGC=50 _JAVA_OPTIONS="-Xmx6g"
export ALLOW_MISSING_DEPENDENCIES=true WITHOUT_CHECK_API=true SKIP_ABI_CHECKS=true
export BUILD_USERNAME=Zoro-15 BUILD_HOSTNAME=crave

# ── cleanup ──
rm -rf .repo/local_manifests device/nokia/PL2 device/nokia/sdm660-common kernel/nokia/sdm660 vendor/nokia

# ── manifest + local manifest + sync ──
repo init -u https://github.com/LineageOS-Revived/android.git -b lineage-17.1 --git-lfs --depth=1
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/nokia.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="zoro" fetch="https://github.com/Zoro-15" revision="lineage-17.1"/>
  <project path="device/nokia/PL2"           name="android_device_nokia_PL2"           remote="zoro"/>
  <project path="device/nokia/sdm660-common" name="android_device_nokia_sdm660-common" remote="zoro"/>
  <project path="kernel/nokia/sdm660"        name="android_kernel_nokia_sdm660"        remote="zoro"/>
  <project path="vendor/nokia"               name="proprietary_vendor_nokia"           remote="zoro"/>
</manifest>
XML
[ -f /opt/crave/resync.sh ] && /opt/crave/resync.sh
repo sync -c --force-sync --force-remove-dirty --no-tags --no-clone-bundle -j$(nproc)

# ── libncurses5 + libtinfo5 (real .deb, system path) ──
if [ -f /usr/lib/x86_64-linux-gnu/libncurses.so.5 ] && \
   [ -f /usr/lib/x86_64-linux-gnu/libtinfo.so.5 ]; then
    echo ">>> libncurses5/libtinfo5 already present"
else
    echo ">>> Installing libncurses5 + libtinfo5..."
    sudo apt-get update -qq 2>/dev/null || true
    POOL="http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses"
    TINFO=$(curl -sL "$POOL/" | grep -oE "libtinfo5_[^\"<> ]+_amd64\.deb"   | sort -V | tail -1)
    NCURS=$(curl -sL "$POOL/" | grep -oE "libncurses5_[^\"<> ]+_amd64\.deb" | sort -V | tail -1)
    if [ -z "$TINFO" ] || [ -z "$NCURS" ]; then
        echo "!!! FATAL: could not find libtinfo5/libncurses5 in Ubuntu pool"
        exit 1
    fi
    wget -q "$POOL/$TINFO" -O /tmp/libtinfo5.deb
    wget -q "$POOL/$NCURS" -O /tmp/libncurses5.deb
    sudo apt-get install -y /tmp/libtinfo5.deb /tmp/libncurses5.deb
    rm -f /tmp/libtinfo5.deb /tmp/libncurses5.deb
    echo ">>> Dependency fix complete"
fi

# ── verify toolchain before burning the queue slot ──
if [ -d prebuilts/clang/host/linux-x86/clang-3289846/bin ]; then
    if ! prebuilts/clang/host/linux-x86/clang-3289846/bin/clang.real --version >/dev/null 2>&1; then
        echo "!!! FATAL:"; ldd prebuilts/clang/host/linux-x86/clang-3289846/bin/clang.real | grep "not found"; exit 1
    fi
    echo "--> toolchain OK"
fi

# ── ccache (in-tree only, no install) ──
if [ -x prebuilts/misc/linux-x86/ccache/ccache ]; then
    export USE_CCACHE=1
    export CCACHE_EXEC="$(pwd)/prebuilts/misc/linux-x86/ccache/ccache"
    export CCACHE_DIR="$HOME/.ccache"
    "$CCACHE_EXEC" -M 50G 2>/dev/null || true
fi

# ── envsetup (some internal cmds return non-zero) ──
set +e; source build/envsetup.sh; set -e
lunch lineage_PL2-userdebug

# ── final guard ──
if ! prebuilts/clang/host/linux-x86/clang-3289846/bin/clang.real --version >/dev/null 2>&1; then
    echo "!!! FATAL before mka:"; ldd prebuilts/clang/host/linux-x86/clang-3289846/bin/clang.real | grep "not found"; exit 1
fi

# ── build ──
make installclean
mka bacon

# ── upload ──
Z=$(ls out/target/product/PL2/lineage-17.1-*.zip 2>/dev/null | head -n1)
[ -f "$Z" ] && {
    echo "=== BUILD OK: $Z ($(du -h "$Z" | cut -f1)) ==="
    curl -s bashupload.com -T "$Z" || curl -s --upload-file "$Z" https://transfer.sh/ || true
    md5sum "$Z"
}
