#!/bin/sh
cd "`echo $0 | sed 's/[^/]*$//'`"

cd ./Core
rm -rf ./irssi
cvs update -dP irssi
tar xzfk irssi.tar.gz >/dev/null 2>&1
cd ./irssi
make distclean
./configure --enable-ipv6 --disable-ssl --disable-shared --disable-glibtest --with-modules --without-textui --without-bot --without-proxy --without-perl SDKROOT=/Developer/SDKs/MacOSX10.2.8.sdk

cd ../..

cd ./Frameworks
rm -rf ./*.framework
tar xzf frameworks.tar.gz
