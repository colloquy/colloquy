/*
toc.c - FireTalk TOC protocol definitions
Copyright (C) 2000 Ian Gulliver

This program is free software; you can redistribute it and/or modify
it under the terms of version 2 of the GNU General Public License as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
#include <sys/types.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <time.h>
#include <fcntl.h>
#include <errno.h>

/* Structures */

struct s_toc_room {
	struct s_toc_room *next;
	int exchange;
	char *name;
	char *id;
	int invited;
	int joined;
};

#define TOC_HTML_MAXLEN 65536

struct s_toc_infoget {
	int sockfd;
	struct s_toc_infoget *next;
#define TOC_STATE_CONNECTING 0
#define TOC_STATE_TRANSFERRING 1
	int state;
	char buffer[TOC_HTML_MAXLEN];
	int buflen;
};

struct s_toc_connection {
	unsigned short local_sequence;                       /* our sequence number */
	unsigned short remote_sequence;                      /* toc's sequence number */
	char *nickname;                                      /* our nickname (correctly spaced) */
	struct s_toc_room *room_head;
	struct s_toc_infoget *infoget_head;
	time_t lasttalk;                                     /* last time we talked */
	time_t lastidle;                                  /* last idle that we told the server */
	double lastsend;
	int passchange;                                      /* whether we're changing our password right now */
	int online;
	int connectstate;
	int gotconfig;
};

typedef struct s_toc_connection * client_t;
#define _HAVE_CLIENT_T

#include "firetalk-int.h"
#include "firetalk.h"
#include "toc.h"
#include "aim.h"
#include "safestring.h"

#define SFLAP_FRAME_SIGNON ((unsigned char)1)
#define SFLAP_FRAME_DATA ((unsigned char)2)
#define SFLAP_FRAME_ERROR ((unsigned char)3)
#define SFLAP_FRAME_SIGNOFF ((unsigned char)4)
#define SFLAP_FRAME_KEEPALIVE ((unsigned char)5)

#define SIGNON_STRING "FLAPON\r\n\r\n"

#define TOC_SERVER "toc.oscar.aol.com"
#define TOC_PORT 9898

#define TOC_HEADER_LENGTH 6
#define TOC_SIGNON_LENGTH 24
#define TOC_HOST_SIGNON_LENGTH 4
#define TOC_USERNAME_MAXLEN 16

static char lastinfo[TOC_USERNAME_MAXLEN + 1] = "";

/* Internal Function Declarations */

static unsigned short toc_fill_header(unsigned char * const header, unsigned char const frame_type, unsigned short const sequence, unsigned short const length);
static unsigned short toc_fill_signon(unsigned char * const signon, const char * const username);
static unsigned char toc_get_frame_type_from_header(const unsigned char * const header);
static unsigned short toc_get_sequence_from_header(const unsigned char * const header);
static unsigned short toc_get_length_from_header(const unsigned char * const header);
static char *toc_quote(const char * const string, const int outside_flag);
static char *toc_hash_password(const char * const password);
static int toc_internal_disconnect(client_t c, const int error);
static int toc_internal_add_room(client_t c, const char * const name, const int exchange);
static int toc_internal_find_exchange(client_t c, const char * const name);
static int toc_internal_set_joined(client_t c, const char * const name, const int exchange);
static int toc_internal_set_id(client_t c, const char * const name, const int exchange, const char * const id);
static char *toc_internal_find_room_id(client_t c, const char * const name);
static char *toc_internal_find_room_name(client_t c, const char * const id);
static int toc_send_printf(client_t c, const char * const format, ...);
static char **toc_parse_args(char * const instring, int maxargs);
static int toc_internal_split_exchange(const char * const string);
static char *toc_internal_split_name(const char * const string);
static int toc_get_tlv_value(char ** args, const int startarg, const int type, char *dest, int destlen);
enum firetalk_error toc_find_packet(client_t c, unsigned char * buffer, unsigned short * bufferpos, char * outbuffer, const int frametype, unsigned short *l);


/* Internal Function Definitions */

enum firetalk_error  toc_find_packet(client_t c, unsigned char * buffer, unsigned short * bufferpos, char * outbuffer, const int frametype, unsigned short *l) {
	unsigned short length;

	if (*bufferpos < TOC_HEADER_LENGTH) /* don't have the whole header yet */
		return FE_NOTFOUND;

	length = toc_get_length_from_header(buffer);
	if (length > (8192 - TOC_HEADER_LENGTH)) {
		toc_internal_disconnect(c,FE_PACKETSIZE);
		return FE_DISCONNECT;
	}

	if (*bufferpos < length + TOC_HEADER_LENGTH) /* don't have the whole packet yet */
		return FE_NOTFOUND;

	if (frametype == SFLAP_FRAME_SIGNON)
		c->remote_sequence = toc_get_sequence_from_header(buffer);
	else {
		if (toc_get_sequence_from_header(buffer) != ++c->remote_sequence) {
			toc_internal_disconnect(c,FE_SEQUENCE);
			return FE_DISCONNECT;
		}
	}

	if (toc_get_frame_type_from_header(buffer) != frametype) {
		toc_internal_disconnect(c,FE_FRAMETYPE);
		return FE_DISCONNECT;
	}

	memcpy(outbuffer,&buffer[TOC_HEADER_LENGTH],length);
	*bufferpos -= length + TOC_HEADER_LENGTH;
	memmove(buffer,&buffer[TOC_HEADER_LENGTH + length],*bufferpos);
	outbuffer[length] = '\0';
	*l = length;
	return FE_SUCCESS;
}

static unsigned short toc_fill_header(unsigned char * const header, unsigned char const frame_type, unsigned short const sequence, unsigned short const length) {
	header[0] = '*';            /* byte 0, length 1, magic 42 */
	header[1] = frame_type;     /* byte 1, length 1, frame type (defined above SFLAP_FRAME_* */
	header[2] = sequence/256;   /* byte 2, length 2, sequence number, network byte order */
	header[3] = (unsigned char) sequence%256;   
	header[4] = length/256;     /* byte 4, length 2, length, network byte order */
	header[5] = (unsigned char) length%256;
	return 6 + length;
}

static unsigned short toc_fill_signon(unsigned char * const signon, const char * const username) {
	size_t length;
	length = strlen(username);
	signon[0] = '\0';              /* byte 0, length 4, flap version (1) */
	signon[1] = '\0';
	signon[2] = '\0';
	signon[3] = '\001';
	signon[4] = '\0';              /* byte 4, length 2, tlv tag (1) */
	signon[5] = '\001';
	signon[6] = length/256;     /* byte 6, length 2, username length, network byte order */
	signon[7] = (unsigned char) length%256;
	memcpy(&signon[8],username,length);
	return(length + 8);
}

