#!/bin/sh
cd ./Core
rm -rf ./irssi
cvs update -dP irssi
tar xzfk irssi.tar.gz >/dev/null 2>&1
cd ./irssi
make distclean
./configure --with-modules --enable-ipv6 --enable-ssl --without-textui --without-perl

cd ../..

cd ./Frameworks
tar xzf frameworks.tar.gz
