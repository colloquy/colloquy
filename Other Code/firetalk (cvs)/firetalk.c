/*
firetalk.c - FireTalk wrapper definitions
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
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <strings.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <time.h>
#include <sys/stat.h>
#include <netdb.h>
#include <math.h>
#include <errno.h>
#include <setjmp.h>
#include <signal.h>
#include <fcntl.h>

#define FIRETALK

#include "firetalk-int.h"
#include "firetalk.h"

#include "dummy.h"

#ifndef DISABLE_IRC_PROTOCOL
#include "irc.h"
#endif

#ifndef DISABLE_TOC_PROTOCOL
#include "toc.h"
#include "aim.h"
#endif

#include "safestring.h"

typedef void (*ptrtotoc)(void *, ...);
typedef void (*sighandler_t)(int);

/* Global variables */
enum firetalk_error firetalkerror;
static struct s_firetalk_handle *handle_head = NULL;
static jmp_buf buf;
static sighandler_t oldhandler;

/* 
 * client can send up to <flood> messages in <delay>
 * the first time they break that, we wait <delay>
 * if they break that, we wait <delay> * <backoff>
 * if they break that, we wait <delay> * <backoff> * <backoff>
 * .....
 * up to a maximum of <ceiling>
 * */
static const double firetalkrates[][4] = {
	/* flood, delay, backoff, ceiling */
#ifndef DISABLE_TOC_PROTOCOL
	{ 2.0, 0.4, 1.5, 5.0 }
#endif
#if (!defined(DISABLE_TOC_PROTOCOL) && !defined(DISABLE_IRC_PROTOCOL))
	,
#endif
#ifndef DISABLE_IRC_PROTOCOL
	{ 6.0, 1.0, 1.5, 2.5 }
#endif
};

static const char *defaultserver[] = {
#ifndef DISABLE_TOC_PROTOCOL
	"toc.oscar.aol.com"
#endif
#if (!defined(DISABLE_TOC_PROTOCOL) && !defined(DISABLE_IRC_PROTOCOL))
	,
#endif
#ifndef DISABLE_IRC_PROTOCOL
	"irc.freenode.net"
#endif
};

static const short defaultport[] = {
#ifndef DISABLE_TOC_PROTOCOL
	9898
#endif
#if (!defined(DISABLE_TOC_PROTOCOL) && !defined(DISABLE_IRC_PROTOCOL))
	,
#endif
#ifndef DISABLE_IRC_PROTOCOL
	6667
#endif
};

static const unsigned short buffersize[] = {
#ifndef DISABLE_TOC_PROTOCOL
	8192
#endif
#if (!defined(DISABLE_TOC_PROTOCOL) && !defined(DISABLE_IRC_PROTOCOL))
	,
#endif
#ifndef DISABLE_IRC_PROTOCOL
	512
#endif
};

static const struct s_firetalk_protocol_functions protocol_functions[FP_MAX] = {
#ifndef DISABLE_TOC_PROTOCOL
	{ /* FP_AIMTOC */
		toc_periodic,
		toc_preselect,
		toc_postselect,
		toc_got_data,
		toc_got_data_connecting,
		toc_prepare_for_transmit,
		aim_compare_nicks,
		toc_disconnect,
		toc_signon,
		dummy_send_raw,
		toc_save_config,
		dummy_get_roomlist,
		dummy_stop_roomlist,
		toc_get_info,
		toc_set_info,
		toc_set_away,
		toc_set_nickname,
		toc_set_password,
		toc_im_add_buddy,
		toc_im_remove_buddy,
		toc_im_add_deny,
		dummy_im_remove_deny,
		toc_im_upload_buddies,
		toc_im_upload_denies,
		toc_im_send_message,
		toc_im_send_action,
		toc_im_evil,
		toc_chat_join,
		toc_chat_part,
		toc_chat_invite,
		dummy_chat_set_topic,
		dummy_chat_op,
		dummy_chat_deop,
		dummy_chat_voice,
		dummy_chat_devoice,
		dummy_chat_kick,
		toc_chat_send_message,
		toc_chat_send_action,
		toc_subcode_send_request,
		toc_subcode_send_reply,
		aim_file_handle_custom,
		aim_file_complete_custom,
		aim_normalize_room_name,
		toc_create_handle,
		toc_destroy_handle
	}
#endif
#if (!defined(DISABLE_TOC_PROTOCOL) && !defined(DISABLE_IRC_PROTOCOL))
,
#endif
#ifndef DISABLE_IRC_PROTOCOL
	{ /* FP_IRC */
		irc_periodic,
		irc_preselect,
		dummy_postselect,
		irc_got_data,
		irc_got_data_connecting,
		irc_prepare_for_transmit,
		irc_compare_nicks,
		irc_disconnect,
		irc_signon,
		irc_send_raw,
		dummy_save_config,
		irc_get_roomlist,
		irc_stop_roomlist,
		irc_get_info,
		dummy_set_info,
		irc_set_away,
		irc_set_nickname,
		irc_set_password,
		irc_im_add_buddy,
		dummy_im_remove_buddy,
		irc_im_add_deny,
		irc_im_remove_deny,
		dummy_im_upload_buddies,
		dummy_im_upload_denies,
		irc_im_send_message,
		irc_im_send_action,
		dummy_im_evil,
		irc_chat_join,
		irc_chat_part,
		irc_chat_invite,
		irc_chat_set_topic,
		irc_chat_op,
		irc_chat_deop,
		irc_chat_voice,
		irc_chat_devoice,
		irc_chat_kick,
		irc_chat_send_message,
		irc_chat_send_action,
		irc_subcode_send_request,
		irc_subcode_send_reply,
		dummy_file_handle_custom,
		dummy_file_complete_custom,
		irc_normalize_room_name,
		irc_create_handle,
		irc_destroy_handle
	}
#endif
};

/* Internal function definitions */

void firetalk_timeout_handler(int signal) {
	longjmp(buf,1);
}

void firetalk_set_timeout(unsigned int seconds) {
	alarm(0);
	oldhandler = signal(SIGALRM,firetalk_timeout_handler);
	alarm(seconds);
}

void firetalk_clear_timeout() {
	alarm(0);
	signal(SIGALRM,oldhandler);
}

double firetalk_gettime() {
	struct timeval tv;

	if (gettimeofday(&tv,NULL) != 0)
		return -1;

	return tv.tv_sec + (((double) tv.tv_usec) / 1000000.0);
}

firetalk_t firetalk_find_handle(client_t c) {
	struct s_firetalk_handle *iter;
	iter = handle_head;
	while (iter) {
		if (iter->handle == c)
			return iter;
		iter = iter->next;
	}
	return NULL;
}

#ifdef DEBUG
enum firetalk_error firetalk_check_handle(firetalk_t c) {
	struct s_firetalk_handle *iter;
	iter = handle_head;
	while (iter) {
		if (iter == c)
			return FE_SUCCESS;
		iter = iter->next;
	}
	return FE_BADHANDLE;
}
#endif

static char **firetalk_parse_subcode_args(char *string) {
	static char *args[256];
	int i,n;
	size_t l;
	l = strlen(string);
	args[0] = string;
	n = 1;
	for (i = 0; (size_t) i < l && n < 255; i++) {
		if (string[i] == ' ') {
			string[i++] = '\0';
			args[n++] = &string[i];
		}
	}
	args[n] = NULL;
	return args;
}

enum firetalk_error firetalk_im_internal_add_buddy(firetalk_t conn, const char * const nickname) {
	struct s_firetalk_buddy *iter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter = conn->buddy_head;
	while (iter) {
		if (protocol_functions[conn->protocol].comparenicks(iter->nickname,nickname) == FE_SUCCESS)
			return FE_DUPEUSER; /* not an error, user is in buddy list */
		iter = iter->next;
	}

	iter = conn->buddy_head;
	conn->buddy_head = safe_malloc(sizeof(struct s_firetalk_buddy));
	conn->buddy_head->next = iter;
	conn->buddy_head->nickname = safe_strdup(nickname);
	conn->buddy_head->online = 0;
	conn->buddy_head->away = 0;
	conn->buddy_head->idletime = 0;
	conn->buddy_head->tempint = 0;
	conn->buddy_head->tempint2 = 0;
	return FE_SUCCESS;
}

enum firetalk_error firetalk_im_internal_add_deny(firetalk_t conn, const char * const nickname) {
	struct s_firetalk_deny *iter;
	struct s_firetalk_buddy *buddyiter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter = conn->deny_head;
	while (iter) {
		if (protocol_functions[conn->protocol].comparenicks(iter->nickname,nickname) == FE_SUCCESS)
			return FE_DUPEUSER; /* not an error, user is in buddy list */
		iter = iter->next;
	}

	iter = conn->deny_head;
	conn->deny_head = safe_malloc(sizeof(struct s_firetalk_deny));
	conn->deny_head->next = iter;
	conn->deny_head->nickname = safe_strdup(nickname);

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (protocol_functions[conn->protocol].comparenicks(buddyiter->nickname,nickname) == FE_SUCCESS) {
			if ((buddyiter->online == 1) && (conn->callbacks[FC_IM_BUDDYOFFLINE] != NULL))
				conn->callbacks[FC_IM_BUDDYOFFLINE](conn,conn->clientstruct,buddyiter->nickname);
		}
		buddyiter = buddyiter->next;
	}

	return FE_SUCCESS;
}

int firetalk_internal_resolve4(const char * const host, struct in_addr *inet4_ip) {
	struct hostent *he = NULL;
	if (setjmp(buf))
		return FE_TIMEOUT;	
	
	firetalk_set_timeout(5);

	he = gethostbyname(host);
	if (he && he != (struct hostent *) FE_TIMEOUT && he->h_addr_list) {
		memcpy(&inet4_ip->s_addr,he->h_addr_list[0],4);
		firetalk_clear_timeout();
		return FE_SUCCESS;
	}
	if (he == (struct hostent *) FE_TIMEOUT) return FE_TIMEOUT;

	firetalk_clear_timeout();
	return FE_NOTFOUND;
}

struct sockaddr_in *firetalk_internal_remotehost4(client_t c) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	return &conn->remote_addr;
}

#ifdef _FC_USE_IPV6
int firetalk_internal_resolve6(const char * const host, struct in6_addr *inet6_ip) {
	struct hostent *he = NULL;
	int result = 0;
	if (setjmp(buf))
		return FE_TIMEOUT;

	firetalk_set_timeout(5);

	he = getipnodebyname(host, AF_INET6, AI_ADDRCONFIG, &result);
	if (he && he != (struct hostent *) FE_TIMEOUT && he->h_addr_list) {
		memcpy(&inet6_ip->s6_addr,he->h_addr_list[0],16);
		firetalk_clear_timeout();
		return FE_SUCCESS;
	}
	if (he == (struct hostent *) FE_TIMEOUT) return FE_TIMEOUT;

	firetalk_clear_timeout();
	return FE_NOTFOUND;
}

struct sockaddr_in6 *firetalk_internal_remotehost6(client_t c) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	return &conn->remote_addr6;
}

#endif

int firetalk_internal_connect_host(const char * const host, const uint16_t port, enum firetalk_proxy proxy) {
	struct sockaddr_in myinet4;
	struct sockaddr_in *sendinet4 = NULL;
#ifdef _FC_USE_IPV6
	struct sockaddr_in6 myinet6;
	struct sockaddr_in6 *sendinet6 = NULL;
#endif

#ifdef _FC_USE_IPV6	
	if ((firetalkerror = firetalk_internal_resolve6(host,&myinet6.sin6_addr)) == FE_SUCCESS) {
		myinet6.sin6_port = htons(port);
		myinet6.sin6_family = AF_INET6;
		sendinet6 = &myinet6;
	} else return -1;
#endif
	if ((firetalkerror = firetalk_internal_resolve4(host,&myinet4.sin_addr)) == FE_SUCCESS) {
		myinet4.sin_port = htons(port);
		myinet4.sin_family = AF_INET;
		sendinet4 = &myinet4;
	} else return -1;

	return firetalk_internal_connect(sendinet4
#ifdef _FC_USE_IPV6
	   , sendinet6
#endif
	   , proxy
	   );
}

