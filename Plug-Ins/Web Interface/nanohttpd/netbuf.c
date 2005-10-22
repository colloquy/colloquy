#include <string.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include "nanohttpd.h"

int	netbuf_read( netbuf_in_t *, char *, size_t );
int	netbuf_read_line( netbuf_in_t *, char *, size_t );
int	netbuf_read_next_token( netbuf_in_t *, char *, char *, size_t );
void netbuf_in_free( netbuf_in_t * );

int	netbuf_printf( netbuf_out_t *, char *, ... );
int	netbuf_vprintf( netbuf_out_t *, char *, va_list );
int	netbuf_write( netbuf_out_t *, char *, size_t len );
void netbuf_out_free( netbuf_out_t * );
int	nebtuf_vprintf( netbuf_out_t *, char *, va_list );

netbuf_in_t *netbuf_in_new( int fd ) {
	netbuf_in_t *me = (netbuf_in_t *) malloc( sizeof( netbuf_in_t ) );

	me -> fd = fd;
	me -> buflen = NETBUF_LEN;
	me -> datalen = 0;
	me -> data = (char *) malloc( me -> buflen);

	me -> delete = netbuf_in_free;
	me -> read = netbuf_read;
	me -> read_line = netbuf_read_line;

	return me;
}

netbuf_out_t *netbuf_out_new( int fd ) {
	netbuf_out_t *me = (netbuf_out_t *) malloc( sizeof( netbuf_out_t ) );

	me -> fd = fd;
	me -> buflen = NETBUF_LEN;
	me -> datalen = 0;
	me -> data = (char *) malloc( me -> buflen);

	me -> delete = netbuf_out_free;
	me -> write = netbuf_write;
	me -> printf = netbuf_printf;
	me -> vprintf = netbuf_vprintf;

	return me;
}

int	netbuf_grow( netbuf_in_t *me ) {
	int nread = read( me -> fd, me -> data + me -> datalen, me -> buflen - me -> datalen );
	if( nread > 0 ) me -> datalen += nread;
	return nread;
}

int	netbuf_read( netbuf_in_t *me, char *buf, size_t buflen ) {
	int nread = 0;
	
	if( ! me -> datalen ) {
		nread = netbuf_grow( me );
		if( nread <= 0 ) return nread;
	}

	nread = ( buflen > me -> datalen ) ? me -> datalen : buflen;
	memcpy( buf, me -> data, nread );
	memmove( me -> data, me -> data + nread, ( me -> datalen - nread ) );
	me -> datalen -= nread;

	return nread;
}

int	netbuf_search( netbuf_in_t *me, const char *search ) {
	for( char *tok = (char *) search; (*tok) != '\0'; tok++ ) {
		char *res = (char *) memchr( me -> data, *tok, me -> datalen );
		if( res ) return( res - ( me -> data ) );
	}

	return -1;
}

int	netbuf_read_line( netbuf_in_t *me, char *buf, size_t buflen ) {
	return netbuf_read_next_token( me, "\n", buf, buflen );
}

int	netbuf_read_next_token( netbuf_in_t *me, char *token, char *buf, size_t buflen ) {
	int nread = 0;

	int pos = netbuf_search( me, token );
	if( pos < 0 ) {
		nread = netbuf_grow( me );
		if( nread <= 0 ) return nread;
		return netbuf_read_line( me, buf, buflen );
	}

	pos++;

	if( pos > buflen ) return -1;

	nread = netbuf_read( me, buf, pos );
	if( nread >= 0 ) buf[nread - 1] = '\0';
	return nread - 1;
}

int netbuf_write( netbuf_out_t *me, char *buf, size_t buflen ) {
	return write( me -> fd, buf, buflen );
}

int netbuf_vprintf( netbuf_out_t *me, char *fmt, va_list ap ) {
	char buf[1024];
	int n = vsnprintf( buf, 1024, fmt, ap );
	return write( me -> fd, buf, ( n > 1023 ? 1023 : n ) );
}

int netbuf_printf( netbuf_out_t *me, char *fmt, ... ) {
	va_list ap;
	va_start( ap, fmt );
	return netbuf_vprintf( me, fmt, ap );
}

void netbuf_out_free( netbuf_out_t *me ) {
	free( me -> data );
	free( me);
}

void netbuf_in_free( netbuf_in_t *me ) {
	free( me -> data );
	free( me );
}