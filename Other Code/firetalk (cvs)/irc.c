/*
irc.c - FireTalk IRC protocol definitions
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
#include <sys/socket.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <strings.h>
#include <sys/time.h>
#include <time.h>
#include <errno.h>
#include <ctype.h>

#define MAXSTACK 15
#define MODES_PER_LINE 3

struct s_irc_whois {
	struct s_irc_whois *next;
	char *nickname;
	char *info;
	char *away;
	int flags;
	long idle;
};

struct s_irc_mode {
	char *nickname;
	char *room;
	int sign;
	char mode;
};

struct s_irc_connection {
	char *nickname;
	char *password;
	char buffer[513];
	int modecount;
	struct s_irc_mode modestack[MAXSTACK];
	time_t lasttime;                                     /* last time we set idles */
	int isons;                                           /* number of ISON's we're waiting on replies to */
	struct s_irc_whois *whois_head;
	int passchange;                                      /* whether we are currently changing our pass */
	int usesilence;                                      /* are we on a network that understands SILENCE */
	int identified;					/* are we identified */
};

typedef struct s_irc_connection * client_t;
#define _HAVE_CLIENT_T

#include "firetalk-int.h"
#include "firetalk.h"
#include "irc.h"
#include "safestring.h"

#define IRC_SERVER "irc.openprojects.net"
#define IRC_PORT 6667
#define ROOMSTARTS "#+&"

#define NUMIRC 16
static const int ircrgb[][3] = {
	{ 0xff, 0xff, 0xff },  /* 00) white */
	{ 0x00, 0x00, 0x00 },  /* 01) black */
	{ 0x00, 0x00, 0x7b },  /* 02) blue */
	{ 0x00, 0x94, 0x00 },  /* 03) green */
	{ 0xff, 0x00, 0x00 },  /* 04) red */
	{ 0x7b, 0x00, 0x00 },  /* 05) brown */
	{ 0x9c, 0x00, 0x9c },  /* 06) purple */
	{ 0xff, 0x7b, 0x00 },  /* 07) orange */
	{ 0xff, 0xff, 0x00 },  /* 08) yellow */
	{ 0x00, 0xff, 0x00 },  /* 09) bright green */
	{ 0x00, 0x94, 0x94 },  /* 10) cyan */
	{ 0x00, 0xff, 0xff },  /* 11) bright cyan */
	{ 0x00, 0x00, 0xff },  /* 12) bright blue */
	{ 0xff, 0x00, 0xff },  /* 13) bright purple */
	{ 0x7b, 0x7b, 0x7b },  /* 14) gray */
	{ 0xd6, 0xd6, 0xd6 }   /* 15) light grey */
};

int irc_rgb_to_irc(unsigned int red, unsigned int green, unsigned int blue);
char *irc_html_to_irc(const char * const string);
char *irc_irc_to_html(const char * const string);
static int irc_send_printf(client_t c, int urgent, const char * const format, ...);
static int irc_internal_disconnect(client_t c, const int error);
static char **irc_recv_parse(client_t c, unsigned char *buffer, unsigned short *bufferpos);
enum firetalk_error irc_flush_modes(client_t c);

int irc_rgb_to_irc(unsigned int red, unsigned int green, unsigned int blue) {
	int distance = 1000, color = 1, i = 0, o = 0;
	for (i = 0; i < NUMIRC; i++) {
		o = abs(red - ircrgb[i][0]) +
		abs(green - ircrgb[i][1]) +
		abs(blue - ircrgb[i][2]);
		if (o < distance) {
			color = i;
			distance = o;
		}
	}
	/* assert: color will always have been set */
	return color;
}

/*

from buddy structure:

tempint1 = ison, default 0, used during ISON checks
tempint2 = away, default 0, used during WHOIS checks

*/

char *irc_html_to_irc(const char * const string) {
	static char *output = NULL;
	int o = 0;
	int inbold = 0, initalics = 0, inunderline = 0, incolor = 0;
	int tagmatch = 0;
	size_t l, i = 0;
	l = safe_strlen(string);
	output = safe_realloc(output,l + 1);
	while (i < l && o < l) {
		switch(string[i]) {
			case '&':
				if (!safe_strncasecmp(&string[i],"&amp;",5)) {
					output[o++] = '&';
					i += 5;
				} else if (!safe_strncasecmp(&string[i],"&gt;",4)) {
					output[o++] = '>';
					i += 4;
				} else if (!safe_strncasecmp(&string[i],"&lt;",4)) {
					output[o++] = '<';
					i += 4;
				} else if (!safe_strncasecmp(&string[i],"&nbsp;",6)) {
					output[o++] = ' ';
					i += 6;
				} else if (!safe_strncasecmp(&string[i],"&quot;",6)) {
					output[o++] = '"';
					i += 6;
				} else
					output[o++] = string[i++];
				break;
			case '<':
				if (!safe_strncasecmp(&string[i],"<b>",3)) {
					output[o++] = '\002';
					i += 3;
					inbold = 1; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"</b>",4)) {
					output[o++] = '\002';
					i += 4;
					inbold = 0; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"<i>",3)) {
					output[o++] = '\026';
					i += 3;
					initalics = 1; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"</i>",4)) {
					output[o++] = '\026';
					i += 4;
					initalics = 0; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"<u>",3)) {
					output[o++] = '\037';
					i += 3;
					inunderline = 1; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"</u>",4)) {
					output[o++] = '\037';
					i += 4;
					inunderline = 0; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"<br>",4)) {
					output[o++] = '\020';
					output[o++] = 'r';
					output[o++] = '\020';
					output[o++] = 'n';
					i += 4; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"<a href=",8)) {
					if( string[i + 8] == '"' || string[i + 8] == '\'' ) i += 9;
					else i += 8;
					output[o++] = '\037';
					while( i < l && string[i] != '"' && string[i] != '\'' )
						output[o++] = string[i++];
					while( i < l && safe_strncasecmp(&string[i],"</a>",4) ) i++;
					output[o++] = '\037';
					i += 4; tagmatch = 1;
				} else if (!safe_strncasecmp(&string[i],"<font",5)) {
					unsigned int fgcolor[3] = { 0x00, 0x00, 0x00 }, bgcolor[3] = { 0xff, 0xff, 0xff };
					char fgfound = 0, bgfound = 0;
					int oi = i, ti = l;

					oi = i;
					while( i < l && safe_strncasecmp(&string[i],">",1) ) i++;
					ti = i + 1;

					i = oi;
					while( i < ti && safe_strncasecmp(&string[i],"color=",6) ) i++;
					if( string[i + 6] == '"' || string[i + 6] == '\'' ) i += 7;
					else i += 6;
					if( string[i] == '#' ) i += 1;
					fgfound = sscanf( &string[i], "%2x%2x%2x", &fgcolor[0], &fgcolor[1], &fgcolor[2] );
					fgfound = ( fgfound == 3 ? 1 : 0 );

					i = oi;
					while( i < ti && safe_strncasecmp(&string[i],"background-color:",17) ) i++;
					if( string[i + 17] == ' ' ) i += 18;
					else i += 17;
					if( string[i] == '#' ) i += 1;
					bgfound = sscanf( &string[i], "%2x%2x%2x", &bgcolor[0], &bgcolor[1], &bgcolor[2] );
					bgfound = ( bgfound == 3 ? 1 : 0 );
					if( bgfound ) fgfound = 1;

					i = ti;

					if( fgfound ) {
						incolor++;
						o += sprintf( &output[o], "\003%02d", irc_rgb_to_irc( fgcolor[0], fgcolor[1], fgcolor[2] ) );
						if( bgfound ) {
							o += sprintf( &output[o], ",%02d", irc_rgb_to_irc( bgcolor[0], bgcolor[1], bgcolor[2] ) );
						}
					}
					incolor = 1; tagmatch = 1;
				} else if (!strncasecmp(&string[i],"</font>",7)) {
					if( incolor ) output[o++] = '\003';
					i += 7;
					incolor--;
					if (incolor < 0) incolor = 0;
					tagmatch = 1;
				} else output[o++] = string[i++];

				if( tagmatch && ! inbold && ! initalics && ! inunderline && ! incolor )
					output[o++] = '\017';

				tagmatch = 0;
				break;
			case '\r':
				output[o++] = '\020';
				output[o++] = 'r';
				break;
			case '\n':
				output[o++] = '\020';
				output[o++] = 'n';
				break;
			case '\020':
				output[o++] = '\020';
				output[o++] = '\020';
				break;
			default:
				output[o++] = string[i++];
				break;
		}
	}
	output[o] = '\0';
	return output;
}

