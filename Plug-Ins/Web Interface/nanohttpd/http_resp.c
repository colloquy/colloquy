#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <nanohttpd.h>

int     http_resp_write(http_resp_t*, char*, size_t);
int     http_resp_printf(http_resp_t*, char*, ...);
int http_resp_send_redirect(http_resp_t*, char*);
void http_resp_free (void*);
int     http_resp_add_header(http_resp_t* , const char* , char* );
void http_resp_add_cookie(http_resp_t*, char*);


http_resp_t*	http_resp_new(int sock, http_req_t* req)
{
	http_resp_t*	me;
	
	me = ( http_resp_t*) malloc ( sizeof ( http_resp_t));
	me->sock = sock;
	me->netbuf = netbuf_out_new ( me->sock);
	me->headers_sent = 0;
	me->req = req;
	
	me->status_code = 200;
	me->reason_phrase ="OK";
	me->content_type="text/html";
	me->cookies = list_new();
	me->headers = hash_new();
	
	me->delete = http_resp_free;
	me->write = http_resp_write;
	me->printf = http_resp_printf;
	me->send_redirect = http_resp_send_redirect;
	me->add_header = http_resp_add_header;
	me->add_cookie = http_resp_add_cookie;
	
	return me;
}

void http_resp_send_headers( http_resp_t* me)
{
	http_req_t* req = me->req;
	char	server[255];
	
	switch ( req->version)
	{
		case REQ_HTTP10:
		case REQ_HTTP11:
			me->netbuf->printf(me->netbuf, "HTTP/1.1 %03i %s\r\n", me->status_code, me->reason_phrase);
			break;
		
	}
	me->add_header(me, "Content-Type", me->content_type);
	snprintf(server, 255, "%s/%s", "nanohttpd", "0.1");
	me->add_header(me, "Server", server);

		
	if (( req->version == REQ_HTTP11) || ( req->version == REQ_HTTP10))
	{
		list_t*	headers, *header_content;
		const char*	header_name, *content_value;
		int first_header_content ;
		char* cookie;
		
		headers = me->headers->keys(me->headers);
		header_name = (char*) headers->first(headers);
		while ( header_name != NULL)
		{
			me->netbuf->printf(me->netbuf, "%s: ",header_name);
			first_header_content = 1;
			
			header_content = (list_t*) me->headers->get(me->headers,  header_name);
			content_value = header_content->first(header_content);
			while ( content_value !=NULL)
			{
				me->netbuf->printf(me->netbuf,"%s%s ", 
					(first_header_content == 1) ?  "": ","  ,
					content_value);
				
				first_header_content = 0;
				content_value = header_content->next ( header_content);
			}
					
			me->netbuf->printf(me->netbuf, "\r\n");
			
			header_name = (char*) headers->next(headers);
		}
		if ( headers)
			headers->delete2(headers);

		for ( cookie = (char*) me->cookies->first(me->cookies);
		cookie != NULL;
		cookie = (char*) me->cookies->next (me->cookies) )
			me->netbuf->printf(me->netbuf, "Set-Cookie: %s\r\n", cookie);
			
	
		me->netbuf->printf(me->netbuf, "\r\n");
		
	}

}


int	http_resp_write(http_resp_t* me, char* buf, size_t buflen)
{
	
	if ( me->headers_sent == 0)
	{
		http_resp_send_headers(me);
		me->headers_sent = 1;
	}
		
		
	return me->netbuf->write(me->netbuf, buf, buflen);
}

int http_resp_printf(http_resp_t* me, char* fmt, ...)
{
	va_list ap;
	
	va_start(ap, fmt);
	
	if ( me->headers_sent == 0)
	{
		http_resp_send_headers(me);
		me->headers_sent = 1;
	}
	
	
	return me->netbuf->vprintf ( me->netbuf, fmt, ap);
}

int	http_resp_add_header(http_resp_t* me, const char* header, char* value)
{
	list_t* h;
	
	h = (list_t*) me->headers->get(me->headers, header);
	if ( h)
		h->add( h,  strdup(value));
	else {
		h = list_new();
		h->add(h,  strdup(value));
		me->headers->set (me->headers, strdup(header), h);
	}
	
	return 0;
}


int http_resp_send_redirect (http_resp_t *me, char* location)
{
	if ( me->headers_sent == 1)
	{
#ifdef LOG_HTTP
		http_log(LOG_ERR, "Can not send redirect, headers already sent.");
#endif
		return -1;
	}

	me->status_code = 301;
	me->reason_phrase ="Moved Permanently";
	me->content_type = "text/html";
	me->add_header ( me, "Location", location);

	http_resp_send_headers(me);

	me->netbuf->printf(me->netbuf, "The document can be found here: <a href=\"%s\">%s</a>", location, location);
	
	return 0;
}

void	http_resp_add_cookie(http_resp_t* me, char* cookie)
{
	me->cookies->add ( me->cookies, cookie);
}

void http_resp_free ( void* _me)
{
	http_resp_t* me = (http_resp_t*) _me;

	if ( me->headers)
		me->headers->delete( me->headers, 1, 1, list_free);
	if ( me->netbuf)
		me->netbuf->delete(me->netbuf);
		
	if (me->cookies)
		me->cookies->delete2( me->cookies);

	free(me);
}
