#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) ArrowOS 10.0 (Android 10 Q) Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROM_TITLE="ArrowOS 10.0 (Android 10 Q)"
export MANIFEST_URL="https://github.com/ArrowOS/android_manifest.git"
export MANIFEST_BRANCH="arrow-10.0"
export LUNCH_TARGET="arrow_PL2-userdebug"
export BUILD_CMD="mka bacon -j$(nproc --all)"

exec bash "$SCRIPT_DIR/crave_common.sh"
