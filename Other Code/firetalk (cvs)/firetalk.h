/*
firetalk.h - FireTalk wrapper declarations
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
#ifndef _FIRETALK_H
#define _FIRETALK_H

#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdint.h>
#include <netinet/in.h>

#include "proxy.h"

#define LIBFIRETALK_VERSION "0.1.0 (Javelin.cc Extensions)"
#define LIBFIRETALK_HOMEPAGE "http://www.penguinhosting.net/~ian/firetalk/"

#ifndef _HAVE_FIRETALK_T
typedef void * firetalk_t;
#define _HAVE_FIRETALK_T
#endif

/* enums */
enum firetalk_protocol {
#ifndef DISABLE_TOC_PROTOCOL
	FP_AIMTOC,
#endif
#ifndef DISABLE_IRC_PROTOCOL
	FP_IRC,
#endif
	FP_MAX /* tracking enum, don't use this */
};

enum firetalk_callback {
	FC_CONNECTED,
		/* void *connection, void *clientstruct */
	FC_CONNECTFAILED,
		/* void *connection, void *clientstruct, int error, char *reason */
	FC_DOINIT,
		/* void *connection, void *clientstruct, char *nickname */
	FC_ERROR,
		/* void *connection, void *clientstruct, int error, char *roomoruser (room or user that error applies to, null if none) */
	FC_DISCONNECT,
		/* void *connection, void *clientstruct, int error */
	FC_SETIDLE,
		/* void *connection, void *clientstruct, long *idle */
	FC_EVILED,
		/* void *connection, void *clientstruct, int newevil, char *eviler */
	FC_NEWNICK,
		/* void *connection, void *clientstruct, char *nickname */
	FC_PASSCHANGED,
		/* void *connection, void *clientstruct */
	FC_NEEDPASS,
		/* void *connection, void *clientstruct, char *pass, int size */
	FC_PRESELECT,
		/* void *connection, void *clientstruct */
	FC_POSTSELECT,
		/* void *connection, void *clientstruct */
	FC_BACKLOG,
		/* void *connection, void *clientstruct, double backlog */
	FC_IM_IDLEINFO,
		/* void *connection, void *clientstruct, char *nickname, long idletime */
	FC_IM_GOTINFO,
		/* void *connection, void *clientstruct, char *nickname, char *info, int warning, int idle */
	FC_IM_USER_NICKCHANGED,
		/* void *connection, void *clientstruct, char *oldnick, char *newnick */
	FC_IM_GETMESSAGE,
		/* void *connection, void *clientstruct, char *sender, int automessage_flag, char *message */
	FC_IM_GETACTION,
		/* void *connection, void *clientstruct, char *sender, int automessage_flag, char *message */
	FC_IM_BUDDYONLINE,
		/* void *connection, void *clientstruct, char *nickname */
	FC_IM_BUDDYOFFLINE,
		/* void *connection, void *clientstruct, char *nickname */
	FC_IM_BUDDYAWAY,
		/* void *connection, void *clientstruct, char *nickname */
	FC_IM_BUDDYUNAWAY,
		/* void *connection, void *clientstruct, char *nickname */
	FC_IM_LISTBUDDY,
		/* void *connection, void *clientstruct, char *nickname, char online, char away, long idletime */
	FC_IM_LISTROOM,
		/* void *connection, void *clientstruct, char *room, int users, char *topic */
	FC_CHAT_JOINED,
		/* void *connection, void *clientstruct, char *room */
	FC_CHAT_LEFT,
		/* void *connection, void *clientstruct, char *room */
	FC_CHAT_KICKED,
		/* void *connection, void *clientstruct, char *room, char *by, char *reason */
	FC_CHAT_GETMESSAGE,
		/* void *connection, void *clientstruct, char *room, char *from, int automessage_flag, char *message */
	FC_CHAT_GETACTION,
		/* void *connection, void *clientstruct, char *room, char *from, int automessage_flag, char *message */
	FC_CHAT_INVITED,
		/* void *connection, void *clientstruct, char *room, char *from, char *message */
	FC_CHAT_OPPED,
		/* void *connection, void *clientstruct, char *room, char *by */
	FC_CHAT_DEOPPED,
		/* void *connection, void *clientstruct, char *room, char *by */
	FC_CHAT_VOICED,
		/* void *connection, void *clientstruct, char *room, char *by */
	FC_CHAT_DEVOICED,
		/* void *connection, void *clientstruct, char *room, char *by */
	FC_CHAT_USER_JOINED,
		/* void *connection, void *clientstruct, char *room, char *who, int previousmember */
	FC_CHAT_USER_LEFT,
		/* void *connection, void *clientstruct, char *room, char *who, char *reason */
	FC_CHAT_GOTTOPIC,
		/* void *connection, void *clientstruct, char *room, char *topic, char *author */
	FC_CHAT_USER_OPPED,
		/* void *connection, void *clientstruct, char *room, char *who, char *by */
	FC_CHAT_USER_DEOPPED,
		/* void *connection, void *clientstruct, char *room, char *who, char *by */
	FC_CHAT_USER_VOICED,
		/* void *connection, void *clientstruct, char *room, char *who, char *by */
	FC_CHAT_USER_DEVOICED,
		/* void *connection, void *clientstruct, char *room, char *who, char *by */
	FC_CHAT_USER_KICKED,
		/* void *connection, void *clientstruct, char *room, char *who, char *by, char *reason */
	FC_CHAT_USER_NICKCHANGED,
		/* void *connection, void *clientstruct, char *room, char *oldnick, char *newnick */
	FC_CHAT_LISTMEMBER,
		/* void *connection, vodi *clientstruct, char *room, char *membername, int opped */
	FC_FILE_OFFER,
		/* void *connection, void *clientstruct, void *filehandle, char *from, char *filename, long size */
	FC_FILE_START,
		/* void *connection, void *clientstruct, void *filehandle, void *clientfilestruct */
	FC_FILE_PROGRESS,
		/* void *connection, void *clientstruct, void *filehandle, void *clientfilestruct, long bytes, long size */
	FC_FILE_FINISH,
		/* void *connection, void *clientstruct, void *filehandle, void *clientfilestruct, long size */
	FC_FILE_ERROR,
		/* void *connection, void *clientstruct, void *filehandle, void *clientfilestruct, int error */
	FC_MAX
		/* tracking enum, don't hook this */
};

