#!/bin/bash
# ==============================================================================
# Android 16 QPR2 Status Bar Battery & Icon Spacing Patch Applicator
# Supported ROMs: LineageOS 17.1, QASSA, NusantaraProject 10, AOSP 10
# Targets:
#   - frameworks/base/packages/SettingsLib (ThemedBatteryDrawable.kt)
#   - frameworks/base/packages/SystemUI (BatteryMeterView.java)
#   - frameworks/base/packages/SystemUI (StatusIconContainer.java)
# ==============================================================================

ROOT_DIR="${1:-$PWD}"
PATCH_FILE="$ROOT_DIR/device/nokia/PL2/patches/0001-SettingsLib-Horizontal-battery-capsule-with-embedded-percentage.patch"
THEMED_BATTERY="$ROOT_DIR/frameworks/base/packages/SettingsLib/src/com/android/settingslib/graph/ThemedBatteryDrawable.kt"
BATTERY_VIEW="$ROOT_DIR/frameworks/base/packages/SystemUI/src/com/android/systemui/BatteryMeterView.java"
STATUS_CONTAINER="$ROOT_DIR/frameworks/base/packages/SystemUI/src/com/android/systemui/statusbar/phone/StatusIconContainer.java"

echo "=== Android 16 QPR2 Status Bar & Battery Patch ==="

# 1. Check if git apply works first
if [ -f "$PATCH_FILE" ] && [ -d "$ROOT_DIR/frameworks/base/.git" ] && command -v git >/dev/null 2>&1; then
    echo "--> Attempting git apply on frameworks/base..."
    if (cd "$ROOT_DIR/frameworks/base" && git apply --check "$PATCH_FILE" 2>/dev/null); then
        (cd "$ROOT_DIR/frameworks/base" && git apply "$PATCH_FILE")
        echo "--> Successfully applied via git apply!"
        exit 0
    else
        echo "--> git apply check failed, falling back to direct AST/python transforms..."
    fi
fi

# 2. Direct Python Transformer for ThemedBatteryDrawable.kt
if [ -f "$THEMED_BATTERY" ]; then
    python3 - << 'PYEOF' || python - << 'PYEOF'
import sys, re

themed_battery_path = sys.argv[1]
with open(themed_battery_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Imports
if "import java.io.File" not in content:
    content = content.replace("import android.util.PathParser", "import android.util.PathParser\nimport android.graphics.Color\nimport android.graphics.Typeface\nimport java.io.File")

# 2. Typeface and textPaint with PlusJakartaSans support
if "PlusJakartaSans-ExtraBold.ttf" not in content:
    text_paint_code = """    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).also { p ->
        p.textAlign = Paint.Align.CENTER
        p.isDither = true
        val fontFile = File("/system/fonts/PlusJakartaSans-ExtraBold.ttf")
        p.typeface = if (fontFile.exists()) {
            try { Typeface.createFromFile(fontFile) } catch (e: Exception) { Typeface.create("sans-serif", Typeface.BOLD) }
        } else {
            Typeface.create("sans-serif", Typeface.BOLD)
        }
        p.isFakeBoldText = true
    }

    private val fillPaint = Paint"""
    if "val textPaint = Paint" in content:
        content = re.sub(r'private val textPaint = Paint\(.*?\n    private val fillPaint = Paint', text_paint_code, content, flags=re.DOTALL)
    else:
        content = content.replace("private val fillPaint = Paint", text_paint_code, 1)

# 3. Canvas dimensions to 35x15
content = re.sub(r'private const val WIDTH = \d+f', 'private const val WIDTH = 35f', content)
content = re.sub(r'private const val HEIGHT = \d+f', 'private const val HEIGHT = 15f', content)

with open(themed_battery_path, "w", encoding="utf-8") as f:
    f.write(content)

print("--> Successfully updated ThemedBatteryDrawable.kt.")
PYEOF
    "$THEMED_BATTERY"
fi

# 3. Suppress external percentage text view in BatteryMeterView if present
if [ -f "$BATTERY_VIEW" ]; then
    python3 - << 'PYEOF' || python - << 'PYEOF'
import sys

battery_view_path = sys.argv[1]
with open(battery_view_path, "r", encoding="utf-8") as f:
    bv_content = f.read()

if "mBatteryPercentView.setVisibility(View.GONE); return;" not in bv_content:
    target = "private void updateShowPercent() {"
    replacement = """private void updateShowPercent() {
        if (mBatteryPercentView != null) {
            mBatteryPercentView.setVisibility(View.GONE);
            return;
        }"""
    if target in bv_content:
        bv_content = bv_content.replace(target, replacement, 1)

# Ensure 7/3 ratio for horizontal pill
bv_content = bv_content.replace("getResources().getDimensionPixelSize(R.dimen.status_bar_battery_icon_width);", "(resHeight * 7) / 3;")

with open(battery_view_path, "w", encoding="utf-8") as f:
    f.write(bv_content)
print("--> Successfully updated BatteryMeterView.java.")
PYEOF
    "$BATTERY_VIEW"
fi

# 4. StatusIconContainer icon spacing (Wi-Fi to Cellular distance)
if [ -f "$STATUS_CONTAINER" ]; then
    python3 - << 'PYEOF' || python - << 'PYEOF'
import sys

status_container_path = sys.argv[1]
with open(status_container_path, "r", encoding="utf-8") as f:
    sc_content = f.read()

if "mIconSpacing" not in sc_content:
    # Add field
    sc_content = sc_content.replace("private int mUnderflowWidth;", "private int mUnderflowWidth;\n    private float mIconSpacing;")
    
    # Initialize in initDimens()
    sc_content = sc_content.replace("mUnderflowWidth = mIconDotFrameWidth + (mStaticDotDiameter + mDotPadding) * 0;",
                                    "mUnderflowWidth = mIconDotFrameWidth + (mStaticDotDiameter + mDotPadding) * 0;\n        mIconSpacing = getResources().getDisplayMetrics().density * 6.5f;")
    
    # Decrement in calculateIconTranslations()
    sc_content = sc_content.replace("translationX -= getViewTotalWidth(child);",
                                    "translationX -= getViewTotalWidth(child);\n            translationX -= mIconSpacing;")
    
    # Measure in onMeasure()
    sc_content = sc_content.replace("contentWidth += getViewTotalMeasuredWidth(child);",
                                    "contentWidth += getViewTotalMeasuredWidth(child);\n            contentWidth += (int) mIconSpacing;")

    with open(status_container_path, "w", encoding="utf-8") as f:
        f.write(sc_content)
    print("--> Successfully applied 6.5dp icon spacing to StatusIconContainer.java.")
PYEOF
    "$STATUS_CONTAINER"
fi

echo "=== Battery & Icon Spacing Patch Application Complete ==="
