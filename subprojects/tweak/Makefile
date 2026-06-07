TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ActivatorTweak

ActivatorTweak_FILES += ActivatorTweak.m
ActivatorTweak_FILES += LATBuiltInListenerRegistry.m
ActivatorTweak_FILES += LATNothingListener.m

ActivatorTweak_CFLAGS += -fobjc-arc
ActivatorTweak_CFLAGS += -I../../include
ActivatorTweak_CFLAGS += -I../libactivator

ActivatorTweak_FRAMEWORKS += Foundation
ActivatorTweak_FRAMEWORKS += UIKit

ActivatorTweak_LIBRARIES += activator

include $(THEOS_MAKE_PATH)/tweak.mk
