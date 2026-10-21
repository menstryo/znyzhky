TARGET := iphone:clang:9.3:6.0
ARCHS = armv7
INSTALL_TARGET_PROCESSES = Znyzhky
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Znyzhky
Znyzhky_FILES = main.m ZNTheme.m ZNStore.m ZNRequest.m ZNImageLoader.m ZNDealCell.m ZNGridCell.m ZNGridViewController.m \
	ZNFiltersViewController.m ZNShoppingListViewController.m ZNDealViewController.m ZNSettingsViewController.m ZNLeafletsViewController.m
Znyzhky_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
Znyzhky_CFLAGS = -fno-objc-arc -Wno-unknown-warning-option -fno-modules -Wno-deprecated-declarations -Wno-unused-variable -Wno-deprecated-module-dot-map

include $(THEOS_MAKE_PATH)/application.mk