enum firetalk_error {
	FE_SUCCESS,
	FE_CONNECT,
	FE_NOMATCH,
	FE_PACKET,
	FE_BADUSERPASS,
	FE_SEQUENCE,
	FE_FRAMETYPE,
	FE_PACKETSIZE,
	FE_SERVER,
	FE_UNKNOWN,
	FE_BLOCKED,
	FE_WIERDPACKET,
	FE_CALLBACKNUM,
	FE_BADUSER,
	FE_NOTFOUND,
	FE_DISCONNECT,
	FE_SOCKET,
	FE_RESOLV,
	FE_VERSION,
	FE_USERUNAVAILABLE,
	FE_USERINFOUNAVAILABLE,
	FE_TOOFAST,
	FE_ROOMUNAVAILABLE,
	FE_INCOMINGERROR,
	FE_USERDISCONNECT,
	FE_INVALIDFORMAT,
	FE_IDLEFAST,
	FE_BADROOM,
	FE_BADMESSAGE,
	FE_BADPROTO,
	FE_NOTCONNECTED,
	FE_BADCONNECTION,
	FE_NOPERMS,
	FE_NOCHANGEPASS,
	FE_DUPEUSER,
	FE_DUPEROOM,
	FE_IOERROR,
	FE_BADHANDLE,
	FE_TIMEOUT,
	FE_NOTDONE
};


/* Firetalk functions */
const char *firetalk_strprotocol(const enum firetalk_protocol p);
const char *firetalk_strerror(const enum firetalk_error e);
firetalk_t firetalk_create_handle(const int protocol, void *clientstruct);
void firetalk_destroy_handle(firetalk_t conn);
void firetalk_set_flood_intervals(firetalk_t conn, const double flood, const double delay, const double backoff, const double ceiling );
void firetalk_set_proxy_type(firetalk_t conn, enum firetalk_proxy type );
enum firetalk_protocol firetalk_get_protocol(firetalk_t conn);

enum firetalk_error firetalk_disconnect(firetalk_t conn);
enum firetalk_error firetalk_signon(firetalk_t conn, const char * const server, const short port, const char * const username);
enum firetalk_error firetalk_register_callback(firetalk_t conn, const int type, void (*function)(firetalk_t, void *, ...));

