#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) ArrowOS 10.0 (Android 10 Q) Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
export ROM_TITLE="ArrowOS 10.0 (Android 10 Q)"
export MANIFEST_URL="https://github.com/ArrowOS/android_manifest.git"
export MANIFEST_BRANCH="arrow-10.0"
export LUNCH_TARGET="arrow_PL2-userdebug"
export BUILD_CMD="mka bacon -j$(nproc --all)"

COMMON_SCRIPT="$SCRIPT_DIR/crave_common.sh"
if [ ! -f "$COMMON_SCRIPT" ]; then
    COMMON_SCRIPT="/tmp/crave_common.sh"
    curl -sL "https://raw.githubusercontent.com/Zoro-15/android_device_nokia_PL2/lineage-17.1/crave_common.sh" -o "$COMMON_SCRIPT"
fi

exec bash "$COMMON_SCRIPT"