void toc_infoget_parse(client_t c, struct s_toc_infoget *i) {
	char *tempchr1, *tempchr2, *tempchr3, *tempchr4;
	int tempint, tempint2;
	i->buffer[i->buflen] = '\0';
#define USER_STRING "Username : <B>"
	tempchr1 = strstr(i->buffer,USER_STRING);
	if (!tempchr1) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,lastinfo[0] == '\0' ? NULL : lastinfo,"Can't find username in info HTML");
		return;
	}
	tempchr1 += sizeof(USER_STRING) - 1;
	tempchr2 = strchr(tempchr1,'<');
	if (!tempchr2) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,lastinfo[0] == '\0' ? NULL : lastinfo,"Can't find end of username in info HTML");
		return;
	}
	tempchr2[0] = '\0';
	tempchr2++;
#define WARNING_STRING "Warning Level : <B>"
	tempchr3 = strstr(tempchr2,WARNING_STRING);
	if (!tempchr3) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,tempchr1,"Can't find warning level in info HTML");
		return;
	}
	tempchr3[0] = '\0';
	tempint = 0;
	if ((strstr(tempchr2,"free") != NULL) || (strstr(tempchr2,"dt") != NULL))
		tempint |= FF_SUBSTANDARD;
	if (strstr(tempchr2,"aol") != NULL)
		tempint |= FF_NORMAL;
	if (strstr(tempchr2,"admin") != NULL)
		tempint |= FF_ADMIN;
	tempchr3 += sizeof(WARNING_STRING) - 1;
	tempchr2 = strchr(tempchr3,'%');
	if (!tempchr2) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,tempchr1,"Can't find %% in info HTML");
		return;
	}
	tempchr2[0] = '\0';
	tempchr2++;
	tempint2 = atoi(tempchr3);
#define IDLE_STRING "Idle Minutes : <B>" 
	tempchr3 = strstr(tempchr2,IDLE_STRING);
	if (!tempchr3) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,tempchr1,"Can't find idle minutes in info HTML");
		return;
	}
	tempchr3 += sizeof(IDLE_STRING) - 1;
	tempchr2 = strchr(tempchr3,'<');
	if (!tempchr2) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,tempchr1,"Can't find end of idle minutes in info HTML");
		return;
	}
	tempchr2[0] = '\0';
	tempchr2++;
#define INFO_STRING "<hr><br>\n"
#define INFO_END_STRING "<br><hr>"
	tempchr4 = strstr(tempchr2,INFO_STRING);
	if (!tempchr4) {
		firetalk_callback_error(c,FE_INVALIDFORMAT,tempchr1,"Can't find info string in info HTML");
		return;
	}
	tempchr4 += sizeof(INFO_STRING) - 1;
	tempchr2 = strstr(tempchr4,INFO_END_STRING);
	if (!tempchr2) {
		firetalk_callback_gotinfo(c,tempchr1,NULL,tempint2,atoi(tempchr3),tempint);
	} else {
		tempchr2[0] = '\0';
		firetalk_callback_gotinfo(c,tempchr1,aim_handle_ect(c,tempchr1,aim_interpolate_variables(tempchr4,c->nickname),1),tempint2,atoi(tempchr3),tempint);
	}
}

void toc_infoget_remove(client_t c, struct s_toc_infoget *i, char *error) {
	struct s_toc_infoget *m, *m2;
	if (error != NULL)
		firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,error);
	m = c->infoget_head;
	m2 = NULL;
	while (m != NULL) {
		if (m == i) {
			if (m2 == NULL)
				c->infoget_head = m->next;
			else
				m2->next = m->next;
			close(m->sockfd);
			free(m);
			return;
		}
		m2 = m;
		m = m->next;
	}
}

enum firetalk_error toc_preselect(client_t c, fd_set *read, fd_set *write, fd_set *except, int *n) {
	struct s_toc_infoget *i;
	i = c->infoget_head;
	while (i != NULL) {
		if (i->state == TOC_STATE_CONNECTING)
			FD_SET(i->sockfd,write);
		else if (i->state == TOC_STATE_TRANSFERRING)
			FD_SET(i->sockfd,read);
		FD_SET(i->sockfd,read);
		if (i->sockfd >= *n)
			*n = i->sockfd + 1;
		i = i->next;
	}
	return FE_SUCCESS;
}

enum firetalk_error toc_postselect(client_t c, fd_set *read, fd_set *write, fd_set *except) {
	struct s_toc_infoget *i,*i2;
	i = c->infoget_head;
	while (i != NULL) {
		if (FD_ISSET(i->sockfd,except)) {
			toc_infoget_remove(c,i,strerror(errno));
			i = i->next;
			continue;
		}
		if (i->state == TOC_STATE_CONNECTING && FD_ISSET(i->sockfd,write)) {
			int r;
			unsigned int o = sizeof(int);
			if (getsockopt(i->sockfd,SOL_SOCKET,SO_ERROR,&r,&o)) {
				i2 = i->next;
				toc_infoget_remove(c,i,strerror(errno));
				i = i2;
				continue;
			}
			if (r != 0) {
				i2 = i->next;
				toc_infoget_remove(c,i,strerror(r));
				i = i2;
				continue;
			}
			if (send(i->sockfd,i->buffer,i->buflen,0) != i->buflen) {
				i2 = i->next;
				toc_infoget_remove(c,i,strerror(errno));
				i = i2;
				continue;
			}
			i->buflen = 0;
			i->state = TOC_STATE_TRANSFERRING;
		} else if (i->state == TOC_STATE_TRANSFERRING && FD_ISSET(i->sockfd,read)) {
			ssize_t s;
			while (1) {
				s = recv(i->sockfd,&i->buffer[i->buflen],TOC_HTML_MAXLEN - i->buflen - 1,0);
				if (s <= 0)
					break;
				i->buflen += s;
				if (i->buflen == TOC_HTML_MAXLEN - 1) {
					s = -2;
					break;
				}
			}
			if (s == -2) {
				i2 = i->next;
				toc_infoget_remove(c,i,"Too much data");
				i = i2;
				continue;
			}
			if (s == -1) {
				i2 = i->next;
				if (errno != EAGAIN)
					toc_infoget_remove(c,i,strerror(errno));
				i = i2;
				continue;
			}
			if (s == 0) {
				/* finished, parse results here */
				toc_infoget_parse(c,i);
				i2 = i->next;
				toc_infoget_remove(c,i,NULL);
				i = i2;
				continue;
			}

		}
		i = i->next;
	}

	return FE_SUCCESS;
}

static unsigned char toc_get_frame_type_from_header(const unsigned char * const header) {
	return header[1];
}

static unsigned short toc_get_sequence_from_header(const unsigned char * const header) {
	unsigned short sequence;
	sequence = ntohs(* ((unsigned short *)(&header[2])));
	return sequence;
}

static unsigned short toc_get_length_from_header(const unsigned char * const header) {
	unsigned short length;
	length = ntohs(* ((unsigned short *)(&header[4])));
	return length;
}