char *irc_irc_to_html(const char * const string) {
	static char *output = NULL;
	int o = 0;
	size_t l = 0, ll = 0, i = 0;
	int wasbold = 0, wasitalics = 0, wasunderline = 0, wascolor = 0;
	int inbold = 0, initalics = 0, inunderline = 0, incolor = 0;
	int fgcolor = -1, bgcolor = -1;
	int iso2022esc = 0;
	int reset = 0;
	l = safe_strlen(string);
	ll = (l * 20);
	output = safe_realloc(output,(l * 40) + 1);
	while (i < l && o < ll) {
		if (wasunderline == 1) {
			memcpy(&output[o],"</u>",4);
			o += 4;
			wasunderline = 0;
		}
		if (wasitalics == 1) {
			memcpy(&output[o],"</i>",4);
			o += 4;
			wasitalics = 0;
		}
		if (wasbold == 1) {
			memcpy(&output[o],"</b>",4);
			o += 4;
			wasbold = 0;
		}
		if (wascolor == 1) {
			memcpy(&output[o],"</font>",7);
			o += 7;
			wascolor = 0;
		}

		switch(string[i]) {
			case '\033':
				if( string[i+1] == '$' && ( string[i+2] == 'B' || string[i+2] == '@' ) ) iso2022esc = 1;
				else if( string[i+1] == '(' && ( string[i+2] == 'B' || string[i+2] == 'J' ) ) iso2022esc = 0;
				goto echo;
			case '\017':
				if (!wasunderline) wasunderline = inunderline;
				inunderline = 0;
				if (!wasitalics) wasitalics = initalics;
				initalics = 0;
				if (!wasbold) wasbold = inbold;
				inbold = 0;
				if (!wascolor) wascolor = incolor;
				fgcolor = -1;
				bgcolor = -1;
				incolor = 0;
				reset = 1;
				break;
			case '\002':
				wasbold = inbold;
				inbold = ! inbold;
				reset = 1;
				break;
			case '\003':
				wascolor = incolor;
				if( isdigit( string[i + 1] ) ) {
					if( isdigit( string[i + 2] ) ) {
						fgcolor = ( string[i + 1] - '0' ) * 10;
						fgcolor += ( string[i + 2] - '0' );
						if( string[i + 3] == ',' ) {
							if( isdigit( string[i + 4] ) ) {
								if( isdigit( string[i + 5] ) ) {
									bgcolor = ( string[i + 4] - '0' ) * 10;
									bgcolor += ( string[i + 5] - '0' );
									i += 1;
								} else bgcolor = ( string[i + 4] - '0' );
								i += 1;
							}
							i += 1;
						}
						i += 1;
					} else if( string[i + 2] == ',' ) {
						fgcolor = ( string[i + 1] - '0' );
						if( isdigit( string[i + 3] ) ) {
							if( isdigit( string[i + 4] ) ) {
								bgcolor = ( string[i + 3] - '0' ) * 10;
								bgcolor += ( string[i + 4] - '0' );
								i += 1;
							} else bgcolor = ( string[i + 3] - '0' );
							i += 1;
						}
						i += 1;
					} else fgcolor = ( string[i + 1] - '0' );
					i += 1;

					if( fgcolor != -1 ) {
						fgcolor %= 16;
						incolor = 1;
					}
					if( bgcolor == 99 ) bgcolor = -1;
					if( bgcolor != -1 ) {
						bgcolor %= 16;
						incolor = 1;
					}
				} else {
					fgcolor = -1;
					bgcolor = -1;
					incolor = 0;
				}
				reset = 1;
				break;
			case '\026':
				wasitalics = initalics;
				initalics = ! initalics;
				reset = 1;
				break;
			case '\037':
				wasunderline = inunderline;
				inunderline = ! inunderline;
				reset = 1;
				break;
			case '&':
				if( ! iso2022esc ) {
					memcpy(&output[o],"&amp;",5);
					o += 5;
				} else goto echo;
				break;
			case '<':
				if( ! iso2022esc ) {
					memcpy(&output[o],"&lt;",4);
					o += 4;
				} else output[o++] = string[i];
				break;
			case '>':
				if( ! iso2022esc ) {
					memcpy(&output[o],"&gt;",4);
					o += 4;
				} else goto echo;
				break;
			case '\020':
				switch(string[++i]) {
					case '\020':
						output[o++] = '\020';
						break;
					case 'r':
						if (string[i+1] == '\020' && string[i+2] == 'n') {
							i += 2;
							memcpy(&output[o],"<br>",4);
							o += 4;
						} else
							output[o++] = '\r';
						break;
					case 'n':
						output[o++] = '\n';
						break;
					default:
						goto echo;
				}
				break;
			default: echo:
				if (reset) {
					if (incolor == 1) {
						o += sprintf( &output[o], "<font color=\"#%02x%02x%02x\"", ircrgb[fgcolor][0], ircrgb[fgcolor][1], ircrgb[fgcolor][2] );
						if( bgcolor != -1 ) {
							o += sprintf( &output[o], " style=\"background-color: #%02x%02x%02x\"", ircrgb[bgcolor][0], ircrgb[bgcolor][1], ircrgb[bgcolor][2] );
						}
						memcpy(&output[o],">",1);
						o += 1;
					}
					if (inbold == 1) {
						memcpy(&output[o],"<b>",3);
						o += 3;
					}
					if (initalics == 1) {
						memcpy(&output[o],"<i>",3);
						o += 3;
					}
					if (inunderline == 1) {
						memcpy(&output[o],"<u>",3);
						o += 3;
					}
					reset = 0;
				}
				output[o++] = string[i];
				break;
		}
		i++;
	}

	if (inunderline == 1) {
		memcpy(&output[o],"</u>",4);
		o += 4;
		inunderline = 0;
	}
	if (initalics == 1) {
		memcpy(&output[o],"</i>",4);
		o += 4;
		initalics = 0;
	}
	if (inbold == 1) {
		memcpy(&output[o],"</b>",4);
		o += 4;
		inbold = 0;
	}
	if (incolor == 1) {
		memcpy(&output[o],"</font>",7);
		o += 7;
	}

	output[o] = '\0';
	return output;
}

