#!/bin/tcsh
cd ./Core
tar xzfk irssi.tar.gz
cd ./irssi
make distclean
./configure --with-modules --enable-ipv6 --enable-ssl --without-textui --without-perl

cd ../..

cd ./Frameworks
tar xzf frameworks.tar.gz
