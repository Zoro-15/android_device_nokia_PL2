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
FW_BASE="$ROOT_DIR/frameworks/base"

THEMED_BATTERY="$FW_BASE/packages/SettingsLib/src/com/android/settingslib/graph/ThemedBatteryDrawable.kt"
BATTERY_VIEW="$FW_BASE/packages/SystemUI/src/com/android/systemui/BatteryMeterView.java"
STATUS_CONTAINER="$FW_BASE/packages/SystemUI/src/com/android/systemui/statusbar/phone/StatusIconContainer.java"

echo "=== Android 16 QPR2 Status Bar & Battery Patch ==="

if [ ! -f "$PATCH_FILE" ]; then
    echo "--> Error: Patch file not found at $PATCH_FILE"
    exit 0
fi

if [ ! -d "$FW_BASE" ]; then
    echo "--> Warning: frameworks/base directory not found at $FW_BASE. Skipping."
    exit 0
fi

# Normalize line endings
sed -i 's/\r$//' "$PATCH_FILE" 2>/dev/null || true

# 1. Clean reset modified targets in frameworks/base to upstream state before applying
# This guarantees idempotency across repeated builds and eliminates dirty drift / duplicate imports
if [ -d "$FW_BASE/.git" ] && command -v git >/dev/null 2>&1; then
    echo "--> Resetting frameworks/base target files to upstream cleanly..."
    (cd "$FW_BASE" && git checkout -- \
        packages/SettingsLib/src/com/android/settingslib/graph/ThemedBatteryDrawable.kt \
        packages/SystemUI/src/com/android/systemui/BatteryMeterView.java \
        packages/SystemUI/src/com/android/systemui/statusbar/phone/StatusIconContainer.java 2>/dev/null || true)
fi

# 2. Primary Method: git apply
if [ -d "$FW_BASE/.git" ] && command -v git >/dev/null 2>&1; then
    echo "--> Attempting git apply on frameworks/base..."
    if (cd "$FW_BASE" && git apply --check --whitespace=nowarn "$PATCH_FILE" 2>/dev/null); then
        (cd "$FW_BASE" && git apply --whitespace=nowarn "$PATCH_FILE")
        echo "--> Successfully applied Android 16 QPR2 status bar & battery patch via git apply!"
        exit 0
    else
        echo "--> git apply check did not match cleanly, attempting patch -p1..."
        if command -v patch >/dev/null 2>&1; then
            if (cd "$FW_BASE" && patch -p1 --forward --batch < "$PATCH_FILE" 2>/dev/null); then
                echo "--> Successfully applied via patch -p1!"
                exit 0
            fi
        fi
    fi
fi

# 3. Safe fallback: AST/Python transformer with duplicate-import guards and full drawing logic
echo "--> Falling back to safe Python transform..."
PYTHON_BIN=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
fi

if [ -z "$PYTHON_BIN" ]; then
    echo "--> Warning: No python interpreter found, skipping fallback."
    exit 0
fi

# 3a. Update ThemedBatteryDrawable.kt
if [ -f "$THEMED_BATTERY" ]; then
    $PYTHON_BIN - "$THEMED_BATTERY" << 'PYEOF'
import sys

tbd_path = sys.argv[1]
with open(tbd_path, 'r', encoding='utf-8') as f:
    tbd = f.read()

# Only add java.io.File if not already present
if 'import java.io.File' not in tbd:
    tbd = tbd.replace('import android.util.PathParser', 'import java.io.File\nimport android.util.PathParser')

# Replace textPaint with GoogleSansRounded-Bold loader
old_tp = """    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).also { p ->
        p.typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
        p.textAlign = Paint.Align.CENTER
    }"""
new_tp = """    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).also { p ->
        p.textAlign = Paint.Align.CENTER
        p.isDither = true
        val fontFile = File("/system/fonts/GoogleSansRounded-Bold.ttf")
        p.typeface = if (fontFile.exists()) {
            try { Typeface.createFromFile(fontFile) } catch (e: Exception) { Typeface.create("sans-serif", Typeface.BOLD) }
        } else {
            Typeface.create("sans-serif", Typeface.BOLD)
        }
        p.isFakeBoldText = false
    }"""
if old_tp in tbd:
    tbd = tbd.replace(old_tp, new_tp)