static int irc_internal_disconnect(client_t c, const int error) {
	struct s_irc_whois *whois_iter,*whois_iter2;
	
	if (c->nickname) {
		free(c->nickname);
		c->nickname = NULL;
	}
	if (c->password) {
		free(c->password);
		c->password = NULL;
	}
	whois_iter = c->whois_head;
	while (whois_iter) {
		whois_iter2 = whois_iter->next;
		if (whois_iter->nickname != NULL)
			free(whois_iter->nickname);
		if (whois_iter->info != NULL)
			free(whois_iter->info);
		free(whois_iter);
		whois_iter = whois_iter2;
	}
	c->whois_head = NULL;
	c->lasttime = 0;
	c->isons = 0;
	c->passchange = 0;
	c->usesilence = 1;
	c->identified = 0;
	firetalk_callback_disconnect(c,error);
	return FE_SUCCESS;
}

static int irc_send_printf(client_t c, int urgent, const char * const format, ...) {
	va_list ap;
	size_t len,i,datai = 0;
	char data[513];
	char *tempchr;
	struct s_firetalk_handle *fchandle;

	va_start(ap,format);

	len = safe_strlen(format);
	for (i = 0; i < len; i++) {
		if (format[i] == '%') {
			switch (format[++i]) {
				case 's':
					tempchr = va_arg(ap, char *);
					if(!tempchr) tempchr = "";
					if (datai + safe_strlen(tempchr) > 509)
						return FE_PACKETSIZE;
					safe_strncpy(&data[datai],tempchr,513-datai);
					datai += safe_strlen(tempchr);
					break;
				case '%':
					data[datai++] = '%';
					break;
			}
		} else {
			data[datai++] = format[i];
			if (datai > 509)
				return FE_PACKETSIZE;
		}
	}
	data[datai] = '\0';

	safe_strncat(data,"\r\n",513);
	datai = safe_strlen(data);

	fchandle = firetalk_find_handle(c);
	firetalk_internal_send_data(fchandle,data,datai,urgent);
	return FE_SUCCESS;
}

static char **irc_recv_parse(client_t c, unsigned char *buffer, unsigned short *bufferpos) {
	static char *args[256];
	static char data[513];
	size_t curarg;
	char *tempchr;
	char *tempchr2;

	args[0] = NULL;

	memcpy(data,buffer,*bufferpos);
	data[*bufferpos] = '\0';

	tempchr = strstr(data,"\r\n");
	if (tempchr == NULL)
		return NULL;
	tempchr[0] = '\0';
	*bufferpos -= (tempchr - data + 2);
	memmove(buffer,&buffer[tempchr - data + 2],*bufferpos);

	curarg = 0;
	tempchr = data;
	if (tempchr[0] == ':')
		tempchr++;

	while ((curarg < 256) && ((tempchr2 = strchr(tempchr,' ')) != NULL)) {
		args[curarg++] = tempchr;
		tempchr2[0] = '\0';
		tempchr = tempchr2 + 1;
		if (tempchr[0] == ':') {
			tempchr = &tempchr[1];
			break;
		}
	}
	args[curarg++] = tempchr;
	args[curarg] = NULL;
	return args;
}

enum firetalk_error irc_flush_modes(client_t c) {
	int i,j,sign;
	int linecount;
	int index[MODES_PER_LINE];
	char outstring[512]; /* go over this and someone is insane */
	char tempstring[2];

	tempstring[1] = '\0';
	i = c->modecount;
	while (i != 0) {
		linecount = 0;
		for (j = 0; j < MODES_PER_LINE; j++) {
			if (j == 0)
				index[j] = 0;
			else
				index[j] = index[j-1] + 1;
			for (; index[j] < c->modecount; index[j]++)
				if (c->modestack[index[j]].sign != 0)
					if (j == 0 || irc_compare_nicks(c->modestack[index[0]].room,c->modestack[index[j]].room) == FE_SUCCESS) {
						linecount++;
						break;
					}
		}
		safe_strncpy(outstring,"MODE ",512);
		safe_strncat(outstring,c->modestack[index[0]].room,512);
		safe_strncat(outstring," ",512);
		sign = 0;
		for (j = 0; j < linecount; j++) {
			if (c->modestack[index[j]].sign != sign) {
				sign = c->modestack[index[j]].sign;
				if (sign == 1)
					safe_strncat(outstring,"+",512);
				else
					safe_strncat(outstring,"-",512);
			}
			tempstring[0] = c->modestack[index[j]].mode;
			safe_strncat(outstring,tempstring,512);
		}
		for (j = 0; j < linecount; j++) {
			safe_strncat(outstring," ",512);
			safe_strncat(outstring,c->modestack[index[j]].nickname,512);
			free(c->modestack[index[j]].nickname);
			free(c->modestack[index[j]].room);
			c->modestack[index[j]].sign = 0;
			i--;
		}
		j = irc_send_printf(c,0,"%s",outstring);
		if (j != FE_SUCCESS) /* TODO: Fix this */
			return j;
	}
	c->modecount = 0;
	return FE_SUCCESS;
}

static char *irc_get_nickname(const char * const hostmask) {
	static char data[512];
	char *tempchr;
	safe_strncpy(data,hostmask,512);
	tempchr = strchr(data,'!');
	if (tempchr)
		tempchr[0] = '\0';
	return data;
}

enum firetalk_error irc_set_nickname(client_t c, const char * const nickname) {
	return irc_send_printf(c,1,"NICK %s",nickname);
}

enum firetalk_error irc_set_password(client_t c, const char * const oldpass, const char * const newpass) {
	if( c->identified && newpass ) {
		c->passchange++;
		return irc_send_printf(c,1,"PRIVMSG NickServ :SET PASSWORD %s",newpass);
	} else if( newpass ) {
		if( c->password ) free( c->password );
		c->password = safe_strdup( newpass );
		if( c->nickname ) {
			return irc_send_printf(c,1,"PRIVMSG NickServ :IDENTIFY %s",c->password);
		} else return FE_SUCCESS;
	}
	return FE_BADUSERPASS;
}

void irc_destroy_handle(client_t c) {
	irc_send_printf(c,1,"QUIT :Handle destroyed");
	irc_internal_disconnect(c,FE_USERDISCONNECT);
	free(c);
}

