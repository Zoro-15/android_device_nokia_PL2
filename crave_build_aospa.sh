#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) Paranoid Android Quartz (Android 10 Q) Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROM_TITLE="Paranoid Android Quartz (Android 10 Q)"
export MANIFEST_URL="https://github.com/AOSPA/manifest"
export MANIFEST_BRANCH="quartz"
export LUNCH_TARGET="pa_PL2-userdebug"
export BUILD_CMD="mka bacon -j$(nproc --all)"

exec bash "$SCRIPT_DIR/crave_common.sh"