# Replace draw(c: Canvas) if not already updated
draw_start = tbd.find('    override fun draw(c: Canvas) {')
draw_end = tbd.find('    private fun batteryColorForLevel(level: Int): Int {')
if draw_start != -1 and draw_end != -1 and 'Frosted track pill body' not in tbd:
    new_draw = """    override fun draw(c: Canvas) {
        val b = bounds
        val scale = b.bottom / 15f
        val isDarkTheme = (fillColor and 0x007fffff) > 0x00400000

        // Determine colors dynamically
        val activeFillColor: Int
        val activeTextColor: Int
        val boltColor: Int
        if (charging) {
            activeFillColor = 0xFF34A853.toInt() // Authentic Google Material Green 500
            activeTextColor = 0xFF383E42.toInt() // Shade 1 Refined Charcoal (Android 16 QPR2)
            boltColor = if (isDarkTheme) Color.WHITE else 0xFF383E42.toInt()
        } else if (batteryLevel <= 15) {
            activeFillColor = 0xFFFF334B.toInt() // Red
            activeTextColor = Color.WHITE
            boltColor = 0
        } else if (batteryLevel <= 20) {
            activeFillColor = 0xFFFFCC00.toInt() // Yellow
            activeTextColor = 0xFF383E42.toInt() // Shade 1 Refined Charcoal
            boltColor = 0
        } else {
            if (isDarkTheme) {
                activeFillColor = Color.WHITE
                activeTextColor = 0xFF383E42.toInt() // Shade 1 Refined Charcoal
            } else {
                activeFillColor = fillColor
                activeTextColor = Color.WHITE
            }
            boltColor = 0
        }
        fillPaint.color = activeFillColor
        textPaint.color = activeTextColor

        // 1. Frosted track pill body: (0.5, 1.0) to (25.5, 14.0), radius 5.2
        val pillLeft = 6.5f * scale
        val pillTop = 1.0f * scale
        val pillRight = 31.5f * scale
        val pillBottom = 14.0f * scale
        val pillRadius = 4.4f * scale

        levelRect.set(pillLeft, pillTop, pillRight, pillBottom)
        unifiedPath.reset()
        unifiedPath.addRoundRect(levelRect, pillRadius, pillRadius, Path.Direction.CCW)
        c.drawPath(unifiedPath, dualToneBackgroundFill)

        // 2. Active fill
        if (batteryLevel > 0) {
            val fillFraction = batteryLevel / 100f
            val fillWidth = Math.max(1.5f, 25.0f * fillFraction) * scale
            val fillRight = pillLeft + fillWidth
            c.save()
            c.clipPath(unifiedPath)
            levelRect.set(pillLeft, pillTop, fillRight, pillBottom)
            c.drawRect(levelRect, fillPaint)
            c.restore()
        }

        // 3. Right side indicator: Authentic Thunderbolt (scaled to 80% around center 25.5, 7.5)
        if (charging) {
            scaledBolt.reset()
            scaledBolt.moveTo(29.9f * scale, 11.5f * scale)
            scaledBolt.lineTo(30.3f * scale, 8.7f * scale)
            scaledBolt.lineTo(28.3f * scale, 8.7f * scale)
            scaledBolt.lineTo(31.9f * scale, 3.5f * scale)
            scaledBolt.lineTo(32.7f * scale, 3.5f * scale)
            scaledBolt.lineTo(32.3f * scale, 6.7f * scale)
            scaledBolt.lineTo(34.7f * scale, 6.7f * scale)
            scaledBolt.lineTo(30.7f * scale, 11.5f * scale)
            scaledBolt.close()
            fillPaint.color = boltColor
            c.drawPath(scaledBolt, fillPaint)
        } else {
            // Stadium terminal cap: (32.2, 5.0) to (33.7, 10.0), radius 0.75 (transparent frosted)
            levelRect.set(32.2f * scale, 5.0f * scale, 33.7f * scale, 10.0f * scale)
            c.drawRoundRect(levelRect, 0.75f * scale, 0.75f * scale, dualToneBackgroundFill)
        }

        // 4. Centered Large Bold Text (Google Sans Rounded Bold)
        textPaint.textSize = (if (batteryLevel == 100) 9.8f else 11.0f) * scale
        val textX = 18.50f * scale
        val fm = textPaint.fontMetrics
        val textY = 7.50f * scale - (fm.descent + fm.ascent) / 2f
        c.drawText(batteryLevel.toString(), textX, textY, textPaint)
    }

"""
    tbd = tbd[:draw_start] + new_draw + tbd[draw_end:]

# Replace setColors
old_sc = """    fun setColors(fgColor: Int, bgColor: Int, singleToneColor: Int) {
        fillColor = if (dualTone) fgColor else singleToneColor

        fillPaint.color = fillColor
        fillColorStrokePaint.color = fillColor

        backgroundColor = bgColor
        dualToneBackgroundFill.color = bgColor

        // Also update the level color, since fillColor may have changed
        levelColor = batteryColorForLevel(batteryLevel)

        invalidateSelf()
    }"""
new_sc = """    fun setColors(fgColor: Int, bgColor: Int, singleToneColor: Int) {
        fillColor = fgColor
        backgroundColor = bgColor
        val isDarkTheme = (fillColor and 0x007fffff) > 0x00400000
        if (isDarkTheme) {
            dualToneBackgroundFill.color = Color.WHITE
            dualToneBackgroundFill.alpha = 0x66
        } else {
            dualToneBackgroundFill.color = fillColor
            dualToneBackgroundFill.alpha = 0x4D
        }
        fillPaint.color = fillColor
        levelColor = batteryColorForLevel(batteryLevel)
        invalidateSelf()
    }"""
if old_sc in tbd:
    tbd = tbd.replace(old_sc, new_sc)

