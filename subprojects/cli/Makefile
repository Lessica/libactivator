TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME += activator
TOOL_NAME += user-reboot

PACKAGE_VERSION ?= unknown

activator_FILES += main.m
activator_FILES += LACommandLineTool.m
activator_CFLAGS += -fobjc-arc
activator_CFLAGS += -I../../include
activator_CFLAGS += -I../libactivator
activator_CFLAGS += -DPACKAGE_VERSION=\"$(PACKAGE_VERSION)\"
activator_CODESIGN_FLAGS += -Splatformize.entitlements
activator_LIBRARIES += activator
activator_FRAMEWORKS += Foundation

user-reboot_FILES += user-reboot.c
user-reboot_CODESIGN_FLAGS += -Suser-reboot.entitlements
user-reboot_INSTALL_PATH := /usr/libexec/activator

include $(THEOS_MAKE_PATH)/tool.mk