static char *toc_quote(const char * const string, const int outside_flag) {
	static char output[2048];
	size_t length;
	size_t counter;
	int newcounter;

	length = strlen(string);
	if (outside_flag == 1) {
 		newcounter = 1;
		output[0] = '"';
	} else
		newcounter = 0;

	for (counter = 0; counter < length; counter++) {
		if (string[counter] == '$' || string[counter] == '{' || string[counter] == '}' || string[counter] == '[' || string[counter] == ']' || string[counter] == '(' || string[counter] == ')' || string[counter] == '\'' || string[counter] == '`' || string[counter] == '"' || string[counter] == '\\') {
			if (newcounter > 2044)
				return NULL;
			output[newcounter++] = '\\';
			output[newcounter++] = string[counter];
		} else {
			if (newcounter > 2045)
				return NULL;
			output[newcounter++] = string[counter];
		}
	}

	if (outside_flag == 1)
		output[newcounter++] = '"';
	output[newcounter] = '\0';

	return output;
}

static char *toc_hash_password(const char * const password) {
#define HASH "Tic/Toc"
	const char hash[sizeof(HASH)] = HASH;
	static char output[2048];
	size_t counter;
	int newcounter;
	size_t length;

	length = strlen(password);

	output[0] = '0';
	output[1] = 'x';

	newcounter = 2;

	for (counter = 0; counter < length; counter++) {
		if (newcounter > 2044)
			return NULL;
		sprintf(&output[newcounter],"%02x",(unsigned int) password[counter] ^ hash[((counter) % (sizeof(HASH)-1))]);
		newcounter += 2;
	}

	output[newcounter] = '\0';

	return output;
}

static int toc_internal_disconnect(client_t c, const int error) {
	if (c->nickname) {
		free(c->nickname);
		c->nickname = NULL;
	}
	firetalk_callback_disconnect(c,error);
	return FE_SUCCESS;
}

static int toc_internal_add_room(client_t c, const char * const name, const int exchange) {
	struct s_toc_room *iter;

	iter = c->room_head;
	c->room_head = safe_malloc(sizeof(struct s_toc_room));
	c->room_head->next = iter;
	c->room_head->name = safe_strdup(name);
	c->room_head->id = NULL;
	c->room_head->invited = 0;
	c->room_head->joined = 0;
	c->room_head->exchange = exchange;
	return FE_SUCCESS;
}

static int toc_internal_set_joined(client_t c, const char * const name, const int exchange) {
	struct s_toc_room *iter;

	iter = c->room_head;

	while (iter) {
		if (iter->joined == 0) {
			if ((iter->exchange == exchange) && (aim_compare_nicks(iter->name,name) == 0)) {
				iter->joined = 1;
				return FE_SUCCESS;
			}
		}
		iter = iter->next;
	}
	return FE_NOTFOUND;
}

static int toc_internal_set_id(client_t c, const char * const name, const int exchange, const char * const id) {
	struct s_toc_room *iter;

	iter = c->room_head;

	while (iter) {
		if (iter->joined == 0) {
			if ((iter->exchange == exchange) && (aim_compare_nicks(iter->name,name) == 0)) {
				iter->id = safe_strdup(id);
				return FE_SUCCESS;
			}
		}
		iter = iter->next;
	}
	return FE_NOTFOUND;
}
	
static int toc_internal_find_exchange(client_t c, const char * const name) {
	struct s_toc_room *iter;

	iter = c->room_head;

	while (iter) {
		if (iter->joined == 0)
			if (aim_compare_nicks(iter->name,name) == 0)
				return iter->exchange;
		iter = iter->next;
	}

	firetalkerror = FE_NOTFOUND;
	return 0;
}

static char * toc_internal_find_room_id(client_t c, const char * const name) {
	struct s_toc_room *iter;
	char *namepart;
	int exchange;

	namepart = toc_internal_split_name(name);
	exchange = toc_internal_split_exchange(name);

	iter = c->room_head;

	while (iter) {
		if (iter->exchange == exchange)
			if (aim_compare_nicks(iter->name,namepart) == 0)
				return iter->id;
		iter = iter->next;
	}

	firetalkerror = FE_NOTFOUND;
	return NULL;
}

static char * toc_internal_find_room_name(client_t c, const char * const id) {
	struct s_toc_room *iter;
	static char newname[2048];

	iter = c->room_head;

	while (iter) {
		if (aim_compare_nicks(iter->id,id) == 0) {
			safe_snprintf(newname,2048,"%d:%s",iter->exchange,iter->name);
			return newname;
		}
		iter = iter->next;
	}

	firetalkerror = FE_NOTFOUND;
	return NULL;
}

static int toc_internal_split_exchange(const char * const string) {
	return atoi(string);
}

static char *toc_internal_split_name(const char * const string) {
	return strchr(string,':') + 1;
}

static int toc_get_tlv_value(char **args, const int startarg, const int type, char *dest, int destlen) {
	int i,o,s,l;
	i = startarg;
	while (args[i]) {
		if (atoi(args[i]) == type) {
			/* got it, now de-base 64 the next block */
			i++;
			o = 0;
			l = (int) strlen(args[i]);
			for (s = 0, o = 0; s <= l - 3 && o + 3 < destlen; s += 4) {
				dest[o++] = (aim_debase64(args[i][s]) << 2) | (aim_debase64(args[i][s+1]) >> 4);
				dest[o++] = (aim_debase64(args[i][s+1]) << 4) | (aim_debase64(args[i][s+2]) >> 2);
				dest[o++] = (aim_debase64(args[i][s+2]) << 6) | aim_debase64(args[i][s+3]);
			}
			return o;
		}
		i += 2;
	}
	return 0;
}

static int toc_internal_set_room_invited(client_t c, const char * const name, const int invited) {
	struct s_toc_room *iter;

	iter = c->room_head;

	while (iter) {
		if (aim_compare_nicks(iter->name,name) == 0) {
			iter->invited = invited;
			return FE_SUCCESS;
		}
		iter = iter->next;
	}

	return FE_NOTFOUND;
}

static int toc_internal_get_room_invited(client_t c, const char * const name) {
	struct s_toc_room *iter;

	iter = c->room_head;

	while (iter) {
		if (aim_compare_nicks(iter->name,name) == FE_SUCCESS && iter->invited == 1)
			return 1;
		iter = iter->next;
	}

	return 0;
}

