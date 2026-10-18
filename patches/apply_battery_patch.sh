#!/bin/bash
# ==============================================================================
# Android 16 QPR2 Status Bar Battery Patch Applicator
# Supported ROMs: LineageOS 17.1, QASSA, NusantaraProject 10, AOSP 10
# Target: frameworks/base (ThemedBatteryDrawable.kt & BatteryMeterView.java)
# ==============================================================================

ROOT_DIR="${1:-$PWD}"
PATCH_FILE="$ROOT_DIR/device/nokia/PL2/patches/0001-SettingsLib-Horizontal-battery-capsule-with-embedded-percentage.patch"
THEMED_BATTERY="$ROOT_DIR/frameworks/base/packages/SettingsLib/src/com/android/settingslib/graph/ThemedBatteryDrawable.kt"
BATTERY_VIEW="$ROOT_DIR/frameworks/base/packages/SystemUI/src/com/android/systemui/BatteryMeterView.java"

echo "=== Android 16 QPR2 Status Bar Battery Patch ==="

if [ ! -f "$THEMED_BATTERY" ]; then
    echo "Warning: $THEMED_BATTERY not found! Check directory structure."
    exit 0
fi

# Check if already patched
if grep -q "WIDTH = 28f" "$THEMED_BATTERY" 2>/dev/null; then
    echo "--> ThemedBatteryDrawable.kt is already patched for 28x15 horizontal capsule."
    exit 0
fi

# Try git apply first if patch file exists
if [ -f "$PATCH_FILE" ] && command -v git >/dev/null 2>&1; then
    echo "--> Attempting git apply on frameworks/base..."
    if (cd "$ROOT_DIR/frameworks/base" && git apply --check "$PATCH_FILE" 2>/dev/null); then
        (cd "$ROOT_DIR/frameworks/base" && git apply "$PATCH_FILE")
        echo "--> Successfully applied via git apply!"
        exit 0
    else
        echo "--> git apply check failed, falling back to direct AST/python transform..."
    fi
fi

# Direct Python Fallback Transformer (Guaranteed to work regardless of minor upstream differences)
python3 - << 'PYEOF' || python - << 'PYEOF'
import sys, re

themed_battery_path = sys.argv[1]
with open(themed_battery_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Typeface import if missing
if "import android.graphics.Typeface" not in content:
    content = content.replace("import android.util.PathParser", "import android.util.PathParser\nimport android.graphics.Typeface")

# 2. Add textPaint initialization if missing
if "val textPaint = Paint" not in content:
    init_marker = "private val fillPaint = Paint"
    text_paint_code = """    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).also { p ->
        p.textAlign = Paint.Align.CENTER
        p.isDither = true
        p.typeface = Typeface.create("sans-serif", Typeface.BOLD)
    }

    private val fillPaint = Paint"""
    content = content.replace(init_marker, text_paint_code, 1)

# 3. Transform horizontal fill in draw()
old_fill = re.search(r'val fillTop =\s*if \(batteryLevel >= 95\)\s*fillRect\.top\s*else\s*fillRect\.top \+ \(fillRect\.height\(\) \* \(1 - fillFraction\)\)\s*levelRect\.top = Math\.floor\(fillTop\.toDouble\(\)\)\.toFloat\(\)', content)
if old_fill:
    new_fill = """val fillRight =
                if (batteryLevel >= 98)
                    fillRect.right
                else
                    fillRect.left + (fillRect.width() * fillFraction)

        levelRect.right = Math.ceil(fillRight.toDouble()).toFloat()"""
    content = content.replace(old_fill.group(0), new_fill, 1)

# 4. Transform dualTone clipRect to horizontal
content = re.sub(r'c\.clipRect\(0f,\s*bounds\.bottom - bounds\.height\(\) \* fillFraction,\s*bounds\.right\.toFloat\(\),\s*bounds\.bottom\.toFloat\(\)\)',
                 'c.clipRect(0f, 0f, 22.5f * fillFraction, 15f)', content)

# 5. Add centered percentage text drawing inside draw()
if "textPaint.textSize" not in content:
    restore_marker = "c.restore()\n    }\n\n    private fun batteryColorForLevel"
    if restore_marker in content:
        draw_text_code = """        // Render real-time battery percentage centered inside the capsule body
        if (batteryLevel >= 0) {
            val pctString = batteryLevel.toString()
            textPaint.textSize = if (batteryLevel >= 100) 6.8f else 8.0f
            textPaint.color = if (batteryLevel >= 90 && !dualTone) {
                Color.BLACK
            } else if (batteryLevel <= Companion.CRITICAL_LEVEL && !charging) {
                Color.WHITE
            } else {
                if (dualTone) Color.WHITE else Color.BLACK
            }
            val centerX = 11.7f
            val centerY = 7.5f - (textPaint.descent() + textPaint.ascent()) / 2f
            c.drawText(pctString, centerX, centerY, textPaint)
        }
        c.restore()
    }

    private fun batteryColorForLevel"""
        content = content.replace(restore_marker, draw_text_code, 1)

# 6. Change Companion dimensions to 28x15
content = re.sub(r'private const val WIDTH = 12f', 'private const val WIDTH = 28f', content)
content = re.sub(r'private const val HEIGHT = 20f', 'private const val HEIGHT = 15f', content)

with open(themed_battery_path, "w", encoding="utf-8") as f:
    f.write(content)

print("--> Successfully transformed ThemedBatteryDrawable.kt to 28x15 horizontal capsule.")
PYEOF
"$THEMED_BATTERY"

# Suppress external percentage text view in BatteryMeterView if present
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
        with open(battery_view_path, "w", encoding="utf-8") as f:
            f.write(bv_content)
        print("--> Successfully suppressed external percent view in BatteryMeterView.java.")
PYEOF
    "$BATTERY_VIEW"
fi

echo "=== Battery Patch Application Complete ==="
