
# Makefile.in for PCRE (Perl-Compatible Regular Expression) library.


#############################################################################

# PCRE is developed on a Unix system. I do not use Windows or Macs, and know
# nothing about building software on them. Although the code of PCRE should
# be very portable, the building system in this Makefile is designed for Unix
# systems. However, there are features that have been supplied to me by various
# people that should make it work on MinGW and Cygwin systems.

# This setting enables Unix-style directory scanning in pcregrep, triggered
# by the -f option. Maybe one day someone will add code for other systems.

PCREGREP_OSTYPE=-DIS_UNIX

#############################################################################


# Libtool places .o files in the .libs directory; this can mean that "make"
# thinks is it not up-to-date when in fact it is. This setting helps when
# GNU "make" is being used. It presumably does no harm in other cases.

VPATH=.libs


#---------------------------------------------------------------------------#
# The following lines are modified by "configure" to insert data that it is #
# given in its arguments, or which it finds out for itself.                 #
#---------------------------------------------------------------------------#

SHELL = /bin/sh
prefix = /usr/local
exec_prefix = ${prefix}
top_srcdir = .

mkinstalldirs = $(SHELL) $(top_srcdir)/mkinstalldirs

# NB: top_builddir is not referred to directly below, but it is used in the
# setting of $(LIBTOOL), so don't remove it!

top_builddir = .

# BINDIR is the directory in which the pcregrep, pcretest, and pcre-config
#          commands are installed.
# INCDIR is the directory in which the public header files pcre.h and
#          pcreposix.h are installed.
# LIBDIR is the directory in which the libraries are installed.
# MANDIR is the directory in which the man pages are installed.

BINDIR = ${exec_prefix}/bin
LIBDIR = ${exec_prefix}/lib
INCDIR = ${prefix}/include
MANDIR = ${prefix}/man

# EXEEXT is set by configure to the extention of an executable file
# OBJEXT is set by configure to the extention of an object file
# The BUILD_* equivalents are the same but for the host we're building on

EXEEXT = 
OBJEXT = o
# Note that these are just here to have a convenient place to look at the
# outcome.
BUILD_EXEEXT = $(EXEEXT)
BUILD_OBJEXT = $(OBJEXT)

# POSIX_OBJ and POSIX_LOBJ are either set empty, or to the names of the
# POSIX object files.

POSIX_OBJ = 
POSIX_LOBJ = 

# The compiler, C flags, preprocessor flags, etc

CC = gcc
CXX = g++
CFLAGS = -g -O2
CXXFLAGS = -g -O2
LDFLAGS = 
CXXLDFLAGS = 

CC_FOR_BUILD = $(CC)
CFLAGS_FOR_BUILD = $(CFLAGS)
CXX_FOR_BUILD = $(CXX)
CXXFLAGS_FOR_BUILD = $(CXXFLAGS)
LDFLAGS_FOR_BUILD = $(LDFLAGS)

UCP = -DSUPPORT_UCP
UTF8 = -DSUPPORT_UTF8
NEWLINE = 
POSIX_MALLOC_THRESHOLD = -DPOSIX_MALLOC_THRESHOLD=10
LINK_SIZE = 
MATCH_LIMIT =  
NO_RECURSE = 
EBCDIC = 

INSTALL = /usr/bin/install -c
INSTALL_DATA = ${INSTALL} -m 644

# LIBTOOL enables the building of shared and static libraries. It is set up
# to do one or the other or both by ./configure.