int firetalk_internal_connect(struct sockaddr_in *inet4_ip
#ifdef _FC_USE_IPV6
		, struct sockaddr_in6 *inet6_ip
#endif
		, enum firetalk_proxy proxy
		) {
	int s,i;

	signal (SIGPIPE, SIG_IGN);
#ifdef _FC_USE_IPV6
	if (inet6_ip) {
		s = socket(PF_INET6, SOCK_STREAM, 0);
		if (s == -1)
			goto ipv6fail;
		if (fcntl(s, F_SETFL, O_NONBLOCK))
			goto ipv6fail;
		i = firetalk_connect(s,(const struct sockaddr *)inet6_ip,sizeof(struct sockaddr_in6),proxy);
		if (i != 0 && errno != EINPROGRESS)
			goto ipv6fail;
		return s;
	}
ipv6fail:
#endif

	if (inet4_ip) {
		s = socket(PF_INET, SOCK_STREAM, 0);
		if (s == -1)
			goto ipv4fail;
		if (fcntl(s, F_SETFL, O_NONBLOCK))
			goto ipv4fail;
		i = firetalk_connect(s,(const struct sockaddr *)inet4_ip,sizeof(struct sockaddr_in),proxy);
		if (i != 0 && errno != EINPROGRESS)
			goto ipv4fail;
		return s;
	}
ipv4fail:

	signal (SIGPIPE, SIG_DFL);

	firetalkerror = FE_CONNECT;
	return -1;
}

enum firetalk_connectstate firetalk_internal_get_connectstate(client_t c) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	return conn->connected;
}

void firetalk_internal_set_connectstate(client_t c, enum firetalk_connectstate fcs) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	conn->connected = fcs;
}

void firetalk_internal_file_register_customdata(client_t c, int fd, void *customdata) {
	firetalk_t conn;
	struct s_firetalk_file *fileiter;

	conn = firetalk_find_handle(c);
	fileiter = conn->file_head;
	while (fileiter) {
		if (fileiter->sockfd == fd) {
			fileiter->customdata = customdata;
			return;
		}
	}
}

void firetalk_internal_send_data(firetalk_t c, char * const data, const int length, const int urgent) {
	double curtime;

	if (!c) return;

	curtime = firetalk_gettime();
	if (curtime > c->lastsend + c->flood_intervals[1]) {
		c->lastsend = curtime;
		c->flood = 0;
	}

	c->flood++;

	/* if this isn't an urgent message and (there's already a queue or we're over the flood limit) queue it */
	if (urgent == 0 && (c->datatail != NULL || c->flood > c->flood_intervals[0] || c->connected != FCS_ACTIVE)) {
		/* queue */
		struct s_firetalk_queued_data *d;
		d = safe_malloc(sizeof(struct s_firetalk_queued_data));
		d->length = length;
		d->data = safe_malloc(length);
		memcpy(d->data,data,length);
		d->next = NULL;
		if (c->datatail == NULL) {
			/* first item in queue */
			c->datatail = d;
			c->datahead = d;
			d->delta = c->flood_intervals[1];
		} else {
			/* add to end of queue */
			c->datatail->next = d;
			d->delta = c->datatail->delta * c->flood_intervals[2]; /* backoff */
			if (d->delta > c->flood_intervals[3]) /* enforce ceiling */
				d->delta = c->flood_intervals[3];
			c->datatail = d;
		}
		firetalk_callback_backlog(c);
	} else {
		/* send now */
		protocol_functions[c->protocol].prepare_for_transmit(c->handle,data,length);
		if (send(c->fd,data,length,0) != length) {
			/* disconnect client (we probably overran the kernel queue, or the other end is gone) */
			firetalk_callback_disconnect(c->handle,FE_PACKET);
		}
	}
}

void firetalk_transmit(struct s_firetalk_handle *c) {
	double t;
	struct s_firetalk_queued_data *d;
	if (c->connected != FCS_ACTIVE)
		return;

	if (c->datahead == NULL)
		return;

	t = firetalk_gettime();
	if (c->lasttransmit + c->datahead->delta > t)
		return;

	protocol_functions[c->protocol].prepare_for_transmit(c->handle,c->datahead->data,c->datahead->length);
	if (send(c->fd,c->datahead->data,c->datahead->length,0) != c->datahead->length)
		/* disconnect client (we probably overran the kernel queue, or the other end is gone) */
		firetalk_callback_disconnect(c->handle,FE_PACKET);
	c->lasttransmit = t;
	d = c->datahead;
	c->datahead = c->datahead->next;
	if (c->datahead == NULL)
		c->datatail = NULL;
	free(d->data);
	free(d);
	firetalk_callback_backlog(c);
}

enum firetalk_error firetalk_chat_internal_add_room(firetalk_t conn, const char * const name) {
	struct s_firetalk_room *iter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter = conn->room_head;
	while (iter) {
		if (protocol_functions[conn->protocol].comparenicks(iter->name,name) == FE_SUCCESS)
			return FE_DUPEROOM; /* not an error, we're already in room */
		iter = iter->next;
	}

	iter = conn->room_head;
	conn->room_head = safe_malloc(sizeof(struct s_firetalk_room));
	conn->room_head->next = iter;
	conn->room_head->name = safe_strdup(name);
	conn->room_head->member_head = NULL;
	conn->room_head->admin = 0;
	conn->room_head->voice = 0;
	conn->room_head->topic = NULL;
	conn->room_head->author = NULL;

	return FE_SUCCESS;
}

enum firetalk_error firetalk_chat_internal_add_member(firetalk_t conn, const char * const room, const char * const nickname) {
	struct s_firetalk_room *iter;
	struct s_firetalk_room *roomhandle;
	struct s_firetalk_member *memberiter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter = conn->room_head;
	roomhandle = NULL;
	while ((iter != NULL) && (roomhandle == NULL)) {
		if (protocol_functions[conn->protocol].comparenicks(iter->name,room) == FE_SUCCESS)
			roomhandle = iter;
		iter = iter->next;
	}

	if (!roomhandle) /* we don't know about that room */
		return FE_NOTFOUND;

	memberiter = roomhandle->member_head;
	while (memberiter) {
		if (protocol_functions[conn->protocol].comparenicks(memberiter->nickname,nickname) == FE_SUCCESS)
			return FE_SUCCESS;
		memberiter = memberiter->next;
	}

	memberiter = roomhandle->member_head;
	roomhandle->member_head = safe_malloc(sizeof(struct s_firetalk_member));
	roomhandle->member_head->next = memberiter;
	roomhandle->member_head->nickname = safe_strdup(nickname);
	roomhandle->member_head->admin = 0;
	roomhandle->member_head->voice = 0;

	return FE_SUCCESS;
}

enum firetalk_error firetalk_im_internal_remove_buddy(firetalk_t conn, const char * const nickname) {
	struct s_firetalk_buddy *iter;
	struct s_firetalk_buddy *iter2;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter2 = NULL;
	iter = conn->buddy_head;
	while (iter) {
		if (protocol_functions[conn->protocol].comparenicks(nickname,iter->nickname) == FE_SUCCESS) {
			if (iter2)
				iter2->next = iter->next;
			else
				conn->buddy_head = iter->next;
			if (iter->nickname)
				free(iter->nickname);
			free(iter);
			return FE_SUCCESS;
		}
		iter2 = iter;
		iter = iter->next;
	}

	return FE_NOTFOUND;
}

enum firetalk_error firetalk_im_internal_remove_deny(firetalk_t conn, const char * const nickname) {
	struct s_firetalk_deny *iter;
	struct s_firetalk_deny *iter2;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter2 = NULL;
	iter = conn->deny_head;
	while (iter) {
		if (protocol_functions[conn->protocol].comparenicks(nickname,iter->nickname) == FE_SUCCESS) {
			if (iter2)
				iter2->next = iter->next;
			else
				conn->deny_head = iter->next;
			if (iter->nickname)
				free(iter->nickname);
			free(iter);
			return FE_SUCCESS;
		}
		iter2 = iter;
		iter = iter->next;
	}

	return FE_NOTFOUND;
}

enum firetalk_error firetalk_chat_internal_remove_room(firetalk_t conn, const char * const name) {
	struct s_firetalk_room *iter;
	struct s_firetalk_room *iter2;
	struct s_firetalk_member *memberiter;
	struct s_firetalk_member *memberiter2;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter2 = NULL;
	iter = conn->room_head;
	while (iter) {
		if (protocol_functions[conn->protocol].comparenicks(name,iter->name) == FE_SUCCESS) {
			memberiter = iter->member_head;
			while (memberiter) {
				memberiter2 = memberiter->next;
				free(memberiter->nickname);
				free(memberiter);
				memberiter = memberiter2;
			}
			if (iter->topic != NULL)
				free(iter->topic);
			if (iter->author != NULL)
				free(iter->author);
			if (iter2)
				iter2->next = iter->next;
			else
				conn->room_head = iter->next;
			if (iter->name)
				free(iter->name);
			free(iter);
			return FE_SUCCESS;
		}
		iter2 = iter;
		iter = iter->next;
	}

	return FE_NOTFOUND;
}

enum firetalk_error firetalk_chat_internal_remove_member(firetalk_t conn, const char * const room, const char * const nickname) {
	struct s_firetalk_room *iter;
	struct s_firetalk_room *roomhandle;
	struct s_firetalk_member *memberiter;
	struct s_firetalk_member *memberiter2;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter = conn->room_head;
	roomhandle = NULL;
	while ((iter != NULL) && (roomhandle == NULL)) {
		if (protocol_functions[conn->protocol].comparenicks(iter->name,room) == FE_SUCCESS)
			roomhandle = iter;
		iter = iter->next;
	}

	if (!roomhandle) /* we don't know about that room */
		return FE_NOTFOUND;

	memberiter2 = NULL;
	memberiter = roomhandle->member_head;
	while (memberiter) {
		if (protocol_functions[conn->protocol].comparenicks(memberiter->nickname,nickname) == FE_SUCCESS) {
			if (memberiter2)
				memberiter2->next = memberiter->next;
			else
				roomhandle->member_head = memberiter->next;
			if (memberiter->nickname)
				free(memberiter->nickname);
			free(memberiter);
			return FE_SUCCESS;
		}
		memberiter2 = memberiter;
		memberiter = memberiter->next;
	}

	return FE_SUCCESS;
}

struct s_firetalk_room *firetalk_find_room(firetalk_t c, const char * const room) {
	struct s_firetalk_room *roomiter;
	const char *normalroom;
	normalroom = protocol_functions[c->protocol].room_normalize(room);
	roomiter = c->room_head;
	while (roomiter) {
		if (protocol_functions[c->protocol].comparenicks(roomiter->name,normalroom) == FE_SUCCESS)
			return roomiter;
		roomiter = roomiter->next;
	}

	firetalkerror = FE_NOTFOUND;
	return NULL;
}

static struct s_firetalk_member *firetalk_find_member(firetalk_t c, struct s_firetalk_room *r, const char * const name) {
	struct s_firetalk_member *memberiter;
	memberiter = r->member_head;
	while (memberiter) {
		if (protocol_functions[c->protocol].comparenicks(memberiter->nickname,name) == FE_SUCCESS)
			return memberiter;
		memberiter = memberiter->next;
	}

	firetalkerror = FE_NOTFOUND;
	return NULL;
}

void firetalk_callback_raw_message(client_t c, const char * const raw, int output) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_RAW_MESSAGE])
		conn->callbacks[FC_RAW_MESSAGE](conn,conn->clientstruct,raw,output);
	return;
}

void firetalk_callback_needpass(client_t c, char *pass, const int size) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_NEEDPASS])
		conn->callbacks[FC_NEEDPASS](conn,conn->clientstruct,pass,size);
	return;
}

