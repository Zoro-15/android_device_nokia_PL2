#
# Copyright (C) 2020 The LineageOS Project
# Copyright (C) 2026 ArrowOS
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, vendor/arrow/config/common.mk)
$(call inherit-product, device/nokia/PL2/device.mk)

TARGET_SCREEN_HEIGHT := 1920
TARGET_SCREEN_WIDTH := 1080
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi
TARGET_BOOT_ANIMATION_RES := 1080
TARGET_OTA_ASSERT_DEVICE := PL2,PL2_sprout,Plate2

PRODUCT_NAME := arrow_PL2
PRODUCT_DEVICE := PL2
PRODUCT_BRAND := Nokia
PRODUCT_MODEL := Nokia 6.1
PRODUCT_MANUFACTURER := HMD Global

ARROW_BUILD_TYPE := UNOFFICIAL
ARROW_MAINTAINER := Zoro-15
PRODUCT_PROPERTY_OVERRIDES += \
    ro.arrow.maintainer=Zoro-15 \
    ro.lineage.maintainer=Zoro-15 \
    ro.build.maintainer=Zoro-15

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_DEVICE=PL2_sprout \
    PRODUCT_NAME=Plate2_00WW \
    PRIVATE_BUILD_DESC="Plate2_00WW-user 10 QKQ1.190828.002 00WW_4_15O release-keys"

BUILD_FINGERPRINT := Nokia/Plate2_00WW/PL2_sprout:10/QKQ1.190828.002/00WW_4_15O:user/release-keys
PRODUCT_GMS_CLIENTID_BASE := android-hmd
