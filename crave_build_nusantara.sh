#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) NusantaraProject Android 10 Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROM_TITLE="NusantaraProject Android 10"
export MANIFEST_URL="https://github.com/NusantaraProject-ROM/android_manifest"
export MANIFEST_BRANCH="10"
export LUNCH_TARGET="nad_PL2-userdebug"
export BUILD_CMD="mka nad -j$(nproc --all) || mka bacon -j$(nproc --all)"

exec bash "$SCRIPT_DIR/crave_common.sh"
