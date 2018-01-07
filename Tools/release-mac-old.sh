#!/bin/sh

#  release-mac-old.sh
#  
#
#  Created by Alexander Kempgen on 2018-01-06.
#  

set -eu


# MARK: Define variables.
CQ_VERSION_COLLOQUY=$(Tools/writeVersionToInfoPlist.sh)
CQ_VERSION_BOUNCER=$(xcrun git -C "../bouncer" rev-list --count HEAD)

CQ_BUILD_DIR="build/${CQ_VERSION_COLLOQUY}_${CQ_VERSION_BOUNCER}"
CQ_DERIVED_DATA_DIR="$CQ_BUILD_DIR/derived-data"

CQ_BUILT_PRODUCTS_DIR="$CQ_DERIVED_DATA_DIR/Build/Products/Release"
CQ_APP_NAME="Colloquy.app"
CQ_ZIP_NAME="Colloquy_${CQ_VERSION_COLLOQUY}_with_Bouncer_${CQ_VERSION_BOUNCER}.zip"

CQ_APP="$CQ_BUILT_PRODUCTS_DIR/$CQ_APP_NAME"
CQ_ZIP="$CQ_BUILD_DIR/$CQ_ZIP_NAME"


# MARK: Define the commands.
CQ_CLEAN_DERIVED_DATA_CMD=(rm -rf $CQ_DERIVED_DATA_DIR)

CQ_BUILD_CMD=(
    xcodebuild
    build
    -quiet
    -workspace Colloquy.xcworkspace
    -configuration Release
    -derivedDataPath $CQ_DERIVED_DATA_DIR
)

CQ_BUILD_COLLOQUY_CMD=(${CQ_BUILD_CMD[@]} -scheme "Colloquy (Aggregate)")
CQ_BUILD_BOUNCER_CMD=(${CQ_BUILD_CMD[@]} -scheme "Colloquy Bouncer (Plug-In)")

CQ_ZIP_CMD=(ditto -c -k --sequesterRsrc --keepParent $CQ_APP $CQ_ZIP)


# MARK: Run the commands.
"${CQ_CLEAN_DERIVED_DATA_CMD[@]}"
"${CQ_BUILD_COLLOQUY_CMD[@]}"
"${CQ_BUILD_BOUNCER_CMD[@]}"
"${CQ_BUILD_COLLOQUY_CMD[@]}"
"${CQ_ZIP_CMD[@]}"
