/*
aim.h - FireTalk generic AIM declarations
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
#ifndef _AIM_H
#define _AIM_H

#include <unistd.h>
#include <sys/time.h>

char *aim_interpolate_variables(const char * const input, const char * const nickname);
const char * const aim_normalize_room_name(const char * const name);
char *aim_handle_ect(void *conn, const char * const from, char * message, const int reply);
enum firetalk_error aim_file_handle_custom(client_t c, const int fd, char *buffer, long *bufferpos, const char * const cookie);
enum firetalk_error aim_file_complete_custom(client_t c, const int fd, void *customdata);
enum firetalk_error aim_compare_nicks(const char * const nick1, const char * const nick2);
unsigned char aim_debase64(const char c);


#endif
