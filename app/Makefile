# ---------------------------------------------------------------------------
#  VLC 9 - reproductor multimedia para iOS 9 (armv7 / iPad mini 1)
#
#  Motor: MobileVLCKit 3.7.4 (framework dinamico, rebanada armv7).
#  La app se compila con Theos y se firma ad-hoc con ldid.
#
#  Compilar:  make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

# La app usa APIs marcadas como obsoletas (iOS 9) y VLCKit tiene avisos
# propios; no queremos que -Werror rompa la compilacion.
GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VLC9

VLC9_FILES = \
	main.m \
	AppDelegate.m \
	OVTheme.m \
	OVMediaItem.m \
	OVLibrary.m \
	OVThumbnailCache.m \
	OVMediaCell.m \
	OVLibraryViewController.m \
	OVFolderBrowserViewController.m \
	OVPlayerViewController.m \
	OVPlaylistViewController.m \
	OVNetworkViewController.m \
	OVSettingsViewController.m

VLC9_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo AudioToolbox \
	CoreGraphics QuartzCore MobileCoreServices MediaPlayer Security CFNetwork \
	OpenGLES CoreText VideoToolbox

VLC9_CFLAGS = -fobjc-arc \
	-Fvendor \
	-Ivendor/MobileVLCKit.framework/Headers \
	-Wno-deprecated-declarations \
	-Wno-unused-parameter \
	-Wno-nullability-completeness \
	-Wno-objc-missing-super-calls

VLC9_LDFLAGS = -Fvendor \
	-framework MobileVLCKit \
	-lc++ -lxml2 -lz -lbz2 -liconv \
	-Wl,-rpath,@executable_path/Frameworks \
	-Wl,-rpath,@loader_path/Frameworks \
	-Wl,-dead_strip

VLC9_RESOURCE_DIRS = Resources

VLC9_CODESIGN_FLAGS = -Sentitlements.plist

# El framework viaja dentro de VLC9.app/Frameworks y se firma ad-hoc antes
# de que Theos empaquete la app. Su install name ya es
# @rpath/MobileVLCKit.framework/MobileVLCKit.
before-package::
	@echo ">> Incrustando MobileVLCKit.framework"
	@mkdir -p "$(THEOS_STAGING_DIR)/Applications/VLC9.app/Frameworks"
	@rm -rf "$(THEOS_STAGING_DIR)/Applications/VLC9.app/Frameworks/MobileVLCKit.framework"
	@cp -R "vendor/MobileVLCKit.framework" "$(THEOS_STAGING_DIR)/Applications/VLC9.app/Frameworks/"
	@chmod +x "$(THEOS_STAGING_DIR)/Applications/VLC9.app/Frameworks/MobileVLCKit.framework/MobileVLCKit"
	@set -e; \
	LDID=$$(command -v ldid 2>/dev/null || true); \
	if [ -z "$$LDID" ] && [ -x "$(THEOS)/bin/ldid" ]; then LDID="$(THEOS)/bin/ldid"; fi; \
	if [ -z "$$LDID" ]; then \
		echo "ERROR: ldid no encontrado; no se puede firmar MobileVLCKit"; \
		exit 1; \
	fi; \
	echo ">> Firmando MobileVLCKit con $$LDID"; \
	"$$LDID" -S "$(THEOS_STAGING_DIR)/Applications/VLC9.app/Frameworks/MobileVLCKit.framework/MobileVLCKit"
	@echo ">> Framework listo en VLC9.app/Frameworks"

include $(THEOS_MAKE_PATH)/application.mk