enum firetalk_error irc_disconnect(client_t c) {
	irc_send_printf(c,1,"QUIT :User disconnected");
	return irc_internal_disconnect(c,FE_USERDISCONNECT);
}

client_t irc_create_handle() {
	client_t c;
	c = safe_malloc(sizeof(struct s_irc_connection));

	c->lasttime = 0;
	c->isons = 0;
	c->whois_head = NULL;
	c->nickname = NULL;
	c->password = NULL;
	c->passchange = 0;
	c->usesilence = 1;
	c->identified = 0;
	c->modecount = 0;

	return c;
}

enum firetalk_error irc_signon(client_t c, const char * const nickname) {
	if ( safe_strlen( c->password ) ) if (irc_send_printf(c,1,"PASS %s",c->password) != FE_SUCCESS)
		return FE_PACKET;

	if (irc_send_printf(c,1,"NICK %s",nickname) != FE_SUCCESS)
		return FE_PACKET;

	if (irc_send_printf(c,1,"USER %s 0 * :%s",nickname,nickname) != FE_SUCCESS)
		return FE_PACKET;

	c->nickname = safe_strdup(nickname);

	return FE_SUCCESS;
}

enum firetalk_error irc_preselect(client_t c, fd_set *read, fd_set *write, fd_set *except, int *n) {
	if (c->modecount > 0)
		irc_flush_modes(c);
	return FE_SUCCESS;
}

enum firetalk_error irc_got_data(client_t c, unsigned char * buffer, unsigned short * bufferpos) {
	char **args = NULL;
	char *tempchr = NULL, *tempchr2 = NULL;
	struct s_firetalk_buddy *buddyiter = NULL;
	struct s_irc_whois *whoisiter, *whoisiter2 = NULL;
	struct s_firetalk_handle *fchandle = NULL;
	int tempint = 0,tempint2 = 0,tempint3 = 0;
	char tempbuf[512];

	fchandle = firetalk_find_handle(c);

