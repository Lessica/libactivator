TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := libactivatorsettings

libactivatorsettings_FILES += ../common/LAPath.m
libactivatorsettings_FILES += LASettingsPlaceholder.m

libactivatorsettings_CFLAGS += -fobjc-arc
libactivatorsettings_CFLAGS += -I../common
libactivatorsettings_CFLAGS += -I../../include

libactivatorsettings_FRAMEWORKS += Foundation
libactivatorsettings_FRAMEWORKS += UIKit

libactivatorsettings_INSTALL_PATH := /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
