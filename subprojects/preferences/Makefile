TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME := LAPreferences

LAPreferences_FILES += LAPreferencesBundle.m

LAPreferences_CFLAGS += -fobjc-arc
LAPreferences_CFLAGS += -I../../include

LAPreferences_FRAMEWORKS += Foundation
LAPreferences_FRAMEWORKS += UIKit
LAPreferences_PRIVATE_FRAMEWORKS += Preferences

LAPreferences_INSTALL_PATH := /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