	args = irc_recv_parse(c,buffer,bufferpos);
	while (args != NULL && args[0] != NULL) {
		/* zero argument items */
		if (strcmp(args[0],"PING") == 0) {
			if (args[1]) {
				if (irc_send_printf(c,1,"PONG %s",args[1]) != 0) {
					irc_internal_disconnect(c,FE_PACKET);
					return FE_PACKET;
				}
			} else {
				if (irc_send_printf(c,1,"PONG") != 0) {
					irc_internal_disconnect(c,FE_PACKET);
					return FE_PACKET;
				}
			}
		}
		if (args[1] != NULL) {
			tempint = atoi(args[1]);
			if (strcmp(args[1],"QUIT") == 0) {
				firetalk_callback_im_buddyonline(c,irc_get_nickname(args[0]),0);
				if (irc_compare_nicks(c->nickname,irc_get_nickname(args[0])) == 0)
					irc_internal_disconnect(c,FE_DISCONNECT);
				else
					firetalk_callback_chat_user_quit(c,irc_get_nickname(args[0]),args[2]);
			}
		}
		if ((args[1] != NULL) && (args[2] != NULL)) {
			/* two-arg commands */
			if (strcmp(args[1],"JOIN") == 0) {
				firetalk_callback_im_buddyonline(c,irc_get_nickname(args[0]),1);
				if (irc_compare_nicks(c->nickname,irc_get_nickname(args[0])) == 0) {
					firetalk_callback_chat_joined(c,args[2]);
/*					if (c->identified == 1) {
						if (irc_send_printf(c,0,"PRIVMSG ChanServ :OP %s %s",args[2],c->nickname) != FE_SUCCESS) {
							irc_internal_disconnect(c,FE_PACKET);
							return FE_PACKET;
						}
					}*/
				} else {
					firetalk_callback_chat_user_joined(c,args[2],irc_get_nickname(args[0]),0);
				}
			} else if (strcmp(args[1],"PART") == 0) {
				if (irc_compare_nicks(c->nickname,irc_get_nickname(args[0])) == 0)
					firetalk_callback_chat_left(c,args[2]);
				else
					firetalk_callback_chat_user_left(c,args[2],irc_get_nickname(args[0]),irc_irc_to_html(args[3]));
			} else if (strcmp(args[1],"NICK") == 0) {
				if (irc_compare_nicks(c->nickname,irc_get_nickname(args[0])) == 0) {
					free(c->nickname);
					c->nickname = safe_strdup(args[2]);
					c->identified = 0;
					firetalk_callback_newnick(c,c->nickname);
				}
				firetalk_callback_user_nickchanged(c,irc_get_nickname(args[0]),args[2]);
			}
		}
		if ((args[1] != NULL) && (args[2] != NULL) && (args[3] != NULL)) {
			if (strcmp(args[1],"PRIVMSG") == 0) {
				/* scan for CTCP's */
				while ((tempchr = strchr(args[3],'\001')) && (tempchr2 = strchr(&tempchr[1],'\001'))) {
					tempchr2[0] = '\0';
					/* we have a ctcp */
					if (strchr(ROOMSTARTS,args[2][0])) {
						/* chat room subcode */
						if (safe_strncasecmp(&tempchr[1],"ACTION ",7) == 0)
							firetalk_callback_chat_getaction(c,args[2],irc_get_nickname(args[0]),0,irc_irc_to_html(&tempchr[8]));
					} else {
						char *endcommand;
						endcommand = strchr(&tempchr[1],' ');
						if (endcommand) {
							*endcommand = '\0';
							endcommand++;
							firetalk_callback_subcode_request(c,irc_get_nickname(args[0]),&tempchr[1],endcommand);
						} else
							firetalk_callback_subcode_request(c,irc_get_nickname(args[0]),&tempchr[1],NULL);
					}
					memmove(tempchr,&tempchr2[1],safe_strlen(&tempchr2[1]) + 1);
				}
				if (args[3][0] != '\0') {
					if (strchr(ROOMSTARTS,args[2][0]))
						firetalk_callback_chat_getmessage(c,args[2],irc_get_nickname(args[0]),0,irc_irc_to_html(args[3]));
					else
						firetalk_callback_im_getmessage(c,irc_get_nickname(args[0]),0,irc_irc_to_html(args[3]));
				}
			} else if (strcmp(args[1],"NOTICE") == 0) {
				/* scan for CTCP's */
				while ((tempchr = strchr(args[3],'\001')) && (tempchr2 = strchr(&tempchr[1],'\001'))) {
					tempchr2[0] = '\0';
					/* we have a ctcp */
					if (strchr(ROOMSTARTS,args[2][0]) == NULL) {
						char *endcommand;
						endcommand = strchr(&tempchr[1],' ');
						if (endcommand) {
							*endcommand = '\0';
							endcommand++;
							firetalk_callback_subcode_reply(c,irc_get_nickname(args[0]),&tempchr[1],endcommand);
						} else
							firetalk_callback_subcode_reply(c,irc_get_nickname(args[0]),&tempchr[1],NULL);
					}
					memmove(tempchr,&tempchr2[1],safe_strlen(&tempchr2[1]) + 1);
				}
				if (!strcasecmp(irc_get_nickname(args[0]),"NickServ")) {
					if ((strstr(args[3],"IDENTIFY") != NULL) && (strstr(args[3],"/msg") != NULL) && (strstr(args[3],"HELP") == NULL)) {
						c->identified = 0;
						/* nickserv seems to be asking us to identify ourselves, and we have a password */
						if (!c->password) {
							c->password = safe_malloc(128);
							firetalk_callback_needpass(c,c->password,128);
						}
						if ((c->password != NULL) && irc_send_printf(c,1,"PRIVMSG NickServ :IDENTIFY %s",c->password) != 0) {
							irc_internal_disconnect(c,FE_PACKET);
							return FE_PACKET;
						}
					}
					if ((strstr(args[3],"Password changed") != NULL) && (c->passchange != 0)) {
						/* successful change */
						c->passchange--;
						firetalk_callback_passchanged(c);
					}
					if ((strstr(args[3],"authentication required") != NULL) && (c->passchange != 0)) {
						/* didn't log in with the right password initially, not happening */
						c->identified = 0;
						c->passchange--;
						firetalk_callback_error(c,FE_NOCHANGEPASS,NULL,args[3]);
					}
					if ((strstr(args[3],"isn't registered") != NULL) && (c->passchange != 0)) {
						/* nick not registered, fail */
						c->passchange--;
						firetalk_callback_error(c,FE_NOCHANGEPASS,NULL,args[3]);
					}
					if (strstr(args[3],"Password accepted") != NULL) {
						/* we're recognized */
						c->identified = 1;
/*						if (irc_send_printf(c,0,"PRIVMSG ChanServ :OP ALL") != FE_SUCCESS) {
							irc_internal_disconnect(c,FE_PACKET);
							return FE_PACKET;
						}*/
					}
				}
				if (args[3][0] != '\0') {
					if (strchr(ROOMSTARTS,args[2][0]))
						firetalk_callback_chat_getmessage(c,args[2],irc_get_nickname(args[0]),1,irc_irc_to_html(args[3]));
					else
						firetalk_callback_im_getmessage(c,irc_get_nickname(args[0]),1,irc_irc_to_html(args[3]));
				}
			} else if (strcmp(args[1],"TOPIC") == 0) {
				firetalk_callback_chat_gottopic(c,args[2],irc_irc_to_html(args[3]),irc_get_nickname(args[0]));
			} else if (strcmp(args[1],"KICK") == 0) {
				if (irc_compare_nicks(c->nickname,irc_get_nickname(args[3])) == 0)
					firetalk_callback_chat_kicked(c,args[2],irc_get_nickname(args[0]),irc_irc_to_html(args[4]));
				else {
					tempchr = safe_strdup(irc_get_nickname(args[0]));
					firetalk_callback_chat_user_kicked(c,args[2],irc_get_nickname(args[3]),tempchr,irc_irc_to_html(args[4]));
					free(tempchr);
				}
			} else {
				switch (tempint) {
					case 301: /* RPL_AWAY */
						buddyiter = fchandle->buddy_head;
						while (buddyiter) {
							if (irc_compare_nicks(args[3],buddyiter->nickname) == 0) {
								buddyiter->tempint2 = 1;
								firetalk_callback_im_buddyaway(c,args[3],1);
								break;
							}
							buddyiter = buddyiter->next;
						}
						break;
					case 303: /* RPL_ISON */
						tempchr = args[3];
						while ((tempchr != NULL) && (tempchr[0] != '\0')) {
							tempchr2 = strchr(tempchr,' ');
							if (tempchr2)
								tempchr2[0] = '\0';
							buddyiter = fchandle->buddy_head;
							while (buddyiter) {
								if (irc_compare_nicks(tempchr,buddyiter->nickname) == 0) {
									buddyiter->tempint = 1;
									break;
								}
								buddyiter = buddyiter->next;
							}
							if (tempchr2)
								tempchr = tempchr2 + 1;
							else
								tempchr = NULL;
						}
						if (--c->isons <= 0) {
							c->isons = 0;
							/* done, send the appropriate data */
							buddyiter = fchandle->buddy_head;
							while (buddyiter) {
								firetalk_callback_im_buddyonline(c,buddyiter->nickname,buddyiter->tempint);
								if (buddyiter->tempint != 0) {
									buddyiter->tempint2 = 0; /* away */
									if (irc_send_printf(c,0,"WHOIS %s",buddyiter->nickname) != 0) {
										irc_internal_disconnect(c,FE_PACKET);
										return FE_PACKET;
									}
								}
								buddyiter = buddyiter->next;
							}
						}
						break;
					case 313: /* RPL_WHOISOPER */
						whoisiter = c->whois_head;
						while (whoisiter) {
							if (irc_compare_nicks(args[3],whoisiter->nickname) == 0) {
								whoisiter->flags |= FF_ADMIN;
								break;
							}
							whoisiter = whoisiter->next;
						}
						break;
					case 318: /* RPL_ENDOFWHOIS */
						whoisiter = c->whois_head;
						whoisiter2 = NULL;
						while (whoisiter) {
							if (irc_compare_nicks(args[3],whoisiter->nickname) == 0) {
								/* manual whois */
								firetalk_callback_gotinfo(c,whoisiter->nickname,irc_irc_to_html(whoisiter->info),0,whoisiter->idle,whoisiter->flags);
								free(whoisiter->nickname);
								if (whoisiter->info)
									free(whoisiter->info);
								if (whoisiter2)
									whoisiter2->next = whoisiter->next;
								else
									c->whois_head = whoisiter->next;
								free(whoisiter);
								break;
							}
							whoisiter2 = whoisiter;
							whoisiter = whoisiter->next;
						}
						buddyiter = fchandle->buddy_head;
						while (buddyiter) {
							if (irc_compare_nicks(args[3],buddyiter->nickname) == 0) {
								if (buddyiter->tempint2 == 0)
									firetalk_callback_im_buddyaway(c,buddyiter->nickname,0);
								break;
							}
							buddyiter = buddyiter->next;
						}
						break;
					case 401: /* ERR_NOSUCHNICK */
					case 441: /* ERR_USERNOTINCHANNEL */
					case 443: /* ERR_USERONCHANNEL */
						firetalk_callback_im_buddyonline(c,args[3],0);
						firetalk_callback_error(c,FE_BADUSER,args[3],args[4]);
						if (!strcasecmp(args[3],"NickServ") && c->passchange)
							c->passchange--;
						whoisiter = c->whois_head;
						whoisiter2 = NULL;
						while (whoisiter) {
							if (irc_compare_nicks(args[3],whoisiter->nickname) == 0) {
								free(whoisiter->nickname);
								if (whoisiter->info)
									free(whoisiter->info);
								if (whoisiter2)
									whoisiter2->next = whoisiter->next;
								else
									c->whois_head = whoisiter->next;
								free(whoisiter);
								break;
							}
							whoisiter2 = whoisiter;
							whoisiter = whoisiter->next;
						}
						break;
					case 403: /* ERR_NOSUCHCHANNEL */
					case 442: /* ERR_NOTONCHANNEL */
						firetalk_callback_error(c,FE_BADROOM,&args[3][1],args[4]);
						break;
					case 404: /* ERR_CANNOTSENDTOCHAN */
					case 405: /* ERR_TOOMANYCHANNELS */
					case 471: /* ERR_CHANNELISFULL */
					case 473: /* ERR_INVITEONLYCHAN */
					case 474: /* ERR_BANNEDFROMCHAN */
					case 475: /* ERR_BADCHANNELKEY */
						firetalk_callback_error(c,FE_ROOMUNAVAILABLE,&args[3][1],args[4]);
						break;
					case 412: /* ERR_NOTEXTTOSEND */
						firetalk_callback_error(c,FE_BADMESSAGE,NULL,args[4]);
						break;
					case 421: /* ERR_UNKNOWNCOMMAND */
						if (strcmp(args[3],"SILENCE") == 0)
							c->usesilence = 0;
						break;
					case 433: /* ERR_NICKNAMEINUSE */
						firetalk_callback_error(c,FE_BADUSER,NULL,"Nickname in use.");
						break;
					case 466: /* ERR_YOUWILLBEBANNED */
						break;
					case 482: /* ERR_CHANOPRIVSNEEDED */
						firetalk_callback_error(c,FE_NOPERMS,&args[3][1],"You need to be a channel operator.");
						break;
				}
			}
		}
		if ((args[1] != NULL) && (args[2] != NULL) && (args[3] != NULL) && (args[4] != NULL)) {
			if (strcmp(args[1],"MODE") == 0) {
				tempint = 0;
				tempint2 = 4;
				tempint3 = 0;
				while ((args[tempint2] != NULL) && (args[3][tempint] != '\0')) {
					switch (args[3][tempint++]) {
						case '+':
							tempint3 = 1;
							break;
						case '-':
							tempint3 = -1;
							break;
						case 'o':
							if (tempint3 == 1) {
								firetalk_callback_chat_user_opped(c,args[2],args[tempint2++],irc_get_nickname(args[0]));
								if (irc_compare_nicks(args[tempint2-1],c->nickname) == FE_SUCCESS)
									firetalk_callback_chat_opped(c,args[2],irc_get_nickname(args[0]));
							} else if (tempint3 == -1) {
								firetalk_callback_chat_user_deopped(c,args[2],args[tempint2++],irc_get_nickname(args[0]));
								if (irc_compare_nicks(args[tempint2-1],c->nickname) == FE_SUCCESS) {
									firetalk_callback_chat_deopped(c,args[2],irc_get_nickname(args[0]));
/*									if (c->identified == 1) {
										// this is us, and we're identified, so we can request a reop
										if (irc_send_printf(c,0,"PRIVMSG ChanServ :OP %s %s",args[2],c->nickname) != FE_SUCCESS) {
											irc_internal_disconnect(c,FE_PACKET);
											return FE_PACKET;
										}
									}*/
								}
							}
							break;
						case 'v':
							if (tempint3 == 1) {
								firetalk_callback_chat_user_voiced(c,args[2],args[tempint2++],irc_get_nickname(args[0]));
								if (irc_compare_nicks(args[tempint2-1],c->nickname) == FE_SUCCESS)
									firetalk_callback_chat_voiced(c,args[2],irc_get_nickname(args[0]));
							} else if (tempint3 == -1) {
								firetalk_callback_chat_user_devoiced(c,args[2],args[tempint2++],irc_get_nickname(args[0]));
								if (irc_compare_nicks(args[tempint2-1],c->nickname) == FE_SUCCESS) {
									firetalk_callback_chat_devoiced(c,args[2],irc_get_nickname(args[0]));
/*									if (c->identified == 1) {
										// this is us, and we're identified, so we can request a revoice
										if (irc_send_printf(c,0,"PRIVMSG ChanServ :VOICE %s %s",args[2],c->nickname) != FE_SUCCESS) {
											irc_internal_disconnect(c,FE_PACKET);
											return FE_PACKET;
										}
									}*/
								}
							}
							break;
						default:
							tempint2++;
							break;
					}
				}
			} else {
				switch (tempint) {
					case 317: /* RPL_WHOISIDLE */
						whoisiter = c->whois_head;
						while (whoisiter) {
							if (irc_compare_nicks(args[3],whoisiter->nickname) == 0) {
								whoisiter->idle = atol(args[4])/60;
								break;
							}
							whoisiter = whoisiter->next;
						}
						buddyiter = fchandle->buddy_head;
						while (buddyiter) {
							if (irc_compare_nicks(args[3],buddyiter->nickname) == 0) {
								firetalk_callback_idleinfo(c,args[3],atol(args[4]) / 60);
								break;
							}
							buddyiter = buddyiter->next;
						}
						break;
					case 331: /* RPL_NOTOPIC */
						firetalk_callback_chat_gottopic(c,args[3],NULL,NULL);
						break;
					case 332: /* RPL_TOPIC */
						firetalk_callback_chat_gottopic(c,args[3],irc_irc_to_html(args[4]),NULL);
						break;
				}
			}
		}
		if ((args[1] != NULL) && (args[2] != NULL) && (args[3] != NULL) && (args[4] != NULL) && (args[5] != NULL)) {
			tempint = atoi(args[1]);
			switch (tempint) {
				case 322: /* RPL_LIST */
					firetalk_callback_gotroomlist(c,args[3],atoi(args[4]),irc_irc_to_html(args[5]));
					break;
				case 353: /* RPL_NAMREPLY */
					tempchr2 = args[5];
					while (1) {
						if ((tempchr = strchr(tempchr2,' ')) != NULL)
							tempchr[0] = '\0';
						if (tempchr2[0] == '\0')
							break;
						if (tempchr2[0] == '@' || tempchr2[0] == '+') {
							firetalk_callback_chat_user_joined(c,args[4],&tempchr2[1],1);
							firetalk_callback_im_buddyonline(c,&tempchr2[1],1);
							if (tempchr2[0] == '@') {
								firetalk_callback_chat_user_opped(c,args[4],&tempchr2[1],NULL);
								if (irc_compare_nicks(&tempchr2[1],c->nickname) == FE_SUCCESS)
									firetalk_callback_chat_opped(c,args[4],NULL);
							} else if (tempchr2[0] == '+') {
								firetalk_callback_chat_user_voiced(c,args[4],&tempchr2[1],NULL);
								if (irc_compare_nicks(&tempchr2[1],c->nickname) == FE_SUCCESS)
									firetalk_callback_chat_voiced(c,args[4],NULL);
							}
						} else {
							firetalk_callback_chat_user_joined(c,args[4],tempchr2,1);
							firetalk_callback_im_buddyonline(c,tempchr2,1);
						}
						if (tempchr == NULL)
							break;
						tempchr2 = tempchr + 1;
					}
					break;
			}
		}
		if ((args[1] != NULL) && (args[2] != NULL) && (args[3] != NULL) && (args[4] != NULL) && (args[5] != NULL) && (args[6] != NULL) && (args[7] != NULL)) {
			switch (tempint) {
				case 311: /* RPL_WHOISUSER */
					whoisiter = c->whois_head;
					while (whoisiter) {
						if (irc_compare_nicks(args[3],whoisiter->nickname) == 0) {
							if (whoisiter->info)
								free(whoisiter->info);
							safe_snprintf(tempbuf,512,"%s@%s: %s",args[4],args[5],args[7]);
							whoisiter->info = safe_strdup(tempbuf);
							break;
						}
						whoisiter = whoisiter->next;
					}
				break;
			}
		}
		
		args = irc_recv_parse(c,buffer,bufferpos);
	}
	return FE_SUCCESS;
}

