#!/bin/sh
cd "`echo $0 | sed 's/[^/]*$//'`"

cd ./Core
rm -rf ./irssi
cvs update -dP irssi
tar xzfk irssi.tar.gz >/dev/null 2>&1
cd ./irssi
make distclean
./configure --with-modules --with-socks --enable-ipv6 --enable-ssl --without-textui --without-perl

cd ../..

cd ./Frameworks
rm -rf ./*.framework
tar xzf frameworks.tar.gz
