INSTALL_DIR=$(HOME)/Applications
BUILD_DIR=build
PRODUCT_NAME=Colloquy.app

CP=ditto --rsrc
RM=rm

all:
	xcodebuild -project Colloquy.xcode -target 'Colloquy (Application)' -buildstyle Deployment build

development:
	xcodebuild -project Colloquy.xcode -target 'Colloquy (Application)' -buildstyle Development build

clean:
	xcodebuild -project Colloquy.xcode -alltargets clean

install:
	-$(RM) -rf $(INSTALL_DIR)/$(PRODUCT_NAME)
	$(CP) $(BUILD_DIR)/$(PRODUCT_NAME) $(INSTALL_DIR)/$(PRODUCT_NAME)