void firetalk_callback_im_getmessage(client_t c, const char * const sender, const int automessage, const char * const message) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_deny *iter;
	conn = firetalk_find_handle(c);
	if (conn->callbacks[FC_IM_GETMESSAGE]) {
		iter = conn->deny_head;
		while (iter) {
			if (protocol_functions[conn->protocol].comparenicks(sender,iter->nickname) == FE_SUCCESS)
				return;
			iter = iter->next;
		}
		conn->callbacks[FC_IM_GETMESSAGE](conn,conn->clientstruct,sender,automessage,message);
	}
	return;
}

void firetalk_callback_im_getaction(client_t c, const char * const sender, const int automessage, const char * const message) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_deny *iter;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_IM_GETACTION]) {
		iter = conn->deny_head;
		while (iter) {
			if (protocol_functions[conn->protocol].comparenicks(sender,iter->nickname) == FE_SUCCESS)
				return;
			iter = iter->next;
		}
		conn->callbacks[FC_IM_GETACTION](conn,conn->clientstruct,sender,automessage,message);
	}
	return;
}

void firetalk_callback_im_buddyonline(client_t c, const char * const nickname, const int online) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;

	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (protocol_functions[conn->protocol].comparenicks(buddyiter->nickname,nickname) == FE_SUCCESS) {
			/* match */
			if (buddyiter->online != online) {
				buddyiter->online = online;
				if ((online == 1) && (conn->callbacks[FC_IM_BUDDYONLINE] != NULL)) {
					if (strcmp(buddyiter->nickname,nickname) != 0) {
						free(buddyiter->nickname);
						buddyiter->nickname = safe_strdup(nickname);
					}
					conn->callbacks[FC_IM_BUDDYONLINE](conn,conn->clientstruct,nickname);
				} else if ((online == 0) && (conn->callbacks[FC_IM_BUDDYOFFLINE] != NULL))
					conn->callbacks[FC_IM_BUDDYOFFLINE](conn,conn->clientstruct,nickname);
				return;
			}
		}
		buddyiter = buddyiter->next;
	}
	return;
}

void firetalk_callback_im_buddyaway(client_t c, const char * const nickname, const int away) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;

	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (protocol_functions[conn->protocol].comparenicks(buddyiter->nickname,nickname) == FE_SUCCESS) {
			/* match */
			if (buddyiter->away != away && (buddyiter->online == 1)) {
				buddyiter->away = away;
				if ((away == 1) && (conn->callbacks[FC_IM_BUDDYAWAY] != NULL))
					conn->callbacks[FC_IM_BUDDYAWAY](conn,conn->clientstruct,nickname);
				else if ((away == 0) && (conn->callbacks[FC_IM_BUDDYUNAWAY] != NULL))
					conn->callbacks[FC_IM_BUDDYUNAWAY](conn,conn->clientstruct,nickname);
				return;
			}
		}
		buddyiter = buddyiter->next;
	}
	return;
}

void firetalk_callback_error(client_t c, const int error, const char * const roomoruser, const char * const description) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_ERROR])
		conn->callbacks[FC_ERROR](conn,conn->clientstruct,error,roomoruser,description);
	return;
}

void firetalk_callback_connectfailed(client_t c, const int error, const char * const description) {
	firetalk_t conn;
	conn = firetalk_find_handle(c);

	if (conn->connected == FCS_NOTCONNECTED)
		return;

	close(conn->fd);
	conn->connected = FCS_NOTCONNECTED;
	if (conn->callbacks[FC_CONNECTFAILED])
		conn->callbacks[FC_CONNECTFAILED](conn,conn->clientstruct,error,description);
	return;
}

void firetalk_callback_backlog(firetalk_t c) {
	struct s_firetalk_queued_data *d;
	double backlog = 0.0;

	d = c->datahead;
	while (d != NULL) {
		backlog += d->delta;
		d = d->next;
	}
	if (c->callbacks[FC_BACKLOG] != NULL)
		c->callbacks[FC_BACKLOG](c,c->clientstruct,backlog);
}

void firetalk_callback_disconnect(client_t c, const int error) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;
	struct s_firetalk_buddy *buddyiter2;
	struct s_firetalk_deny *denyiter;
	struct s_firetalk_deny *denyiter2;
	struct s_firetalk_room *roomiter;
	struct s_firetalk_room *roomiter2;
	struct s_firetalk_member *memberiter;
	struct s_firetalk_member *memberiter2;

	conn = firetalk_find_handle(c);

	if (!conn) return;

	if (conn->connected == FCS_NOTCONNECTED)
		return;
	close(conn->fd);

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		buddyiter2 = buddyiter;
		buddyiter = buddyiter->next;
		free(buddyiter2->nickname);
		free(buddyiter2);
	}
	conn->buddy_head = NULL;

	denyiter = conn->deny_head;
	while (denyiter) {
		denyiter2 = denyiter;
		denyiter = denyiter->next;
		free(denyiter2->nickname);
		free(denyiter2);
	}
	conn->deny_head = NULL;

	roomiter = conn->room_head;
	while (roomiter) {
		roomiter2 = roomiter;
		roomiter = roomiter->next;
		memberiter = roomiter2->member_head;
		while (memberiter) {
			memberiter2 = memberiter;
			memberiter = memberiter->next;
			free(memberiter2->nickname);
			free(memberiter2);
		}
		free(roomiter2->name);
		free(roomiter2);
	}
	conn->room_head = NULL;

	if (conn->connected == FCS_NOTCONNECTED)
		return;
	conn->connected = FCS_NOTCONNECTED;

	if (conn->callbacks[FC_DISCONNECT])
		conn->callbacks[FC_DISCONNECT](conn,conn->clientstruct,error);
	return;
}

void firetalk_callback_gotinfo(client_t c, const char * const nickname, const char * const username, const char * const hostname, const char * const server, const char * const realname, const int warning, const long idle, const long connected, const int flags) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_IM_GOTINFO])
		conn->callbacks[FC_IM_GOTINFO](conn,conn->clientstruct,nickname,username,hostname,server,realname,warning,idle,connected,flags);
	return;
}

void firetalk_callback_idleinfo(client_t c, char const * const nickname, const long idletime) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;

	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;

	if (!conn->callbacks[FC_IM_IDLEINFO])
		return;

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (protocol_functions[conn->protocol].comparenicks(buddyiter->nickname,nickname) == FE_SUCCESS) {
			/* match */
			if (buddyiter->idletime != idletime && (buddyiter->online == 1)) {
				buddyiter->idletime = idletime;
				conn->callbacks[FC_IM_IDLEINFO](conn,conn->clientstruct,nickname,idletime);
				return;
			}
		}
		buddyiter = buddyiter->next;
	}
	return;
}

void firetalk_callback_doinit(client_t c, const char * const nickname) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_DOINIT])
		conn->callbacks[FC_DOINIT](conn,conn->clientstruct,nickname);
	return;
}

void firetalk_callback_setidle(client_t c, long * const idle) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_SETIDLE])
		conn->callbacks[FC_SETIDLE](conn,conn->clientstruct,idle);
	return;
}

void firetalk_callback_eviled(client_t c, const int newevil, const char * const eviler) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_EVILED])
		conn->callbacks[FC_EVILED](conn,conn->clientstruct,newevil,eviler);
	return;
}

void firetalk_callback_newnick(client_t c, const char * const nickname) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_NEWNICK])
		conn->callbacks[FC_NEWNICK](conn,conn->clientstruct,nickname);
	return;
}

void firetalk_callback_passchanged(client_t c) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_PASSCHANGED])
		conn->callbacks[FC_PASSCHANGED](conn,conn->clientstruct);
	return;
}

void firetalk_callback_gotroomlist(client_t c, const char * const room, const int users, const char * const topic) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_IM_LISTROOM])
		conn->callbacks[FC_IM_LISTROOM](conn,conn->clientstruct,room,users,topic);
	return;
}

void firetalk_callback_user_nickchanged(client_t c, const char * const oldnick, const char * const newnick) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;
	struct s_firetalk_room *roomiter;
	struct s_firetalk_member *memberiter;
	char *tempstr;

	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (protocol_functions[conn->protocol].comparenicks(buddyiter->nickname,oldnick) == FE_SUCCESS) {
			/* match */
			if (strcmp(buddyiter->nickname,newnick) != 0) {
				tempstr = buddyiter->nickname;
				buddyiter->nickname = safe_strdup(newnick);
				if (conn->callbacks[FC_IM_USER_NICKCHANGED])
					conn->callbacks[FC_IM_USER_NICKCHANGED](conn,conn->clientstruct,tempstr,newnick);
				if (tempstr)
					free(tempstr);
			}
		}
		buddyiter = buddyiter->next;
	}

	roomiter = conn->room_head;
	while (roomiter) {
		memberiter = roomiter->member_head;
		while (memberiter) {
			if (protocol_functions[conn->protocol].comparenicks(memberiter->nickname,oldnick) == FE_SUCCESS) {
				/* match */
				if (strcmp(memberiter->nickname,newnick) != 0) {
					tempstr = memberiter->nickname;
					memberiter->nickname = safe_strdup(newnick);
					if (conn->callbacks[FC_CHAT_USER_NICKCHANGED])
						conn->callbacks[FC_CHAT_USER_NICKCHANGED](conn,conn->clientstruct,roomiter->name,tempstr,newnick);
					if (tempstr)
						free(tempstr);
				}
			}
			memberiter = memberiter->next;
		}
		roomiter = roomiter->next;
	}
	return;
}

void firetalk_callback_chat_joined(client_t c, const char * const room) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (firetalk_chat_internal_add_room(conn,room) != FE_SUCCESS)
		return;
	if (conn->callbacks[FC_CHAT_JOINED])
		conn->callbacks[FC_CHAT_JOINED](conn,conn->clientstruct,room);
	return;
}

void firetalk_callback_chat_left(client_t c, const char * const room) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (firetalk_chat_internal_remove_room(conn,room) != FE_SUCCESS)
		return;
	if (conn->callbacks[FC_CHAT_LEFT])
		conn->callbacks[FC_CHAT_LEFT](conn,conn->clientstruct,room);
	return;
}

void firetalk_callback_chat_kicked(client_t c, const char * const room, const char * const by, const char * const reason) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (firetalk_chat_internal_remove_room(conn,room) != FE_SUCCESS)
		return;
	if (conn->callbacks[FC_CHAT_KICKED])
		conn->callbacks[FC_CHAT_KICKED](conn,conn->clientstruct,room,by,reason);
	return;
}

void firetalk_callback_chat_getmessage(client_t c, const char * const room, const char * const from, const int automessage, const char * const message) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_CHAT_GETMESSAGE])
		conn->callbacks[FC_CHAT_GETMESSAGE](conn,conn->clientstruct,room,from,automessage,message);
	return;
}

void firetalk_callback_chat_getaction(client_t c, const char * const room, const char * const from, const int automessage, const char * const message) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_CHAT_GETACTION])
		conn->callbacks[FC_CHAT_GETACTION](conn,conn->clientstruct,room,from,automessage,message);
	return;
}

void firetalk_callback_chat_invited(client_t c, const char * const room, const char * const from, const char * const message) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (conn->callbacks[FC_CHAT_INVITED])
		conn->callbacks[FC_CHAT_INVITED](conn,conn->clientstruct,room,from,message);
	return;
}

void firetalk_callback_chat_user_joined(client_t c, const char * const room, const char * const who, const int previous ) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (firetalk_chat_internal_add_member(conn,room,who) != FE_SUCCESS)
		return;
	if (conn->callbacks[FC_CHAT_USER_JOINED])
		conn->callbacks[FC_CHAT_USER_JOINED](conn,conn->clientstruct,room,who,previous);
	return;
}

void firetalk_callback_chat_user_left(client_t c, const char * const room, const char * const who, const char * const reason) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (firetalk_chat_internal_remove_member(conn,room,who) != FE_SUCCESS)
		return;
	if (conn->callbacks[FC_CHAT_USER_LEFT])
		conn->callbacks[FC_CHAT_USER_LEFT](conn,conn->clientstruct,room,who,reason);
	return;
}