enum firetalk_error firetalk_im_add_buddy(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_remove_buddy(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_add_deny(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_remove_deny(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_upload_buddies(firetalk_t conn);
enum firetalk_error firetalk_im_upload_denies(firetalk_t conn);
enum firetalk_error firetalk_im_send_message(firetalk_t conn, const char * const dest, const char * const message, const int auto_flag);
enum firetalk_error firetalk_im_send_action(firetalk_t conn, const char * const dest, const char * const message, const int auto_flag);
enum firetalk_error firetalk_im_list_buddies(firetalk_t conn);
enum firetalk_error firetalk_im_evil(firetalk_t c, const char * const who);
enum firetalk_error firetalk_im_get_info(firetalk_t conn, const char * const nickname, const int priority);
enum firetalk_error firetalk_im_get_roomlist(firetalk_t conn, const char * const search);
enum firetalk_error firetalk_im_stop_roomlist(firetalk_t conn);

enum firetalk_error firetalk_chat_join(firetalk_t conn, const char * const room);
enum firetalk_error firetalk_chat_part(firetalk_t conn, const char * const room);
enum firetalk_error firetalk_chat_send_message(firetalk_t conn, const char * const room, const char * const message, const int auto_flag);
enum firetalk_error firetalk_chat_send_action(firetalk_t conn, const char * const room, const char * const message, const int auto_flag);
enum firetalk_error firetalk_chat_invite(firetalk_t conn, const char * const room, const char * const who, const char * const message);
enum firetalk_error firetalk_chat_set_topic(firetalk_t conn, const char * const room, const char * const topic);
enum firetalk_error firetalk_chat_op(firetalk_t conn, const char * const room, const char * const who);
enum firetalk_error firetalk_chat_deop(firetalk_t conn, const char * const room, const char * const who);
enum firetalk_error firetalk_chat_voice(firetalk_t conn, const char * const room, const char * const who);
enum firetalk_error firetalk_chat_devoice(firetalk_t conn, const char * const room, const char * const who);
enum firetalk_error firetalk_chat_kick(firetalk_t conn, const char * const room, const char * const who, const char * const reason);
enum firetalk_error firetalk_chat_listmembers(firetalk_t conn, const char * const room);
const char *firetalk_chat_get_topic(firetalk_t conn, const char * const room);

enum firetalk_error firetalk_im_internal_add_buddy(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_internal_add_deny(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_internal_remove_buddy(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_im_internal_remove_deny(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_subcode_send_reply(firetalk_t conn, const char * const to, const char * const command, const char * const args);
enum firetalk_error firetalk_subcode_send_request(firetalk_t conn, const char * const to, const char * const command, const char * const args);

enum firetalk_error firetalk_subcode_register_request_callback(firetalk_t conn, const char * const command, void (*callback)(firetalk_t, void *, const char * const, const char * const, const char * const));
enum firetalk_error firetalk_subcode_register_reply_callback(firetalk_t conn, const char * const command, void (*callback)(firetalk_t, void *, const char * const, const char * const, const char * const));

enum firetalk_error firetalk_file_offer(firetalk_t conn, void **filehandle, const char * const nickname, const char * const filename);
enum firetalk_error firetalk_file_accept(firetalk_t conn, void *filehandle, void *clientfilestruct, const char * const localfile);
enum firetalk_error firetalk_file_resume(firetalk_t conn, void *filehandle, void *clientfilestruct, const char * const localfile);
enum firetalk_error firetalk_file_refuse(firetalk_t conn, void *filehandle);
enum firetalk_error firetalk_file_cancel(firetalk_t conn, void *filehandle);

enum firetalk_error firetalk_compare_nicks(firetalk_t conn, const char * const nick1, const char * const nick2);
enum firetalk_error firetalk_save_config(firetalk_t conn);
enum firetalk_error firetalk_set_info(firetalk_t conn, const char * const info);
enum firetalk_error firetalk_set_away(firetalk_t c, const char * const message);
const char * firetalk_chat_normalize(firetalk_t conn, const char * const room);
enum firetalk_error firetalk_set_nickname(firetalk_t conn, const char * const nickname);
enum firetalk_error firetalk_set_password(firetalk_t conn, const char * const oldpass, const char * const newpass);
enum firetalk_error firetalk_select();
enum firetalk_error firetalk_select_custom(int n, fd_set *fd_read, fd_set *fd_write, fd_set *fd_except, struct timeval *timeout);

#ifndef FIRETALK
extern enum firetalk_error firetalkerror;
#endif

#define FF_SUBSTANDARD                  0x0001
#define FF_NORMAL                       0x0002
#define FF_ADMIN                        0x0004

#endif
