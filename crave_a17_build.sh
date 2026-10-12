#!/bin/bash
set -e

echo "=== LineageOS 24.0 (Android 17) Build for Nokia 6.1 (PL2) ==="

# 1. Base Manifest & Upstream PL2 Local Manifest
rm -rf .repo/local_manifests/
mkdir -p .repo/local_manifests

repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --depth=1

cat << "EOF" > .repo/local_manifests/PL2.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Device tree -->
  <project path="device/nokia/PL2" name="nokia-msm8998/android_device_nokia_PL2" revision="lineage-24.0" remote="github" />
  <project path="device/nokia/sdm660-common" name="nokia-msm8998/android_device_nokia_sdm660-common" revision="lineage-24.0" remote="github" />

  <!-- Kernel sources (Linux 4.19 unified tree) -->
  <project path="kernel/nokia/sdm660" name="nokia-msm8998/android_kernel_nokia_sdm660_419" revision="lineage-23.2" remote="github" />

  <!-- Proprietary vendor blobs -->
  <project path="vendor/nokia/PL2" name="nokia-msm8998/proprietary_vendor_nokia_PL2" revision="lineage-24.0" remote="github" />
  <project path="vendor/nokia/sdm660-common" name="nokia-msm8998/proprietary_vendor_nokia_sdm660-common" revision="lineage-24.0" remote="github" />
</manifest>
EOF

# 2. Source Sync
echo "--> Syncing source repositories..."
if [ -f "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
else
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --prune
fi

# 3. Build Setup & Compilation
export USE_CCACHE=1
source build/envsetup.sh

echo "--> Selecting target and starting compilation..."
breakfast PL2 || lunch lineage_PL2-trunk_staging-userdebug || lunch lineage_PL2-userdebug

mka bacon -j$(nproc --all) 2>&1 | tee build_a17_PL2.log

# 4. Artifact Upload
FILES=$(ls out/target/product/PL2/lineage-24.*.zip out/target/product/PL2/boot.img 2>/dev/null || echo "build_a17_PL2.log")
for f in $FILES; do
    [ -f "$f" ] && curl -sL https://bashupload.com/ -T "$f" && echo ""
done
