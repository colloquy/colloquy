
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>


#ifdef HAVE_ERRNO_H
#       include <errno.h>
#else
        extern int errno;
#endif

#include <nanohttpd.h>


char* getext(char* in)
{
	char* ext;
	ext = strrchr(in, '.');
	if ( ext == NULL)
		return ext;
	else
		return ext +1;
}

void mod_dir( http_req_t* req, http_resp_t* resp, http_server_t* server)
{
	DIR *dir;
	struct dirent *di;
	char* ext;
	const char* mime;
	char filename[1024];
	char*	index;

	
	if ( server->directory_index !=NULL) {
		for (	index = (char*)server->directory_index->first(server->directory_index);
					index;
					index = (char*) server->directory_index->first(server->directory_index))
			{
				snprintf(filename, 1024, "%s%s%s", server->document_root, req->file_name, index);
				if ( access ( filename, R_OK) == 0)
				{
					snprintf(filename, 1024, "%s%s", req->file_name, index);
					free( req->file_name );
					req->file_name = strdup( filename );
					mod_file( req, resp, server );
					return;
				}
			
			}
	}

	snprintf(filename, 1024, "%s%s", server->document_root, req->file_name);
	
	resp->printf(resp,
		"<html>"
		"<head><title>Directory listing %s</title>"
		"</head>"
		"<body>"
		"<h1>Directory listing for %s</h1>"
		"<br/>"
		"<table border=\"0\">"
		"<tr><th>File name</th><th>size</th><th>mime type</th></tr>",
		req->file_name, filename);
		
	
	dir = opendir(filename);
	if ( dir == NULL) {
#ifdef LOG_HTTP
		http_log_perror(LOG_ERR, "opendir()");
#endif
		return;
	}
	
	while ( ( di = readdir(dir)) !=NULL)
	{
		ext = getext(di->d_name);
		if (ext)
			mime = server->get_mime(server, ext);
		else
			mime = "unknown";
			
		if ( di->d_name[0] !='.')
		resp->printf(resp, "<tr><td><a href=\"%s%s\">%s</a></td><td>%i bytes</td><td>%s</td></tr>",
			req->file_name, di->d_name, di->d_name, di->d_reclen, mime );
	}
	
	closedir(dir);
	resp->printf(resp, "</table></body></html>");

}

void mod_file(http_req_t* req, http_resp_t* resp, http_server_t* server )
{

	char filename[1024];
	struct stat sb;
	int fd;
	const char* content_type;
	char* ext;
	
	if ( server->document_root == NULL)
	{
		resp->status_code = 500;
		resp->reason_phrase ="No document root defined";
		
		resp->printf(resp, "Err : no document root defined");
		return;	
	}

	snprintf(filename, 1024, "%s%s", server->document_root, req->file_name);
	
	if ( stat ( filename, &sb) < 0)
	{
		resp->status_code = 404;
		resp->reason_phrase = "Cannot access document";
		
		resp->printf(resp, "Cannot access document : %s", strerror(errno));
		return;
	}
	
	if ( S_ISDIR(sb.st_mode))
	{
		snprintf(filename, 1024, "%s/", req->file_name);		
		resp->send_redirect(resp, filename);
		return;
	}

	ext = getext(filename);
	if ( ext)
		content_type = server->get_mime ( server, ext);
		
	if ( content_type)
		resp->content_type = (char*) content_type;
	
	fd = open( filename, O_RDONLY);
	if ( fd > 0)
	{
		char buf[1024];
		int nread;

		while ( (nread = read ( fd, buf, 1024)) > 0)
			resp->write( resp, buf, nread);
			
		close(fd);
	}
}