LIBTOOL = $(SHELL) $(top_builddir)/libtool
LTCOMPILE = $(LIBTOOL) --mode=compile $(CC) -c $(CFLAGS) -I. -I$(top_srcdir) $(NEWLINE) $(LINK_SIZE) $(MATCH_LIMIT) $(NO_RECURSE) $(EBCDIC)
LTCXXCOMPILE = $(LIBTOOL) --mode=compile $(CXX) -c $(CXXFLAGS) -I. -I$(top_srcdir) $(NEWLINE) $(LINK_SIZE) $(MATCH_LIMIT) $(NO_RECURSE) $(EBCDIC)
#LINK = $(CC) $(LDFLAGS) -I. -I$(top_srcdir) -L.libs
LINK = $(LIBTOOL) --mode=link $(CC) $(CFLAGS) $(LDFLAGS) -I. -I$(top_srcdir)
LINKLIB = $(LIBTOOL) --mode=link $(CC) -export-symbols-regex '^[^_]' $(LDFLAGS) -I. -I$(top_srcdir)
LINK_FOR_BUILD = $(LIBTOOL) --mode=link $(CC_FOR_BUILD) $(CFLAGS_FOR_BUILD) $(LDFLAGS_FOR_BUILD) -I. -I$(top_srcdir)
#CXXLINK = $(CXX) $(LDFLAGS) -I. -I$(top_srcdir) -L.libs
CXXLINK = $(LIBTOOL) --mode=link $(CXX) $(CXXFLAGS) $(CXXLDFLAGS) -I. -I$(top_srcdir)
CXXLINKLIB = $(LIBTOOL) --mode=link $(CXX) $(LDFLAGS) -I. -I$(top_srcdir)

# These are the version numbers for the shared libraries

PCRELIBVERSION = 0:1:0
PCREPOSIXLIBVERSION = 0:0:0
PCRECPPLIBVERSION = 0:0:0

##############################################################################


OBJ = pcre_chartables.o \
  pcre_compile.o \
  pcre_config.o \
  pcre_dfa_exec.o \
  pcre_exec.o \
  pcre_fullinfo.o \
  pcre_get.o \
  pcre_globals.o \
  pcre_info.o \
  pcre_maketables.o \
  pcre_ord2utf8.o \
  pcre_refcount.o \
  pcre_study.o \
  pcre_tables.o \
  pcre_try_flipped.o \
  pcre_ucp_searchfuncs.o \
  pcre_valid_utf8.o \
  pcre_version.o \
  pcre_xclass.o \
  $(POSIX_OBJ)

LOBJ = pcre_chartables.lo \
  pcre_compile.lo \
  pcre_config.lo \
  pcre_dfa_exec.lo \
  pcre_exec.lo \
  pcre_fullinfo.lo \
  pcre_get.lo \
  pcre_globals.lo \
  pcre_info.lo \
  pcre_maketables.lo \
  pcre_ord2utf8.lo \
  pcre_refcount.lo \
  pcre_study.lo \
  pcre_tables.lo \
  pcre_try_flipped.lo \
  pcre_ucp_searchfuncs.lo \
  pcre_valid_utf8.lo \
  pcre_version.lo \
  pcre_xclass.lo \
  $(POSIX_LOBJ)

CPPOBJ = pcrecpp.o \
  pcre_scanner.o \
  pcre_stringpiece.o

CPPLOBJ = pcrecpp.lo \
  pcre_scanner.lo \
  pcre_stringpiece.lo

CPP_TARGETS = libpcrecpp.la \
  pcrecpp_unittest \
  pcre_scanner_unittest \
  pcre_stringpiece_unittest

all:            libpcre.la libpcreposix.la pcretest pcregrep \
		$(CPP_TARGETS) # winshared

pcregrep: libpcre.la pcregrep.o # winshared
		$(LINK) -o pcregrep pcregrep.o libpcre.la

pcretest: libpcre.la libpcreposix.la pcretest.o \
		# winshared
		$(LINK) $(PURIFY) $(EFENCE) -o pcretest  \
		pcretest.o \
		libpcre.la libpcreposix.la

pcrecpp_unittest: libpcrecpp.la pcrecpp_unittest.o \
		# winshared
		$(CXXLINK) $(PURIFY) $(EFENCE) -o pcrecpp_unittest \
		pcrecpp_unittest.o \
		libpcrecpp.la libpcreposix.la

pcre_scanner_unittest: libpcrecpp.la pcre_scanner_unittest.o \
		# winshared
		$(CXXLINK) $(PURIFY) $(EFENCE) \
		-o pcre_scanner_unittest \
		pcre_scanner_unittest.o \
		libpcrecpp.la libpcreposix.la

pcre_stringpiece_unittest: libpcrecpp.la \
		pcre_stringpiece_unittest.o # winshared
		$(CXXLINK) $(PURIFY) $(EFENCE) \
		-o pcre_stringpiece_unittest \
		pcre_stringpiece_unittest.o \
		libpcrecpp.la libpcreposix.la

