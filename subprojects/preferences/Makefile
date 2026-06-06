TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := ActivatorPreferences

ActivatorPreferences_FILES += ActivatorPreferencesBundle.m

ActivatorPreferences_CFLAGS += -fobjc-arc
ActivatorPreferences_CFLAGS += -I../../include

ActivatorPreferences_FRAMEWORKS += Foundation
ActivatorPreferences_FRAMEWORKS += UIKit
ActivatorPreferences_PRIVATE_FRAMEWORKS += Preferences

ActivatorPreferences_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
