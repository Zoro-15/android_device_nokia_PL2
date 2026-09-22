
set -e


rm -rf .repo/local_manifests
repo init -u https://github.com/accupara/los18.1.git -b lineage-17.1 --depth=1 --git-lfs

mkdir -p .repo/local_manifests
curl -sL https://raw.githubusercontent.com/Zoro-15/android_device_nokia_PL2/lineage-17.1/lineage_pl2.xml -o .repo/local_manifests/lineage_pl2.xml


repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune


if [ ! -f "device/nokia/PL2/device.mk" ]; then
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_PL2 device/nokia/PL2
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_device_nokia_sdm660-common device/nokia/sdm660-common
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/android_kernel_nokia_sdm660 kernel/nokia/sdm660
    git clone --depth=1 -b lineage-17.1 https://github.com/Zoro-15/proprietary_vendor_nokia vendor/nokia
fi

export WITHOUT_CHECK_API=true
export SKIP_ABI_CHECKS=true

source build/envsetup.sh
lunch lineage_PL2-userdebug

mka bacon -j$(nproc --all)
