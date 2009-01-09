INSTALL_DIR := $(shell if [[ -d $(HOME)/Applications/Colloquy.app ]]; then echo $(HOME)/Applications; else echo /Applications; fi)
BUILD_DIR = build/Release
PRODUCT_NAME = Colloquy.app

CP = ditto --rsrc
RM = rm
COMMON_XCODE_OPTIONS = -project Colloquy.xcodeproj -target 'Colloquy (Application)'

all release r:
	xcodebuild $(COMMON_XCODE_OPTIONS) -configuration Release build

development dev d:
	xcodebuild $(COMMON_XCODE_OPTIONS) -configuration Development build

clean c:
	xcodebuild -project Colloquy.xcodeproj -alltargets clean

clean-all ca:
	xcodebuild -project Colloquy.xcodeproj -alltargets clean -configuration Release
	xcodebuild -project Colloquy.xcodeproj -alltargets clean -configuration Development

install i: r
	-$(RM) -rf $(INSTALL_DIR)/$(PRODUCT_NAME)
	$(CP) $(BUILD_DIR)/$(PRODUCT_NAME) $(INSTALL_DIR)/$(PRODUCT_NAME)

zip z: ca r
	ditto -c -k --keepParent --sequesterRsrc $(BUILD_DIR)/$(PRODUCT_NAME) $(BUILD_DIR)/$(PRODUCT_NAME).zip
