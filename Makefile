INSTALL_DIR:=$(shell if [[ -d $(HOME)/Applications/Colloquy.app ]]; then echo $(HOME)/Applications; else echo /Applications; fi)
BUILD_DIR=build/Release
PRODUCT_NAME=Colloquy.app

CP=ditto --rsrc
RM=rm

all release r:
	xcodebuild -project Colloquy.xcodeproj -target 'Colloquy (Application)' -configuration Release build

universal u:
	xcodebuild -project Colloquy.xcodeproj -target 'Colloquy (Application)' -configuration 'Release (Universal)' build

development dev d:
	xcodebuild -project Colloquy.xcodeproj -target 'Colloquy (Application)' -configuration Development build

clean c:
	xcodebuild -project Colloquy.xcodeproj -alltargets clean

install i:
	-$(RM) -rf $(INSTALL_DIR)/$(PRODUCT_NAME)
	$(CP) $(BUILD_DIR)/$(PRODUCT_NAME) $(INSTALL_DIR)/$(PRODUCT_NAME)