void firetalk_callback_chat_user_quit(client_t c, const char * const who, const char * const reason) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *roomiter;
	struct s_firetalk_member *memberiter;
	struct s_firetalk_member *memberiter2;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	
	roomiter = conn->room_head;
	while (roomiter) {
		memberiter = roomiter->member_head;
		while (memberiter) {
			memberiter2 = memberiter->next;
			if (protocol_functions[conn->protocol].comparenicks(memberiter->nickname,who) == FE_SUCCESS)
				firetalk_callback_chat_user_left(c,roomiter->name,who,reason);
			memberiter = memberiter2;
		}
		roomiter = roomiter->next;
	}
	return;
}

void firetalk_callback_chat_gottopic(client_t c, const char * const room, const char * const topic, const char * const author) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	if (r->topic != NULL)
		free(r->topic);
	if (r->author != NULL) {
		free(r->author);
		r->author = NULL;
	}
	r->topic = safe_strdup(topic);
	if (author != NULL)
		r->author = safe_strdup(author);
	if (conn->callbacks[FC_CHAT_GOTTOPIC])
		conn->callbacks[FC_CHAT_GOTTOPIC](conn,conn->clientstruct,room,topic,author);
	return;
}

void firetalk_callback_chat_room_mode(client_t c, const char * const op, const char * const room, const int on, enum firetalk_room_mode mode, const char * const params) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	if (on) r->modes |= mode;
	else r->modes &= ~mode;
	if (conn->callbacks[FC_CHAT_ROOM_MODE])
		conn->callbacks[FC_CHAT_ROOM_MODE](conn,conn->clientstruct,room,op,on,mode,params);
}

void firetalk_callback_chat_user_opped(client_t c, const char * const room, const char * const who, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	struct s_firetalk_member *m;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	m = firetalk_find_member(conn,r,who);
	if (m == NULL)
		return;
	if (m->admin == 0) {
		m->admin = 1;
		if (conn->callbacks[FC_CHAT_USER_OPPED])
			conn->callbacks[FC_CHAT_USER_OPPED](conn,conn->clientstruct,room,who,by);
	}
	return;
}

void firetalk_callback_chat_user_deopped(client_t c, const char * const room, const char * const who, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	struct s_firetalk_member *m;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	m = firetalk_find_member(conn,r,who);
	if (m == NULL)
		return;
	if (m->admin == 1) {
		m->admin = 0;
		if (conn->callbacks[FC_CHAT_USER_DEOPPED])
			conn->callbacks[FC_CHAT_USER_DEOPPED](conn,conn->clientstruct,room,who,by);
	}
	return;
}

void firetalk_callback_chat_user_voiced(client_t c, const char * const room, const char * const who, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	struct s_firetalk_member *m;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	m = firetalk_find_member(conn,r,who);
	if (m == NULL)
		return;
	if (m->voice == 0) {
		m->voice = 1;
		if (conn->callbacks[FC_CHAT_USER_VOICED])
			conn->callbacks[FC_CHAT_USER_VOICED](conn,conn->clientstruct,room,who,by);
	}
	return;
}

void firetalk_callback_chat_user_devoiced(client_t c, const char * const room, const char * const who, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	struct s_firetalk_member *m;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	m = firetalk_find_member(conn,r,who);
	if (m == NULL)
		return;
	if (m->voice == 1) {
		m->voice = 0;
		if (conn->callbacks[FC_CHAT_USER_DEVOICED])
			conn->callbacks[FC_CHAT_USER_DEVOICED](conn,conn->clientstruct,room,who,by);
	}
	return;
}

void firetalk_callback_chat_opped(client_t c, const char * const room, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	if (r->admin == 0)
		r->admin = 1;
	else
		return;
	if (conn->callbacks[FC_CHAT_OPPED])
		conn->callbacks[FC_CHAT_OPPED](conn,conn->clientstruct,room,by);
	return;
}

void firetalk_callback_chat_deopped(client_t c, const char * const room, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	if (r->admin == 1)
		r->admin = 0;
	else
		return;
	if (conn->callbacks[FC_CHAT_DEOPPED])
		conn->callbacks[FC_CHAT_DEOPPED](conn,conn->clientstruct,room,by);
	return;
}

void firetalk_callback_chat_voiced(client_t c, const char * const room, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	if (r->voice == 0)
		r->voice = 1;
	else
		return;
	if (conn->callbacks[FC_CHAT_VOICED])
		conn->callbacks[FC_CHAT_VOICED](conn,conn->clientstruct,room,by);
	return;
}

void firetalk_callback_chat_devoiced(client_t c, const char * const room, const char * const by) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_room *r;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	r = firetalk_find_room(conn,room);
	if (r == NULL)
		return;
	if (r->voice == 1)
		r->voice = 0;
	else
		return;
	if (conn->callbacks[FC_CHAT_DEVOICED])
		conn->callbacks[FC_CHAT_DEVOICED](conn,conn->clientstruct,room,by);
	return;
}

void firetalk_callback_chat_user_kicked(client_t c, const char * const room, const char * const who, const char * const by, const char * const reason) {
	struct s_firetalk_handle *conn;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	if (firetalk_chat_internal_remove_member(conn,room,who) != FE_SUCCESS)
		return;
	if (conn->callbacks[FC_CHAT_USER_KICKED])
		conn->callbacks[FC_CHAT_USER_KICKED](conn,conn->clientstruct,room,who,by,reason);
	return;
}

void firetalk_callback_chat_user_away(client_t c, const char * const who, const char * const message) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_buddy *buddyiter;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;
	buddyiter = conn->buddy_head;
	while (buddyiter) {
		if (protocol_functions[conn->protocol].comparenicks(buddyiter->nickname,who) == FE_SUCCESS) {
			buddyiter->tempint2 = 1;
			firetalk_callback_im_buddyaway(c,who,1);
			break;
		}
		buddyiter = buddyiter->next;
	}
	if (conn->callbacks[FC_CHAT_USER_AWAY])
		conn->callbacks[FC_CHAT_USER_AWAY](conn,conn->clientstruct,who,message);
	return;
}

void firetalk_callback_subcode_request(client_t c, const char * const from, const char * const command, char *args) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_subcode_callback *iter;
	conn = firetalk_find_handle(c);

	if (conn == NULL)
		return;
	iter = conn->subcode_request_head;
	while (iter != NULL) {
		if (strcasecmp(command,iter->command) == 0) {
			iter->callback(conn,conn->clientstruct,from,command,args);
			return;
		}
		iter = iter->next;
	}

	if (strcasecmp(command,"VERSION") == 0) {
		struct utsname sysv;
		char version[512];
		uname(&sysv);
		snprintf( version, 512, "firetalk %s - %s %s - %s", LIBFIRETALK_VERSION, sysv.sysname, sysv.release, LIBFIRETALK_HOMEPAGE );
		firetalk_subcode_send_reply(conn,from,"VERSION",version);
		return;
	} else if (strcasecmp(command,"CLIENTINFO") == 0) {
		char tempbuf[512];
		safe_strncpy( tempbuf, "CLIENTINFO PING ACTION VERSION TIME DCC", 512 );
		iter = conn->subcode_request_head;
		while (iter != NULL) {
			if (!strstr(tempbuf,iter->command)) {
				safe_strncat( tempbuf, " ", 512 );
				safe_strncat( tempbuf, iter->command, 512 );
			}
			iter = iter->next;
		}
		firetalk_subcode_send_reply(conn,from,"CLIENTINFO",tempbuf);
		return;
	} else if (strcasecmp(command,"PING") == 0) {
		if (args && safe_strlen( args ) <= 16 )
			firetalk_subcode_send_reply(conn,from,"PING",args);
		return;
	} else if (strcasecmp(command,"TIME") == 0) {
		char tempbuf[48];
		time_t tmv = time( NULL );
		struct tm *tms = localtime( &tmv );
		strftime( tempbuf, 47, "%a, %d %b %Y %T %z", tms );
		firetalk_subcode_send_reply(conn,from,"TIME",tempbuf);
		return;
	} else if (strcasecmp(command,"ACTION") == 0) {
		/* we don't support chatroom subcodes, so we're just going to assume that this is a private ACTION and let the protocol code handle the other case */
		firetalk_callback_im_getaction(c,from,0,args);
		return;
	} else if ((strcasecmp(command,"DCC") == 0) && (strncasecmp(args,"SEND ",5) == 0)) {
		/* DCC send */
		struct in_addr addr;
		uint32_t ip;
		long size = -1;
		uint16_t port;
		char **myargs;
#ifdef _FC_USE_IPV6
		struct in6_addr addr6;
		struct in6_addr *sendaddr6 = NULL;
#endif
		myargs = firetalk_parse_subcode_args(&args[5]);
		if ((myargs[0] != NULL) && (myargs[1] != NULL) && (myargs[2] != NULL)) {
			/* valid dcc send */
			if (myargs[3]) {
				size = atol(myargs[3]);
#ifdef _FC_USE_IPV6
				if (myargs[4]) {
					/* ipv6-enabled dcc */
					inet_pton(AF_INET6,myargs[4],&addr6);
					sendaddr6 = &addr6;
				}
#endif
			}
			sscanf(myargs[1],"%lu",(unsigned long *) &ip);
			ip = htonl(ip);
			memcpy(&addr.s_addr,&ip,4);
			port = (uint16_t) atoi(myargs[2]);
			firetalk_callback_file_offer(c,from,myargs[0],size,inet_ntoa(addr),NULL,port,FF_TYPE_DCC,NULL);
		}
	} else if ((strcasecmp(command,"DCC") == 0) && (strncasecmp(args,"RESUME ",7) == 0)) {
		uint16_t port;
		unsigned long position;
		char dccargs[256];
		char **myargs;
		struct s_firetalk_file *fileiter;

		myargs = firetalk_parse_subcode_args(&args[7]);
		port = (uint16_t) atoi(myargs[1]);
		position = (unsigned long) atol(myargs[2]);

		fileiter = conn->file_head;
		while (fileiter) {
			if (fileiter->port == port) break;
			fileiter = fileiter->next;
		}

		if (!fileiter) return;

		if ((unsigned long) position >= (unsigned long) fileiter->size) return;

		lseek( fileiter->filefd, position, SEEK_SET );
		fileiter->bytes = position;

		safe_snprintf(dccargs,256,"ACCEPT %s %u %l",myargs[0],port,position);
		firetalk_subcode_send_request(conn,from,"DCC",dccargs);
	} else if ((strcasecmp(command,"DCC") == 0) && (strncasecmp(args,"ACCEPT ",7) == 0)) {
		uint16_t port;
		unsigned long position;
		char **myargs;
		struct s_firetalk_file *fileiter;
		struct sockaddr_in addr;

		myargs = firetalk_parse_subcode_args(&args[7]);
		port = (uint16_t) atoi(myargs[1]);
		position = (unsigned long) atol(myargs[2]);

		fileiter = conn->file_head;
		while (fileiter) {
			if (fileiter->port == port) break;
			fileiter = fileiter->next;
		}

		if (!fileiter) return;

		fileiter->filefd = open(fileiter->filename,O_WRONLY,S_IRUSR | S_IWUSR);
		if (fileiter->filefd == -1)
			return;

		lseek( fileiter->filefd, position, SEEK_SET );
		fileiter->bytes = position;

		addr.sin_family = AF_INET;
		addr.sin_port = fileiter->port;
		memcpy(&addr.sin_addr.s_addr,&fileiter->inet_ip,4);
		fileiter->sockfd = firetalk_internal_connect(&addr
#ifdef _FC_USE_IPV6
											   , NULL
#endif
											   , conn->proxy
											   );
		if (fileiter->sockfd == -1) {
			firetalk_file_cancel(conn,fileiter);
			return;
		}
		fileiter->state = FF_STATE_WAITSYNACK;
	} else if (conn->subcode_request_default != NULL)
		conn->subcode_request_default->callback(conn,conn->clientstruct,from,command,args);

	return;
}

void firetalk_callback_subcode_reply(client_t c, const char * const from, const char * const command, const char * const args) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_subcode_callback *iter;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;

	iter = conn->subcode_reply_head;
	while (iter != NULL) {
		if (strcasecmp(command,iter->command) == 0) {
			iter->callback(conn,conn->clientstruct,from,command,args);
			return;
		}
		iter = iter->next;
	}

	if (conn->subcode_reply_default != NULL)
		conn->subcode_reply_default->callback(conn,conn->clientstruct,from,command,args);

	return;
}

