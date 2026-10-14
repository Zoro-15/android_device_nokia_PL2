#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) LineageOS 17.1 (Android 10 Q) Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROM_TITLE="LineageOS 17.1 (Android 10 Q)"
export MANIFEST_URL="https://github.com/LineageOS-Revived/android.git"
export MANIFEST_BRANCH="lineage-17.1"
export LUNCH_TARGET="lineage_PL2-userdebug"
export BUILD_CMD="mka bacon -j$(nproc --all)"

exec bash "$SCRIPT_DIR/crave_common.sh"
