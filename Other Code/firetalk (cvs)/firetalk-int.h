/*
firetalk-int.h - FireTalk wrapper declarations
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
#ifndef _FIRETALK_INT_H
#define _FIRETALK_INT_H

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

typedef struct s_firetalk_handle * firetalk_t;
#define _HAVE_FIRETALK_T

#ifndef _HAVE_CLIENT_T
#define _HAVE_CLIENT_T
typedef void * client_t;
#endif

#include "firetalk.h"

#ifndef MSG_WAITALL
#define MSG_WAITALL 0x100
#endif

#ifndef SHUT_RDWR
#define SHUT_RDWR 2
#endif


typedef void (*ptrtofnct)(firetalk_t, void *, ...);

struct s_firetalk_buddy {
	struct s_firetalk_buddy *next;
	char *nickname;
	int online;
	int away;
	long idletime;
	int tempint;
	int tempint2;
};

struct s_firetalk_deny {
	struct s_firetalk_deny *next;
	char *nickname;
};

struct s_firetalk_member {
	struct s_firetalk_member *next;
	char *nickname;
	int admin;
	int voice;
};

struct s_firetalk_room {
	struct s_firetalk_room *next;
	struct s_firetalk_member *member_head;
	int admin;
	int voice;
	unsigned modes;
	char *password;
	int member_limit;
	char *name;
	char *topic;
	char *author;
};

struct s_firetalk_file {
	struct s_firetalk_file *next;
	char *who;
	char *filename;
	struct in_addr inet_ip;
#ifdef _FC_USE_IPV6
	struct in6_addr inet6_ip;
	int tryinet6;
#endif
	uint16_t port;
	long size;
	long bytes;
	uint32_t acked;
#define FF_STATE_WAITLOCAL     0
#define FF_STATE_WAITREMOTE    1
#define FF_STATE_WAITSYNACK    2
#define FF_STATE_TRANSFERRING  3
	int state;
#define FF_DIRECTION_SENDING   0
#define FF_DIRECTION_RECEIVING 1
	int direction;
#define FF_TYPE_DCC            0
#define FF_TYPE_RAW            1
#define FF_TYPE_CUSTOM         2
#define FF_TYPE_CUSTOM_RAW     3
	int type;
#define FF_INITBUFFER_MAXLEN 256
	char initbuffer[FF_INITBUFFER_MAXLEN];
	int sockfd;
	int filefd;
	void *clientfilestruct;
	char *cookie;
	void *customdata;
};

struct s_firetalk_subcode_callback {
	struct s_firetalk_subcode_callback *next;
	char *command;
	ptrtofnct callback;
};

struct s_firetalk_queued_data {
	struct s_firetalk_queued_data *next;
	struct s_firetalk_queued_data *prev;
	char *data;
	int length;
	double delta;
};

struct s_firetalk_handle {
	void *handle;
	void *clientstruct;
	int connected;
	struct sockaddr_in remote_addr;
	struct in_addr local_addr;
#ifdef _FC_USE_IPV6
	struct sockaddr_in6 remote_addr6;
	struct in6_addr local_addr6;
#endif
	unsigned long localip;
	int protocol;
	char *username;
	int fd;
	ptrtofnct callbacks[FC_MAX];
	unsigned char *buffer;
	unsigned short bufferpos;
	struct s_firetalk_handle *next;
	struct s_firetalk_handle *prev;
	struct s_firetalk_buddy *buddy_head;
	struct s_firetalk_deny *deny_head;
	struct s_firetalk_room *room_head;
	struct s_firetalk_file *file_head;
	struct s_firetalk_subcode_callback *subcode_request_head;
	struct s_firetalk_subcode_callback *subcode_reply_head;
	struct s_firetalk_subcode_callback *subcode_request_default;
	struct s_firetalk_subcode_callback *subcode_reply_default;
	double lastsend;
	double lasttransmit;
	double flood_intervals[4];
	int flood;
	/* next data to send */
	struct s_firetalk_queued_data *datahead;
	/* where to place new data */
	struct s_firetalk_queued_data *datatail;
	enum firetalk_proxy proxy;
};