static int toc_send_printf(client_t c, const char * const format, ...) {
	va_list ap;
	size_t len;
	size_t i;
	char data[2048];
	char tempnum[25];
	int tn;
	short datai;
	char *tempchr;
	unsigned short length;
	struct s_firetalk_handle *fchandle;

	fchandle = firetalk_find_handle(c);

	va_start(ap,format);
	datai = TOC_HEADER_LENGTH;

	len = strlen(format);
	for (i = 0; i < len; i++) {
		if (format[i] == '%') {
			switch (format[++i]) {
				case 's':
					tempchr = va_arg(ap, char *);
					tempchr = toc_quote(tempchr,1);
					if (!tempchr || (datai + strlen(tempchr) > 2046))
						return FE_PACKETSIZE;
					safe_strncpy(&data[datai],tempchr,(size_t) 2048-datai);
					datai += strlen(tempchr);
					break;
				case 'd':
					tn = va_arg(ap, int);
					safe_snprintf(tempnum,25,"%d",tn);
					safe_strncpy(&data[datai],tempnum,(size_t) 2048-datai);
					datai += strlen(tempnum);
					break;
				case '%':
					data[datai++] = '%';
					break;
			}
		} else {
			data[datai++] = format[i];
			if (datai > 2046)
				return FE_PACKETSIZE;
		}
	}
	data[datai++] = '\0';

	length = toc_fill_header((unsigned char *)data,SFLAP_FRAME_DATA,++c->local_sequence,datai - TOC_HEADER_LENGTH);

	firetalk_internal_send_data(fchandle,data,length,0);
	return FE_SUCCESS;
}

static char *toc_get_arg0(char * const instring) {
	static char data[8192];
	char *tempchr;

	if (strlen(instring) > 8192) {
		firetalkerror = FE_PACKETSIZE;
		return NULL;
	}

	safe_strncpy(data,instring,8192);
	tempchr = strchr(data,':');
	if (tempchr)
		tempchr[0] = '\0';
	return data;
}

static char **toc_parse_args(char * const instring, const int maxargs) {
	static char *args[256];
	int curarg;
	char *tempchr;
	char *tempchr2;

	curarg = 0;
	tempchr = instring;

	while (curarg < (maxargs - 1) && curarg < 256 && ((tempchr2 = strchr(tempchr,':')) != NULL)) {
		args[curarg++] = tempchr;
		tempchr2[0] = '\0';
		tempchr = tempchr2 + 1;
	}
	args[curarg++] = tempchr;
	args[curarg] = NULL;
	return args;
}

/* External Function Definitions */

client_t toc_create_handle() {
	client_t c;

	c = safe_malloc(sizeof(struct s_toc_connection));

	c->nickname = NULL;
	c->room_head = NULL;
	c->infoget_head = NULL;
	c->lasttalk = time(NULL);
	c->lastidle = 0;
	c->passchange = 0;
	c->local_sequence = 0;
	c->lastsend = 0;
	c->remote_sequence = 0;
	c->online = 0;

	return c;
}

void toc_destroy_handle(client_t c) {
	(void) toc_internal_disconnect(c,FE_USERDISCONNECT);
	free(c);
}

enum firetalk_error toc_disconnect(client_t c) {
	return toc_internal_disconnect(c,FE_USERDISCONNECT);
}

enum firetalk_error toc_signon(client_t c, const char * const username) {
	struct s_firetalk_handle *conn;

	/* fill & send the flap signon packet */

	conn = firetalk_find_handle(c);

	c->lasttalk = time(NULL);
	c->connectstate = 0;
	c->gotconfig = 0;
	c->nickname = safe_strdup(username);

	/* send the signon string to indicate that we're speaking FLAP here */

	firetalk_internal_send_data(conn,SIGNON_STRING,strlen(SIGNON_STRING),0);

	return FE_SUCCESS;
}

enum firetalk_error toc_im_add_buddy(client_t c, const char * const nickname) {
	return toc_send_printf(c,"toc_add_buddy %s",nickname);
}

enum firetalk_error toc_im_remove_buddy(client_t c, const char * const nickname) {
	return toc_send_printf(c,"toc_remove_buddy %s",nickname);
}

enum firetalk_error toc_im_add_deny(client_t c, const char * const nickname) {
	return toc_send_printf(c,"toc_add_deny %s",nickname);
}

enum firetalk_error toc_im_remove_deny(client_t c, const char * const nickname) {
	return FE_SUCCESS;
}

enum firetalk_error toc_save_config(client_t c) {
	char data[2048];
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;
	struct s_firetalk_deny *denyiter;

	conn = firetalk_find_handle(c);

	safe_strncpy(data,"m 4\ng Buddies\n",2048);
	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (strlen(data) > 2000)
			return FE_PACKETSIZE;
		safe_strncat(data,"b ",2048);
		safe_strncat(data,buddyiter->nickname,2048);
		safe_strncat(data,"\n",2048);
		buddyiter = buddyiter->next;
	}
	denyiter = conn->deny_head;
	while (denyiter) {
		if (strlen(data) > 2000)
			return FE_PACKETSIZE;
		safe_strncat(data,"d ",2048);
		safe_strncat(data,denyiter->nickname,2048);
		safe_strncat(data,"\n",2048);
		denyiter = denyiter->next;
	}
	return toc_send_printf(c,"toc_set_config %s",data);
}

enum firetalk_error toc_im_upload_buddies(client_t c) {
	char data[2048];
	struct s_firetalk_buddy *buddyiter;
	struct s_firetalk_handle *fchandle;
	unsigned short length; 

	fchandle = firetalk_find_handle(c);


	safe_strncpy(&data[TOC_HEADER_LENGTH],"toc_add_buddy",(size_t) 2048 - TOC_HEADER_LENGTH);

	if (fchandle->buddy_head == NULL) {
		safe_strncat(&data[TOC_HEADER_LENGTH]," ",(size_t) 2048 - TOC_HEADER_LENGTH);
		safe_strncat(&data[TOC_HEADER_LENGTH],toc_quote("flamingcow66",1),(size_t) 2048 - TOC_HEADER_LENGTH);
	}

	buddyiter = fchandle->buddy_head;
	while (buddyiter) {
		safe_strncat(&data[TOC_HEADER_LENGTH]," ",(size_t) 2048 - TOC_HEADER_LENGTH);
		safe_strncat(&data[TOC_HEADER_LENGTH],toc_quote(buddyiter->nickname,1),(size_t) 2048 - TOC_HEADER_LENGTH);
		if (strlen(&data[TOC_HEADER_LENGTH]) > 2000) {
			length = toc_fill_header((unsigned char *)data,SFLAP_FRAME_DATA,++c->local_sequence,strlen(&data[TOC_HEADER_LENGTH])+1);

			firetalk_internal_send_data(fchandle,data,length,0);
			safe_strncpy(&data[TOC_HEADER_LENGTH],"toc_add_buddy",(size_t) 2048 - TOC_HEADER_LENGTH);
		}
		buddyiter = buddyiter->next;
	}
	length = toc_fill_header((unsigned char *)data,SFLAP_FRAME_DATA,++c->local_sequence,strlen(&data[TOC_HEADER_LENGTH])+1);

	firetalk_internal_send_data(fchandle,data,length,0);
	return FE_SUCCESS;
}

