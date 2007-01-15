#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include "nanohttpd.h"

int http_resp_write( http_resp_t *, const char *, size_t );
int http_resp_printf( http_resp_t *, const char *, ... ) __attribute__ ((format (printf, 2, 3)));
int http_resp_send_redirect( http_resp_t *, const char *);
void http_resp_free( void *);
int http_resp_add_header( http_resp_t *, const char *, const char *);
void http_resp_add_cookie( http_resp_t *, const char *);

http_resp_t *http_resp_new( int sock, http_req_t *req ) {
	http_resp_t *me = (http_resp_t *) malloc( sizeof( http_resp_t ) );
	me -> sock = sock;
	me -> netbuf = netbuf_out_new( me -> sock );
	me -> headers_sent = 0;
	me -> req = req;

	me -> status_code = 200;
	me -> reason_phrase = "OK";
	me -> content_type = "text/html";
	me -> cookies = list_new();
	me -> headers = hash_new();

	me -> delete = http_resp_free;
	me -> write = http_resp_write;
	me -> printf = http_resp_printf;
	me -> send_redirect = http_resp_send_redirect;
	me -> add_header = http_resp_add_header;
	me -> add_cookie = http_resp_add_cookie;

	return me;
}

static void http_resp_send_headers( http_resp_t *me ) {
	if( me -> headers_sent ) return;

	http_req_t *req = me -> req;

	switch( req -> version ) {
	case REQ_HTTP10:
	case REQ_HTTP11:
		me -> netbuf -> printf( me -> netbuf, "HTTP/1.1 %03i %s\r\n", me -> status_code, me -> reason_phrase );
		break;
	}

	me -> add_header( me, "Content-Type", me -> content_type );

	if( req -> version == REQ_HTTP11 || req -> version == REQ_HTTP10 ) {
		int first_header_content = 1;
		list_t *headers = me -> headers -> keys(me -> headers);
		const char *header_name = (char *) headers -> first(headers);
		while( header_name ) {
			me -> netbuf -> printf( me -> netbuf, "%s: ", header_name );

			list_t *header_content = (list_t *) me -> headers -> get( me -> headers, header_name );
			const char *content_value = header_content -> first( header_content );
			while( content_value ) {
				me -> netbuf -> printf( me -> netbuf, "%s%s ", ( first_header_content ? "" : "," ), content_value );
				first_header_content = 0;
				content_value = header_content -> next( header_content );
			}

			me -> netbuf -> printf( me -> netbuf, "\r\n" );

			header_name = (char *) headers -> next( headers );
		}

		if( headers ) headers -> delete( headers );

		char *cookie = (char *) me -> cookies -> first( me -> cookies );
		while( cookie ) {
			me -> netbuf -> printf( me -> netbuf, "Set-Cookie: %s\r\n", cookie );
			cookie = (char *) me -> cookies -> next( me -> cookies );
		}

		me -> netbuf -> printf( me -> netbuf, "\r\n" );
		me -> headers_sent = 1;
	}
}

int http_resp_write( http_resp_t *me, const char *buf, size_t buflen ) {
	if( ! me -> headers_sent )
		http_resp_send_headers( me );
	return me -> netbuf -> write( me -> netbuf, buf, buflen );
}

int http_resp_printf( http_resp_t *me, const char *fmt, ... ) {
	va_list ap;
	va_start( ap, fmt );

	if( ! me -> headers_sent )
		http_resp_send_headers( me );

	return me -> netbuf -> vprintf( me -> netbuf, fmt, ap );
}

int http_resp_add_header( http_resp_t *me, const char *header, const char *value ) {
	list_t *h = (list_t *) me -> headers -> get( me -> headers, header );
	if( h ) h -> add( h, strdup( value ) );
	else {
		h = list_new();
		h -> add( h, strdup( value ) );
		me -> headers -> set( me -> headers, strdup( header ), h );
	}

	return 0;
}

int http_resp_send_redirect( http_resp_t *me, const char *location ) {
	if( me -> headers_sent ) {
#ifdef LOG_HTTP
		http_log(LOG_ERR, "Can not send redirect, headers already sent.");
#endif
		return -1;
	}

	me -> status_code = 301;
	me -> reason_phrase  = "Moved Permanently";
	me -> content_type = "text/html";
	me -> add_header( me, "Location", location );

	http_resp_send_headers( me );

	me -> netbuf -> printf( me -> netbuf, "The document can be found here: <a href = \"%s\">%s</a>", location, location );

	return 0;
}

void http_resp_add_cookie( http_resp_t *me, const char *cookie ) {
	me -> cookies -> add( me -> cookies, cookie );
}

void http_resp_free( void *_me ) {
	http_resp_t *me = (http_resp_t *) _me;

	if( me -> headers )
		me -> headers -> delete( me -> headers, 1, 1, list_free );
	if( me -> netbuf )
		me -> netbuf -> delete( me -> netbuf );
	if( me -> cookies )
		me -> cookies -> delete2( me -> cookies );

	free( me );
}
