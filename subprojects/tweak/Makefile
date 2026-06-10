TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ActivatorTweak

ActivatorTweak_FILES += ActivatorTweak.m
ActivatorTweak_FILES += LATBuiltInListenerRegistry.m
ActivatorTweak_FILES += listeners/LATMediaActionListener.m
ActivatorTweak_FILES += listeners/LATNothingListener.m
ActivatorTweak_FILES += listeners/LATRingerActionListener.m
ActivatorTweak_FILES += listeners/LATURLActionListener.m

ActivatorTweak_CFLAGS += -fobjc-arc
ActivatorTweak_CFLAGS += -I.
ActivatorTweak_CFLAGS += -Ilisteners
ActivatorTweak_CFLAGS += -I../../include
ActivatorTweak_CFLAGS += -I../libactivator

ifeq ($(LA_TESTING),1)
ActivatorTweak_CFLAGS += -DLA_TESTING=1
endif

ActivatorTweak_FRAMEWORKS += Foundation
ActivatorTweak_FRAMEWORKS += UIKit

ActivatorTweak_LIBRARIES += activator

ActivatorTweak_PRIVATE_FRAMEWORKS += IOKit
ActivatorTweak_PRIVATE_FRAMEWORKS += MediaRemote
ActivatorTweak_PRIVATE_FRAMEWORKS += SpringBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk
