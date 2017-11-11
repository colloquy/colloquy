#ifdef LOG_HTTP
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

#ifdef HAVE_ERRNO_H
#include <errno.h>
#else
extern int errno;
#endif

#include "nanohttpd.h"

void http_log( int level, const char *fmt, ... ) {
	va_list ap;
	const char *lmsg;

	va_start( ap, fmt );

	switch( level ) {
	case LOG_ERR:
		lmsg = "[ERR] ";
		break;

	case LOG_INFO:
		lmsg = "[INFO] ";
		break;

	default:
		lmsg = "[DEBUG] ";
		break;
	}

	printf( "%s", lmsg );
	vprintf( fmt, ap );
	printf( "\n" );	
	va_end( ap );
}

void http_log_perror( int level, const char *msg ) {
	http_log( level, "%s: %s", msg, strerror( errno ) );
}
#endif