enum firetalk_error irc_got_data_connecting(client_t c, unsigned char * buffer, unsigned short * bufferpos) {
	char **args = NULL;

	args = irc_recv_parse(c,buffer,bufferpos);
	while (args) {
		if (args[0] == NULL) {
			firetalk_callback_connectfailed(c,FE_PACKET,args[0]);
			return FE_PACKET;
		}
		/* zero argument items */
		if (strcmp(args[0],"ERROR") == 0) {
			irc_send_printf(c,1,"QUIT :Error");
			firetalk_callback_connectfailed(c,FE_PACKET,"Server returned ERROR");
			return FE_PACKET;
		}

		if (!args[1])
			continue;
		/* one argument items */
		if (strcmp(args[1],"ERROR") == 0) {
			irc_send_printf(c,1,"QUIT :Error");
			firetalk_callback_connectfailed(c,FE_PACKET,"Server returned ERROR");
			return FE_PACKET;
		}
		if (strcmp(args[0],"PING") == 0) {
			if (irc_send_printf(c,1,"PONG %s",args[1]) != 0) {
				irc_send_printf(c,1,"QUIT :Error");
				firetalk_callback_connectfailed(c,FE_PACKET,"Packet transfer error");
				return FE_PACKET;
			}
		} else {
			switch (atoi(args[1])) {
				case 001: // RPL_WELCOME
				case 376: // RPL_ENDOFMOTD
				case 422: // ERR_NOMOTD
					// reset the password to clear the server password
					if (c->password) {
						free(c->password);
						c->password = NULL;
					}
					firetalk_callback_doinit(c,c->nickname);
					firetalk_callback_connected(c);
					break;
				case 431: // ERR_NONICKNAMEGIVEN
				case 432: // ERR_ERRONEUSNICKNAME
				case 461: // ERR_NEEDMOREPARAMS
					irc_send_printf(c,1,"QUIT :Invalid nickname");
					firetalk_callback_connectfailed(c,FE_BADUSER,"Invalid nickname");
					return FE_BADUSER;
				case 433: // ERR_NICKNAMEINUSE
				case 436: // ERR_NICKCOLLISION
				case 437: // ERR_UNAVAILRESOURCE
					irc_send_printf(c,1,"QUIT :Nickname in use");
					firetalk_callback_connectfailed(c,FE_BADUSER,"Nickname in use");
					return FE_BADUSER;
				case 463: // ERR_NOPERMFORHOST
					irc_send_printf(c,1,"QUIT :Host blocked");
					firetalk_callback_connectfailed(c,FE_BLOCKED,"Your host isn't among the privileged");
					return FE_BLOCKED;
				case 464: // ERR_PASSWDMISMATCH
					irc_send_printf(c,1,"QUIT :Invalid connection password");
					firetalk_callback_connectfailed(c,FE_BADUSERPASS,"Invalid server password");
					return FE_BADUSERPASS;
				case 465: // ERR_YOUREBANNEDCREEP
					irc_send_printf(c,1,"QUIT :Banned");
					firetalk_callback_connectfailed(c,FE_BLOCKED,"You are banned");
					return FE_BLOCKED;
				case 484: // ERR_RESTRICTED
					//log we are restricted with connection
					break;
			}
		}
		args = irc_recv_parse(c,buffer,bufferpos);
	}

