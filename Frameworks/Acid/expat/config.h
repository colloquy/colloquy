/* config.h.  Generated automatically by configure.  */
/* config.h.in.  Generated automatically from configure.in by autoheader.  */

/* Define to empty if the keyword does not work.  */
/* #undef const */

/* Define if you have a working `mmap' system call.  */
#define HAVE_MMAP 1

/* Define to `long' if <sys/types.h> doesn't define.  */
/* #undef off_t */

/* Define to `unsigned' if <sys/types.h> doesn't define.  */
/* #undef size_t */

/* Define if you have the ANSI C header files.  */
#define STDC_HEADERS 1

/* Define if you have the bcopy function.  */
#define HAVE_BCOPY 1

/* Define if you have the getpagesize function.  */
#define HAVE_GETPAGESIZE 1

/* Define if you have the memmove function.  */
#define HAVE_MEMMOVE 1

/* Define if you have the <fcntl.h> header file.  */
#define HAVE_FCNTL_H 1

/* Define if you have the <unistd.h> header file.  */
#define HAVE_UNISTD_H 1

/* whether byteorder is bigendian */
#if defined __BIG_ENDIAN__  || !defined __LITTLE_ENDIAN__
#define WORDS_BIGENDIAN 1
/* 1234 = LIL_ENDIAN, 4321 = BIGENDIAN */
#define BYTEORDER 4321
#else /* arch is __LITTLE_ENDIAN__ */
#define WORDS_BIGENDIAN 0
/* 1234 = LIL_ENDIAN, 4321 = BIGENDIAN */
#define BYTEORDER 1234
#endif

#define XML_NS
#define XML_DTD

#define XML_CONTEXT_BYTES 1024

#ifndef HAVE_MEMMOVE
#ifdef HAVE_BCOPY
#define memmove(d,s,l) bcopy((s),(d),(l))
#else
#define memmove(d,s,l) ;punting on memmove;
#endif

#endif
