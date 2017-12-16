#!/bin/bash

#  writeVersionToInfoPlist.sh
#
#
#  Created by Alexander Kempgen on 2017-12-16.
#

set -eu

INFO_PLIST=


# Parse arguments.
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --infoPlist)
        INFO_PLIST="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        exit -1
        ;;
    esac
done


# Set bundle version based on the commit count.
BUNDLE_VERSION=$(/usr/bin/git rev-list --count HEAD)


# If --infoPlist was specified, write the bundle version there, otherwise echo it.
if [[ -n "${INFO_PLIST}" ]]; then
    /usr/libexec/PlistBuddy -c "set :CFBundleVersion ${BUNDLE_VERSION}" ${INFO_PLIST}
else
    echo $COMMITS
fi
