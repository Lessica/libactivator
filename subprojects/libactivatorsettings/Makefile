TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := libactivatorsettings

libactivatorsettings_FILES += LASettingsLibrary.m

libactivatorsettings_CFLAGS += -fobjc-arc

libactivatorsettings_FRAMEWORKS += Foundation

libactivatorsettings_INSTALL_PATH := /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