enum firetalk_error toc_im_upload_denies(client_t c) {
	char data[2048];
	struct s_firetalk_deny *denyiter;
	unsigned short length; 
	struct s_firetalk_handle *fchandle;

	fchandle = firetalk_find_handle(c);

	if (fchandle->deny_head == NULL)
		return FE_SUCCESS;

	safe_strncpy(&data[TOC_HEADER_LENGTH],"toc_add_deny",(size_t) 2048 - TOC_HEADER_LENGTH);
	denyiter = fchandle->deny_head;
	while (denyiter) {
		safe_strncat(&data[TOC_HEADER_LENGTH]," ",(size_t) 2048 - TOC_HEADER_LENGTH);
		safe_strncat(&data[TOC_HEADER_LENGTH],toc_quote(denyiter->nickname,0),(size_t) 2048 - TOC_HEADER_LENGTH);
		if (strlen(&data[TOC_HEADER_LENGTH]) > 2000) {
			length = toc_fill_header((unsigned char *)data,SFLAP_FRAME_DATA,++c->local_sequence,strlen(&data[TOC_HEADER_LENGTH])+1);

			firetalk_internal_send_data(fchandle,data,length,0);
			safe_strncpy(&data[TOC_HEADER_LENGTH],"toc_add_deny",(size_t) 2048 - TOC_HEADER_LENGTH);
		}
		denyiter = denyiter->next;
	}
	length = toc_fill_header((unsigned char *)data,SFLAP_FRAME_DATA,++c->local_sequence,strlen(&data[TOC_HEADER_LENGTH])+1);

	firetalk_internal_send_data(fchandle,data,length,0);
	return FE_SUCCESS;
}

enum firetalk_error toc_im_send_message(client_t c, const char * const dest, const char * const message, const int auto_flag) {
	if ((auto_flag == 0) && (aim_compare_nicks(dest,c->nickname) == FE_NOMATCH))
		c->lasttalk = time(NULL);
	
	if (auto_flag == 1)
		return toc_send_printf(c,"toc_send_im %s %s auto",dest,aim_interpolate_variables(message,dest));
	else
		return toc_send_printf(c,"toc_send_im %s %s",dest,message);
}

enum firetalk_error toc_im_send_action(client_t c, const char * const dest, const char * const message, const int auto_flag) {
	char tempbuf[2048]; 

	if (strlen(message) > 2042)
		return FE_PACKETSIZE;

	safe_strncpy(tempbuf,"/me ",2048);
	safe_strncat(tempbuf,message,2048);

	if (auto_flag == 0)
		c->lasttalk = time(NULL);
	
	if (auto_flag == 1)
		return toc_send_printf(c,"toc_send_im %s %s auto",dest,tempbuf);
	else
		return toc_send_printf(c,"toc_send_im %s %s",dest,tempbuf);
}

enum firetalk_error toc_get_info(client_t c, const char * const nickname) {
	safe_strncpy(lastinfo,nickname,(size_t) TOC_USERNAME_MAXLEN + 1);
	return toc_send_printf(c,"toc_get_info %s",nickname);
}

enum firetalk_error toc_set_info(client_t c, const char * const info) {
	return toc_send_printf(c,"toc_set_info %s",info);
}

enum firetalk_error toc_set_away(client_t c, const char * const message) {
	if (message)
		return toc_send_printf(c,"toc_set_away %s",message);
	else
		return toc_send_printf(c,"toc_set_away");
}

enum firetalk_error toc_set_nickname(client_t c, const char * const nickname) {
	return toc_send_printf(c,"toc_format_nickname %s",nickname);
}

enum firetalk_error toc_set_password(client_t c, const char * const oldpass, const char * const newpass) {
	c->passchange++;
	return toc_send_printf(c,"toc_change_passwd %s %s",oldpass,newpass);
}

enum firetalk_error toc_im_evil(client_t c, const char * const who) {
	return toc_send_printf(c,"toc_evil %s norm",who);
}

enum firetalk_error toc_got_data(client_t c, unsigned char * buffer, unsigned short * bufferpos) {
	char *tempchr1;
	char *tempchr2;
	char *tempchr3;
	char data[8192 - TOC_HEADER_LENGTH + 1];
	char *arg0;
	char **args;
	enum firetalk_error r;
	unsigned short l;

got_data_start:

	r = toc_find_packet(c,buffer,bufferpos,data,SFLAP_FRAME_DATA,&l);
	if (r == FE_NOTFOUND)
		return FE_SUCCESS;
	else if (r != FE_SUCCESS)
		return r;