/* size may be -1 if unknown (0 is valid) */
void firetalk_callback_file_offer(client_t c, const char * const from, const char * const filename, const long size, const char * const ipstring, const char * const ip6string, const uint16_t port, const int type, const char *cookie) {
	struct s_firetalk_handle *conn;
	struct s_firetalk_file *iter;
	conn = firetalk_find_handle(c);
	if (conn == NULL)
		return;

	iter = conn->file_head;
	conn->file_head = safe_malloc(sizeof(struct s_firetalk_file));
	conn->file_head->who = safe_strdup(from);
	conn->file_head->filename = safe_strdup(filename);
	conn->file_head->size = size;
	conn->file_head->bytes = 0;
	conn->file_head->acked = 0;
	conn->file_head->state = FF_STATE_WAITLOCAL;
	conn->file_head->direction = FF_DIRECTION_RECEIVING;
	conn->file_head->sockfd = -1;
	conn->file_head->filefd = -1;
	conn->file_head->port = htons(port);
	conn->file_head->type = type;
	conn->file_head->next = iter;
	conn->file_head->clientfilestruct = NULL;
	conn->file_head->customdata = NULL;
	if (type == FF_TYPE_CUSTOM && cookie != NULL)
		conn->file_head->cookie = safe_strdup(cookie);
	else
		conn->file_head->cookie = NULL;
	if (inet_pton(AF_INET,ipstring,&conn->file_head->inet_ip) == 0) {
		firetalk_file_cancel(c,conn->file_head);
		return;
	}
#ifdef _FC_USE_IPV6
	conn->file_head->tryinet6 = 0;
	if (ip6string)
		if (inet_pton(AF_INET6,ip6string,&conn->file_head->inet6_ip) != 0)
			conn->file_head->tryinet6 = 1;
#endif
	if (conn->callbacks[FC_FILE_OFFER])
		conn->callbacks[FC_FILE_OFFER](conn,conn->clientstruct,(void *)conn->file_head,from,filename,size);
	return;
}

void firetalk_handle_receive(struct s_firetalk_handle * c, struct s_firetalk_file *filestruct) {
	/* we have to copy from sockfd to filefd until we run out, then send the packet */
	static char buffer[4096];
	unsigned long netbytes = 0;
	ssize_t s = 0;

	if (filestruct->type == FF_TYPE_CUSTOM) {
		int r;
		s = recv(filestruct->sockfd,&filestruct->initbuffer[filestruct->bytes],FF_INITBUFFER_MAXLEN - filestruct->bytes,0);
		if (s <= 0) {
			if (c->callbacks[FC_FILE_ERROR])
				c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
			firetalk_file_cancel(c,filestruct);
			return;
		}
		filestruct->bytes += s;
		r = protocol_functions[c->protocol].file_handle_custom(c->handle,filestruct->sockfd,filestruct->initbuffer,&filestruct->bytes,filestruct->cookie);
		if (r == FE_SUCCESS) {
			filestruct->type = FF_TYPE_CUSTOM_RAW;
			if (write(filestruct->filefd,filestruct->initbuffer,filestruct->bytes) != filestruct->bytes) {
				if (c->callbacks[FC_FILE_ERROR])
					c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
				firetalk_file_cancel(c,filestruct);
				return;
			}
		} else if (r != FE_NOTDONE) {
			if (c->callbacks[FC_FILE_ERROR])
				c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
			firetalk_file_cancel(c,filestruct);
			return;
		}
		return;
	}

	signal (SIGPIPE, SIG_IGN);
	while ((s = recv(filestruct->sockfd,buffer,4096,0)) == 4096) {
		if (write(filestruct->filefd,buffer,4096) != 4096) {
			if (c->callbacks[FC_FILE_ERROR])
				c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
			firetalk_file_cancel(c,filestruct);
			return;
		}
		filestruct->bytes += 4096;
	}
	if (s > 0) {
		if (write(filestruct->filefd,buffer,(size_t) s) != s) {
			if (c->callbacks[FC_FILE_ERROR])
				c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
			firetalk_file_cancel(c,filestruct);
			return;
		}
		filestruct->bytes += s;
	} else if (s == 0 && errno != EAGAIN) {
		if (c->callbacks[FC_FILE_ERROR])
			c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
		firetalk_file_cancel(c,filestruct);
		return;
	}
	if (filestruct->type == FF_TYPE_DCC) {
		netbytes = htonl((uint32_t) filestruct->bytes);
		if (write(filestruct->sockfd,&netbytes,4) != 4) {
			if (c->callbacks[FC_FILE_ERROR])
				c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
			firetalk_file_cancel(c,filestruct);
			return;
		}
	}
	signal (SIGPIPE, SIG_DFL);

	if (c->callbacks[FC_FILE_PROGRESS])
		c->callbacks[FC_FILE_PROGRESS](c,c->clientstruct,filestruct,filestruct->clientfilestruct,filestruct->bytes,filestruct->size);
	if (filestruct->bytes == filestruct->size) {
		if (filestruct->type == FF_TYPE_CUSTOM_RAW)
			protocol_functions[c->protocol].file_complete_custom(c->handle,filestruct->sockfd,filestruct->customdata);
		if (c->callbacks[FC_FILE_FINISH])
			c->callbacks[FC_FILE_FINISH](c,c->clientstruct,filestruct,filestruct->clientfilestruct,filestruct->size);
		firetalk_file_cancel(c,filestruct);
	}
}

void firetalk_handle_send(struct s_firetalk_handle * c, struct s_firetalk_file *filestruct) {
	/* we have to copy from filefd to sockfd until we run out or sockfd refuses the data */
	static char buffer[4096];
	uint32_t acked = 0;
	ssize_t s = 0;

	signal (SIGPIPE, SIG_IGN);
	while ((s = read(filestruct->filefd,buffer,4096)) == 4096) {
		if ((s = send(filestruct->sockfd,buffer,4096,0)) != 4096) {
			lseek(filestruct->filefd,-(4096 - (s > 0 ? s : 0)),SEEK_CUR);
			filestruct->bytes += (s > 0 ? s : 0);
			if (c->callbacks[FC_FILE_PROGRESS])
				c->callbacks[FC_FILE_PROGRESS](c,c->clientstruct,filestruct,filestruct->clientfilestruct,filestruct->bytes,filestruct->size);
			return;
		}
		filestruct->bytes += s;
		if (c->callbacks[FC_FILE_PROGRESS])
			c->callbacks[FC_FILE_PROGRESS](c,c->clientstruct,filestruct,filestruct->clientfilestruct,filestruct->bytes,filestruct->size);
		if (filestruct->type == FF_TYPE_DCC) {
			while (recv(filestruct->sockfd,&acked,4,0) == 4)
				filestruct->acked = ntohl(acked);
		}
	}
	if (send(filestruct->sockfd,buffer,s,0) != s) {
		if (c->callbacks[FC_FILE_ERROR])
			c->callbacks[FC_FILE_ERROR](c,c->clientstruct,filestruct,filestruct->clientfilestruct,FE_IOERROR);
		firetalk_file_cancel(c,filestruct);
		return;
	}
	filestruct->bytes += s;
	if (filestruct->type == FF_TYPE_DCC) {
		while (filestruct->acked < (uint32_t) filestruct->bytes) {
			if (recv(filestruct->sockfd,&acked,4,0) == 4)
				filestruct->acked = ntohl(acked);
		}
	}
	signal (SIGPIPE, SIG_DFL);

	if (c->callbacks[FC_FILE_PROGRESS])
		c->callbacks[FC_FILE_PROGRESS](c,c->clientstruct,filestruct,filestruct->clientfilestruct,filestruct->bytes,filestruct->size);
	if (c->callbacks[FC_FILE_FINISH])
		c->callbacks[FC_FILE_FINISH](c,c->clientstruct,filestruct,filestruct->clientfilestruct,filestruct->bytes);
	firetalk_file_cancel(c,filestruct);
}

void firetalk_ratelimit(double *lastsend, double *delay, double basedelay, double backoff, double ceiling) {
	struct timeval tv;
	double now;
	double temp;

	gettimeofday(&tv, NULL);
	now = tv.tv_usec/1000000. + ((double)tv.tv_sec);

	if (*lastsend + *delay > now) {
		fd_set b;
		temp = (*lastsend + *delay) - now;
		tv.tv_usec = (temp - (double)((int) temp)) * 1000000;
		tv.tv_sec = floor(temp);
		FD_ZERO(&b);
		*delay *= backoff;
		if (*delay > ceiling)
			*delay = ceiling;
		select(0,&b,&b,&b,&tv);
	} else {
		double i;
		temp = now - (*lastsend + *delay);
		for (i = 0; i < temp; i += basedelay) {
			*delay /= backoff;
			if (*delay < basedelay) {
				*delay = basedelay;
				break;
			}
		}
	}

	gettimeofday(&tv,NULL);
	*lastsend = tv.tv_usec/1000000. + ((double)tv.tv_sec);
}

/* External function definitions */

const char *firetalk_strprotocol(const enum firetalk_protocol p) {
	switch (p) {
#ifndef DISABLE_TOC_PROTOCOL
		case FP_AIMTOC:
			return "AIM/TOC";
#endif
#ifndef DISABLE_IRC_PROTOCOL
		case FP_IRC:
			return "IRC";
#endif
		default:
			return "Invalid Protocol";
	}
}

const char *firetalk_strerror(const enum firetalk_error e) {
	switch (e) {
		case FE_SUCCESS:
			return "Success";
		case FE_CONNECT:
			return "Connection failed";
		case FE_NOMATCH:
			return "Usernames do not match";
		case FE_PACKET:
			return "Packet transfer error";
		case FE_BADUSERPASS:
			return "Invalid username or password";
		case FE_SEQUENCE:
			return "Invalid sequence number from server";
		case FE_FRAMETYPE:
			return "Invalid frame type from server";
		case FE_PACKETSIZE:
			return "Packet too long";
		case FE_SERVER:
			return "Server problem; try again later";
		case FE_UNKNOWN:
			return "Unknown error";
		case FE_BLOCKED:
			return "You are blocked";
		case FE_WIERDPACKET:
			return "Unknown packet received from server";
		case FE_CALLBACKNUM:
			return "Invalid callback number";
		case FE_BADUSER:
			return "Invalid username";
		case FE_NOTFOUND:
			return "Username not found in list";
		case FE_DISCONNECT:
			return "Server disconnected";
		case FE_SOCKET:
			return "Unable to create socket";
		case FE_RESOLV:
			return "Unable to resolve hostname";
		case FE_VERSION:
			return "Wrong server version";
		case FE_USERUNAVAILABLE:
			return "User is currently unavailable";
		case FE_USERINFOUNAVAILABLE:
			return "User information is currently unavilable";
		case FE_TOOFAST:
			return "You are sending messages too fast; last message was dropped";
		case FE_ROOMUNAVAILABLE:
			return "Chat room is currently unavailable";
		case FE_INCOMINGERROR:
			return "Incoming message delivery failure";
		case FE_USERDISCONNECT:
			return "User disconnected";
		case FE_INVALIDFORMAT:
			return "Server response was formatted incorrectly";
		case FE_IDLEFAST:
			return "You have requested idle to be reset too fast";
		case FE_BADROOM:
			return "Invalid room name";
		case FE_BADMESSAGE:
			return "Invalid message (too long?)";
		case FE_BADPROTO:
			return "Invalid protocol";
		case FE_NOTCONNECTED:
			return "Not connected";
		case FE_BADCONNECTION:
			return "Invalid connection number";
		case FE_NOPERMS:
			return "No permission to perform operation";
		case FE_NOCHANGEPASS:
			return "Unable to change password";
		case FE_DUPEUSER:
			return "User already in list";
		case FE_DUPEROOM:
			return "Room already in list";
		case FE_IOERROR:
        		return "Input/output error";
		case FE_BADHANDLE:
        		return "Invalid handle";
		case FE_TIMEOUT:
			return "Operation timed out";
		case FE_NOTDONE:
			return "Operation incomplete";
		default:
			return "Invalid error number";
	}
}

