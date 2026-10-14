#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) NusantaraProject Android 10 Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
export ROM_TITLE="NusantaraProject Android 10"
export MANIFEST_URL="https://github.com/NusantaraProject-ROM/android_manifest"
export MANIFEST_BRANCH="10"
export LUNCH_TARGET="nad_PL2-userdebug"
export BUILD_CMD="mka nad -j$(nproc --all) || mka bacon -j$(nproc --all)"

COMMON_SCRIPT="$SCRIPT_DIR/crave_common.sh"
if [ ! -f "$COMMON_SCRIPT" ]; then
    COMMON_SCRIPT="/tmp/crave_common.sh"
    curl -sL "https://raw.githubusercontent.com/Zoro-15/android_device_nokia_PL2/lineage-17.1/crave_common.sh" -o "$COMMON_SCRIPT"
fi

exec bash "$COMMON_SCRIPT"