	arg0 = toc_get_arg0(data);
	if (!arg0)
		return FE_SUCCESS;
	if (strcmp(arg0,"ERROR") == 0) {
		args = toc_parse_args(data,3);
		if (!args[1]) {
			(void) toc_internal_disconnect(c,FE_INVALIDFORMAT);
			return FE_INVALIDFORMAT;
		}
		switch (atoi(args[1])) {
			case 901:
				firetalk_callback_error(c,FE_USERUNAVAILABLE,args[2],NULL);
				break;
			case 902:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,args[2],NULL);
				break;
			case 903:
				firetalk_callback_error(c,FE_TOOFAST,NULL,NULL);
				break;
			case 911:
				if (c->passchange != 0) {
					c->passchange--;
					firetalk_callback_error(c,FE_NOCHANGEPASS,NULL,NULL);
				} else
					firetalk_callback_error(c,FE_BADUSER,NULL,NULL);
				break;
			case 915:
				firetalk_callback_error(c,FE_TOOFAST,NULL,NULL);
				break;
			case 950:
				firetalk_callback_error(c,FE_ROOMUNAVAILABLE,args[2],NULL);
				break;
			case 960:
				firetalk_callback_error(c,FE_TOOFAST,args[2],NULL);
				break;
			case 961:
				firetalk_callback_error(c,FE_INCOMINGERROR,args[2],"Message too big.");
				break;
			case 962:
				firetalk_callback_error(c,FE_INCOMINGERROR,args[2],"Message sent too fast.");
				break;
			case 970:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,NULL);
				break;
			case 971:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Too many matches.");
				break;
			case 972:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Need more qualifiers.");
				break;
			case 973:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Directory service unavailable.");
				break;
			case 974:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Email lookup restricted.");
				break;
			case 975:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Keyword ignored.");
				break;
			case 976:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"No keywords.");
				break;
			case 977:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Language not supported.");
				break;
			case 978:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,"Country not supported.");
				break;
			case 979:
				firetalk_callback_error(c,FE_USERINFOUNAVAILABLE,NULL,NULL);
				break;
			case 980:
				firetalk_callback_error(c,FE_BADUSERPASS,NULL,NULL);
				break;
			case 981:
				firetalk_callback_error(c,FE_UNKNOWN,NULL,"Service temporarily unavailable.");
				break;
			case 982:
				firetalk_callback_error(c,FE_BLOCKED,NULL,"Your warning level is too high to sign on.");
				break;
			case 983:
				firetalk_callback_error(c,FE_BLOCKED,NULL,"You have been connected and disconnecting too frequently.  Wait 10 minutes.");
				break;
			case 989:
				firetalk_callback_error(c,FE_UNKNOWN,NULL,NULL);
				break;
			default:
				firetalk_callback_error(c,FE_UNKNOWN,NULL,NULL);
				break;
		}
	} else if (strcmp(arg0,"PAUSE") == 0) {
		c->connectstate = 1;
		firetalk_internal_set_connectstate(c,FCS_WAITING_SIGNON);
	} else if (strcmp(arg0,"IM_IN") == 0) {
		args = toc_parse_args(data,4);
		if ((args[1] == NULL) || (args[2] == NULL) || (args[3] == NULL)) {
			(void) toc_internal_disconnect(c,FE_INVALIDFORMAT);
			return FE_INVALIDFORMAT;
		}
		(void) aim_handle_ect(c,args[1],args[3],args[2][0] == 'T' ? 1 : 0);
		if (strlen(args[3]) > 0) {
			char *mestart;
			if (safe_strncasecmp(args[3],"/me ",4) == 0)
				firetalk_callback_im_getaction(c,args[1],args[2][0] == 'T' ? 1 : 0,&args[3][4]);
			else if ((mestart = strstr(args[3],">/me ")) != NULL)
				firetalk_callback_im_getaction(c,args[1],args[2][0] == 'T' ? 1 : 0,&mestart[5]);
			else {
				if (args[2][0] == 'T') /* interpolate only auto-messages */
					firetalk_callback_im_getmessage(c,args[1],1,aim_interpolate_variables(args[3],c->nickname));
				else
					firetalk_callback_im_getmessage(c,args[1],0,args[3]);
			}
		}
	} else if (strcmp(arg0,"UPDATE_BUDDY") == 0) {
		args = toc_parse_args(data,7);
		if (!args[1] || !args[2] || !args[3] || !args[4] || !args[5] || !args[6]) {
			(void) toc_internal_disconnect(c,FE_INVALIDFORMAT);
			return FE_INVALIDFORMAT;
		}
		firetalk_callback_im_buddyonline(c,args[1],args[2][0] == 'T' ? 1 : 0);
		firetalk_callback_user_nickchanged(c,args[1],args[1]);
		firetalk_callback_im_buddyaway(c,args[1],args[6][2] == 'U' ? 1 : 0);
		firetalk_callback_idleinfo(c,args[1],atol(args[5]));
	} else if (strcmp(arg0,"GOTO_URL") == 0) {
		struct s_toc_infoget *i;
		/* create a new infoget object and set it to connecting state */
		args = toc_parse_args(data,3);
		if (!args[1] || !args[2]) {
			(void) toc_internal_disconnect(c,FE_INVALIDFORMAT);
			return FE_INVALIDFORMAT;
		}
		i = c->infoget_head;
		c->infoget_head = safe_malloc(sizeof(struct s_toc_infoget));
#define TOC_HTTP_REQUEST "GET /%s HTTP/1.0\r\n\r\n"

		safe_snprintf(c->infoget_head->buffer,TOC_HTML_MAXLEN,TOC_HTTP_REQUEST,args[2]);
		c->infoget_head->buflen = strlen(c->infoget_head->buffer);
		c->infoget_head->next = i;
		c->infoget_head->state = TOC_STATE_CONNECTING;
		c->infoget_head->sockfd = firetalk_internal_connect(firetalk_internal_remotehost4(c)
#ifdef _FC_USE_IPV6
				firetalk_internal_remotehost6(c)
#endif
				);
		if (c->infoget_head->sockfd == -1) {
			firetalk_callback_error(c,FE_CONNECT,lastinfo[0] == '\0' ? NULL : lastinfo,"Failed to connect to info server");
			free(c->infoget_head);
			c->infoget_head = i;
			return FE_SUCCESS;
		}
	} else if (strcmp(arg0,"EVILED") == 0) {
		args = toc_parse_args(data,3);
		if (!args[1]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"EVILED");
			return FE_SUCCESS;
		}
		firetalk_callback_eviled(c,atoi(args[1]),args[2]);
	} else if (strcmp(arg0,"CHAT_JOIN") == 0) {
		int i;
		args = toc_parse_args(data,3);
		if (!args[1] || !args[2]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"CHAT_JOIN");
			return FE_SUCCESS;
		}
		i = toc_internal_find_exchange(c,args[2]);
		if (i != 0)
			if (toc_internal_set_id(c,args[2],i,args[1]) == FE_SUCCESS)
				if (toc_internal_set_joined(c,args[2],i) == FE_SUCCESS)
					firetalk_callback_chat_joined(c,toc_internal_find_room_name(c,args[1]));
	} else if (strcmp(arg0,"CHAT_LEFT") == 0) {
		args = toc_parse_args(data,2);
		if (!args[1]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"CHAT_LEFT");
			return FE_SUCCESS;
		}
		firetalk_callback_chat_left(c,toc_internal_find_room_name(c,args[1]));
	} else if (strcmp(arg0,"CHAT_IN") == 0) {
		args = toc_parse_args(data,5);
		if (!args[1] || !args[2] || !args[3] || !args[4]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"CHAT_IN");
			return FE_SUCCESS;
		}
		if (safe_strncasecmp(args[4],"<HTML><PRE>",11) == 0) {
			args[4] = &args[4][11];
			if ((tempchr1 = strchr(args[4],'<')))
				tempchr1[0] = '\0';
		}
		if ((safe_strncasecmp(args[4],"/me ",4) == 0) || (safe_strncasecmp(args[4],"<HTML>/me ",9) == 0))
			firetalk_callback_chat_getaction(c,toc_internal_find_room_name(c,args[1]),args[2],0,&args[4][4]);
		else
			firetalk_callback_chat_getmessage(c,toc_internal_find_room_name(c,args[1]),args[2],0,args[4]);
	} else if (strcmp(arg0,"CHAT_INVITE") == 0) {
		args = toc_parse_args(data,5);
		if (!args[1] || !args[2] || !args[3] || !args[4]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"CHAT_INVITE");
			return FE_SUCCESS;
		}
		if (toc_internal_add_room(c,args[1],4) == FE_SUCCESS)
			if (toc_internal_set_room_invited(c,args[1],1) == FE_SUCCESS)
				if (toc_internal_set_id(c,args[1],4,args[2]) == FE_SUCCESS)
					firetalk_callback_chat_invited(c,args[1],args[3],args[4]);
	} else if (strcmp(arg0,"CHAT_UPDATE_BUDDY") == 0) {
		args = toc_parse_args(data,4);
		if (!args[1] || !args[2] || !args[3]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"CHAT_UPDATE_BUDDY");
			return FE_SUCCESS;
		}
		tempchr1 = args[3];
		tempchr3 = toc_internal_find_room_name(c,args[1]);
		while ((tempchr2 = strchr(tempchr1,':'))) {
			/* cycle through list of buddies */
			tempchr2[0] = '\0';
			if (args[2][0] == 'T')
				firetalk_callback_chat_user_joined(c,tempchr3,tempchr1,0);
			else
				firetalk_callback_chat_user_left(c,tempchr3,tempchr1,NULL);
			tempchr1 = tempchr2 + 1;
		}
		if (args[2][0] == 'T')
			firetalk_callback_chat_user_joined(c,tempchr3,tempchr1,0);
		else
			firetalk_callback_chat_user_left(c,tempchr3,tempchr1,NULL);
	} else if (strcmp(arg0,"ADMIN_NICK_STATUS") == 0) {
		/* ignore this one */
	} else if (strcmp(arg0,"NICK") == 0) {
		args = toc_parse_args(data,2);
		if (!args[1]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"NICK");
			return FE_SUCCESS;
		}
		firetalk_callback_user_nickchanged(c,c->nickname,args[1]);
		free(c->nickname);
		c->nickname = safe_strdup(args[1]);
		firetalk_callback_newnick(c,args[1]);
	} else if (strcmp(arg0,"ADMIN_PASSWD_STATUS") == 0) {
		c->passchange--;
		args = toc_parse_args(data,3);
		if (!args[1]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"ADMIN_PASSWD_STATUS");
			return FE_SUCCESS;
		}
		if (atoi(args[1]) != 0)
			firetalk_callback_error(c,FE_NOCHANGEPASS,NULL,NULL);
		else
			firetalk_callback_passchanged(c);
	} else if (strcmp(arg0,"RVOUS_PROPOSE") == 0) {
		args = toc_parse_args(data,255);
		if (!args[1] || !args[2] || !args[3] || !args[4] || !args[5] || !args[6] || !args[7] || !args[8]) {
			firetalk_callback_error(c,FE_INVALIDFORMAT,NULL,"RVOUS_PROPOSE");
			return FE_SUCCESS;
		}
		if (strcmp(args[2],"09461343-4C7F-11D1-8222-444553540000") == 0) {
			/* file send offer */
			char filename[256];
			int length;
			int totalsize = 0;

			length = toc_get_tlv_value(args,9,10001,filename,255);

			if (length < 8) {
				firetalk_callback_error(c,FE_INVALIDFORMAT,args[1],"RVOUS_PROPOSE Invalid TLV length");
				return FE_SUCCESS;
			}
			if (filename[3] != 1) {
				firetalk_callback_error(c,FE_INVALIDFORMAT,args[1],"User offered multiple files (unsupported)");
				return FE_SUCCESS;
			}

			totalsize |= (filename[4] << 24) & 0xff000000;
			totalsize |= (filename[5] << 16) & 0x00ff0000;
			totalsize |= (filename[6] << 8) & 0x0000ff00;
			totalsize |= (filename[7] << 0) & 0x000000ff;

			firetalk_callback_file_offer(c,args[1],&filename[8],totalsize,args[7],NULL,(uint16_t)atoi(args[8]),FF_TYPE_CUSTOM,args[3]);
		}
	} else
		firetalk_callback_error(c,FE_WIERDPACKET,NULL,arg0);

	goto got_data_start;
}