firetalk_t firetalk_create_handle(const int protocol, void *clientstruct) {
	struct s_firetalk_handle *c;
	int i;
	if (protocol < 0 || protocol >= FP_MAX) {
		firetalkerror = FE_BADPROTO;
		return NULL;
	}
	c = handle_head;
	handle_head = safe_malloc(sizeof(struct s_firetalk_handle));
	for (i = 0; i < FC_MAX; i++)
		handle_head->callbacks[i] = NULL;
	handle_head->buffer = safe_malloc(buffersize[protocol]);
	handle_head->bufferpos = 0;
	handle_head->clientstruct = clientstruct;
	handle_head->prev = NULL;
	handle_head->next = c;
	handle_head->handle = NULL;
	handle_head->username = NULL;
	handle_head->buddy_head = NULL;
	handle_head->deny_head = NULL;
	handle_head->room_head = NULL;
	handle_head->file_head = NULL;
	handle_head->subcode_request_head = NULL;
	handle_head->subcode_reply_head = NULL;
	handle_head->subcode_request_default = NULL;
	handle_head->subcode_reply_default = NULL;
	handle_head->lastsend = 0;
	handle_head->lasttransmit = firetalk_gettime();
	handle_head->flood = 0;
	handle_head->datahead = NULL;
	handle_head->datatail = NULL;
	handle_head->connected = FCS_NOTCONNECTED;
	handle_head->protocol = protocol;
	handle_head->handle = protocol_functions[protocol].create_handle();
	handle_head->flood_intervals[0] = firetalkrates[protocol][0];
	handle_head->flood_intervals[1] = firetalkrates[protocol][1];
	handle_head->flood_intervals[2] = firetalkrates[protocol][2];
	handle_head->flood_intervals[3] = firetalkrates[protocol][3];
	handle_head->proxy = FX_NONE;
	return handle_head;
}

void firetalk_destroy_handle(firetalk_t conn) {
	struct s_firetalk_buddy *buddyiter, *buddyiter2;
	struct s_firetalk_deny *denyiter, *denyiter2;
	struct s_firetalk_room *roomiter, *roomiter2;
	struct s_firetalk_member *memberiter, *memberiter2;
	struct s_firetalk_file *fileiter, *fileiter2;
	struct s_firetalk_subcode_callback *subcodeiter, *subcodeiter2;
	struct s_firetalk_queued_data *dataiter, *dataiter2;
	struct s_firetalk_handle *handleiter, *handleiter2;
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return;
#endif
	free(conn->buffer);
	if (conn->username)
		free(conn->username);
	handleiter = handle_head;
	handleiter2 = NULL;
	while (handleiter != NULL) {
		if (handleiter == conn) {
			if (handleiter2 == NULL)
				handle_head = conn->next;
			else
				handleiter2->next = conn->next;
		}
		handleiter2 = handleiter;
		handleiter = handleiter->next;
	}
	if (conn->handle)
		protocol_functions[conn->protocol].destroy_handle(conn->handle);

//Added
	buddyiter = conn->buddy_head;
	while (buddyiter != NULL) {
		buddyiter2 = buddyiter->next;
		if (buddyiter->nickname != NULL)
			free(buddyiter->nickname);
		free(buddyiter);
		buddyiter = buddyiter2;
	}

	denyiter = conn->deny_head;
	while (denyiter != NULL) {
		denyiter2 = denyiter->next;
		if (denyiter->nickname != NULL)
			free(denyiter->nickname);
		free(denyiter);
		denyiter = denyiter2;
	}

	roomiter = conn->room_head;
	while (roomiter != NULL) {
		roomiter2 = roomiter->next;
		if (roomiter->name != NULL)
			free(roomiter->name);
		if (roomiter->topic != NULL)
			free(roomiter->topic);
		if (roomiter->author != NULL)
			free(roomiter->author);
		memberiter = roomiter->member_head;
		while (memberiter != NULL) {
			memberiter2 = memberiter;
			if (memberiter->nickname != NULL)
				free(memberiter->nickname);
			free(memberiter);
			memberiter = memberiter2;
		}
		free(roomiter);
		roomiter = roomiter2;
	}

	fileiter = conn->file_head;
	while (fileiter != NULL) {
		fileiter2 = fileiter->next;
		if (fileiter->who != NULL)
			free(fileiter->who);
		if (fileiter->filename != NULL)
			free(fileiter->filename);
		if (fileiter->sockfd != -1)
			close(fileiter->sockfd);
		if (fileiter->filefd != -1)
			close(fileiter->filefd);
		if (fileiter->cookie != NULL)
			free(fileiter->cookie);
		if (fileiter->customdata != NULL)
			free(fileiter->customdata);
		free(fileiter);
		fileiter = fileiter2;
	}

	subcodeiter = conn->subcode_request_head;
	while (subcodeiter != NULL) {
		subcodeiter2 = subcodeiter->next;
		if (subcodeiter->command != NULL)
			free(subcodeiter->command);
		free(subcodeiter);
		subcodeiter = subcodeiter2;
	}

	subcodeiter = conn->subcode_reply_head;
	while (subcodeiter != NULL) {
		subcodeiter2 = subcodeiter->next;
		if (subcodeiter->command != NULL)
			free(subcodeiter->command);
		free(subcodeiter);
		subcodeiter = subcodeiter2;
	}

	subcodeiter = conn->subcode_request_default;
	while (subcodeiter != NULL) {
		subcodeiter2 = subcodeiter->next;
		if (subcodeiter->command != NULL)
			free(subcodeiter->command);
		free(subcodeiter);
		subcodeiter = subcodeiter2;
	}

	subcodeiter = conn->subcode_reply_default;
	while (subcodeiter != NULL) {
		subcodeiter2 = subcodeiter->next;
		if (subcodeiter->command != NULL)
			free(subcodeiter->command);
		free(subcodeiter);
		subcodeiter = subcodeiter2;
	}

	dataiter = conn->datahead;
	while (dataiter != NULL) {
		dataiter2 = dataiter->next;
		if (dataiter->data != NULL)
			free(dataiter->data);
		free(dataiter);
		dataiter = dataiter2;
	}
//end add
	free(conn);
	return;
}

void firetalk_set_flood_intervals(firetalk_t conn, const double flood, const double delay, const double backoff, const double ceiling ) {
	conn->flood_intervals[0] = flood;
	conn->flood_intervals[1] = delay;
	conn->flood_intervals[2] = backoff;
	conn->flood_intervals[3] = ceiling;
}

void firetalk_set_proxy_type(firetalk_t conn, enum firetalk_proxy type ) {
	if( type == FX_SOCKS ) conn->proxy = FX_SOCKS;
	else if( type == FX_HTTPS ) conn->proxy = FX_HTTPS;
	else conn->proxy = FX_NONE;
}

enum firetalk_error firetalk_disconnect(firetalk_t conn) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected == FCS_NOTCONNECTED)
		return FE_NOTCONNECTED;

	return protocol_functions[conn->protocol].disconnect(conn->handle);
}

enum firetalk_error firetalk_signon(firetalk_t conn, const char * const server, const short port, const char * const username) {
	short realport;
	const char * realserver;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_NOTCONNECTED)
		return FE_CONNECT;

	if (conn->username)
		free(conn->username);

	conn->username = safe_strdup(username);

	if (server == NULL)
		realserver = defaultserver[conn->protocol];
	else
		realserver = server;

	if (port == 0)
		realport = defaultport[conn->protocol];
	else
		realport = port;
	
	conn->fd = firetalk_internal_connect_host(realserver,realport,conn->proxy);

	if (conn->fd != -1) {
		conn->connected = FCS_WAITING_SYNACK;
		return FE_SUCCESS;
	} else
		return firetalkerror;
}

enum firetalk_error firetalk_send_raw(firetalk_t conn, const char * const message) {
	
#ifdef DEBUG
    if (firetalk_check_handle(conn) != FE_SUCCESS)
        return FE_BADHANDLE;
#endif
    
    return protocol_functions[conn->protocol].send_raw(conn->handle,message);
}

enum firetalk_error firetalk_handle_synack(firetalk_t conn) {
	int i;
	unsigned int o = sizeof(int);

	if (getsockopt(conn->fd,SOL_SOCKET,SO_ERROR,&i,&o)) {
		close(conn->fd);
		conn->connected = FCS_NOTCONNECTED;
		if (conn->callbacks[FC_CONNECTFAILED])
			conn->callbacks[FC_CONNECTFAILED](conn,conn->clientstruct,FE_SOCKET,strerror(errno));
		return FE_SOCKET;
	}

	if (i != 0) {
		close(conn->fd);
		conn->connected = FCS_NOTCONNECTED;
		if (conn->callbacks[FC_CONNECTFAILED])
			conn->callbacks[FC_CONNECTFAILED](conn,conn->clientstruct,FE_CONNECT,strerror(i));
		return FE_CONNECT;
	}

	conn->connected = FCS_WAITING_SIGNON;
	i = protocol_functions[conn->protocol].signon(conn->handle,conn->username);
	if (i != FE_SUCCESS)
		return i;

	return FE_SUCCESS;
}

void firetalk_callback_connected(client_t c) {
	unsigned int l;
	struct sockaddr_in addr;
	firetalk_t conn;

	conn = firetalk_find_handle(c);

	conn->connected = FCS_ACTIVE;
	l = (unsigned int) sizeof(struct sockaddr_in);
	getsockname(conn->fd,(struct sockaddr *) &addr,&l);
	memcpy(&conn->localip,&addr.sin_addr.s_addr,4);
	conn->localip = htonl((uint32_t) conn->localip);

	if (conn->callbacks[FC_CONNECTED])
		conn->callbacks[FC_CONNECTED](conn,conn->clientstruct);
}

enum firetalk_error firetalk_handle_file_synack(firetalk_t conn, struct s_firetalk_file *file) {
	int i;
	unsigned int o = sizeof(int);

	if (getsockopt(file->sockfd,SOL_SOCKET,SO_ERROR,&i,&o)) {
		firetalk_file_cancel(conn,file);
		return FE_SOCKET;
	}

	if (i != 0) {
		if (conn->callbacks[FC_FILE_ERROR])
			conn->callbacks[FC_FILE_ERROR](conn,conn->clientstruct,file,file->clientfilestruct,FE_CONNECT);
		firetalk_file_cancel(conn,file);
		return FE_CONNECT;
	}

	file->state = FF_STATE_TRANSFERRING;

	if (conn->callbacks[FC_FILE_START])
		conn->callbacks[FC_FILE_START](conn,conn->clientstruct,file,file->clientfilestruct);
	return FE_SUCCESS;
}

enum firetalk_protocol firetalk_get_protocol(firetalk_t conn) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif
	return conn->protocol;
}

enum firetalk_error firetalk_register_callback(firetalk_t conn, const int type, void (*function)(firetalk_t, void *, ...)) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
	if (type < 0 || type >= FC_MAX)
		return FE_CALLBACKNUM;
#endif
	conn->callbacks[type] = function;
	return FE_SUCCESS;
}

enum firetalk_error firetalk_im_add_buddy(firetalk_t conn, const char * const nickname) {
	int ret;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	ret = firetalk_im_internal_add_buddy(conn,nickname);
	if (ret != FE_SUCCESS)
		return ret;

	return protocol_functions[conn->protocol].im_add_buddy(conn->handle,nickname);
}

enum firetalk_error firetalk_im_remove_buddy(firetalk_t conn, const char * const nickname) {
	int ret;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	ret = firetalk_im_internal_remove_buddy(conn,nickname);
	if (ret != FE_SUCCESS)
		return ret;

	return protocol_functions[conn->protocol].im_remove_buddy(conn->handle,nickname);
}

enum firetalk_error firetalk_im_add_deny(firetalk_t conn, const char * const nickname) {
	int ret;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	ret = firetalk_im_internal_add_deny(conn,nickname);
	if (ret != FE_SUCCESS)
		return ret;

	return protocol_functions[conn->protocol].im_add_deny(conn->handle,nickname);
}

