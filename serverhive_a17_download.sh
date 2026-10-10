#!/bin/bash
set -e

START_TIME=$(date +%s)
echo "=== LineageOS 24.0 (Android 17) Repository Downloader for Nokia 6.1 (PL2) ==="
echo "Target Platform: ServerHive Bare-Metal Host"

# 1. Clean broken Windows-copied git cookie configuration if present
if git config --global --get http.cookiefile 2>/dev/null | grep -qi "USERPROFILE"; then
    echo "--> Clearing invalid Windows cookiefile from Linux git config..."
    git config --global --unset http.cookiefile || true
fi

# 2. Base Manifest Initialization (LineageOS 24.0 / Android 17)
echo "--> Initializing LineageOS 24.0 base manifest..."
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --depth=1

# 3. Local Manifest Deployment
echo "--> Deploying PL2 local manifest for Android 17 (LineageOS 24.0)..."
mkdir -p .repo/local_manifests
cat << "EOF" > .repo/local_manifests/PL2.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Remove default HAL & sepolicy paths to allow custom CAF / legacy trees -->
  <remove-project name="LineageOS/android_hardware_qcom_audio" />
  <remove-project name="LineageOS/android_hardware_qcom_display" />
  <remove-project name="LineageOS/android_hardware_qcom_media" />
  <remove-project name="LineageOS/android_device_qcom_sepolicy" />
  <remove-project name="LineageOS/android_hardware_lineage_compat" />

  <!-- Core Zoro-15 Forked Repositories (lineage-24.0 branch) -->
  <project path="device/nokia/sdm660-common" name="Zoro-15/android_device_nokia_sdm660-common" remote="github" revision="lineage-24.0" />
  <project path="device/nokia/PL2" name="Zoro-15/android_device_nokia_PL2" remote="github" revision="lineage-24.0" />
  <project path="vendor/nokia/sdm660-common" name="Zoro-15/proprietary_vendor_nokia_sdm660-common" remote="github" revision="lineage-24.0" />
  <project path="vendor/nokia/PL2" name="Zoro-15/proprietary_vendor_nokia_PL2" remote="github" revision="lineage-24.0" />
  <project path="kernel/nokia/sdm660" name="Zoro-15/android_kernel_nokia_sdm660_419" remote="github" revision="lineage-24.0" />

  <!-- Qualcomm CAF HALs & Compatibility Trees for SDM660 (lineage-24.0) -->
  <project path="hardware/qcom-caf/sdm660/audio" name="LineageOS/android_hardware_qcom_audio" remote="github" revision="lineage-24.0-caf-sdm660" />
  <project path="hardware/qcom-caf/sdm660/display" name="LineageOS/android_hardware_qcom_display" remote="github" revision="lineage-24.0-caf-msm8953" />
  <project path="hardware/qcom-caf/sdm660/media" name="LineageOS/android_hardware_qcom_media" remote="github" revision="lineage-24.0-caf-msm8953" />
  <project path="device/qcom/sepolicy-legacy-um" name="LineageOS/android_device_qcom_sepolicy" remote="github" revision="lineage-24.0-legacy-um" />
  <project path="hardware/lineage/compat" name="LineageOS/android_hardware_lineage_compat" remote="github" revision="lineage-24.0" />
  <project path="hardware/samsung_slsi/nfc" name="LineageOS/android_hardware_samsung_slsi_nfc" remote="github" revision="lineage-24.0" />
</manifest>
EOF

# 4. Abort any stuck rebases/merges before syncing
echo "--> Aborting any stuck rebases across tree before sync..."
CUSTOM_DIRS=(
    "device/nokia/PL2"
    "device/nokia/sdm660-common"
    "vendor/nokia/PL2"
    "vendor/nokia/sdm660-common"
    "kernel/nokia/sdm660"
    "hardware/qcom-caf/sdm660/audio"
    "hardware/qcom-caf/sdm660/display"
    "hardware/qcom-caf/sdm660/media"
    "device/qcom/sepolicy-legacy-um"
    "hardware/lineage/compat"
    "hardware/samsung_slsi/nfc"
)

for d in "${CUSTOM_DIRS[@]}"; do
    if [ -d "$d/.git" ]; then
        git -C "$d" rebase --abort 2>/dev/null || true
        git -C "$d" merge --abort 2>/dev/null || true
    fi
done

# 5. Repo Sync Execution
echo "--> Syncing source repositories (Optimized flags for ServerHive)..."
set +e
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
SYNC_STATUS=$?
set -e

if [ $SYNC_STATUS -ne 0 ]; then
    echo "[WARNING] repo sync returned code $SYNC_STATUS. Proceeding to fallback clones to guarantee all repositories are present..."
