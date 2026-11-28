#
# SPDX-FileCopyrightText: 2026 The LineageOS Project
# SPDX-FileCopyrightText: 2026 The Clover Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from PL2 device
$(call inherit-product, device/nokia/PL2/device.mk)

# Inherit some common Clover stuff
$(call inherit-product, vendor/clover/config/common_full_phone.mk)

PRODUCT_BRAND := Nokia
PRODUCT_DEVICE := PL2
PRODUCT_MANUFACTURER := HMD Global
PRODUCT_MODEL := Nokia 6.1
PRODUCT_NAME := clover_PL2

PRODUCT_GMS_CLIENTID_BASE := android-hmd

# Set Clover build device identifier if not already defined
CLOVER_BUILD ?= PL2
CLOVER_BUILDTYPE := OFFICIAL
CLOVER_MAINTAINER ?= Abhi

TARGET_ENABLE_BLUR := false

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="Plate2_00WW-user 10 QKQ1.190828.002 00WW_4_15O release-keys" \
    DeviceProduct=PL2_sprout

$(call inherit-product, device/nokia/PL2/gms_core.mk)