enum firetalk_error firetalk_im_remove_deny(firetalk_t conn, const char * const nickname) {
	int ret;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	ret = firetalk_im_internal_remove_deny(conn,nickname);
	if (ret != FE_SUCCESS)
		return ret;

	return protocol_functions[conn->protocol].im_remove_deny(conn->handle,nickname);
}

enum firetalk_error firetalk_save_config(firetalk_t conn) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].save_config(conn->handle);
}

enum firetalk_error firetalk_im_upload_buddies(firetalk_t conn) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	return protocol_functions[conn->protocol].im_upload_buddies(conn->handle);
}

enum firetalk_error firetalk_im_upload_denies(firetalk_t conn) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	return protocol_functions[conn->protocol].im_upload_denies(conn->handle);
}

enum firetalk_error firetalk_im_send_message(firetalk_t conn, const char * const dest, const char * const message, const int auto_flag) {
	enum firetalk_error e;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	e = protocol_functions[conn->protocol].im_send_message(conn->handle,dest,message,auto_flag);
	if (e != FE_SUCCESS)
		return e;

	e = protocol_functions[conn->protocol].periodic(conn);
	if (e != FE_SUCCESS && e != FE_IDLEFAST)
		return e;

	return FE_SUCCESS;
}

enum firetalk_error firetalk_im_send_action(firetalk_t conn, const char * const dest, const char * const message, const int auto_flag) {
	enum firetalk_error e;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	e = protocol_functions[conn->protocol].im_send_action(conn->handle,dest,message,auto_flag);
	if (e != FE_SUCCESS)
		return e;

	e = protocol_functions[conn->protocol].periodic(conn);
	if (e != FE_SUCCESS && e != FE_IDLEFAST)
		return e;

	return FE_SUCCESS;
}

enum firetalk_error firetalk_im_get_info(firetalk_t conn, const char * const nickname, const int priority) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].get_info(conn->handle,nickname,priority);
}

enum firetalk_error firetalk_im_get_roomlist(firetalk_t conn, const char * const search) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].get_roomlist(conn->handle,search);
}

enum firetalk_error firetalk_im_stop_roomlist(firetalk_t conn) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].stop_roomlist(conn->handle);
}

enum firetalk_error firetalk_set_info(firetalk_t conn, const char * const info) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].set_info(conn->handle,info);
}

enum firetalk_error firetalk_im_list_buddies(firetalk_t conn) {
	struct s_firetalk_buddy *buddyiter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	if (!conn->callbacks[FC_IM_LISTBUDDY])
		return FE_SUCCESS;

	buddyiter = conn->buddy_head;
	while (buddyiter) {
		conn->callbacks[FC_IM_LISTBUDDY](conn,conn->clientstruct,buddyiter->nickname,buddyiter->online,buddyiter->away,buddyiter->idletime);
		buddyiter = buddyiter->next;
	}

	return FE_SUCCESS;
}

enum firetalk_error firetalk_chat_listmembers(firetalk_t conn, const char * const roomname) {
	struct s_firetalk_room *room;
	struct s_firetalk_member *memberiter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (conn->connected != FCS_ACTIVE)
		return FE_NOTCONNECTED;

	if (!conn->callbacks[FC_CHAT_LISTMEMBER])
		return FE_SUCCESS;

	room = firetalk_find_room(conn,roomname);
	if (room == NULL)
		return firetalkerror;

	memberiter = room->member_head;
	while (memberiter) {
		conn->callbacks[FC_CHAT_LISTMEMBER](conn,conn->clientstruct,room->name,memberiter->nickname,memberiter->admin);
		memberiter = memberiter->next;
	}

	return FE_SUCCESS;
}

const char *firetalk_chat_get_topic(firetalk_t conn, const char * const room) {
	struct s_firetalk_room *r;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS) {
		firetalkerror = FE_BADHANDLE;
		return NULL;
	}
#endif
	
	r = firetalk_find_room(conn,room);
	if (r == NULL) {
		firetalkerror = FE_NOTFOUND;
		return NULL;
	}
	return r->topic;
}

const char * firetalk_chat_normalize(firetalk_t conn, const char * const room) {
	return protocol_functions[conn->protocol].room_normalize(room);
}

enum firetalk_error firetalk_set_away(firetalk_t conn, const char * const message) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].set_away(conn->handle,message);
}

enum firetalk_error firetalk_set_nickname(firetalk_t conn, const char * const nickname) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].set_nickname(conn->handle,nickname);
}

enum firetalk_error firetalk_set_password(firetalk_t conn, const char * const oldpass, const char * const newpass) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].set_password(conn->handle,oldpass,newpass);
}

enum firetalk_error firetalk_im_evil(firetalk_t conn, const char * const who) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].im_evil(conn->handle,who);
}

enum firetalk_error firetalk_chat_join(firetalk_t conn, const char * const room) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_join(conn->handle,normalroom);
}

enum firetalk_error firetalk_chat_part(firetalk_t conn, const char * const room) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_part(conn->handle,normalroom);
}

enum firetalk_error firetalk_chat_send_message(firetalk_t conn, const char * const room, const char * const message, const int auto_flag) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_send_message(conn->handle,normalroom,message,auto_flag);
}

enum firetalk_error firetalk_chat_send_action(firetalk_t conn, const char * const room, const char * const message, const int auto_flag) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_send_action(conn->handle,normalroom,message,auto_flag);
}

enum firetalk_error firetalk_chat_invite(firetalk_t conn, const char * const room, const char * const who, const char * const message) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_invite(conn->handle,normalroom,who,message);
}

enum firetalk_error firetalk_chat_set_topic(firetalk_t conn, const char * const room, const char * const topic) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_set_topic(conn->handle,normalroom,topic);
}

enum firetalk_error firetalk_chat_op(firetalk_t conn, const char * const room, const char * const who) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_op(conn->handle,normalroom,who);
}

enum firetalk_error firetalk_chat_deop(firetalk_t conn, const char * const room, const char * const who) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_deop(conn->handle,normalroom,who);
}

enum firetalk_error firetalk_chat_voice(firetalk_t conn, const char * const room, const char * const who) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_voice(conn->handle,normalroom,who);
}

enum firetalk_error firetalk_chat_devoice(firetalk_t conn, const char * const room, const char * const who) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_devoice(conn->handle,normalroom,who);
}

enum firetalk_error firetalk_chat_kick(firetalk_t conn, const char * const room, const char * const who, const char * const reason) {
	const char *normalroom;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	normalroom = protocol_functions[conn->protocol].room_normalize(room);
	if (!normalroom)
		return FE_ROOMUNAVAILABLE;

	return protocol_functions[conn->protocol].chat_kick(conn->handle,normalroom,who,reason);
}

enum firetalk_error firetalk_subcode_send_request(firetalk_t conn, const char * const to, const char * const command, const char * const args) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].subcode_send_request(conn->handle,to,command,args);
}

enum firetalk_error firetalk_subcode_send_reply(firetalk_t conn, const char * const to, const char * const command, const char * const args) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].subcode_send_reply(conn->handle,to,command,args);
}

enum firetalk_error firetalk_subcode_register_request_callback(firetalk_t conn, const char * const command, void (*callback)(firetalk_t, void *, const char * const, const char * const, const char * const)) {
	struct s_firetalk_subcode_callback *iter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (command == NULL) {
		if (conn->subcode_request_default)
			free(conn->subcode_request_default);
		conn->subcode_request_default = safe_malloc(sizeof(struct s_firetalk_subcode_callback));
		conn->subcode_request_default->next = NULL;
		conn->subcode_request_default->command = NULL;
		conn->subcode_request_default->callback = (ptrtofnct) callback;
	} else {
		iter = conn->subcode_request_head;
		conn->subcode_request_head = safe_malloc(sizeof(struct s_firetalk_subcode_callback));
		conn->subcode_request_head->next = iter;
		conn->subcode_request_head->command = safe_strdup(command);
		conn->subcode_request_head->callback = (ptrtofnct) callback;
	}
	return FE_SUCCESS;
}

enum firetalk_error firetalk_subcode_register_reply_callback(firetalk_t conn, const char * const command, void (*callback)(firetalk_t, void *, const char * const, const char * const, const char * const)) {
	struct s_firetalk_subcode_callback *iter;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	if (command == NULL) {
		if (conn->subcode_reply_default)
			free(conn->subcode_reply_default);
		conn->subcode_reply_default = safe_malloc(sizeof(struct s_firetalk_subcode_callback));
		conn->subcode_reply_default->next = NULL;
		conn->subcode_reply_default->command = NULL;
		conn->subcode_reply_default->callback = (ptrtofnct) callback;
	} else {
		iter = conn->subcode_reply_head;
		conn->subcode_reply_head = safe_malloc(sizeof(struct s_firetalk_subcode_callback));
		conn->subcode_reply_head->next = iter;
		conn->subcode_reply_head->command = safe_strdup(command);
		conn->subcode_reply_head->callback = (ptrtofnct) callback;
	}
	return FE_SUCCESS;
}

char *firetalk_file_name( const char *name ) {
	const char *base = name;
	while( *name ) if( *name++ == '/' ) base = name;
	return (char *) base;
}

enum firetalk_error firetalk_file_offer(firetalk_t conn, void **filehandle, const char * const nickname, const char * const filename) {
	struct s_firetalk_file *iter;
	struct stat s;
	struct sockaddr_in addr;
	char args[256];
	char *encoded_filename;
	unsigned int l;

	if (filehandle) *filehandle = NULL;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	iter = conn->file_head;
	conn->file_head = safe_malloc(sizeof(struct s_firetalk_file));
	conn->file_head->who = safe_strdup(nickname);
	conn->file_head->filename = safe_strdup(filename);
	conn->file_head->sockfd = -1;
	conn->file_head->customdata = NULL;

	conn->file_head->filefd = open(filename,O_RDONLY);
	if (conn->file_head->filefd == -1) {
		firetalk_file_cancel(conn,conn->file_head);
		return FE_IOERROR;
	}

	if (fstat(conn->file_head->filefd,&s) != 0) {
		firetalk_file_cancel(conn,conn->file_head);
		return FE_IOERROR;
	}

	conn->file_head->size = (long) s.st_size;

	conn->file_head->sockfd = socket(PF_INET, SOCK_STREAM, 0);
	if (conn->file_head->sockfd == -1) {
		firetalk_file_cancel(conn,conn->file_head);
		return FE_SOCKET;
	}

	addr.sin_family = AF_INET;
	addr.sin_port = 0;
	addr.sin_addr.s_addr = INADDR_ANY;
	if (bind(conn->file_head->sockfd,(struct sockaddr *) &addr,sizeof(struct sockaddr_in)) != 0) {
		firetalk_file_cancel(conn,conn->file_head);
		return FE_SOCKET;
	}

	if (listen(conn->file_head->sockfd,1) != 0) {
		firetalk_file_cancel(conn,conn->file_head);
		return FE_SOCKET;
	}

	l = (unsigned int) sizeof(struct sockaddr_in);
	if (getsockname(conn->file_head->sockfd,(struct sockaddr *) &addr,&l) != 0) {
		firetalk_file_cancel(conn,conn->file_head);
		return FE_SOCKET;
	}

	conn->file_head->bytes = 0;
	conn->file_head->state = FF_STATE_WAITREMOTE;
	conn->file_head->direction = FF_DIRECTION_SENDING;
	conn->file_head->port = ntohs(addr.sin_port);
	conn->file_head->next = iter;
	conn->file_head->type = FF_TYPE_DCC;

	encoded_filename = safe_strdup(firetalk_file_name(conn->file_head->filename));
	for( l = 0; encoded_filename[l]; l++ ) if( encoded_filename[l] == ' ' ) encoded_filename[l] = '_';

	safe_snprintf(args,256,"SEND %s %y %u %l",encoded_filename,conn->localip,conn->file_head->port,conn->file_head->size);

	free(encoded_filename);
	
	if (filehandle) *filehandle = conn->file_head;

	return firetalk_subcode_send_request(conn,nickname,"DCC",args);
}

