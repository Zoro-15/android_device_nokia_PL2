#!/bin/bash
set -e

# ==============================================================================
# Master Crave Build Runner for Nokia 6.1 (PL2)
# Usage:
#   ./crave_build.sh             (builds default: keepQASSA 2.4)
#   ./crave_build.sh qassa       (keepQASSA 2.4)
#   ./crave_build.sh los17       (LineageOS 17.1)
#   ./crave_build.sh arrow       (ArrowOS 10.0)
#   ./crave_build.sh nusantara   (NusantaraProject Android 10)
#   ./crave_build.sh aospa       (Paranoid Android Quartz)
#   ./crave_build.sh du          (Dirty Unicorns 14)
# ==============================================================================

TARGET_ROM="${1:-qassa}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"

case "$TARGET_ROM" in
    qassa)
        export ROM_TITLE="keepQASSA 2.4 (Android 10 Q)"
        export MANIFEST_URL="https://github.com/keepQASSA/manifest"
        export MANIFEST_BRANCH="Q"
        export LUNCH_TARGET="qassa_PL2-userdebug"
        export BUILD_CMD="mka bacon -j$(nproc --all)"
        export EXTRA_ENV="export WITH_GAPPS=false"
        ;;
    los17|lineage|los)
        export ROM_TITLE="LineageOS 17.1 (Android 10 Q)"
        export MANIFEST_URL="https://github.com/LineageOS-Revived/android.git"
        export MANIFEST_BRANCH="lineage-17.1"
        export LUNCH_TARGET="lineage_PL2-userdebug"
        export BUILD_CMD="mka bacon -j$(nproc --all)"
        ;;
    arrow)
        export ROM_TITLE="ArrowOS 10.0 (Android 10 Q)"
        export MANIFEST_URL="https://github.com/ArrowOS/android_manifest.git"
        export MANIFEST_BRANCH="arrow-10.0"
        export LUNCH_TARGET="arrow_PL2-userdebug"
        export BUILD_CMD="mka bacon -j$(nproc --all)"
        ;;
    nusantara|nad)
        export ROM_TITLE="NusantaraProject Android 10"
        export MANIFEST_URL="https://github.com/NusantaraProject-ROM/android_manifest"
        export MANIFEST_BRANCH="10"
        export LUNCH_TARGET="nad_PL2-userdebug"
        export BUILD_CMD="mka nad -j$(nproc --all) || mka bacon -j$(nproc --all)"
        ;;
    aospa|pa)
        export ROM_TITLE="Paranoid Android Quartz (Android 10 Q)"
        export MANIFEST_URL="https://github.com/AOSPA/manifest"
        export MANIFEST_BRANCH="quartz"
        export LUNCH_TARGET="pa_PL2-userdebug"
        export BUILD_CMD="mka bacon -j$(nproc --all)"
        ;;
    du)
        export ROM_TITLE="Dirty Unicorns 14 (Android 10 Q)"
        export MANIFEST_URL="https://github.com/DirtyUnicorns/android_manifest"
        export MANIFEST_BRANCH="q10"
        export LUNCH_TARGET="du_PL2-userdebug"
        export BUILD_CMD="mka du -j$(nproc --all) || mka bacon -j$(nproc --all)"
        ;;
    *)
        echo "Unknown target ROM: $TARGET_ROM"
        echo "Available targets: qassa, los17, arrow, nusantara, aospa, du"
        exit 1
        ;;
esac

COMMON_SCRIPT="$SCRIPT_DIR/crave_common.sh"
if [ ! -f "$COMMON_SCRIPT" ]; then
    COMMON_SCRIPT="/tmp/crave_common.sh"
    curl -sL "https://raw.githubusercontent.com/Zoro-15/android_device_nokia_PL2/lineage-17.1/crave_common.sh" -o "$COMMON_SCRIPT"
fi

exec bash "$COMMON_SCRIPT"