libpcre.la:     $(OBJ)
		-rm -f libpcre.la
		$(LINKLIB) -rpath $(LIBDIR) -version-info \
		'$(PCRELIBVERSION)' -o libpcre.la $(LOBJ)

libpcreposix.la: libpcre.la pcreposix.o
		-rm -f libpcreposix.la
		$(LINKLIB) -rpath $(LIBDIR) libpcre.la -version-info \
		'$(PCREPOSIXLIBVERSION)' -o libpcreposix.la pcreposix.lo

libpcrecpp.la: libpcre.la $(CPPOBJ)
		-rm -f libpcrecpp.la
		$(CXXLINKLIB) -rpath $(LIBDIR) libpcre.la -version-info \
		'$(PCRECPPLIBVERSION)' -o libpcrecpp.la $(CPPLOBJ)

# Note that files generated by ./configure and by dftables are in the current
# directory, not the source directory.

pcre_chartables.o: pcre_chartables.c
		@$(LTCOMPILE) pcre_chartables.c

pcre_compile.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_compile.c \
		$(top_srcdir)/pcre_printint.src
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_compile.c

pcre_config.o:  Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_config.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_config.c

pcre_dfa_exec.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_dfa_exec.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_dfa_exec.c

pcre_exec.o:    Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_exec.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_exec.c

pcre_fullinfo.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_fullinfo.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_fullinfo.c

pcre_get.o:     Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_get.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_get.c

pcre_globals.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_globals.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_globals.c

pcre_info.o:    Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_info.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_info.c

pcre_maketables.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_maketables.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_maketables.c

pcre_ord2utf8.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_ord2utf8.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_ord2utf8.c

pcre_refcount.o:   Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_refcount.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_refcount.c

pcre_study.o:   Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_study.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_study.c

pcre_tables.o:  Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_tables.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_tables.c

pcre_try_flipped.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_try_flipped.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_try_flipped.c

pcre_ucp_searchfuncs.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h \
		$(top_srcdir)/pcre_ucp_searchfuncs.c \
		$(top_srcdir)/ucptable.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_ucp_searchfuncs.c

pcre_valid_utf8.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_valid_utf8.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_valid_utf8.c

pcre_version.o: Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_version.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_version.c

