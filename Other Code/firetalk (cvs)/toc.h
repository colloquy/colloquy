/*
toc.h - FireTalk TOC protocol declarations
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
#ifndef _TOC_H
#define _TOC_H

#include "firetalk.h"
#include "firetalk-int.h"
#include <unistd.h>
#include <sys/time.h>

/* AOL/TOC Functions */
client_t toc_create_handle();
void toc_destroy_handle(client_t c);

enum firetalk_error toc_disconnect(client_t c);
enum firetalk_error toc_signon(client_t c, const char * const username);

enum firetalk_error toc_preselect(client_t c, fd_set *read, fd_set *write, fd_set *except, int *n);
enum firetalk_error toc_postselect(client_t c, fd_set *read, fd_set *write, fd_set *except);

enum firetalk_error toc_im_add_buddy(client_t c, const char * const nickname);
enum firetalk_error toc_im_remove_buddy(client_t c, const char * const nickname);
enum firetalk_error toc_im_add_deny(client_t c, const char * const nickname);
enum firetalk_error toc_im_remove_deny(client_t c, const char * const nickname);
enum firetalk_error toc_im_upload_buddies(client_t c);
enum firetalk_error toc_im_upload_denies(client_t c);
enum firetalk_error toc_im_send_message(client_t c, const char * const dest, const char * const message, const int auto_flag);
enum firetalk_error toc_im_send_action(client_t c, const char * const dest, const char * const message, const int auto_flag);
enum firetalk_error toc_im_evil(client_t c, const char * const who);

enum firetalk_error toc_chat_join(client_t c, const char * const room);
enum firetalk_error toc_chat_part(client_t c, const char * const room);
enum firetalk_error toc_chat_set_topic(client_t c, const char * const room, const char * const topic);
enum firetalk_error toc_chat_op(client_t c, const char * const room, const char * const who);
enum firetalk_error toc_chat_deop(client_t c, const char * const room, const char * const who);
enum firetalk_error toc_chat_kick(client_t c, const char * const room, const char * const who, const char * const reason);
enum firetalk_error toc_chat_send_message(client_t c, const char * const room, const char * const message, const int auto_flag);
enum firetalk_error toc_chat_send_action(client_t c, const char * const room, const char * const message, const int auto_flag);
enum firetalk_error toc_chat_invite(client_t c, const char * const room, const char * const who, const char * const message);

enum firetalk_error toc_subcode_send_request(client_t c, const char * const to, const char * const command, const char * const args);
enum firetalk_error toc_subcode_send_reply(client_t c, const char * const to, const char * const command, const char * const args);

enum firetalk_error toc_save_config(client_t c);
enum firetalk_error toc_get_info(client_t c, const char * const nickname);
enum firetalk_error toc_set_info(client_t c, const char * const info);
enum firetalk_error toc_set_away(client_t c, const char * const message);
enum firetalk_error toc_set_nickname(client_t c, const char * const nickname);
enum firetalk_error toc_set_password(client_t c, const char * const oldpass, const char * const newpass);
enum firetalk_error toc_got_data(client_t c, unsigned char * buffer, unsigned short * bufferpos);
enum firetalk_error toc_got_data_connecting(client_t c, unsigned char * buffer, unsigned short * bufferpos);
enum firetalk_error toc_periodic(firetalk_t c);

#endif
