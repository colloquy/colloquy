INSTALL_DIR:=$(shell if [[ -d $(HOME)/Applications/Colloquy.app ]]; then echo $(HOME)/Applications; else echo /Applications; fi)
BUILD_DIR=build
PRODUCT_NAME=Colloquy.app

CP=ditto --rsrc
RM=rm

all:
	xcodebuild -project Colloquy.xcodeproj -target 'Colloquy (Application)' -configuration Release build

universal:
	xcodebuild -project Colloquy.xcodeproj -target 'Colloquy (Application)' -configuration 'Release (Universal)' build

development:
	xcodebuild -project Colloquy.xcodeproj -target 'Colloquy (Application)' -configuration Development build

clean:
	xcodebuild -project Colloquy.xcodeproj -alltargets clean

install:
	-$(RM) -rf $(INSTALL_DIR)/$(PRODUCT_NAME)
	$(CP) $(BUILD_DIR)/$(PRODUCT_NAME) $(INSTALL_DIR)/$(PRODUCT_NAME)