struct s_firetalk_protocol_functions {
	enum firetalk_error (*periodic)(struct s_firetalk_handle * const);
	enum firetalk_error (*preselect)(client_t, fd_set *read, fd_set *write, fd_set *except, int *n);
	enum firetalk_error (*postselect)(client_t, fd_set *read, fd_set *write, fd_set *except);
	enum firetalk_error (*got_data)(client_t, unsigned char * buffer, unsigned short *bufferpos);
	enum firetalk_error (*got_data_connecting)(client_t, unsigned char * buffer, unsigned short *bufferpos);
	enum firetalk_error (*prepare_for_transmit)(client_t, char * const data, const int length);
	enum firetalk_error (*comparenicks)(const char * const, const char * const);
	enum firetalk_error (*disconnect)(client_t);
	enum firetalk_error (*signon)(client_t, const char * const);
    enum firetalk_error (*send_raw)(client_t, const char * const);
	enum firetalk_error (*save_config)(client_t);
	enum firetalk_error (*get_roomlist)(client_t, const char * const);
	enum firetalk_error (*stop_roomlist)(client_t);
	enum firetalk_error (*get_info)(client_t, const char * const, const int);
	enum firetalk_error (*set_info)(client_t, const char * const);
	enum firetalk_error (*set_away)(client_t, const char * const);
	enum firetalk_error (*set_nickname)(client_t, const char * const);
	enum firetalk_error (*set_password)(client_t, const char * const, const char * const);
	enum firetalk_error (*im_add_buddy)(client_t, const char * const);
	enum firetalk_error (*im_remove_buddy)(client_t, const char * const);
	enum firetalk_error (*im_add_deny)(client_t, const char * const);
	enum firetalk_error (*im_remove_deny)(client_t, const char * const);
	enum firetalk_error (*im_upload_buddies)(client_t);
	enum firetalk_error (*im_upload_denies)(client_t);
	enum firetalk_error (*im_send_message)(client_t, const char * const, const char * const, const int);
	enum firetalk_error (*im_send_action)(client_t, const char * const, const char * const, const int);
	enum firetalk_error (*im_evil)(client_t, const char * const);
	enum firetalk_error (*chat_join)(client_t, const char * const);
	enum firetalk_error (*chat_part)(client_t, const char * const);
	enum firetalk_error (*chat_invite)(client_t, const char * const, const char * const, const char * const);
	enum firetalk_error (*chat_set_topic)(client_t, const char * const, const char * const);
	enum firetalk_error (*chat_op)(client_t, const char * const, const char * const);
	enum firetalk_error (*chat_deop)(client_t, const char * const, const char * const);
	enum firetalk_error (*chat_voice)(client_t, const char * const, const char * const);
	enum firetalk_error (*chat_devoice)(client_t, const char * const, const char * const);
	enum firetalk_error (*chat_kick)(client_t, const char * const, const char * const, const char * const);
	enum firetalk_error (*chat_send_message)(client_t, const char * const, const char * const, const int);
	enum firetalk_error (*chat_send_action)(client_t, const char * const, const char * const, const int);
	enum firetalk_error (*subcode_send_request)(client_t, const char * const, const char * const, const char * const);
	enum firetalk_error (*subcode_send_reply)(client_t, const char * const, const char * const, const char * const);
	enum firetalk_error (*file_handle_custom)(client_t, const int, char *, long *, const char * const);
	enum firetalk_error (*file_complete_custom)(client_t, const int, void *);
	const char * const (*room_normalize)(const char * const);
	client_t (*create_handle)();
	void (*destroy_handle)(client_t);
	void (*signon_init)(client_t);
};

enum firetalk_connectstate {
	FCS_NOTCONNECTED,
	FCS_WAITING_SYNACK,
	FCS_WAITING_SIGNON,
	FCS_ACTIVE
};

double firetalk_gettime();