fi

# 6. Fallback Clones & Fast Updates (Guarantees all required custom trees are present & up to date)
echo "--> Verifying and updating custom repository checkouts..."
REPOS_TO_SYNC=(
    "device/nokia/PL2:lineage-24.0:https://github.com/Zoro-15/android_device_nokia_PL2.git"
    "device/nokia/sdm660-common:lineage-24.0:https://github.com/Zoro-15/android_device_nokia_sdm660-common.git"
    "vendor/nokia/PL2:lineage-24.0:https://github.com/Zoro-15/proprietary_vendor_nokia_PL2.git"
    "vendor/nokia/sdm660-common:lineage-24.0:https://github.com/Zoro-15/proprietary_vendor_nokia_sdm660-common.git"
    "kernel/nokia/sdm660:lineage-24.0:https://github.com/Zoro-15/android_kernel_nokia_sdm660_419.git"
    "hardware/qcom-caf/sdm660/audio:lineage-24.0-caf-sdm660:https://github.com/LineageOS/android_hardware_qcom_audio.git"
    "hardware/qcom-caf/sdm660/display:lineage-24.0-caf-msm8953:https://github.com/LineageOS/android_hardware_qcom_display.git"
    "hardware/qcom-caf/sdm660/media:lineage-24.0-caf-msm8953:https://github.com/LineageOS/android_hardware_qcom_media.git"
    "device/qcom/sepolicy-legacy-um:lineage-24.0-legacy-um:https://github.com/LineageOS/android_device_qcom_sepolicy.git"
    "hardware/lineage/compat:lineage-24.0:https://github.com/LineageOS/android_hardware_lineage_compat.git"
    "hardware/samsung_slsi/nfc:lineage-24.0:https://github.com/LineageOS/android_hardware_samsung_slsi_nfc.git"
)

for entry in "${REPOS_TO_SYNC[@]}"; do
    IFS=":" read -r target_path target_branch repo_url <<< "$entry"
    if [ -d "$target_path/.git" ]; then
        REMOTE_NAME=$(git -C "$target_path" remote 2>/dev/null | head -n 1 || echo "origin")
        echo "--> Updating $target_path ($target_branch)..."
        git -C "$target_path" rebase --abort 2>/dev/null || true
        git -C "$target_path" merge --abort 2>/dev/null || true
        git -C "$target_path" fetch "$REMOTE_NAME" "$target_branch" --depth=1 2>/dev/null || true
        git -C "$target_path" reset --hard "FETCH_HEAD" 2>/dev/null || true
    else
        echo "--> Cloning missing repository: $target_path from $repo_url ($target_branch)..."
        mkdir -p "$(dirname "$target_path")"
        git clone --depth=1 -b "$target_branch" "$repo_url" "$target_path"
    fi
done

# 7. Supplemental Opensource Display Repos (Display metadata dependencies)
if [ ! -d "vendor/qcom/opensource/display" ]; then
    echo "--> Cloning vendor/qcom/opensource/display (lineage-24.0)..."
    git clone --depth=1 -b lineage-24.0 https://github.com/LineageOS/android_vendor_qcom_opensource_display.git vendor/qcom/opensource/display 2>/dev/null || true
fi
if [ ! -d "vendor/qcom/opensource/commonsys-intf/display" ]; then
    echo "--> Cloning vendor/qcom/opensource/commonsys-intf/display (lineage-24.0)..."
    git clone --depth=1 -b lineage-24.0 https://github.com/LineageOS/android_vendor_qcom_opensource_display-commonsys-intf.git vendor/qcom/opensource/commonsys-intf/display 2>/dev/null || true
fi

# Remove duplicate libqdmetadata from generic display repo (sdm660 uses hardware/qcom-caf/sdm660/display/libqdutils)
rm -rf vendor/qcom/opensource/display/libqdmetadata

# 8. Ensure Dummy Soong Namespaces
echo "--> Setting up Soong namespaces for sdm660 CAF HALs..."
mkdir -p hardware/qcom-caf/sdm660 hardware/qcom-caf/msm8998
echo "soong_namespace {}" > hardware/qcom-caf/sdm660/Android.bp
echo "soong_namespace {}" > hardware/qcom-caf/msm8998/Android.bp

# Remove any rogue roomservice manifest generated by breakfast/lunch
rm -f .repo/local_manifests/roomservice.xml

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "=== Android 17 (LineageOS 24.0) Source Repositories Ready! (took $((ELAPSED / 60))m $((ELAPSED % 60))s) ==="
