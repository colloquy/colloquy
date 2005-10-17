#include <ctype.h>
#include "nanohttpd.h"

void strtolower( char *in ) {
	while( *in ) {
		*in = (char) tolower( *in );
		in++;
	}

	*in = '\0';
}

static int TwoHex2Int( char *pC ) {
	int hi = pC[0];
	int lo = pC[1];

	if( '0' <= hi && hi <= '9' ) hi -= '0';
	else if( 'a' <= hi && hi <= 'f' ) hi -= ( 'a' - 10 );
	else if( 'A' <= hi && hi <= 'F' ) hi -= ( 'A' - 10 );

	if( '0' <= lo && lo <= '9' ) lo -= '0';
	else if( 'a' <= lo && lo <= 'f' ) lo -= ( 'a' - 10 );
	else if( 'A' <= lo && lo <= 'F' ) lo -=( 'A' - 10 );

	return lo + ( 16 * hi );
}

void url_decode( char *p ) {
	char *pD = p;
    while( *p ) {
		switch( *p ) {
			case '%':
			p++;
			if( isxdigit( p[0] ) && isxdigit( p[1] ) ) {
				*pD++ = (char) TwoHex2Int( p );
				p += 2;
			}
			break;

			case '+':
				*pD++=' '; p++;		
				break;

			default: 
			*pD++ = *p++;
       }
	}

    *pD = '\0';
}

#ifndef HAVE_STRSEP
char *strsep( char **stringp, char *delim ) {
    char *start = *stringp;
    char *cp;
    char ch;

    if( ! start ) return NULL;

    for( cp = start; ch = *cp; cp++) {
        if( strchr(delim, ch)) {
            *cp++ = 0;
            *stringp = cp;
            return start;
        }
    }

    *stringp = NULL;
    return start;
}
#endif
