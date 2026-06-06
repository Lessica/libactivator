TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := Activator

Activator_FILES += main.m
Activator_FILES += LAAppDelegate.m

Activator_CFLAGS += -fobjc-arc
Activator_CFLAGS += -I../../include

Activator_FRAMEWORKS += Foundation
Activator_FRAMEWORKS += UIKit

include $(THEOS_MAKE_PATH)/application.mk
