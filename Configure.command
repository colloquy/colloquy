#!/bin/sh
cd "`echo $0 | sed 's/[^/]*$//'`"

cd ./Core
rm -rf ./irssi
if [[ ! -d .svn && -x /usr/bin/svk ]]; then
	svk revert -R  irssi
else
	svn update irssi
fi
tar xzfk irssi.tar.gz >/dev/null 2>&1
cd ./irssi
make distclean
./configure --enable-ipv6 --enable-ssl --disable-shared --disable-glibtest --with-modules --without-textui --without-bot --without-proxy --without-perl SDKROOT=/Developer/SDKs/MacOSX10.3.0.sdk

cd ../..

cd ./Frameworks
rm -rf ./*.framework
tar xzf frameworks.tar.gz