	return FE_SUCCESS;
}

static char irc_tolower(const char c) {
	if ((c >= 'A') && (c <= 'Z'))
		return (c - 'A') + 'a';
	if (c == '[')
		return '{';
	if (c == ']')
		return '{';
	if (c == '\\')
		return '|';
	return c;
}

enum firetalk_error irc_compare_nicks(const char * const nick1, const char * const nick2) {
	int i = 0;

	while (nick1[i] != '\0') {
		if (irc_tolower(nick1[i]) != irc_tolower(nick2[i]))
			return FE_NOMATCH;
		i++;
	}
	if (nick2[i] != '\0')
		return FE_NOMATCH;

	return FE_SUCCESS;
}

enum firetalk_error irc_chat_join(client_t c, const char * const room) {
	return irc_send_printf(c,1,"JOIN %s",room);
}

enum firetalk_error irc_chat_part(client_t c, const char * const room) {
	return irc_send_printf(c,1,"PART %s",room);
}

enum firetalk_error irc_chat_send_message(client_t c, const char * const room, const char * const message, const int auto_flag) {
	if (auto_flag == 1)
		return irc_send_printf(c,1,"NOTICE %s :%s",room,irc_html_to_irc(message));
	else
		return irc_send_printf(c,1,"PRIVMSG %s :%s",room,irc_html_to_irc(message));
}

enum firetalk_error irc_chat_send_action(client_t c, const char * const room, const char * const message, const int auto_flag) {
	if (auto_flag == 1)
		return irc_send_printf(c,1,"NOTICE %s :\001ACTION %s\001",room,irc_html_to_irc(message));
	else
		return irc_send_printf(c,1,"PRIVMSG %s :\001ACTION %s\001",room,irc_html_to_irc(message));
}

enum firetalk_error irc_chat_invite(client_t c, const char * const room, const char * const who, const char * const message) {
	return irc_send_printf(c,1,"INVITE %s %s",who,room);
}

enum firetalk_error irc_im_send_message(client_t c, const char * const dest, const char * const message, const int auto_flag) {
	if (auto_flag == 1)
		return irc_send_printf(c,1,"NOTICE %s :%s",dest,irc_html_to_irc(message));
	else
		return irc_send_printf(c,1,"PRIVMSG %s :%s",dest,irc_html_to_irc(message));
}

enum firetalk_error irc_im_send_action(client_t c, const char * const dest, const char * const message, const int auto_flag) {
	if (auto_flag == 1)
		return irc_send_printf(c,1,"NOTICE %s :\001ACTION %s\001",dest,irc_html_to_irc(message));
	else
		return irc_send_printf(c,1,"PRIVMSG %s :\001ACTION %s\001",dest,irc_html_to_irc(message));
}

enum firetalk_error irc_chat_set_topic(client_t c, const char * const room, const char * const topic) {
	return irc_send_printf(c,1,"TOPIC %s :%s",room,irc_html_to_irc(topic));
}

