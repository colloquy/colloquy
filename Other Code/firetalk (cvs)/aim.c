/*
aim.c - FireTalk generic AIM definitions
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
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <ctype.h>
#include "firetalk-int.h"
#include "firetalk.h"
#include "aim.h"
#include "safestring.h"

struct s_aim_file_header {
	char  magic[4];         /* 0 */
	short hdrlen;           /* 4 */
	short hdrtype;          /* 6 */
	char  bcookie[8];       /* 8 */
	short encrypt;          /* 16 */
	short compress;         /* 18 */
	short totfiles;         /* 20 */
	short filesleft;        /* 22 */
	short totparts;         /* 24 */
	short partsleft;        /* 26 */
	long  totsize;          /* 28 */
	long  size;             /* 32 */
	long  modtime;          /* 36 */
	long  checksum;         /* 40 */
	long  rfrcsum;          /* 44 */
	long  rfsize;           /* 48 */
	long  cretime;          /* 52 */
	long  rfcsum;           /* 56 */
	long  nrecvd;           /* 60 */
	long  recvcsum;         /* 64 */
	char  idstring[32];     /* 68 */
	char  flags;            /* 100 */
	char  lnameoffset;      /* 101 */
	char  lsizeoffset;      /* 102 */
	char  dummy[69];        /* 103 */
	char  macfileinfo[16];  /* 172 */
	short nencode;          /* 188 */
	short nlanguage;        /* 190 */
	char  name[64];         /* 192 */
				/* 256 */
};

char *aim_interpolate_variables(const char * const input, const char * const nickname) {
	static char output[16384]; /* 2048 / 2 * 16 + 1 (max size with a string full of %n's, a 16-char nick and a null at the end) */
	int o = 0,gotpercent = 0;
	size_t nl,dl,tl,l,i;
	char date[15],tim[15];
	{ /* build the date and time */
		int hour;
		int am = 1;
		struct tm *t;
		time_t b;
		b = time(NULL);
		t = localtime(&b);
		if (t == NULL)
			return NULL;
		hour = t->tm_hour;
		if (hour >= 12)
			am = 0;
		if (hour > 12)
			hour -= 12;
		if (hour == 0)
			hour = 12;
		sprintf(tim,"%d:%02d:%02d %s",hour,t->tm_min,t->tm_sec,am == 1 ? "AM" : "PM");
		safe_snprintf(date,15,"%d/%d/%d",t->tm_mon + 1,t->tm_mday,t->tm_year + 1900);
	}
	nl = strlen(nickname);
	dl = strlen(date);
	tl = strlen(tim);
	l = strlen(input);
	for (i = 0; i < l; i++) {
		switch (input[i]) {
			case '%':
				if (gotpercent == 1) {
					gotpercent = 0;
					output[o++] = '%';
					output[o++] = '%';
				} else
					gotpercent = 1;
				break;
			case 'n':
				if (gotpercent == 1) {
					gotpercent = 0;
					memcpy(&output[o],nickname,nl);
					o += nl;
				} else
					output[o++] = 'n';
				break;
			case 'd':
				if (gotpercent == 1) {
					gotpercent = 0;
					memcpy(&output[o],date,dl);
					o += dl;
				} else
					output[o++] = 'd';
				break;
			case 't':
				if (gotpercent == 1) {
					gotpercent = 0;
					memcpy(&output[o],tim,tl);
					o += tl;
				} else
					output[o++] = 't';
				break;
			default:
				if (gotpercent == 1) {
					gotpercent = 0;
					output[o++] = '%';
				}
				output[o++] = input[i];

		}
	}
	output[o] = '\0';
	return output;
}

const char * const aim_normalize_room_name(const char * const name) {
	static char newname[2048];
	if (name == NULL)
		return NULL;
	if (strchr(name,':'))
		return name;
	if (strlen(name) > 2045)
		return NULL;
	safe_strncpy(newname,"4:",2048);
	safe_strncat(newname,name,2048);
	return newname;
}