enum firetalk_error toc_got_data_connecting(client_t c, unsigned char * buffer, unsigned short * bufferpos) {
	char data[8192 - TOC_HEADER_LENGTH + 1];
	char password[128];
	enum firetalk_error r;
	unsigned short length;
	char *arg0;
	char **args;
	char *tempchr1;
	char *tempchr2;
	int permit_mode;
	firetalk_t fchandle;

got_data_connecting_start:
	
	r = toc_find_packet(c,buffer,bufferpos,data,c->connectstate == 0 ? SFLAP_FRAME_SIGNON : SFLAP_FRAME_DATA,&length);
	if (r == FE_NOTFOUND)
		return FE_SUCCESS;
	else if (r != FE_SUCCESS)
		return r;

	switch (c->connectstate) {
		case 0: /* we're waiting for the flap version number */
			if (length != TOC_HOST_SIGNON_LENGTH) {
				firetalk_callback_connectfailed(c,FE_PACKETSIZE,"Host signon length incorrect");
				return FE_PACKETSIZE;
			}
			if (data[0] != '\0' || data[1] != '\0' || data[2] != '\0' || data[3] != '\1') {
				firetalk_callback_connectfailed(c,FE_VERSION,NULL);
				return FE_VERSION;
			}
			srand((unsigned int) time(NULL));
			c->local_sequence = (unsigned short) 1+(unsigned short) (65536.0*rand()/(RAND_MAX+1.0));

			length = toc_fill_header((unsigned char *) data,SFLAP_FRAME_SIGNON,++c->local_sequence,toc_fill_signon((unsigned char *)&data[TOC_HEADER_LENGTH],c->nickname));

			fchandle = firetalk_find_handle(c);
			firetalk_internal_send_data(fchandle,data,length,0);

			firetalk_callback_needpass(c,password,128);

			c->connectstate = 1;
			r = toc_send_printf(c,"toc_signon login.oscar.aol.com 5190 %s %s english \"libfiretalk v" LIBFIRETALK_VERSION "\"",c->nickname,toc_hash_password(password));
			if (r != FE_SUCCESS) {
				firetalk_callback_connectfailed(c,r,NULL);
				return r;
			}
			break;
		case 1:
			arg0 = toc_get_arg0(data);
			if (strcmp(arg0,"SIGN_ON") != 0) {
				if (strcmp(arg0,"ERROR") == 0) {
					args = toc_parse_args(data,3);
					if (args[1]) {
						switch (atoi(args[1])) {
							case 980:
								firetalk_callback_connectfailed(c,FE_BADUSERPASS,NULL);
								return FE_BADUSERPASS;
							case 981:
								firetalk_callback_connectfailed(c,FE_SERVER,NULL);
								return FE_SERVER;
							case 982:
								firetalk_callback_connectfailed(c,FE_BLOCKED,"Your warning level is too high to sign on");
								return FE_BLOCKED;
							case 983:
								firetalk_callback_connectfailed(c,FE_BLOCKED,"You have been connecting and disconnecting too frequently");
								return FE_BLOCKED;
						}
					}
				}
				firetalk_callback_connectfailed(c,FE_UNKNOWN,NULL);
				return FE_UNKNOWN;
			}
			c->connectstate = 2;
			break;
		case 2:
		case 3:
			arg0 = toc_get_arg0(data);
			if (arg0 == NULL)
				return FE_SUCCESS;
			if (strcmp(arg0,"NICK") == 0) {
				args = toc_parse_args(data,2);
				if (args[1]) {
					if (c->nickname)
						free(c->nickname);
					c->nickname = safe_strdup(args[1]);
				}
				c->connectstate = 3;
			} else if (strcmp(arg0,"CONFIG") == 0) {
				fchandle = firetalk_find_handle(c);
				args = toc_parse_args(data,2);
				if (!args[1]) {
					firetalk_callback_connectfailed(c,FE_INVALIDFORMAT,"CONFIG");
					return FE_INVALIDFORMAT;
				}
				tempchr1 = args[1];
				permit_mode = 0;
				c->gotconfig = 1;
				while ((tempchr2 = strchr(tempchr1,'\n'))) {
					/* rather stupidly, we have to tell it everything back that it just told us.  how dumb */
					tempchr2[0] = '\0';
					switch (tempchr1[0]) {
						case 'm':    /* permit mode */
							permit_mode = ((int) (tempchr1[2] - '1')) + 1;
							break;
						case 'd':    /* deny */
							firetalk_im_internal_add_deny(fchandle,&tempchr1[2]);
							break;
						case 'b':    /* buddy */
							firetalk_im_internal_add_buddy(fchandle,&tempchr1[2]);
							break;
					}
					tempchr1 = &tempchr2[1];
				}
				if (permit_mode != 4)
					r = toc_send_printf(c,"toc_add_deny");
					if (r != FE_SUCCESS) {
						firetalk_callback_connectfailed(c,r,NULL);
						return r;
					}
			} else {
				firetalk_callback_connectfailed(c,FE_WIERDPACKET,arg0);
				return FE_WIERDPACKET;
			}
			if (c->gotconfig == 1 && c->connectstate == 3) {
				/* ask the client to handle its init */
				firetalk_callback_doinit(c,c->nickname);
				if (toc_im_upload_buddies(c) != FE_SUCCESS) {
					firetalk_callback_connectfailed(c,FE_PACKET,"Error uploading buddies");
					return FE_PACKET;
				}
				if (toc_im_upload_denies(c) != FE_SUCCESS) {
					firetalk_callback_connectfailed(c,FE_PACKET,"Error uploading denies");
					return FE_PACKET;
				}
				r = toc_send_printf(c,"toc_init_done");
				if (r != FE_SUCCESS) {
					firetalk_callback_connectfailed(c,r,NULL);
					return r;
				}
				
				c->online = 1;

				r = toc_send_printf(c,"toc_set_caps 09461343-4C7F-11D1-8222-444553540000");
				if (r != FE_SUCCESS) {
					firetalk_callback_connectfailed(c,r,NULL);
					return r;
				}
				firetalk_callback_connected(c);
				return FE_SUCCESS;
			}
			break;

	}
	goto got_data_connecting_start;
}

