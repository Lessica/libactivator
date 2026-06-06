TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := libactivator

libactivator_FILES += ../common/LAPath.m
libactivator_FILES += LAActivatorPlaceholder.m

libactivator_CFLAGS += -fobjc-arc
libactivator_CFLAGS += -I../common
libactivator_CFLAGS += -I../../include

libactivator_FRAMEWORKS += Foundation
libactivator_FRAMEWORKS += UIKit
libactivator_FRAMEWORKS += CoreGraphics

libactivator_INSTALL_PATH := /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
