#ifndef _NANOHTTPD_H
#define _NANOHTTPD_H

#ifdef HAVE_CONFIG_H
#include <config.h>
#ifndef HAVE_STRSEP
extern char *strsep( char **stringp, char *delim );
#endif
#endif

#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

// list.c
typedef struct _list_elem_t {
	struct _list_elem_t *next;
	const void *data;
} list_elem_t;

typedef struct _list_t {
	list_elem_t *data;
	list_elem_t *position;

	const void *( *first )( struct _list_t * );
	const void *( *next )( struct _list_t * );
	void ( *add )( struct _list_t *, const void * );
	int ( *remove_func )( struct _list_t *, int(*)( void *, void * ), void *, void(*)( void * ));

	void ( *delete )( void * );
	void ( *delete2 )( void * );
	void ( *delete_func )( void *, void(*)( void * ));
} list_t;

extern list_t *list_new();
extern void list_free( void * );

// hash.c
typedef struct _hash_item_t {
	char *key;
	void *data;
	struct _hash_item_t *next;
} hash_item_t;

typedef struct _hash_t {
	hash_item_t **slots;

	void ( *set )( struct _hash_t *, char *, void * );
	const void *( *get )( struct _hash_t *, const char * );
	list_t *( *keys )( const struct _hash_t * );
	void( *delete )( struct _hash_t *, int, int, void(*)( void * ));
} hash_t;

extern hash_t *	hash_new();

// netbuf.c
#ifndef	NETBUF_LEN
#define NETBUF_LEN 8192
#endif

#include <stdarg.h>
typedef struct _netbuf_in_t {
	char * data;
	size_t buflen;
	size_t datalen;
	int	fd;

	int ( *read )( struct _netbuf_in_t *, char *, size_t );
	int ( *read_line )( struct _netbuf_in_t *, char *, size_t );
	void ( *delete )( struct _netbuf_in_t * );
} netbuf_in_t;

typedef struct _netbuf_out_t {
	char *data;
	size_t buflen;
	size_t datalen;
	int fd;

	int ( *write )( struct _netbuf_out_t *, char *, size_t );
	int ( *printf )( struct _netbuf_out_t *, char *, ... );
	int ( *vprintf )( struct _netbuf_out_t *, char *, va_list );
	void ( *delete )( struct _netbuf_out_t * );
} netbuf_out_t;

extern netbuf_in_t *netbuf_in_new( int fd );
extern netbuf_out_t *netbuf_out_new( int fd );

// utils.c
extern void strtolower( char *string );
extern void url_decode( char *string, int queryString );

// mime.c
typedef struct _st_mime_message {
	list_t *parts;
	void( *delete )( void * );
} mime_message_t;

typedef struct _st_mime_part {
	list_t *headers;
	char *boundary;
	char *begin; // begin of data
	size_t length; // length of the payload of this part
} mime_part_t;

typedef struct _st_mime_header {
	char *name;
	char *value;
	hash_t *params;
} mime_header_t;

extern mime_message_t *mime_parse_message( char *buf, int *buflen, char *boundary );

// http_req.c
#define REQ_GET 1
#define REQ_POST 2

#define REQ_HTTP09 0
#define REQ_HTTP10 1
#define REQ_HTTP11 2

#define REQ_BAD_REQUEST -1
#define REQ_UNKNWON_PROTO -2

typedef struct _http_req_t {
	int sock;
	netbuf_in_t *netbuf;
	int	method;
	int version;

	char *uri;
	char *file_name;
	char *query;
	hash_t *headers;
	char *content;
	hash_t *parameters;
	mime_message_t *mime_msg; // mime message attached to the request

	const hash_t *( *get_headers )( struct _http_req_t * );
	const list_t *( *get_header )( struct _http_req_t *, const char * );
	const list_t *( *get_cookies )( struct _http_req_t * );
	char *( *get_cookie )( struct _http_req_t *, const char * );
	list_t *( *get_parameters )( struct _http_req_t * );
	const char *( *get_parameter )( struct _http_req_t *, const char * );
	void ( *delete )( void * );
} http_req_t;

extern http_req_t *http_req_new( int sock );

// http_resp.c
typedef struct _http_resp_t {
	int sock;
	netbuf_out_t *netbuf;
	int	status_code;
	char *reason_phrase;
	char *content_type;
	int	headers_sent;

	http_req_t *req;
	hash_t *headers;
	list_t *cookies;

	void ( *delete )( void * );
	int ( *write )( struct _http_resp_t *, char *,size_t );
	int ( *printf )( struct _http_resp_t *, char *, ... );
	int ( *send_redirect )( struct _http_resp_t *, char * );
	void ( *add_cookie )( struct _http_resp_t *, char * );
	int ( *add_header )( struct _http_resp_t *, const char *, char * );
} http_resp_t;

extern http_resp_t *http_resp_new( int sock, http_req_t *req );

// http_server.c
typedef struct _http_server_t http_server_t;
typedef void( *http_server_handler )( http_req_t *,http_resp_t *, http_server_t * );

struct _http_server_t {
	char *host;
	char *svc;
	int sock;

	char *document_root;
	hash_t *mime_types;
	list_t *directory_index;
	list_t *url_mappings;
	void *context;

	int	initial_process;
	int	nb_process;
	char running;

	int	( *add_url )( struct _http_server_t *, const char *, http_server_handler );
	void ( *delete )( void * );
	void ( *run )( struct _http_server_t * );
	const char *( *get_mime )( struct _http_server_t *, const char * );
};

extern http_server_t *http_server_new( char *hostname, char *port );

// url_map.c
#include <sys/types.h>
#include <regex.h>
typedef struct _url_map_t {
	regex_t *regex;
	http_server_handler handler;
	http_server_handler	( *is_url_map )( struct _url_map_t *, char * );
	void ( *delete )( void * );
} url_map_t;

extern url_map_t *url_map_new( const char *regex, http_server_handler handler );
extern void url_map_free( void *url );

// basic_modules.c
extern void mod_file( http_req_t *req, http_resp_t *resp, http_server_t *server );
extern void mod_dir( http_req_t *req, http_resp_t *resp, http_server_t *server );

#ifdef LOG_HTTP
// http_log.c
#define LOG_ERR 1
#define LOG_INFO 2
#define LOG_DEBUG 3

extern void http_log( int, char *, ... );
extern void http_log_perror( int, char * );
#endif

#endif
