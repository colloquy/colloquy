/*
gui.c - FireTalk example code
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
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>

#include "firetalk.h"
#include "safestring.h"

#define PASSWDFILE "/home/ian/.firetalktest"

char *username1[FP_MAX];
char *password1[FP_MAX];
char *username2[FP_MAX];
char *password2[FP_MAX];
void *handle1, *handle2;


typedef void (*ptrtofnct)(firetalk_t, void *, ...);

int waitingfor = 0;
int waitingfor2 = 0;
int proto;

#define WF_DOINIT 1
#define WF_BUDDYONLINE 2
#define WF_BUDDYOFFLINE 3
#define WF_IM_GETMESSAGE 4
#define WF_IM_GETACTION 5
#define WF_IM_BUDDYAWAY 6
#define WF_IM_BUDDYUNAWAY 7
#define WF_GOTINFO 8
#define WF_SUBCODE_REPLY 9
#define WF_CHAT_JOINED 10
#define WF_CHAT_USER_JOINED 11
#define WF_CHAT_USER_LEFT 12
#define WF_CHAT_LEFT 13
#define WF_CHAT_GETMESSAGE 14
#define WF_CHAT_GETACTION 15
#define WF_CONNECTED 16

void needpass (void *c, void *cs, char *pass, int size) {
	if (c == handle1)
		safe_strncpy(pass,password1[proto],size);
	else if (c == handle2)
		safe_strncpy(pass,password2[proto],size);
}

void doinit (void *c, void *cs, char *nickname) {
	if (waitingfor == WF_DOINIT)
		waitingfor = 0;
}

void error (void *c, void *cs, const int error, const char * const roomoruser, const char * const description) {
	fprintf(stderr,"ERROR: '%s': %d (%s) (%s)\n",roomoruser,error,firetalk_strerror(error),description);
}

void connected (void *c, void *cs) {
	if (waitingfor == WF_CONNECTED)
		waitingfor = 0;
}

void connectfailed (void *c, void *cs) {
	fprintf(stderr,"\t--> ERROR: connection failed\n");
	exit(1);
}

void buddy_online () {
	if (waitingfor == WF_BUDDYONLINE)
		waitingfor = 0;
}

void buddy_offline () {
	if (waitingfor == WF_BUDDYOFFLINE)
		waitingfor = 0;
}

void im_getmessage (void *c, void *cs, char *n, int a, char *m) {
	if ((waitingfor == WF_IM_GETMESSAGE) && (strcmp(m,"firetalktest v" LIBFIRETALK_VERSION) == 0))
		waitingfor = 0;
}

void im_getaction (void *c, void *cs, char *n, int a, char *m) {
	if ((waitingfor == WF_IM_GETACTION) && (strcmp(m,"firetalktest v" LIBFIRETALK_VERSION) == 0))
		waitingfor = 0;
}

void im_buddyaway () {
	if (waitingfor == WF_IM_BUDDYAWAY)
		waitingfor = 0;
}

void im_buddyunaway () {
	if (waitingfor == WF_IM_BUDDYUNAWAY)
		waitingfor = 0;
}

void gotinfo (void *c, void *cs, char *n, char *i) {
	if ((waitingfor == WF_GOTINFO) && (strcmp(i,"firetalktest v" LIBFIRETALK_VERSION) == 0))
		waitingfor = 0;
	if ((waitingfor == WF_GOTINFO) && (proto == FP_IRC)) /* no real info support */
		waitingfor = 0;
}

void subcode_reply (void *c, void *cs, const char * const from, const char * const command, const char * const args) {
	if (waitingfor == WF_SUBCODE_REPLY)
		waitingfor = 0;
}

void chat_joined () {
	if (waitingfor == WF_CHAT_JOINED)
		waitingfor = 0;
	if (waitingfor2 == WF_CHAT_JOINED)
		waitingfor2 = 0;
}


void chat_user_joined () {
	if (waitingfor == WF_CHAT_USER_JOINED)
		waitingfor = 0;
}

