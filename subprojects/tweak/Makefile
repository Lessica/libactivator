TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ActivatorSpringBoard

ActivatorSpringBoard_FILES += ActivatorSpringBoard.m

ActivatorSpringBoard_CFLAGS += -fobjc-arc
ActivatorSpringBoard_CFLAGS += -I../../include

ActivatorSpringBoard_FRAMEWORKS += Foundation
ActivatorSpringBoard_FRAMEWORKS += UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