enum firetalk_error toc_periodic(struct s_firetalk_handle * const c) {
	struct s_toc_connection *conn;
	time_t idle;
	long passidle;
	char data[32];

	conn = c->handle;

	if (firetalk_internal_get_connectstate(conn) != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	idle = (long) time(NULL) - conn->lasttalk;

	if (idle < 600)
		idle = 0;

	if (idle == conn->lastidle)
		return FE_IDLEFAST;

	if (idle - conn->lastidle < 40)
		if (idle - conn->lastidle > 0)
			return FE_IDLEFAST;

	conn->lastidle = idle;

	passidle = (long) idle;
	firetalk_callback_setidle(conn,&passidle);
	sprintf(data,"%ld",(long) idle);
	return toc_send_printf(conn,"toc_set_idle %s",data);
}

enum firetalk_error toc_chat_join(client_t c, const char * const room) {
	int i;
	char *s;
	s = toc_internal_split_name(room);
	i = toc_internal_get_room_invited(c,s);
	if (i == 1) {
		(void) toc_internal_set_room_invited(c,room,0);
		return toc_send_printf(c,"toc_chat_accept %s",toc_internal_find_room_id(c,room));
	} else {
		int m;
		(void) toc_internal_add_room(c,s,m = toc_internal_split_exchange(room));
		return toc_send_printf(c,"toc_chat_join %d %s",m,s);
	}
}

enum firetalk_error toc_chat_part(client_t c, const char * const room) {
	char *temp = toc_internal_find_room_id(c,room);
	if (!temp)
		return FE_ROOMUNAVAILABLE;
	return toc_send_printf(c,"toc_chat_leave %s",temp);
}

enum firetalk_error toc_chat_set_topic(client_t c, const char * const room, const char * const topic) {
	return FE_SUCCESS;
}

enum firetalk_error toc_chat_op(client_t c, const char * const room, const char * const who) {
	return FE_SUCCESS;
}

enum firetalk_error toc_chat_deop(client_t c, const char * const room, const char * const who) {
	return FE_SUCCESS;
}

enum firetalk_error toc_chat_kick(client_t c, const char * const room, const char * const who, const char * const reason) {
	return FE_SUCCESS;
}

enum firetalk_error toc_chat_send_message(client_t c, const char * const room, const char * const message, const int auto_flag) {
	char *temp = toc_internal_find_room_id(c,room);
	if (!temp)
		return FE_ROOMUNAVAILABLE;
	return toc_send_printf(c,"toc_chat_send %s %s",temp,message);
}

enum firetalk_error toc_chat_send_action(client_t c, const char * const room, const char * const message, const int auto_flag) {
	char tempbuf[2048];

	if (strlen(message) > 2042)
		return FE_PACKETSIZE;
		
	safe_strncpy(tempbuf,"/me ",2048);
	safe_strncat(tempbuf,message,2048);
	return toc_send_printf(c,"toc_chat_send %s %s",toc_internal_find_room_id(c,room),tempbuf);
}

enum firetalk_error toc_chat_invite(client_t c, const char * const room, const char * const who, const char * const message) {
	char *roomid;
	roomid = toc_internal_find_room_id(c,room);
	if (roomid != NULL)
		return toc_send_printf(c,"toc_chat_invite %s %s %s",toc_internal_find_room_id(c,room),message,who);
	else
		return FE_NOTFOUND;
}

enum firetalk_error toc_subcode_send_request(client_t c, const char * const to, const char * const command, const char * const args) {
	char buffer[2048];
	if (args == NULL)
		safe_snprintf(buffer,2048,"<!--ECT %s-->",command);
	else
		safe_snprintf(buffer,2048,"<!--ECT %s %s-->",command,args);
	return toc_im_send_message(c,to,buffer,0);
}

enum firetalk_error toc_subcode_send_reply(client_t c, const char * const to, const char * const command, const char * const args) {
	char buffer[2048];
	if (args == NULL)
		safe_snprintf(buffer,2048,"<!--ECT %s-->",command);
	else
		safe_snprintf(buffer,2048,"<!--ECT %s %s-->",command,args);
	return toc_im_send_message(c,to,buffer,1);
}