void firetalk_callback_raw_message(client_t c, const char * const raw, int output);
void firetalk_callback_im_getmessage(client_t c, const char * const sender, const int automessage, const char * const message);
void firetalk_callback_im_getaction(client_t c, const char * const sender, const int automessage, const char * const message);
void firetalk_callback_im_buddyonline(client_t c, const char * const nickname, const int online);
void firetalk_callback_im_buddyaway(client_t c,  const char * const nickname, const int away);
void firetalk_callback_error(client_t c, const int error, const char * const roomoruser, const char * const description);
void firetalk_callback_backlog(firetalk_t c);
void firetalk_callback_connectfailed(client_t c, const int error, const char * const description);
void firetalk_callback_connected(client_t c);
void firetalk_callback_disconnect(client_t c, const int error);
void firetalk_callback_gotinfo(client_t c, const char * const nickname, const char * const username, const char * const hostname, const char * const server, const char * const realname, const int warning, const long idle, const long connected, const int flags);
void firetalk_callback_idleinfo(client_t c, char const * const nickname, const long idletime);
void firetalk_callback_doinit(client_t c, char const * const nickname);
void firetalk_callback_setidle(client_t c, long * const idle);
void firetalk_callback_eviled(client_t c, const int newevil, const char * const eviler);
void firetalk_callback_newnick(client_t c, const char * const nickname);
void firetalk_callback_passchanged(client_t c);
void firetalk_callback_gotroomlist(client_t c, const char * const room, const int users, const char * const topic);
void firetalk_callback_user_nickchanged(client_t c, const char * const oldnick, const char * const newnick);
void firetalk_callback_chat_joined(client_t c, const char * const room);
void firetalk_callback_chat_left(client_t c, const char * const room);
void firetalk_callback_chat_kicked(client_t c, const char * const room, const char * const by, const char * const reason);
void firetalk_callback_chat_getmessage(client_t c, const char * const room, const char * const from, const int automessage, const char * const message);
void firetalk_callback_chat_getaction(client_t c, const char * const room, const char * const from, const int automessage, const char * const message);
void firetalk_callback_chat_invited(client_t c, const char * const room, const char * const from, const char * const message);
void firetalk_callback_chat_user_joined(client_t c, const char * const room, const char * const who, const int previousmember);
void firetalk_callback_chat_user_left(client_t c, const char * const room, const char * const who, const char * const reason);
void firetalk_callback_chat_user_quit(client_t c, const char * const who, const char * const reason);
void firetalk_callback_chat_gottopic(client_t c, const char * const room, const char * const topic, const char * const author);
void firetalk_callback_chat_room_mode(client_t c, const char * const op, const char * const room, const int on, enum firetalk_room_mode mode, const char * const params);
void firetalk_callback_chat_user_opped(client_t c, const char * const room, const char * const who, const char * const by);
void firetalk_callback_chat_user_deopped(client_t c, const char * const room, const char * const who, const char * const by);
void firetalk_callback_chat_user_voiced(client_t c, const char * const room, const char * const who, const char * const by);
void firetalk_callback_chat_user_devoiced(client_t c, const char * const room, const char * const who, const char * const by);
void firetalk_callback_chat_opped(client_t c, const char * const room, const char * const by);
void firetalk_callback_chat_deopped(client_t c, const char * const room, const char * const by);
void firetalk_callback_chat_voiced(client_t c, const char * const room, const char * const by);
void firetalk_callback_chat_devoiced(client_t c, const char * const room, const char * const by);
void firetalk_callback_chat_user_kicked(client_t c, const char * const room, const char * const who, const char * const by, const char * const reason);
void firetalk_callback_chat_user_away(client_t c, const char * const who, const char * const message);
void firetalk_callback_subcode_request(client_t c, const char * const from, const char * const command, char *args);
void firetalk_callback_subcode_reply(client_t c, const char * const from, const char * const command, const char * const args);
void firetalk_callback_file_offer(client_t c, const char * const from, const char * const filename, const long size, const char * const ipstring, const char * const ip6string, const uint16_t port, const int type, const char *cookie);
void firetalk_callback_needpass(client_t c, char *pass, const int size);

firetalk_t firetalk_find_handle(client_t c);

enum firetalk_error firetalk_chat_internal_add_room(firetalk_t conn, const char * const name);
enum firetalk_error firetalk_chat_internal_add_member(firetalk_t conn, const char * const room, const char * const nickname);
enum firetalk_error firetalk_chat_internal_remove_room(firetalk_t conn, const char * const name);
enum firetalk_error firetalk_chat_internal_remove_member(firetalk_t conn, const char * const room, const char * const nickname);

struct s_firetalk_room *firetalk_find_room(struct s_firetalk_handle *c, const char * const room);

void firetalk_handle_send(struct s_firetalk_handle * c, struct s_firetalk_file *filestruct);
void firetalk_handle_receive(struct s_firetalk_handle * c, struct s_firetalk_file *filestruct);

void firetalk_internal_send_data(struct s_firetalk_handle * c, char * const data, const int length, const int urgent);
void firetalk_transmit(struct s_firetalk_handle *c);

int firetalk_internal_connect_host(const char * const host, const uint16_t port, enum firetalk_proxy proxy);
int firetalk_internal_connect(struct sockaddr_in *inet4_ip
#ifdef _FC_USE_IPV6
		, struct sockaddr_in6 *inet6_ip
#endif
		, enum firetalk_proxy proxy );
int firetalk_internal_resolve4(const char * const host, struct in_addr *inet4_ip);
struct sockaddr_in *firetalk_internal_remotehost4(client_t c);
#ifdef _FC_USE_IPV6
int firetalk_internal_resolve6(const char * const host, struct in6_addr *inet6_ip);
struct sockaddr_in6 *firetalk_internal_remotehost6(client_t c);
#endif
enum firetalk_connectstate firetalk_internal_get_connectstate(client_t c);
void firetalk_internal_set_connectstate(client_t c, enum firetalk_connectstate fcs);
void firetalk_internal_file_register_customdata(client_t c, int fd, void *customdata);

#ifdef DEBUG
enum firetalk_error firetalk_check_handle(struct s_firetalk_handle *c);
#endif
void firetalk_set_timeout(unsigned int seconds);
void firetalk_clear_timeout();

#endif
