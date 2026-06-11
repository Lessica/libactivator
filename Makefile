export PACKAGE_VERSION := 2.0.0

TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += subprojects/libactivator
SUBPROJECTS += subprojects/cli
SUBPROJECTS += subprojects/libactivatorsettings
SUBPROJECTS += subprojects/tweak
SUBPROJECTS += subprojects/preferences
SUBPROJECTS += subprojects/app

include $(THEOS_MAKE_PATH)/aggregate.mk
export THEOS_STAGING_DIR

internal-stage::
	$(ECHO_NOTHING)scripts/stage-public-headers.sh$(ECHO_END)

ifeq ($(LA_TESTING),1)
LA_TESTING_MAKE_GOALS := all stage
ifneq ($(filter commands,$(MAKECMDGOALS)),)
LA_TESTING_MAKE_GOALS := commands stage
else ifneq ($(filter clean,$(MAKECMDGOALS)),)
LA_TESTING_MAKE_GOALS := clean all stage
endif
after-stage::
	$(ECHO_NOTHING)$(MAKE) -C tests THEOS_PROJECT_DIR=$(CURDIR)/tests $(LA_TESTING_MAKE_GOALS) LA_TESTING=1$(ECHO_END)
endif

include $(THEOS_MAKE_PATH)/package.mk
