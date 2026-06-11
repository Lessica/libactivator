TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME := libactivator-tests

libactivator-tests_FILES += main.m
libactivator-tests_FILES += LATestRunner.m
libactivator-tests_FILES += LATestRunnerRecorder.m
libactivator-tests_FILES += runner/LATestClientFacadeSuite.m
libactivator-tests_FILES += runner/LATestRunnerResultPrinter.m
libactivator-tests_FILES += runner/LATestRuntimeStatePrinter.m
libactivator-tests_FILES += runner/LATestSpringBoardClient.m
libactivator-tests_CFLAGS += -fobjc-arc
libactivator-tests_CFLAGS += -DLA_TESTING=1
libactivator-tests_CFLAGS += -I.
libactivator-tests_CFLAGS += -Irunner
libactivator-tests_CFLAGS += -I../include
libactivator-tests_CFLAGS += -I../subprojects/libactivator
libactivator-tests_CODESIGN_FLAGS += -Splatformize.entitlements
libactivator-tests_FRAMEWORKS += Foundation
libactivator-tests_FRAMEWORKS += UIKit
libactivator-tests_PRIVATE_FRAMEWORKS += AppSupport
libactivator-tests_LIBRARIES += activator
libactivator-tests_INSTALL_PATH := /usr/libexec/libactivator

include $(THEOS_MAKE_PATH)/tool.mk
