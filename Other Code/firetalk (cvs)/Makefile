OBJECTS = firetalk.o dummy.o irc.o safestring.o
INFLAGS=-DDISABLE_TOC_PROTOCOL -D_FC_USE_IPV6

all: static

compat: compat-static

static:
	MYFLAGS="-O3 -fexpensive-optimizations -funroll-loops ${INFLAGS}" CC="gcc" MYLIBS="-lm ${INLIBS}" ${MAKE} libfiretalk.a

shared:
	MYFLAGS="-O3 -fexpensive-optimizations -funroll-loops ${INFLAGS}" CC="gcc" MYLIBS="-lm ${INLIBS}" ${MAKE} libfiretalk.so

compat-static:
	MYFLAGS="${INFLAGS}" CC="cc" MYLIBS="-lm ${INLIBS}" ${MAKE} libfiretalk.a
	
gui:
	MYFLAGS="-O3 -fexpensive-optimizations -funroll-loops ${INFLAGS}" CC="gcc" MYLIBS="-lm ${INLIBS}" ${MAKE} firetalk

test:
	MYFLAGS="-O3 -fexpensive-optimizations -funroll-loops ${INFLAGS}" CC="gcc" MYLIBS="-lm ${INLIBS}" ${MAKE} tester

debug:
	${MAKE} clean
	CFLAGS="" MYFLAGS="-DDEBUG -Wall -ansi -pedantic -g -fbounds-checking ${INFLAGS}" CC="gcc" MYLIBS="-lm ${INLIBS}" ${MAKE} firetalk tester

gdb:
	${MAKE} clean
	CFLAGS="" MYFLAGS="-DDEBUG -Wall -ansi -pedantic -g ${INFLAGS}" CC="gcc" MYLIBS="-lm ${INLIBS}" ${MAKE} firetalk tester

safestring.o: safestring.c safestring.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c safestring.c

dummy.o: dummy.c dummy.h firetalk.h firetalk-int.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c dummy.c

irc.o: irc.c irc.h firetalk.h firetalk-int.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c irc.c

toc.o: toc.c toc.h firetalk.h firetalk-int.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c toc.c

oscar.o: oscar.c oscar.h firetalk.h firetalk-int.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c oscar.c

aim.o: aim.h aim.c Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c aim.c

firetalk.o: firetalk.c toc.h irc.h oscar.h aim.h firetalk.h firetalk-int.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c firetalk.c

libfiretalk.a: $(OBJECTS) Makefile
	rm -f libfiretalk.a
	ar cru libfiretalk.a $(OBJECTS)
	ranlib libfiretalk.a

gui.o: gui.c firetalk.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c gui.c

tester.o: tester.c firetalk.h Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -c tester.c

firetalk: libfiretalk.a gui.o Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) -lcurses $(LIBS) $(MYLIBS) -o firetalk gui.o libfiretalk.a

tester: libfiretalk.a tester.o Makefile
	$(CC) $(CFLAGS) $(MYFLAGS) $(LIBS) $(MYLIBS) -o tester tester.o safestring.o libfiretalk.a

clean:
	rm -f *.o *.a *.so firetalk tester

install: libfiretalk.so firetalk.h
	cp -f libfiretalk.so /usr/local/lib
	cp -f firetalk.h /usr/local/include

distclean: clean
