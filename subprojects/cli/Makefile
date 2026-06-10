TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME := activator

activator_FILES += main.m

activator_CFLAGS += -fobjc-arc
activator_CFLAGS += -I../../include
activator_CODESIGN_FLAGS += -Splatformize.entitlements
activator_LIBRARIES += activator
activator_FRAMEWORKS += Foundation

include $(THEOS_MAKE_PATH)/tool.mk