pcre_xclass.o:  Makefile config.h $(top_srcdir)/pcre.h \
		$(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre_xclass.c
		@$(LTCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_xclass.c

pcreposix.o:    $(top_srcdir)/pcreposix.c $(top_srcdir)/pcreposix.h \
		  $(top_srcdir)/pcre_internal.h $(top_srcdir)/pcre.h config.h Makefile
		@$(LTCOMPILE) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcreposix.c

pcrecpp.o:      $(top_srcdir)/pcrecpp.cc $(top_srcdir)/pcrecpp.h \
		pcrecpparg.h pcre_stringpiece.h $(top_srcdir)/pcre.h config.h Makefile
		@$(LTCXXCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcrecpp.cc

pcre_scanner.o: $(top_srcdir)/pcre_scanner.cc \
		$(top_srcdir)/pcre_scanner.h \
		$(top_srcdir)/pcrecpp.h pcrecpparg.h pcre_stringpiece.h \
		$(top_srcdir)/pcre.h config.h Makefile
		@$(LTCXXCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_scanner.cc

pcre_stringpiece.o:  $(top_srcdir)/pcre_stringpiece.cc \
		pcre_stringpiece.h \
		config.h Makefile
		@$(LTCXXCOMPILE) $(UTF8) $(UCP) $(POSIX_MALLOC_THRESHOLD) \
		$(top_srcdir)/pcre_stringpiece.cc

pcretest.o:     $(top_srcdir)/pcretest.c $(top_srcdir)/pcre_internal.h \
		$(top_srcdir)/pcre_printint.src $(top_srcdir)/pcre.h config.h Makefile
		$(CC) -c $(CFLAGS) -I. -I$(top_srcdir) $(UTF8) $(UCP) \
		$(LINK_SIZE) $(top_srcdir)/pcretest.c

pcrecpp_unittest.o:  $(top_srcdir)/pcrecpp_unittest.cc \
		$(top_srcdir)/pcrecpp.h \
		pcrecpparg.h pcre_stringpiece.h $(top_srcdir)/pcre.h config.h Makefile
		$(CXX) -c $(CXXFLAGS) -I. -I$(top_srcdir) $(UTF8) $(UCP) \
		$(LINK_SIZE) $(top_srcdir)/pcrecpp_unittest.cc

pcre_stringpiece_unittest.o: $(top_srcdir)/pcre_stringpiece_unittest.cc \
		pcre_stringpiece.h pcrecpparg.h config.h Makefile
		$(CXX) -c $(CXXFLAGS) -I. -I$(top_srcdir) $(UTF8) $(UCP) \
		$(LINK_SIZE) $(top_srcdir)/pcre_stringpiece_unittest.cc

pcre_scanner_unittest.o:  $(top_srcdir)/pcre_scanner_unittest.cc \
		$(top_srcdir)/pcre_scanner.h \
		$(top_srcdir)/pcrecpp.h pcre_stringpiece.h \
		$(top_srcdir)/pcre.h pcrecpparg.h config.h Makefile
		$(CXX) -c $(CXXFLAGS) -I. -I$(top_srcdir) $(UTF8) $(UCP) \
		$(LINK_SIZE) $(top_srcdir)/pcre_scanner_unittest.cc

pcregrep.o:     $(top_srcdir)/pcregrep.c $(top_srcdir)/pcre.h Makefile config.h
		$(CC) -c $(CFLAGS) -I. -I$(top_srcdir) $(UTF8) $(UCP) \
		$(PCREGREP_OSTYPE) $(top_srcdir)/pcregrep.c

# Some Windows-specific targets for MinGW. Do not use for Cygwin.

winshared : .libs/pcre.dll .libs/pcreposix.dll \
		.libs/pcrecpp.dll

.libs/pcre.dll : libpcre.la
	$(CC) $(CFLAGS) -shared -o $@ \
	-Wl,--whole-archive .libs/libpcre.a \
	-Wl,--out-implib,.libs/libpcre.dll.a \
	-Wl,--output-def,.libs/pcre.dll-def \
	-Wl,--export-all-symbols \
	-Wl,--no-whole-archive
	sed -e "s#dlname=''#dlname='../bin/pcre.dll'#" \
	-e "s#library_names=''#library_names='libpcre.dll.a'#" \
	< .libs/libpcre.lai > .libs/libpcre.lai.tmp && \
	mv -f .libs/libpcre.lai.tmp .libs/libpcre.lai
	sed -e "s#dlname=''#dlname='../bin/pcre.dll'#" \
	-e "s#library_names=''#library_names='libpcre.dll.a'#" \
	< libpcre.la > libpcre.la.tmp && \
	mv -f libpcre.la.tmp libpcre.la


.libs/pcreposix.dll: libpcreposix.la libpcre.la
	$(CC) $(CFLAGS) -shared -o $@ \
	-Wl,--whole-archive .libs/libpcreposix.a \
	-Wl,--out-implib,.libs/pcreposix.dll.a \
	-Wl,--output-def,.libs/libpcreposix.dll-def \
	-Wl,--export-all-symbols \
	-Wl,--no-whole-archive .libs/libpcre.a
	sed -e "s#dlname=''#dlname='../bin/pcreposix.dll'#" \
	-e "s#library_names=''#library_names='libpcreposix.dll.a'#"\
	< .libs/libpcreposix.lai > .libs/libpcreposix.lai.tmp && \
	mv -f .libs/libpcreposix.lai.tmp .libs/libpcreposix.lai
	sed -e "s#dlname=''#dlname='../bin/pcreposix.dll'#" \
	-e "s#library_names=''#library_names='libpcreposix.dll.a'#"\
	< libpcreposix.la > libpcreposix.la.tmp && \
	mv -f libpcreposix.la.tmp libpcreposix.la

.libs/pcrecpp.dll: libpcrecpp.la libpcre.la
	$(CXX) $(CXXFLAGS) -shared -o $@ \
	-Wl,--whole-archive .libs/libpcrecpp.a \
	-Wl,--out-implib,.libs/pcrecpp.dll.a \
	-Wl,--output-def,.libs/libpcrecpp.dll-def \
	-Wl,--export-all-symbols \
	-Wl,--no-whole-archive .libs/libpcre.a
	sed -e "s#dlname=''#dlname='../bin/pcrecpp.dll'#" \
	-e "s#library_names=''#library_names='libpcrecpp.dll.a'#"\
	< .libs/libpcrecpp.lai > .libs/libpcrecpp.lai.tmp && \
	mv -f .libs/libpcrecpp.lai.tmp .libs/libpcrecpp.lai
	sed -e "s#dlname=''#dlname='../bin/pcrecpp.dll'#" \
	-e "s#library_names=''#library_names='libpcrecpp.dll.a'#"\
	< libpcrecpp.la > libpcrecpp.la.tmp && \
	mv -f libpcrecpp.la.tmp libpcrecpp.la


wininstall : winshared
	$(mkinstalldirs) $(DESTDIR)$(LIBDIR)
	$(mkinstalldirs) $(DESTDIR)$(BINDIR)
	$(INSTALL) .libs/pcre.dll $(DESTDIR)$(BINDIR)/pcre.dll
	$(INSTALL) .libs/pcreposix.dll $(DESTDIR)$(BINDIR)/pcreposix.dll
	$(INSTALL) .libs/libpcreposix.dll.a $(DESTDIR)$(LIBDIR)/libpcreposix.dll.a
	$(INSTALL) .libs/libpcre.dll.a $(DESTDIR)$(LIBDIR)/libpcre.dll.a
	 $(INSTALL) .libs/pcrecpp.dll $(DESTDIR)$(BINDIR)/pcrecpp.dll
	 $(INSTALL) .libs/libpcrecpp.dll.a $(DESTDIR)$(LIBDIR)/libpcrecpp.dll.a
	-strip -g $(DESTDIR)$(BINDIR)/pcre.dll
	-strip -g $(DESTDIR)$(BINDIR)/pcreposix.dll
	 -strip -g $(DESTDIR)$(BINDIR)/pcrecpp.dll
	-strip $(DESTDIR)$(BINDIR)/pcregrep
	-strip $(DESTDIR)$(BINDIR)/pcretest

# An auxiliary program makes the default character table source. This is put
# in the current directory, NOT the $top_srcdir directory.

pcre_chartables.c:   dftables$(EXEEXT)
		./dftables$(EXEEXT) pcre_chartables.c

dftables.$(OBJEXT):     $(top_srcdir)/dftables.c \
		$(top_srcdir)/pcre_maketables.c $(top_srcdir)/pcre_internal.h \
		$(top_srcdir)/pcre.h config.h Makefile
		$(CC_FOR_BUILD) -c $(CFLAGS_FOR_BUILD) -I. $(top_srcdir)/dftables.c

dftables$(EXEEXT):      dftables.$(OBJEXT)
		$(LINK_FOR_BUILD) -o dftables$(EXEEXT) dftables.o

install:        all # wininstall
	       $(mkinstalldirs) $(DESTDIR)$(LIBDIR)
	       echo "$(LIBTOOL) --mode=install $(INSTALL) libpcre.la $(DESTDIR)$(LIBDIR)/libpcre.la"
	       $(LIBTOOL) --mode=install $(INSTALL) libpcre.la $(DESTDIR)$(LIBDIR)/libpcre.la
	       echo "$(LIBTOOL) --mode=install $(INSTALL) libpcreposix.la $(DESTDIR)$(LIBDIR)/libpcreposix.la"
	       $(LIBTOOL) --mode=install $(INSTALL) libpcreposix.la $(DESTDIR)$(LIBDIR)/libpcreposix.la
		echo "$(LIBTOOL) --mode=install $(INSTALL) libpcrecpp.la $(DESTDIR)$(LIBDIR)/libpcrecpp.la"
		$(LIBTOOL) --mode=install $(INSTALL) libpcrecpp.la $(DESTDIR)$(LIBDIR)/libpcrecpp.la
	       $(LIBTOOL) --finish $(DESTDIR)$(LIBDIR)
		$(mkinstalldirs) $(DESTDIR)$(INCDIR)
		$(INSTALL_DATA) $(top_srcdir)/pcre.h $(DESTDIR)$(INCDIR)/pcre.h
		$(INSTALL_DATA) $(top_srcdir)/pcreposix.h $(DESTDIR)$(INCDIR)/pcreposix.h
		 $(INSTALL_DATA) $(top_srcdir)/pcrecpp.h $(DESTDIR)$(INCDIR)/pcrecpp.h
		 $(INSTALL_DATA) pcrecpparg.h $(DESTDIR)$(INCDIR)/pcrecpparg.h
		 $(INSTALL_DATA) pcre_stringpiece.h $(DESTDIR)$(INCDIR)/pcre_stringpiece.h
		 $(INSTALL_DATA) $(top_srcdir)/pcre_scanner.h $(DESTDIR)$(INCDIR)/pcre_scanner.h
		$(mkinstalldirs) $(DESTDIR)$(MANDIR)/man3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre.3 $(DESTDIR)$(MANDIR)/man3/pcre.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcreapi.3 $(DESTDIR)$(MANDIR)/man3/pcreapi.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrebuild.3 $(DESTDIR)$(MANDIR)/man3/pcrebuild.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrecallout.3 $(DESTDIR)$(MANDIR)/man3/pcrecallout.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrecompat.3 $(DESTDIR)$(MANDIR)/man3/pcrecompat.3
		 $(INSTALL_DATA) $(top_srcdir)/doc/pcrecpp.3 $(DESTDIR)$(MANDIR)/man3/pcrecpp.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrematching.3 $(DESTDIR)$(MANDIR)/man3/pcrematching.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrepartial.3 $(DESTDIR)$(MANDIR)/man3/pcrepartial.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrepattern.3 $(DESTDIR)$(MANDIR)/man3/pcrepattern.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcreperform.3 $(DESTDIR)$(MANDIR)/man3/pcreperform.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcreposix.3 $(DESTDIR)$(MANDIR)/man3/pcreposix.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcreprecompile.3 $(DESTDIR)$(MANDIR)/man3/pcreprecompile.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcresample.3 $(DESTDIR)$(MANDIR)/man3/pcresample.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcrestack.3 $(DESTDIR)$(MANDIR)/man3/pcrestack.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_compile.3 $(DESTDIR)$(MANDIR)/man3/pcre_compile.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_compile2.3 $(DESTDIR)$(MANDIR)/man3/pcre_compile2.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_config.3 $(DESTDIR)$(MANDIR)/man3/pcre_config.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_copy_named_substring.3 $(DESTDIR)$(MANDIR)/man3/pcre_copy_named_substring.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_copy_substring.3 $(DESTDIR)$(MANDIR)/man3/pcre_copy_substring.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_dfa_exec.3 $(DESTDIR)$(MANDIR)/man3/pcre_dfa_exec.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_exec.3 $(DESTDIR)$(MANDIR)/man3/pcre_exec.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_free_substring.3 $(DESTDIR)$(MANDIR)/man3/pcre_free_substring.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_free_substring_list.3 $(DESTDIR)$(MANDIR)/man3/pcre_free_substring_list.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_fullinfo.3 $(DESTDIR)$(MANDIR)/man3/pcre_fullinfo.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_get_named_substring.3 $(DESTDIR)$(MANDIR)/man3/pcre_get_named_substring.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_get_stringnumber.3 $(DESTDIR)$(MANDIR)/man3/pcre_get_stringnumber.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_get_stringtable_entries.3 $(DESTDIR)$(MANDIR)/man3/pcre_get_stringtable_entries.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_get_substring.3 $(DESTDIR)$(MANDIR)/man3/pcre_get_substring.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_get_substring_list.3 $(DESTDIR)$(MANDIR)/man3/pcre_get_substring_list.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_info.3 $(DESTDIR)$(MANDIR)/man3/pcre_info.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_maketables.3 $(DESTDIR)$(MANDIR)/man3/pcre_maketables.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_refcount.3 $(DESTDIR)$(MANDIR)/man3/pcre_refcount.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_study.3 $(DESTDIR)$(MANDIR)/man3/pcre_study.3
		$(INSTALL_DATA) $(top_srcdir)/doc/pcre_version.3 $(DESTDIR)$(MANDIR)/man3/pcre_version.3
		$(mkinstalldirs) $(DESTDIR)$(MANDIR)/man1
		$(INSTALL_DATA) $(top_srcdir)/doc/pcregrep.1 $(DESTDIR)$(MANDIR)/man1/pcregrep.1
		$(INSTALL_DATA) $(top_srcdir)/doc/pcretest.1 $(DESTDIR)$(MANDIR)/man1/pcretest.1
		$(mkinstalldirs) $(DESTDIR)$(BINDIR)
		$(LIBTOOL) --mode=install $(INSTALL) pcregrep $(DESTDIR)$(BINDIR)/pcregrep
		$(LIBTOOL) --mode=install $(INSTALL) pcretest $(DESTDIR)$(BINDIR)/pcretest
		$(INSTALL) pcre-config $(DESTDIR)$(BINDIR)/pcre-config
		$(mkinstalldirs) $(DESTDIR)$(LIBDIR)/pkgconfig
		$(INSTALL_DATA) libpcre.pc $(DESTDIR)$(LIBDIR)/pkgconfig/libpcre.pc

# The uninstall target removes all the files that were installed.

uninstall:;     -rm -rf \
		$(DESTDIR)$(LIBDIR)/libpcre.* \
		$(DESTDIR)$(LIBDIR)/libpcreposix.* \
		$(DESTDIR)$(LIBDIR)/libpcrecpp.* \
		$(DESTDIR)$(INCDIR)/pcre.h \
		$(DESTDIR)$(INCDIR)/pcreposix.h \
		$(DESTDIR)$(INCDIR)/pcrecpp.h \
		$(DESTDIR)$(INCDIR)/pcrecpparg.h \
		$(DESTDIR)$(INCDIR)/pcre_scanner.h \
		$(DESTDIR)$(INCDIR)/pcre_stringpiece.h \
		$(DESTDIR)$(MANDIR)/man3/pcre.3 \
		$(DESTDIR)$(MANDIR)/man3/pcreapi.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrebuild.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrecallout.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrecompat.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrecpp.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrematching.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrepartial.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrepattern.3 \
		$(DESTDIR)$(MANDIR)/man3/pcreperform.3 \
		$(DESTDIR)$(MANDIR)/man3/pcreposix.3 \
		$(DESTDIR)$(MANDIR)/man3/pcreprecompile.3 \
		$(DESTDIR)$(MANDIR)/man3/pcresample.3 \
		$(DESTDIR)$(MANDIR)/man3/pcrestack.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_compile.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_compile2.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_config.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_copy_named_substring.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_copy_substring.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_dfa_exec.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_exec.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_free_substring.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_free_substring_list.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_fullinfo.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_get_named_substring.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_get_stringnumber.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_get_stringtable_entries.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_get_substring.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_get_substring_list.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_info.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_maketables.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_refcount.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_study.3 \
		$(DESTDIR)$(MANDIR)/man3/pcre_version.3 \
		$(DESTDIR)$(MANDIR)/man1/pcregrep.1 \
		$(DESTDIR)$(MANDIR)/man1/pcretest.1 \
		$(DESTDIR)$(BINDIR)/pcregrep \
		$(DESTDIR)$(BINDIR)/pcretest \
		$(DESTDIR)$(BINDIR)/pcre-config \
		$(DESTDIR)$(LIBDIR)/pkgconfig/libpcre.pc

# We deliberately omit dftables and pcre_chartables.c from 'make clean'; once
# made pcre_chartables.c shouldn't change, and if people have edited the tables
# by hand, you don't want to throw them away.

clean:;         -rm -rf *.o *.lo *.a *.la .libs pcretest pcre_stringpiece_unittest pcrecpp_unittest pcre_scanner_unittest pcregrep testtry

# But "make distclean" should get back to a virgin distribution

distclean:      clean
		-rm -f pcre_chartables.c libtool pcre-config libpcre.pc \
		pcre_stringpiece.h pcrecpparg.h \
		dftables RunGrepTest RunTest \
		Makefile config.h config.status config.log config.cache

check:          runtest

pcre.dll : winshared
	cp .libs/pcre.dll .

test:           runtest

runtest:        all # pcre.dll
		@./RunTest
		@./RunGrepTest
		 @echo ""
		 @echo "Testing C++ wrapper"
		 @echo ""; echo "Test 1++: stringpiece"
		 @./pcre_stringpiece_unittest
		 @echo ""; echo "Test 2++: RE class"
		 @./pcrecpp_unittest
		 @echo ""; echo "Test 3++: Scanner class"
		 @./pcre_scanner_unittest

# End
