INSTALL_DIR := $(shell if [[ -d $(HOME)/Applications/Colloquy.app ]]; then echo $(HOME)/Applications; else echo /Applications; fi)
BUILD_DIR = build/Release
PRODUCT_NAME = Colloquy.app

CP = ditto --rsrc
RM = rm
COMMON_XCODE_OPTIONS = -project Colloquy.xcodeproj -target 'Colloquy (Application)'
IGNORE_COMMAND = grep -v setenv && exit $${PIPESTATUS[0]}

all release r:
	( xcodebuild $(COMMON_XCODE_OPTIONS)  -configuration Release build | $(IGNORE_COMMAND) )

universal u:
	( xcodebuild $(COMMON_XCODE_OPTIONS)  -configuration 'Release (Universal)' build | $(IGNORE_COMMAND) )

development dev d:
	( xcodebuild $(COMMON_XCODE_OPTIONS)  -configuration Development build | $(IGNORE_COMMAND) )

clean c:
	xcodebuild -project Colloquy.xcodeproj -alltargets clean

install i:
	-$(RM) -rf $(INSTALL_DIR)/$(PRODUCT_NAME)
	$(CP) $(BUILD_DIR)/$(PRODUCT_NAME) $(INSTALL_DIR)/$(PRODUCT_NAME)