char *aim_handle_ect(void *conn, const char * const from, char * message, const int reply) {
	char *tempchr1, *tempchr2;

	while ((tempchr1 = strstr(message,"<!--ECT "))) {
		if ((tempchr2 = strstr(&tempchr1[8],"-->"))) {
			/* valid ECT */
			char *endcommand;
			*tempchr2 = '\0';
			endcommand = strchr(&tempchr1[8],' ');
			if (endcommand) {
				*endcommand = '\0';
				endcommand++;
				if (reply == 1)
					firetalk_callback_subcode_reply(conn,from,&tempchr1[8],endcommand);
				else
					firetalk_callback_subcode_request(conn,from,&tempchr1[8],endcommand);
			} else {
				if (reply == 1)
					firetalk_callback_subcode_reply(conn,from,&tempchr1[8],NULL);
				else
					firetalk_callback_subcode_request(conn,from,&tempchr1[8],NULL);
			}
			memmove(tempchr1,&tempchr2[3],strlen(&tempchr2[3]) + 1);
		}
	}
	return message;
}

unsigned char aim_debase64(const char c) {
	if (c >= 'A' && c <= 'Z')
		return (unsigned char) (c - 'A');
	if (c >= 'a' && c <= 'z')
		return (unsigned char) ((char) 26 + (c - 'a'));
	if (c >= '0' && c <= '9')
		return (unsigned char) ((char) 52 + (c - '0'));
	if (c == '+')
		return (unsigned char) 62;
	if (c == '/')
		return (unsigned char) 63;
	return (unsigned char) 0;
}

enum firetalk_error aim_file_handle_custom(client_t c, const int fd, char *buffer, long *bufferpos, const char * const cookie) {
	struct s_aim_file_header *h;
	char *cd;

	if (*bufferpos < 256)
		return FE_NOTDONE;

	h = (struct s_aim_file_header *)buffer;
	h->hdrtype = htons(0x202);
	h->encrypt = 0;
	h->compress = 0;
	h->bcookie[0] = (aim_debase64(cookie[0]) << 2) | (aim_debase64(cookie[1]) >> 4);
	h->bcookie[1] = (aim_debase64(cookie[1]) << 4) | (aim_debase64(cookie[2]) >> 2);
	h->bcookie[2] = (aim_debase64(cookie[2]) << 6) | aim_debase64(cookie[3]);
	h->bcookie[3] = (aim_debase64(cookie[4]) << 2) | (aim_debase64(cookie[5]) >> 4);
	h->bcookie[4] = (aim_debase64(cookie[5]) << 4) | (aim_debase64(cookie[6]) >> 2);
	h->bcookie[5] = (aim_debase64(cookie[6]) << 6) | aim_debase64(cookie[7]);
	h->bcookie[6] = (aim_debase64(cookie[8]) << 2) | (aim_debase64(cookie[9]) >> 4);
	h->bcookie[7] = (aim_debase64(cookie[9]) << 4) | (aim_debase64(cookie[10]) >> 2);
	if (send(fd,h,256,0) != 256)
		return FE_IOERROR;
	cd = safe_malloc(256);
	memcpy(cd,h,256);
	firetalk_internal_file_register_customdata(c,fd,cd);
	*bufferpos -= 256;
	memmove(buffer,&buffer[256],*bufferpos);
	return FE_SUCCESS;
}

enum firetalk_error aim_file_complete_custom(client_t c, const int fd, void *customdata) {
	struct s_aim_file_header *h;

	h = (struct s_aim_file_header *) customdata;
	h->hdrtype = htons(0x204);
	h->filesleft = 0;
	h->partsleft = 0;
	h->recvcsum = h->checksum;
	h->nrecvd = htons(1);
	h->flags = 0;
	if (send(fd,h,256,0) != 256)
		return FE_IOERROR;
	return FE_SUCCESS;
}

enum firetalk_error aim_compare_nicks (const char * const nick1, const char * const nick2) {
	const char * tempchr1;
	const char * tempchr2;

	tempchr1 = nick1;
	tempchr2 = nick2;

	if (!nick1 || !nick2)
		return FE_NOMATCH;

	while (tempchr1[0] != '\0') {
		while (tempchr1[0] == ' ')
			tempchr1++;
		while (tempchr2[0] == ' ')
			tempchr2++;
		if (tolower((unsigned char) tempchr1[0]) != tolower((unsigned char) tempchr2[0]))
			return FE_NOMATCH;
		tempchr1++;
		tempchr2++;
	}
	if (tempchr2[0] != '\0')
		return FE_NOMATCH;

	return FE_SUCCESS;
}