enum firetalk_error firetalk_file_accept(firetalk_t conn, void *filehandle, void *clientfilestruct, const char * const localfile) {
	struct s_firetalk_file *fileiter;
	struct sockaddr_in addr;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	fileiter = filehandle;
	fileiter->clientfilestruct = clientfilestruct;
	if (fileiter->filename) free(fileiter->filename);
	fileiter->filename = safe_strdup(localfile);

	fileiter->filefd = open(localfile,O_WRONLY | O_CREAT | O_TRUNC,S_IRUSR | S_IWUSR);
	if (fileiter->filefd == -1)
		return FE_NOPERMS;

	addr.sin_family = AF_INET;
	addr.sin_port = fileiter->port;
	memcpy(&addr.sin_addr.s_addr,&fileiter->inet_ip,4);
	fileiter->sockfd = firetalk_internal_connect(&addr
#ifdef _FC_USE_IPV6
	, NULL
#endif
	,conn->proxy
	);
	if (fileiter->sockfd == -1) {
		firetalk_file_cancel(conn,filehandle);
		return FE_SOCKET;
	}
	fileiter->state = FF_STATE_WAITSYNACK;
	return FE_SUCCESS;
}

enum firetalk_error firetalk_file_resume(firetalk_t conn, void *filehandle, void *clientfilestruct, const char * const localfile) {
	struct s_firetalk_file *fileiter;
	char dccargs[256];
	struct stat statbuf;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	fileiter = filehandle;
	fileiter->clientfilestruct = clientfilestruct;

	if( stat( localfile, &statbuf ) )
		return FE_NOPERMS;

	safe_snprintf(dccargs,256,"RESUME %s %u %l",fileiter->filename,fileiter->port,(unsigned long) statbuf.st_size);
	firetalk_subcode_send_request(conn,fileiter->who,"DCC",dccargs);

	if (fileiter->filename) free(fileiter->filename);
	fileiter->filename = safe_strdup(localfile);

	return FE_SUCCESS;
}

enum firetalk_error firetalk_file_cancel(firetalk_t conn, void *filehandle) {
	struct s_firetalk_file *fileiter,*fileiter2;

#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	fileiter2 = NULL;
	fileiter = conn->file_head;
	while (fileiter) {
		if (fileiter == filehandle) {
			if (fileiter2)
				fileiter2->next = fileiter->next;
			else
				conn->file_head = fileiter->next;
			if (fileiter->who)
				free(fileiter->who);
			if (fileiter->filename)
				free(fileiter->filename);
			if (fileiter->sockfd >= 0)
				close(fileiter->sockfd);
			if (fileiter->filefd >= 0)
				close(fileiter->filefd);
			if (fileiter->cookie)
				free(fileiter->cookie);
			if (fileiter->customdata != NULL)
				free(fileiter->customdata);
			return FE_SUCCESS;
		}
		fileiter2 = fileiter;
		fileiter = fileiter->next;
	}
	return FE_NOTFOUND;
}

enum firetalk_error firetalk_file_refuse(firetalk_t conn, void *filehandle) {
	return firetalk_file_cancel(conn,filehandle);
}

enum firetalk_error firetalk_compare_nicks(firetalk_t conn, const char * const nick1, const char * const nick2) {
#ifdef DEBUG
	if (firetalk_check_handle(conn) != FE_SUCCESS)
		return FE_BADHANDLE;
#endif

	return protocol_functions[conn->protocol].comparenicks(nick1,nick2);
}

enum firetalk_error firetalk_select() {
	return firetalk_select_custom(0,NULL,NULL,NULL,NULL);
}

enum firetalk_error firetalk_select_custom(int n, fd_set *fd_read, fd_set *fd_write, fd_set *fd_except, struct timeval *timeout) {
	int ret;
	fd_set *my_read;
	fd_set *my_write;
	fd_set *my_except;
	fd_set internal_read;
	fd_set internal_write;
	fd_set internal_except;
	struct timeval internal_timeout;
	struct timeval *my_timeout;
	struct s_firetalk_handle *fchandle;
	struct s_firetalk_file *fileiter,*fileiter2;
	double waittime = 15.0;
	double connwait;
	double curtime;
	long s,us;

	my_read = fd_read;
	my_write = fd_write;
	my_except = fd_except;
	my_timeout = timeout;

	if (!my_read) {
		my_read = &internal_read;
		FD_ZERO(my_read);
	}

	if (!my_write) {
		my_write = &internal_write;
		FD_ZERO(my_write);
	}

	if (!my_except) {
		my_except = &internal_except;
		FD_ZERO(my_except);
	}

	curtime = firetalk_gettime();

	fchandle = handle_head;
	while (fchandle) {
		if (fchandle->connected == FCS_NOTCONNECTED) {
			fchandle = fchandle->next;
			continue;
		}
		protocol_functions[fchandle->protocol].periodic(fchandle);
		if (fchandle->connected == FCS_NOTCONNECTED) {
			fchandle = fchandle->next;
			continue;
		}
		if (fchandle->fd >= n)
			n = fchandle->fd + 1;
		FD_SET(fchandle->fd,my_except);
		if (fchandle->connected == FCS_WAITING_SYNACK)
			FD_SET(fchandle->fd,my_write);
		else
			FD_SET(fchandle->fd,my_read);
		firetalk_transmit(fchandle);
		if (fchandle->connected == FCS_ACTIVE && fchandle->datahead != NULL) {
				connwait = fchandle->datahead->delta - (curtime - fchandle->lasttransmit);
				if (connwait < waittime)
					waittime = connwait;

		}

		fileiter = fchandle->file_head;
		while (fileiter) {
			if (fileiter->state == FF_STATE_TRANSFERRING) {
				if (fileiter->sockfd >= n)
					n = fileiter->sockfd + 1;
				switch (fileiter->direction) {
					case FF_DIRECTION_SENDING:
						FD_SET(fileiter->sockfd,my_write);
						FD_SET(fileiter->sockfd,my_except);
						break;
					case FF_DIRECTION_RECEIVING:
						FD_SET(fileiter->sockfd,my_read);
						FD_SET(fileiter->sockfd,my_except);
						break;
				}
			} else if (fileiter->state == FF_STATE_WAITREMOTE) {
				if (fileiter->sockfd >= n)
					n = fileiter->sockfd + 1;
				FD_SET(fileiter->sockfd,my_read);
				FD_SET(fileiter->sockfd,my_except);
			} else if (fileiter->state == FF_STATE_WAITSYNACK) {
				if (fileiter->sockfd >= n)
					n = fileiter->sockfd + 1;
				FD_SET(fileiter->sockfd,my_write);
				FD_SET(fileiter->sockfd,my_except);
			}
			fileiter = fileiter->next;
		}

		fchandle = fchandle->next;
	}

	fchandle = handle_head;
	while (fchandle) {
		protocol_functions[fchandle->protocol].preselect(fchandle->handle,my_read,my_write,my_except,&n);
		if (fchandle->callbacks[FC_PRESELECT])
			fchandle->callbacks[FC_PRESELECT](fchandle,fchandle->clientstruct);
		fchandle = fchandle->next;
	}

	if (my_timeout == NULL) {
		my_timeout = &internal_timeout;
		my_timeout->tv_sec = 15;
		my_timeout->tv_usec = 0;
	}

	s = floor(waittime);
	us = (long) ((waittime - s) * 1000000.0);

	if (my_timeout->tv_sec > s) {
		my_timeout->tv_sec = s;
		my_timeout->tv_usec = us;
	} else if (my_timeout->tv_usec > us)
		my_timeout->tv_usec = us;

	ret = select(n,my_read,my_write,my_except,my_timeout);
	if (ret == -1)
		return FE_PACKET;

	fchandle = handle_head;
	while (fchandle) {
		protocol_functions[fchandle->protocol].postselect(fchandle->handle,my_read,my_write,my_except);
		if (fchandle->callbacks[FC_POSTSELECT])
			fchandle->callbacks[FC_POSTSELECT](fchandle,fchandle->clientstruct);
		fchandle = fchandle->next;
	}

	fchandle = handle_head;
	while (fchandle) {
		if (fchandle->connected == FCS_NOTCONNECTED) {
			fchandle = fchandle->next;
			continue;
		}
		firetalk_transmit(fchandle);
		if (FD_ISSET(fchandle->fd,my_except))
			protocol_functions[fchandle->protocol].disconnect(fchandle->handle);
		else if (FD_ISSET(fchandle->fd,my_read)) {
			short length;
			/* read data into handle buffer */
			length = recv(fchandle->fd,&fchandle->buffer[fchandle->bufferpos],buffersize[fchandle->protocol] - fchandle->bufferpos,0);
			if (length < 1)
				firetalk_callback_disconnect(fchandle->handle,FE_DISCONNECT);
			else {
				fchandle->bufferpos += length;
				if (fchandle->connected == FCS_ACTIVE)
					protocol_functions[fchandle->protocol].got_data(fchandle->handle,fchandle->buffer,&fchandle->bufferpos);
				else
					protocol_functions[fchandle->protocol].got_data_connecting(fchandle->handle,fchandle->buffer,&fchandle->bufferpos);
				if (fchandle->bufferpos == buffersize[fchandle->protocol])
					firetalk_callback_disconnect(fchandle->handle,FE_PACKETSIZE);
			}
		}
		else if (FD_ISSET(fchandle->fd,my_write))
			firetalk_handle_synack(fchandle);
		fileiter = fchandle->file_head;
		while (fileiter) {
			fileiter2 = fileiter->next;
			if (fileiter->state == FF_STATE_TRANSFERRING) {
				if (FD_ISSET(fileiter->sockfd,my_write))
					firetalk_handle_send(fchandle,fileiter);
				if (FD_ISSET(fileiter->sockfd,my_read))
					firetalk_handle_receive(fchandle,fileiter);
				if (FD_ISSET(fileiter->sockfd,my_except)) {
					if (fchandle->callbacks[FC_FILE_ERROR])
						fchandle->callbacks[FC_FILE_ERROR](fchandle,fchandle->clientstruct,fileiter,fileiter->clientfilestruct,FE_IOERROR);
					firetalk_file_cancel(fchandle,fileiter);
				}
			} else if (fileiter->state == FF_STATE_WAITREMOTE) {
				if (FD_ISSET(fileiter->sockfd,my_read)) {
					unsigned int l = sizeof(struct sockaddr_in);
					struct sockaddr_in addr;
					int s;

					s = accept(fileiter->sockfd,(struct sockaddr *)&addr,&l);
					if (s == -1) {
						if (fchandle->callbacks[FC_FILE_ERROR])
							fchandle->callbacks[FC_FILE_ERROR](fchandle,fchandle->clientstruct,fileiter,fileiter->clientfilestruct,FE_SOCKET);
						firetalk_file_cancel(fchandle,fileiter);
					} else {
						close(fileiter->sockfd);
						fileiter->sockfd = s;
						if (fcntl(fileiter->sockfd, F_SETFL, O_NONBLOCK))
							firetalk_file_cancel(fchandle,fileiter);
						else {
							fileiter->state = FF_STATE_TRANSFERRING;
							if (fchandle->callbacks[FC_FILE_START])
								fchandle->callbacks[FC_FILE_START](fchandle,fchandle->clientstruct,fileiter,fileiter->clientfilestruct);
						}
					}
				} else if (FD_ISSET(fileiter->sockfd,my_except)) {
					if (fchandle->callbacks[FC_FILE_ERROR])
						fchandle->callbacks[FC_FILE_ERROR](fchandle,fchandle->clientstruct,fileiter,fileiter->clientfilestruct,FE_IOERROR);
					firetalk_file_cancel(fchandle,fileiter);
				}
			} else if (fileiter->state == FF_STATE_WAITSYNACK) {
				if (FD_ISSET(fileiter->sockfd,my_write))
					firetalk_handle_file_synack(fchandle,fileiter);
				if (FD_ISSET(fileiter->sockfd,my_except))
					firetalk_file_cancel(fchandle,fileiter);
			}
			fileiter = fileiter2;
		}

		fchandle = fchandle->next;
	}
	return FE_SUCCESS;
}
