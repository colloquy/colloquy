/*
oscar.c - FireTalk OSCAR protocol definitions
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

midendian can suck my left nut.

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

#include "firetalk-int.h"
#include "firetalk.h"
#include "oscar.h"

#define LOGIN_SERVER "login.oscar.aol.com"
#define LOGIN_PORT 443

struct s_oscar_flap {
	unsigned char command_start;
	unsigned char channel_id;
	unsigned short sequence_number;
	unsigned short data_length;
};

struct s_oscar_connection {
	int s;
	unsigned short local_sequence;
	unsigned short remote_sequence;
	char *cookie;
};

#define FLAP_CHANNEL_NEWCON 0x01
#define FLAP_CHANNEL_SNAC   0x02
#define FLAP_CHANNEL_ERROR  0x03
#define FLAP_CHANNEL_CLOSE  0x04

static int oscar_internal_disconnect(struct s_oscar_connection * const c, const int error);
static int oscar_send_flap(struct s_oscar_connection * const c, const unsigned char channel_id, const unsigned short length, const char * const data);
static int oscar_get_cookie(struct s_oscar_connection * const c);

static int oscar_internal_disconnect(struct s_oscar_connection * const c, const int error) {
	close(c->s);
	free(c);
	firetalkerror = error;
	firetalk_callback_disconnect(c,error);
	firetalkerror = FE_SUCCESS;
	return FE_SUCCESS;
}

static int oscar_send_flap(struct s_oscar_connection * const c, const unsigned char channel_id, const unsigned short length, const char * const data) {
	static struct s_oscar_flap header = { (unsigned char)0x2a, '\0', 0x0000, 0x0000 };

	header.channel_id = channel_id;
	header.sequence_number = c->local_sequence++;
	header.data_length = length;
	if (send(c->s,&header,sizeof(struct s_oscar_flap),0) != sizeof(struct s_oscar_flap)) {
		(void) oscar_internal_disconnect(c,FE_PACKET);
		firetalkerror = FE_PACKET;
		return FE_PACKET;
	}
	if (send(c->s,data,length,0) != length) {
		(void) oscar_internal_disconnect(c,FE_PACKET);
		firetalkerror = FE_PACKET;
		return FE_PACKET;
	}
	firetalkerror = FE_SUCCESS;
	return FE_SUCCESS;
}

static int oscar_get_cookie(struct s_oscar_connection * const c) {
	return 0;
}
