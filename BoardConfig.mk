#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-FileCopyrightText: The Clover Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/nokia/PL2

# Partitions
BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE := 3221225472
BOARD_SUPER_PARTITION_VENDOR_DEVICE_SIZE := 1073741824

# Inherit from nokia sdm660-common
-include device/nokia/sdm660-common/BoardConfigCommon.mk

# Inherit from Clover
-include vendor/clover/config/BoardConfigClover.mk
-include vendor/clover/config/BoardConfigReservedSize.mk

# Architecture
TARGET_CPU_VARIANT_RUNTIME := cortex-a53
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

# Assertions
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt
TARGET_OTA_ASSERT_DEVICE := PL2,PL2_sprout,Plate2

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := sdm630

# Display
TARGET_SCREEN_DENSITY := 420

# HIDL
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/manifest.xml

# Kernel
TARGET_KERNEL_CONFIG += vendor/nokia/PL2.config

# Properties
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Inherit from the proprietary version
include vendor/nokia/PL2/BoardConfigVendor.mk
