#!/bin/bash
set -e
# ==============================================================================
# Nokia 6.1 (PL2) Dirty Unicorns 14 (Android 10 Q) Crave Build Script
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROM_TITLE="Dirty Unicorns 14 (Android 10 Q)"
export MANIFEST_URL="https://github.com/DirtyUnicorns/android_manifest"
export MANIFEST_BRANCH="q10"
export LUNCH_TARGET="du_PL2-userdebug"
export BUILD_CMD="mka du -j$(nproc --all) || mka bacon -j$(nproc --all)"

exec bash "$SCRIPT_DIR/crave_common.sh"
