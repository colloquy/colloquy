/*
dummy.h - FireTalk dummy protocol declarations
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
#ifndef _DUMMY_H
#define _DUMMY_H

#include <sys/types.h>
#include "firetalk-int.h"

client_t dummy_create_handle();
void dummy_destroy_handle(client_t c);

const char * const dummy_normalize_room_name(const char * const name);

enum firetalk_error dummy_compare_nicks(const char * const nick1, const char * const nick2);
enum firetalk_error dummy_disconnect(client_t c);
enum firetalk_error dummy_signon(client_t c, const char * const nickname);
enum firetalk_error dummy_save_config(client_t c);

enum firetalk_error dummy_preselect(client_t c, fd_set *read, fd_set *write, fd_set *except, int *n);
enum firetalk_error dummy_postselect(client_t c, fd_set *read, fd_set *write, fd_set *except);

enum firetalk_error dummy_got_data(client_t c, unsigned char * buffer, unsigned short * bufferpos);
enum firetalk_error dummy_got_data_connecting(client_t c, unsigned char * buffer, unsigned short * bufferpos);
enum firetalk_error dummy_set_away(client_t c, const char * const message);
enum firetalk_error dummy_periodic(struct s_firetalk_handle * const c);
enum firetalk_error dummy_get_roomlist(client_t c, const char * const search);
enum firetalk_error dummy_stop_roomlist(client_t c);
enum firetalk_error dummy_get_info(client_t c, const char * const nickname);
enum firetalk_error dummy_set_info(client_t c, const char * const info);
enum firetalk_error dummy_set_nickname(client_t c, const char * const nickname);
enum firetalk_error dummy_set_password(client_t c, const char * const oldpass, const char * const newpass);

enum firetalk_error dummy_chat_join(client_t c, const char * const room);
enum firetalk_error dummy_chat_part(client_t c, const char * const room);
enum firetalk_error dummy_chat_send_message(client_t c, const char * const room, const char * const message, const int auto_flag);
enum firetalk_error dummy_chat_send_action(client_t c, const char * const room, const char * const message, const int auto_flag);
enum firetalk_error dummy_chat_invite(client_t c, const char * const room, const char * const who, const char * const message);
enum firetalk_error dummy_chat_set_topic(client_t c, const char * const room, const char * const topic);
enum firetalk_error dummy_chat_op(client_t c, const char * const room, const char * const who);
enum firetalk_error dummy_chat_deop(client_t c, const char * const room, const char * const who);
enum firetalk_error dummy_chat_voice(void * const c, const char * const room, const char * const who);
enum firetalk_error dummy_chat_devoice(void * const c, const char * const room, const char * const who);
enum firetalk_error dummy_chat_kick(client_t c, const char * const room, const char * const who, const char * const reason);

enum firetalk_error dummy_im_send_message(client_t c, const char * const dest, const char * const message, const int auto_flag);
enum firetalk_error dummy_im_send_action(client_t c, const char * const dest, const char * const message, const int auto_flag);
enum firetalk_error dummy_im_add_buddy(client_t c, const char * const nickname);
enum firetalk_error dummy_im_remove_buddy(client_t c, const char * const nickname);
enum firetalk_error dummy_im_add_deny(client_t c, const char * const nickname);
enum firetalk_error dummy_im_remove_deny(client_t c, const char * const nickname);
enum firetalk_error dummy_im_upload_buddies(client_t c);
enum firetalk_error dummy_im_upload_denies(client_t c);
enum firetalk_error dummy_im_evil(client_t c, const char * const who);

enum firetalk_error dummy_subcode_send_request(client_t c, const char * const to, const char * const command, const char * const args);
enum firetalk_error dummy_subcode_send_reply(client_t c, const char * const to, const char * const command, const char * const args);

enum firetalk_error dummy_file_handle_custom(client_t c, const int fd, char *buffer, long *bufferpos, const char * const cookie);
enum firetalk_error dummy_file_complete_custom(client_t c, const int fd, void *customdata);
enum firetalk_error dummy_prepare_for_transmit(client_t c, char * const data, const int length);

#endif
