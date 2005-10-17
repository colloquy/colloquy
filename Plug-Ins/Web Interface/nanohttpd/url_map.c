#include <sys/types.h>
#include <regex.h>
#include "nanohttpd.h"

http_server_handler is_url_map( url_map_t *me, char *url ) {
	if( ! regexec( me -> regex, url, 0, NULL, 0 ) )
		return me -> handler;
	return NULL;
}

void url_map_free( void *_me ) {
	url_map_t *me = (url_map_t *) _me;
	if( me -> regex) free( me -> regex );
	free( me );
}

url_map_t *url_map_new( const char *url, http_server_handler handler ) {
	url_map_t *me = (url_map_t *) malloc( sizeof( url_map_t ));
	me -> regex = (regex_t *) malloc( sizeof( regex_t ));

	if( regcomp( me -> regex, url, ( REG_EXTENDED | REG_NOSUB ) ) ) {
#ifdef LOG_HTTP
		http_log( LOG_ERR, "regex: cant compile expression");
#endif
		return NULL;
	}

	me -> handler = handler;
	me -> delete = url_map_free;
	me -> is_url_map = is_url_map;
	return me;
}
