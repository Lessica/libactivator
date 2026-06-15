export PACKAGE_VERSION := 2.0.0

TARGET := iphone:clang:16.5:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := SpringBoard Camera MobilePhone

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

ifeq ($(LIBACTIVATOR_TEST_SUPPORT),1)
TEST_SUPPORT_MAKE_GOALS := all stage
ifneq ($(filter commands,$(MAKECMDGOALS)),)
TEST_SUPPORT_MAKE_GOALS := commands stage
else ifneq ($(filter clean,$(MAKECMDGOALS)),)
TEST_SUPPORT_MAKE_GOALS := clean all stage
endif
after-stage::
	$(ECHO_NOTHING)$(MAKE) -C tests THEOS_PROJECT_DIR=$(CURDIR)/tests $(TEST_SUPPORT_MAKE_GOALS) LIBACTIVATOR_TEST_SUPPORT=1$(ECHO_END)
endif

include $(THEOS_MAKE_PATH)/package.mk