# Update dimensions to 35x15
tbd = tbd.replace("private const val WIDTH = 12f", "private const val WIDTH = 35f")
tbd = tbd.replace("private const val HEIGHT = 20f", "private const val HEIGHT = 15f")

with open(tbd_path, 'w', encoding='utf-8') as f:
    f.write(tbd)
print("--> Successfully updated ThemedBatteryDrawable.kt.")
PYEOF
fi

# 3b. Update BatteryMeterView.java
if [ -f "$BATTERY_VIEW" ]; then
    $PYTHON_BIN - "$BATTERY_VIEW" << 'PYEOF'
import sys

bmv_path = sys.argv[1]
with open(bmv_path, 'r', encoding='utf-8') as f:
    bmv = f.read()

# Suppress external percentage view
if "mBatteryPercentView.setVisibility(View.GONE); return;" not in bmv:
    old_up = "private void updateShowPercent() {"
    new_up = """private void updateShowPercent() {
        if (mBatteryPercentView != null) {
            mBatteryPercentView.setVisibility(View.GONE);
            return;
        }"""
    if old_up in bmv:
        bmv = bmv.replace(old_up, new_up, 1)

# Ensure 7/3 ratio for horizontal pill
old_mlp = """        final MarginLayoutParams mlp = new MarginLayoutParams(
                getResources().getDimensionPixelSize(R.dimen.status_bar_battery_icon_width),
                getResources().getDimensionPixelSize(R.dimen.status_bar_battery_icon_height));"""
new_mlp = """        int resHeight = getResources().getDimensionPixelSize(R.dimen.status_bar_battery_icon_height);
        int resWidth = (resHeight * 7) / 3;
        final MarginLayoutParams mlp = new MarginLayoutParams(resWidth, resHeight);"""
if old_mlp in bmv:
    bmv = bmv.replace(old_mlp, new_mlp)

old_style = """        int batteryHeight = res.getDimensionPixelSize(R.dimen.status_bar_battery_icon_height);
        int batteryWidth = mBatteryStyle == BATTERY_STYLE_CIRCLE ?
                res.getDimensionPixelSize(R.dimen.status_bar_battery_icon_circle_width) :
                res.getDimensionPixelSize(R.dimen.status_bar_battery_icon_width);"""
new_style = """        int batteryHeight = res.getDimensionPixelSize(R.dimen.status_bar_battery_icon_height);
        int batteryWidth = mBatteryStyle == BATTERY_STYLE_CIRCLE ?
                res.getDimensionPixelSize(R.dimen.status_bar_battery_icon_circle_width) :
                (batteryHeight * 7) / 3;"""
if old_style in bmv:
    bmv = bmv.replace(old_style, new_style)

with open(bmv_path, 'w', encoding='utf-8') as f:
    f.write(bmv)
print("--> Successfully updated BatteryMeterView.java.")
PYEOF
fi

# 3c. Update StatusIconContainer.java
if [ -f "$STATUS_CONTAINER" ]; then
    $PYTHON_BIN - "$STATUS_CONTAINER" << 'PYEOF'
import sys

sic_path = sys.argv[1]
with open(sic_path, 'r', encoding='utf-8') as f:
    sic = f.read()

if "mIconSpacing" not in sic:
    # Add import
    sic = sic.replace("import com.android.systemui.statusbar.StatusIconDisplayable;",
                      "import com.android.systemui.statusbar.StatusIconDisplayable;\nimport com.android.systemui.statusbar.StatusBarWifiView;")

    # Add field
    sic = sic.replace("private int mUnderflowWidth;", "private int mUnderflowWidth;\n    private float mIconSpacing;")

    # Initialize in initDimens()
    old_init = "mUnderflowWidth = mIconDotFrameWidth + (MAX_DOTS - 1) * (mStaticDotDiameter + mDotPadding);"
    new_init = "mUnderflowWidth = mIconDotFrameWidth + (MAX_DOTS - 1) * (mStaticDotDiameter + mDotPadding);\n        mIconSpacing = getResources().getDisplayMetrics().density * 6.5f;"
    sic = sic.replace(old_init, new_init)

    # Measure in onMeasure()
    old_meas = """            } else {
                totalWidth += getViewTotalMeasuredWidth(child);
            }
        }"""
    new_meas = """            } else {
                totalWidth += getViewTotalMeasuredWidth(child);
            }
            totalWidth += (int) mIconSpacing;
        }"""
    sic = sic.replace(old_meas, new_meas)

    # Offset in calculateIconTranslations()
    old_calc = """            translationX -= getViewTotalWidth(child);
        }"""
    new_calc = """            translationX -= getViewTotalWidth(child);
            if (child instanceof StatusBarWifiView) {
                translationX += getResources().getDisplayMetrics().density * 2.5f;
            } else {
                translationX -= mIconSpacing;
            }
        }"""
    sic = sic.replace(old_calc, new_calc)

    with open(sic_path, 'w', encoding='utf-8') as f:
        f.write(sic)
    print("--> Successfully applied 6.5dp icon spacing to StatusIconContainer.java.")
PYEOF
fi

echo "=== Battery & Icon Spacing Patch Application Complete ==="