void chat_getmessage (char *c, void *cs, const char * const room, const char * const from, const int autoflag, const char * const m) {
	if ((waitingfor == WF_CHAT_GETMESSAGE) && (strstr(m,"firetalktest v" LIBFIRETALK_VERSION) != NULL))
		waitingfor = 0;
}

void chat_getaction (char *c, void *cs, const char * const room, const char * const from, const int autoflag, const char * const m) {
	if ((waitingfor == WF_CHAT_GETACTION) && (strstr(m,"firetalktest v" LIBFIRETALK_VERSION) != NULL))
		waitingfor = 0;
}

void chat_user_left () {
	if (waitingfor == WF_CHAT_USER_LEFT)
		waitingfor = 0;
}

void chat_left () {
	if (waitingfor == WF_CHAT_LEFT)
		waitingfor = 0;
}

int main(int argc, char *argv[]) {
	int i,e;
	FILE *in;
	char inbuf[1024];

	in = fopen(PASSWDFILE,"r");
	if (in == NULL) {
		perror("fopen");
		exit(EXIT_FAILURE);
	}
	for (i = 0; i < FP_MAX; i++) {
		if (fgets(inbuf,1024,in) == NULL) {
			perror("fgets");
			exit(EXIT_FAILURE);
		}
		inbuf[strlen(inbuf)-1] = '\0';
		username1[i] = safe_strdup(inbuf);
		if (fgets(inbuf,1024,in) == NULL) {
			perror("fgets");
			exit(EXIT_FAILURE);
		}
		inbuf[strlen(inbuf)-1] = '\0';
		password1[i] = safe_strdup(inbuf);
		if (fgets(inbuf,1024,in) == NULL) {
			perror("fgets");
			exit(EXIT_FAILURE);
		}
		inbuf[strlen(inbuf)-1] = '\0';
		username2[i] = safe_strdup(inbuf);
		if (fgets(inbuf,1024,in) == NULL) {
			perror("fgets");
			exit(EXIT_FAILURE);
		}
		inbuf[strlen(inbuf)-1] = '\0';
		password2[i] = safe_strdup(inbuf);
	}
	fclose(in);

	fprintf(stderr,"firetalk tester for firetalk v" LIBFIRETALK_VERSION " starting...\n");
	for (i = 0; i < FP_MAX; i++) {
		time_t tt;
		proto = i;
		fprintf(stderr,"\nstarting tests for %s...\n",firetalk_strprotocol(i));


		fprintf(stderr,"\tcreating handle1...");
		handle1 = firetalk_create_handle(i,NULL);
		if (handle1 == NULL) {
			fprintf(stderr,"failed: %d (%s) <--\n",firetalkerror,firetalk_strerror(firetalkerror));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tcreating handle2...");
		handle2 = firetalk_create_handle(i,NULL);
		if (handle2 == NULL) {
			fprintf(stderr,"failed: %d (%s) <--\n",firetalkerror,firetalk_strerror(firetalkerror));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tregistering error callback for handle1...");
		e = firetalk_register_callback(handle1,FC_ERROR,(ptrtofnct) error);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tregistering error callback for handle2...");
		e = firetalk_register_callback(handle2,FC_ERROR,(ptrtofnct) error);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tregistering needpass callback for handle1...");
		e = firetalk_register_callback(handle1,FC_NEEDPASS,(ptrtofnct) needpass);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tregistering needpass callback for handle2...");
		e = firetalk_register_callback(handle2,FC_NEEDPASS,(ptrtofnct) needpass);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tregistering connected callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CONNECTED,(ptrtofnct) connected);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tregistering connected callback for handle2...");
		e = firetalk_register_callback(handle2,FC_CONNECTED,(ptrtofnct) connected);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tregistering connectfailed callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CONNECTFAILED,(ptrtofnct) connectfailed);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tregistering connectfailed callback for handle2...");
		e = firetalk_register_callback(handle2,FC_CONNECTFAILED,(ptrtofnct) connectfailed);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tregistering doinit callback for handle2...");
		e = firetalk_register_callback(handle2,FC_DOINIT,(ptrtofnct) doinit);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tsigning on user '%s' on handle1...",username1[i]);
		e = firetalk_signon(handle1,NULL,0,username1[i]);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_CONNECTED;

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> connected callback is good (%lds)\n",time(NULL) - tt);

		fprintf(stderr,"\tsleeping 5 seconds for server sync...");
		sleep(5);
		fprintf(stderr,"ok\n");

		waitingfor = WF_DOINIT;

		fprintf(stderr,"\tsigning on user '%s' on handle2...",username2[i]);
		e = firetalk_signon(handle2,NULL,0,username2[i]);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}


		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> doinit callback is good (%lds)\n",time(NULL) - tt);


		waitingfor = WF_BUDDYONLINE;


		fprintf(stderr,"\tregistering buddyonline callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_BUDDYONLINE,(ptrtofnct) buddy_online);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tremoving '%s' from handle1 buddy list...",username2[i]);
		e = firetalk_im_remove_buddy(handle1,username2[i]);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s)",e,firetalk_strerror(e));
			if (e == FE_NOTFOUND)
				fprintf(stderr,"...");
			else {
				fprintf(stderr," <--\n");
				exit(EXIT_FAILURE);
			}
		}
		fprintf(stderr,"ok\n");

		fprintf(stderr,"\tadding '%s' back to handle1 buddy list...",username2[i]);
		e = firetalk_im_add_buddy(handle1,username2[i]);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> buddyonline callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering im_buddyaway callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_BUDDYAWAY,(ptrtofnct) im_buddyaway);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_IM_BUDDYAWAY;

		fprintf(stderr,"\tsetting handle2 away...");
		e = firetalk_set_away(handle2,"firetalktest " LIBFIRETALK_VERSION);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> im_buddyaway callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering im_buddyunaway callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_BUDDYUNAWAY,(ptrtofnct) im_buddyunaway);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_IM_BUDDYUNAWAY;

		fprintf(stderr,"\tsetting handle2 unaway...");
		e = firetalk_set_away(handle2,NULL);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> im_buddyunaway callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tsetting handle2 info to 'firetalktest v" LIBFIRETALK_VERSION "'...");
		e = firetalk_set_info(handle2,"firetalktest v" LIBFIRETALK_VERSION);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tsleeping 5 seconds for server sync...");
		sleep(5);
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tregistering gotinfo callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_GOTINFO,(ptrtofnct) gotinfo);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_GOTINFO;

		fprintf(stderr,"\trequesting info for '%s' from handle1...",username2[i]);
		e = firetalk_im_get_info(handle1,username2[i]);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> gotinfo callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering im_getmessage callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_GETMESSAGE,(ptrtofnct) im_getmessage);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_IM_GETMESSAGE;

		fprintf(stderr,"\tsending message to '%s' from handle2...",username1[i]);
		e = firetalk_im_send_message(handle2,username1[i],"firetalktest v" LIBFIRETALK_VERSION,0);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> im_getmessage callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering im_getaction callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_GETACTION,(ptrtofnct) im_getaction);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_IM_GETACTION;

		fprintf(stderr,"\tsending action to '%s' from handle2...",username1[i]);
		e = firetalk_im_send_action(handle2,username1[i],"firetalktest v" LIBFIRETALK_VERSION,0);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> im_getaction callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering subcode_reply PING callback for handle1...");
		e = firetalk_subcode_register_reply_callback(handle1,"PING",subcode_reply);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_SUBCODE_REPLY;

		fprintf(stderr,"\tsending PING subcode request to '%s' from handle1...",username2[i]);
		e = firetalk_subcode_send_request(handle1,username2[i],"PING","firetalktest " LIBFIRETALK_VERSION);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> subcode request and reply is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering chat_joined callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CHAT_JOINED,(ptrtofnct) chat_joined);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_CHAT_JOINED;

		fprintf(stderr,"\tjoining channel 'fttest' from handle1...");
		e = firetalk_chat_join(handle1,"fttest");
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> chat_joined callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering chat_user_joined callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CHAT_USER_JOINED,(ptrtofnct) chat_user_joined);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		fprintf(stderr,"\tregistering chat_joined callback for handle2...");
		e = firetalk_register_callback(handle2,FC_CHAT_JOINED,(ptrtofnct) chat_joined);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


		waitingfor = WF_CHAT_USER_JOINED;
		waitingfor2 = WF_CHAT_JOINED;

		fprintf(stderr,"\tjoining channel 'fttest' from handle2...");
		e = firetalk_chat_join(handle2,"fttest");
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && ((waitingfor != 0) || (waitingfor2 != 0))) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)/(%d)\n",waitingfor,waitingfor2);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> chat_user_joined callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering chat_getmessage callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CHAT_GETMESSAGE,(ptrtofnct) chat_getmessage);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_CHAT_GETMESSAGE;

		fprintf(stderr,"\tsending message to channel 'fttest' from handle2...");
		e = firetalk_chat_send_message(handle2,"fttest","firetalktest v" LIBFIRETALK_VERSION,0);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && ((waitingfor != 0) || (waitingfor2 != 0))) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)/(%d)\n",waitingfor,waitingfor2);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> chat_getmessage callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering chat_getaction callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CHAT_GETACTION,(ptrtofnct) chat_getaction);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_CHAT_GETACTION;

		fprintf(stderr,"\tsending action to channel 'fttest' from handle2...");
		e = firetalk_chat_send_action(handle2,"fttest","firetalktest v" LIBFIRETALK_VERSION,0);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && ((waitingfor != 0) || (waitingfor2 != 0))) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)/(%d)\n",waitingfor,waitingfor2);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> chat_getaction callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering chat_user_left callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CHAT_USER_LEFT,(ptrtofnct) chat_user_left);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_CHAT_USER_LEFT;

		fprintf(stderr,"\tparting channel 'fttest' from handle2...");
		e = firetalk_chat_part(handle2,"fttest");
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> chat_user_left callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering chat_left callback for handle1...");
		e = firetalk_register_callback(handle1,FC_CHAT_LEFT,(ptrtofnct) chat_left);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_CHAT_LEFT;

		fprintf(stderr,"\tparting channel 'fttest' from handle1...");
		e = firetalk_chat_part(handle1,"fttest");
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> chat_left callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tregistering buddyoffline callback for handle1...");
		e = firetalk_register_callback(handle1,FC_IM_BUDDYOFFLINE,(ptrtofnct) buddy_offline);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		waitingfor = WF_BUDDYOFFLINE;

		fprintf(stderr,"\tdisconnecting handle2...");
		e = firetalk_disconnect(handle2);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");

		{
			struct timeval t;
			time(&tt);
			fprintf(stderr,"\tselecting for 120 seconds...");
			while ((tt + 120 > time(NULL)) && (waitingfor != 0)) {
				t.tv_sec = 120;
				t.tv_usec = 0;
				e = firetalk_select_custom(0,NULL,NULL,NULL,&t);
				if (e != FE_SUCCESS) {
					fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
					exit(EXIT_FAILURE);
				}
			}
			fprintf(stderr,"ok\n");
		}

		if (waitingfor != 0) {
			fprintf(stderr,"\t--> ERROR: still waiting (%d)\n",waitingfor);
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"\t--> buddyoffline callback is good (%lds)\n",time(NULL) - tt);


		fprintf(stderr,"\tdisconnecting handle1...");
		e = firetalk_disconnect(handle1);
		if (e != FE_SUCCESS) {
			fprintf(stderr,"failed: %d (%s) <--\n",e,firetalk_strerror(e));
			exit(EXIT_FAILURE);
		}
		fprintf(stderr,"ok\n");


	}
	return 0;
}