enum firetalk_error irc_chat_op(client_t c, const char * const room, const char * const who) {
	c->modestack[c->modecount].sign = 1;
	c->modestack[c->modecount].mode = 'o';
	c->modestack[c->modecount].nickname = safe_strdup(who);
	c->modestack[c->modecount].room = safe_strdup(room);
	if (++c->modecount >= MAXSTACK)
		return irc_flush_modes(c);
	return FE_SUCCESS;
}

enum firetalk_error irc_chat_deop(client_t c, const char * const room, const char * const who) {
	c->modestack[c->modecount].sign = -1;
	c->modestack[c->modecount].mode = 'o';
	c->modestack[c->modecount].nickname = safe_strdup(who);
	c->modestack[c->modecount].room = safe_strdup(room);
	if (++c->modecount >= MAXSTACK)
		return irc_flush_modes(c);
	return FE_SUCCESS;
}

enum firetalk_error irc_chat_voice(client_t c, const char * const room, const char * const who) {
	c->modestack[c->modecount].sign = 1;
	c->modestack[c->modecount].mode = 'v';
	c->modestack[c->modecount].nickname = safe_strdup(who);
	c->modestack[c->modecount].room = safe_strdup(room);
	if (++c->modecount >= MAXSTACK)
		return irc_flush_modes(c);
	return FE_SUCCESS;
}

enum firetalk_error irc_chat_devoice(client_t c, const char * const room, const char * const who) {
	c->modestack[c->modecount].sign = -1;
	c->modestack[c->modecount].mode = 'v';
	c->modestack[c->modecount].nickname = safe_strdup(who);
	c->modestack[c->modecount].room = safe_strdup(room);
	if (++c->modecount >= MAXSTACK)
		return irc_flush_modes(c);
	return FE_SUCCESS;
}

enum firetalk_error irc_chat_kick(client_t c, const char * const room, const char * const who, const char * const reason) {
	if (reason)
		return irc_send_printf(c,1,"KICK %s %s :%s",room,who,irc_html_to_irc(reason));
	else
		return irc_send_printf(c,1,"KICK %s %s",room,who);
}

enum firetalk_error irc_im_add_buddy(client_t c, const char * const nickname) {
	c->isons++;
	return irc_send_printf(c,1,"ISON %s",nickname);
}

enum firetalk_error irc_im_add_deny(client_t c, const char * const nickname) {
	if (c->usesilence == 1)
		return irc_send_printf(c,1,"SILENCE +%s!*@*",nickname);
	else
		return FE_SUCCESS;
}

enum firetalk_error irc_im_remove_deny(client_t c, const char * const nickname) {
	if (c->usesilence == 1)
		return irc_send_printf(c,1,"SILENCE -%s!*@*",nickname);
	else
		return FE_SUCCESS;
}

enum firetalk_error irc_get_roomlist(client_t c, const char * const search) {
	if (search)
		return irc_send_printf(c,1,"LIST %s",search);
	else
		return irc_send_printf(c,1,"LIST");
}

enum firetalk_error irc_stop_roomlist(client_t c) {
	return irc_send_printf(c,1,"LIST STOP");
}

enum firetalk_error irc_get_info(client_t c, const char * const nickname, const int priority) {
	struct s_irc_whois *whoistemp;

	whoistemp = c->whois_head;
	c->whois_head = safe_malloc(sizeof(struct s_irc_whois));
	c->whois_head->nickname = safe_strdup(nickname);
	c->whois_head->flags = FF_NORMAL;
	c->whois_head->idle = 0;
	c->whois_head->info = NULL;
	c->whois_head->next = whoistemp;
	return irc_send_printf(c,priority,"WHOIS %s",nickname);
}

enum firetalk_error irc_set_away(client_t c, const char * const message) {
	if (message)
		return irc_send_printf(c,1,"AWAY :%s",irc_html_to_irc(message));
	else
		return irc_send_printf(c,1,"AWAY");
}

enum firetalk_error irc_periodic(struct s_firetalk_handle * const c) {
	client_t conn;
	struct s_firetalk_buddy *buddyiter;
	char obuf[1024];
	size_t i;

	obuf[0] = '\0';

	conn = c->handle;

	if (conn->lasttime > (time(NULL) - 20))
		return FE_IDLEFAST;

	if (conn->isons > 0)
		return FE_IDLEFAST;

	buddyiter = c->buddy_head;
	while (buddyiter) {
		if (safe_strlen(obuf) + safe_strlen(buddyiter->nickname) > 502) {
			i = safe_strlen(obuf);
			if (i > 0)
				obuf[i-1] = '\0';
			if (irc_send_printf(conn,0,"ISON %s",obuf) != 0) {
				irc_internal_disconnect(conn,FE_PACKET);
				return FE_PACKET;
			}
			conn->isons++;
			obuf[0] = '\0';
		}
		safe_strncat(obuf,buddyiter->nickname,1024);
		safe_strncat(obuf," ",1024);
		buddyiter->tempint = 0;
		buddyiter = buddyiter->next;
	}

	i = safe_strlen(obuf);
	if (i > 0) {
		obuf[i-1] = '\0';
		if (irc_send_printf(conn,0,"ISON %s",obuf) != 0) {
			irc_internal_disconnect(conn,FE_PACKET);
			return FE_PACKET;
		}
		conn->isons++;
	}

	time(&conn->lasttime);
	return FE_SUCCESS;
}

enum firetalk_error irc_subcode_send_request(client_t c, const char * const to, const char * const command, const char * const args) {
	if (args == NULL) {
		if (irc_send_printf(c,1,"PRIVMSG %s :\001%s\001",to,command) != 0) {
			irc_internal_disconnect(c,FE_PACKET);
			return FE_PACKET;
		}
	} else {
		if (irc_send_printf(c,1,"PRIVMSG %s :\001%s %s\001",to,command,args) != 0) {
			irc_internal_disconnect(c,FE_PACKET);
			return FE_PACKET;
		}
	}
	return FE_SUCCESS;
}

enum firetalk_error irc_subcode_send_reply(client_t c, const char * const to, const char * const command, const char * const args) {
	if (args == NULL) {
		if (irc_send_printf(c,1,"NOTICE %s :\001%s\001",to,command) != 0) {
			irc_internal_disconnect(c,FE_PACKET);
			return FE_PACKET;
		}
	} else {
		if (irc_send_printf(c,1,"NOTICE %s :\001%s %s\001",to,command,args) != 0) {
			irc_internal_disconnect(c,FE_PACKET);
			return FE_PACKET;
		}
	}
	return FE_SUCCESS;
}

const char * const irc_normalize_room_name(const char * const name) {
	static char newname[2048];
	if (strchr(ROOMSTARTS,name[0]))
		return name;
	safe_strncpy(newname,"#",2048);
	safe_strncat(newname,name,2048);
	return newname;
}

enum firetalk_error irc_prepare_for_transmit(client_t c, char * const data, const int length) {
	return FE_SUCCESS;
}
