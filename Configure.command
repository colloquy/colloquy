#!/bin/sh
cd "`echo $0 | sed 's/[^/]*$//'`"

cd ./Core
rm -rf ./irssi
if [[ ! -d .svn && -x /usr/bin/svk ]]; then
	svk revert -R  irssi
else
	svn update irssi
fi

if (( $? != 0 )); then
	echo "ERROR! Make sure svn or svk is in your path. Can't proceed until this is done."
	exit 2
fi

tar xzfk irssi.tar.gz >/dev/null 2>&1

#cd ./irssi
#make distclean

#SDK=/Developer/SDKs/MacOSX10.4u.sdk
#CFLAGS="-isysroot ${SDK} -arch ppc"
#LDFLAGS="-isysroot ${SDK} -Wl,-syslibroot,${SDK}"

#export CFLAGS
#export LDFLAGS

#./configure --enable-ipv6 --enable-ssl --disable-shared --disable-glibtest --without-modules --without-textui --without-bot --without-proxy --without-perl

cd ..

cd ./Frameworks
rm -rf ./*.framework
tar xzf frameworks.tar.gz
