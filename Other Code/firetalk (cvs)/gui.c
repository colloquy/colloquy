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
#include <curses.h>
#include <strings.h>

#include "firetalk.h"
#include "safestring.h"

char indata[1024] = "";
int dataloc = 0;
int proto = 0;
char query[256] = "";
char room[256] = "";
char pass[256] = "";
firetalk_t handles[FP_MAX];

typedef void (*ptrtofnct)(firetalk_t, void *, ...);

void clearline() {
	int i;
	for (i = 0; i < 180; i++)
		printw("\b \b");
	clrtoeol();
}

void printline() {
	int i;
	printw("%s",firetalk_strprotocol(proto));
	if (query[0])
		printw(",%s",query);
	else if (room[0])
		printw(",%s",room);
	printw("> ");
	for (i = 0; i < dataloc; i++)
		addch(indata[i]);
	refresh();
}

void needpass (void *c, void *cs, char *p, const int size) {
	clearline();
	printw("(%s) Sending pass '%s' at request\n",firetalk_strprotocol(firetalk_get_protocol(c)),pass);
	safe_strncpy(p,pass,size);
	printline();
}

void subcode_request (void *c, void *cs, const char * const from, const char * const command, const char * const args) {
	clearline();
	printw("(%s) Subcode request from '%s' for '%s' with args '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),from,command,args);
	printline();
}

void subcode_reply (void *c, void *cs, const char * const from, const char * const command, const char * const args) {
	clearline();
	printw("(%s) Subcode reply from '%s' for '%s' with args '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),from,command,args);
	printline();
}

void disconnect (void *c, void *cs, const int error) {
	clearline();
	printw("(%s) Disconnected: '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),firetalk_strerror(error));
	printline();
}

void connected (void *c, void *cs) {
	clearline();
	printw("(%s) Connected.\n",firetalk_strprotocol(firetalk_get_protocol(c)));
	printline();
}

void connectfailed (void *c, void *cs, int error, char *reason) {
	clearline();
	printw("(%s) Connection failed: %s (%s)\n",firetalk_strprotocol(firetalk_get_protocol(c)),firetalk_strerror(error),reason);
	printline();
}

void doinit (void *c, void *cs, char *nickname) {
	clearline();
	printw("(%s) Our nickname is '%s'.\n",firetalk_strprotocol(firetalk_get_protocol(c)),nickname);
	printw("(%s) Uploading init.\n",firetalk_strprotocol(firetalk_get_protocol(c)));
	printline();
	switch (firetalk_get_protocol(c)) {
#ifndef DISABLE_TOC_PROTOCOL
		case FP_AIMTOC:
			/*
			firetalk_im_internal_add_buddy(c,"flamingcow66");
			firetalk_im_internal_add_buddy(c,"prncow3");
			firetalk_im_internal_add_buddy(c,"prncow4");
			firetalk_im_internal_add_buddy(c,"prncow5");
			*/
			firetalk_set_info(c,"firetalk v" LIBFIRETALK_VERSION " http://www.penguinhosting.net/~ian/firetalk/");
			break;
#endif
#ifndef DISABLE_IRC_PROTOCOL
		case FP_IRC:
			firetalk_im_internal_add_buddy(c,"ian");
			firetalk_im_internal_add_buddy(c,"flamngcow");
			firetalk_im_internal_add_buddy(c,"flamingcow");
			break;
#endif
	}
}

void error (void *c, void *cs, const int error, const char * const roomoruser, const char * const description) {
	clearline();
	printw("(%s) Error for '%s': %s (%s)\n",firetalk_strprotocol(firetalk_get_protocol(c)),roomoruser,firetalk_strerror(error),description);
	printline();
}

void getmessage (void *c, void *cs, const char * const who, const int automessage, const char * const message) {
	clearline();
	printw("(%s) %s message from '%s': '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),(automessage ? "Automatic" : "Normal"),who,message);
	printline();
}

void getaction (void *c, void *cs, const char * const who, const int automessage, const char * const message) {
	clearline();
	printw("(%s) %s action from '%s': '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),(automessage ? "Automatic" : "Normal"),who,message);
	printline();
}

void buddy_online (void *c, void *cs, const char * const who) {
	clearline();
	printw("(%s) '%s' is now online\n",firetalk_strprotocol(firetalk_get_protocol(c)),who);
	printline();
}

void buddy_offline (void *c, void *cs, const char * const who) {
	clearline();
	printw("(%s) '%s' is now offline\n",firetalk_strprotocol(firetalk_get_protocol(c)),who);
	printline();
}

void buddy_away (void *c, void *cs, const char * const who) {
	clearline();
	printw("(%s) '%s' is now away\n",firetalk_strprotocol(firetalk_get_protocol(c)),who);
	printline();
}

void buddy_unaway (void *c, void *cs, const char * const who) {
	clearline();
	printw("(%s) '%s' is now back\n",firetalk_strprotocol(firetalk_get_protocol(c)),who);
	printline();
}

void got_info (void *c, void *cs, const char * const who, const char * const info, const int warning, const int idle, const int flags) {
	clearline();
	printw("(%s) Info for '%s': warning=%d, idle=%d, info='%s', substandard=%s, normal=%s, admin=%s\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,warning,idle,info,flags & FF_SUBSTANDARD ? "yes" : "no",flags & FF_NORMAL ? "yes" : "no",flags & FF_ADMIN ? "yes" : "no");
	printline();
}

void got_idle (void *c, void *cs, const char * const who, const long idletime) {
	clearline();
	printw("(%s) '%s' is now idle %ld minutes\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,idletime);
	printline();
}

void set_idle (void *c, void *cs, const int * const idle) {
	clearline();
	printw("(%s) Our idle is now %d seconds\n",firetalk_strprotocol(firetalk_get_protocol(c)),*idle);
	printline();
}

void eviled (void *c, void *cs, const int newevil, const char * const eviler) {
	clearline();
	printw("(%s) Eviled by '%s' to %d\n",firetalk_strprotocol(firetalk_get_protocol(c)),eviler,newevil);
	printline();
}

void newnick (void *c, void *cs, const char * const nickname) {
	clearline();
	printw("(%s) New nickname is '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),nickname);
	printline();
}

void passchanged (void *c, void *cs) {
	clearline();
	printw("(%s) Password changed successfully\n",firetalk_strprotocol(firetalk_get_protocol(c)));
	printline();
}

void im_user_nickchanged (void *c, void *cs, const char * const oldnick, const char * const newnick) {
	clearline();
	printw("(%s) Buddy changed nickname from '%s' to '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),oldnick,newnick);
	printline();
}

void listbuddy (void *c, void *cs, const char * const nickname, const int online, const int away, const long idle) {
	clearline();
	printw("(%s) Buddy: '%s' (online=%d, away=%d, idle=%ld)\n",firetalk_strprotocol(firetalk_get_protocol(c)),nickname,online,away,idle);
	printline();
}

void listmember (void *c, void *cs, const char * const room, const char * const nickname, const int admin) {
	clearline();
	printw("(%s) Room '%s' member: '%s' (admin=%d)\n",firetalk_strprotocol(firetalk_get_protocol(c)),room,nickname,admin);
	printline();
}

void chat_joined (void *c, void *cs, const char * const room, const int previous) {
	clearline();
	printw("(%s) Joined '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),room);
	printline();
}

void chat_left (void *c, void *cs, const char * const room) {
	clearline();
	printw("(%s) Left '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),room);
	printline();
}

void chat_kicked (void *c, void *cs, const char * const room, const char * const by, const char * const reason) {
	clearline();
	printw("(%s) Kicked from '%s' by '%s' because '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),room,by,reason);
	printline();
}

void chat_getmessage (void *c, void *cs, const char * const room, const char * const from, const int automessage, const char * message) {
	clearline();
	printw("(%s) %s message from '%s' in '%s': '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),automessage ? "Automatic" : "Normal",from,room,message);
	printline();
}

void chat_getaction (void *c, void *cs, const char * const room, const char * const from, const int automessage, const char * message) {
	clearline();
	printw("(%s) %s action in '%s' from '%s': '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),automessage ? "Automatic" : "Normal",room,from,message);
	printline();
}

void chat_invited (void *c, void *cs, const char * const room, const char * const from, const char * message) {
	clearline();
	printw("(%s) '%s' invited you to '%s': '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),from,room,message);
	printline();
}

void chat_user_joined (void *c, void *cs, const char * const room, const char * const who) {
	clearline();
	printw("(%s) '%s' joined '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,room);
	printline();
}

void chat_user_left (void *c, void *cs, const char * const room, const char * const who, const char * const reason) {
	clearline();
	printw("(%s) '%s' left '%s' with reason '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,room,reason);
	printline();
}

void chat_user_kicked (void *c, void *cs, const char * const room, const char * const who, const char * const by, const char * const reason) {
	clearline();
	printw("(%s) '%s' kicked from '%s' by '%s' because '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,room,by,reason);
	printline();
}

void chat_gottopic (void *c, void *cs, const char * const room, const char * const topic, const char * const author) {
	clearline();
	printw("(%s) Topic in '%s' set by '%s': '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),room,author,topic);
	printline();
}

void chat_user_opped (void *c, void *cs, const char * const room, const char * const who, const char * const by) {
	clearline();
	printw("(%s) '%s' opped in '%s' by '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,room,by);
	printline();
}

void chat_user_deopped (void *c, void *cs, const char * const room, const char * const who, const char * const by) {
	clearline();
	printw("(%s) '%s' deopped in '%s' by '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),who,room,by);
	printline();
}

void chat_opped (void *c, void *cs, const char * const room, const char * const by) {
	clearline();
	printw("(%s) We were opped in '%s' by '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),room,by);
	printline();
}

void chat_deopped (void *c, void *cs, const char * const room, const char * const by) {
	clearline();
	printw("(%s) We were deopped in '%s' by '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),room,by);
	printline();
}

void chat_user_nickchanged (void *c, void *cs, const char * const room, const char * const oldnick, const char * const newnick) {
	clearline();
	printw("(%s) User '%s' in '%s' changed nickname to '%s'\n",firetalk_strprotocol(firetalk_get_protocol(c)),oldnick,room,newnick);
	printline();
}

void file_offer(void *c, void *cs, void *filehandle, const char * const from, const char * const filename, const long size) {
	clearline();
	printw("(%s) Offer of file '%s' from '%s' (handle=%08x, %ld bytes)\n",firetalk_strprotocol(firetalk_get_protocol(c)),filename,from,(unsigned long) filehandle,size);
	printline();
}

void file_start(void *c, void *cs, void *filehandle, void *cfs) {
	clearline();
	printw("(%s) Starting transfer with handle=%08x\n",firetalk_strprotocol(firetalk_get_protocol(c)),(long) filehandle);
	printline();
}

void file_finish(void *c, void *cs, void *filehandle, void *cfs, const long size) {
	clearline();
	printw("(%s) Finished transfer of %ld bytes with handle=%08x\n",firetalk_strprotocol(firetalk_get_protocol(c)),size,(unsigned long) filehandle);
	printline();
}

void file_error(void *c, void *cs, void *filehandle, void *cfs, int error) {
	clearline();
	printw("(%s) Transfer error of handle=%08x: %s\n",firetalk_strprotocol(firetalk_get_protocol(c)),(unsigned long) filehandle,firetalk_strerror(error));
	printline();
}

void file_progress(void *c, void *cs, void *filehandle, void *cfs, const long bytes, const long size) {
	clearline();
	printw("(%s) Progress: transferred %ld/%ld of handle=%08x\n",firetalk_strprotocol(firetalk_get_protocol(c)),bytes,size,(unsigned long) filehandle);
	printline();
}

int parse_args (char **args, char *string) {
	int inquote = 0;
	int inescape = 0;
	static char outstring[1024];
	int curarg = 1;
	int len = strlen(string);
	int i;
	int outstringpos = 0;

	args[0] = outstring;

	for (i = 0; i < len; i++) {
		if (curarg > 8)
			return curarg - 1;
		if (string[i] == ' ' && !inquote && !inescape) {
			outstring[outstringpos++] = '\0';
			args[curarg++] = &outstring[outstringpos];
		} else if (string[i] == '"' && !inescape)
			inquote = !inquote;
		else if (string[i] == '\\' && !inescape)
			inescape = 1;
		else
			outstring[outstringpos++] = string[i];
	}
	outstring[outstringpos] = '\0';
	return curarg - 1;
}

int main(int argc, char *argv[]) {
	fd_set read;
	char inchar;
	int numargs;
	char *args[10];
	int i;

	initscr();
	cbreak();
	noecho();
	nodelay(stdscr,TRUE);
	idlok(stdscr,TRUE);
	scrollok(stdscr,TRUE);
	erase();
	printw("firetalk v" LIBFIRETALK_VERSION "\n");
	printline();

	for (i = 0; i < FP_MAX; i++) {
		handles[i] = firetalk_create_handle(i,NULL);
		firetalk_register_callback(handles[i],FC_DISCONNECT,(ptrtofnct) disconnect);
		firetalk_register_callback(handles[i],FC_ERROR,(ptrtofnct) error);
		firetalk_register_callback(handles[i],FC_IM_GETMESSAGE,(ptrtofnct) getmessage);
		firetalk_register_callback(handles[i],FC_IM_GETACTION,(ptrtofnct) getaction);
		firetalk_register_callback(handles[i],FC_IM_BUDDYONLINE,(ptrtofnct) buddy_online);
		firetalk_register_callback(handles[i],FC_IM_BUDDYOFFLINE,(ptrtofnct) buddy_offline);
		firetalk_register_callback(handles[i],FC_IM_BUDDYAWAY,(ptrtofnct) buddy_away);
		firetalk_register_callback(handles[i],FC_IM_BUDDYUNAWAY,(ptrtofnct) buddy_unaway);
		firetalk_register_callback(handles[i],FC_IM_LISTBUDDY,(ptrtofnct) listbuddy);
		firetalk_register_callback(handles[i],FC_IM_USER_NICKCHANGED,(ptrtofnct) im_user_nickchanged);
		firetalk_register_callback(handles[i],FC_IM_GOTINFO,(ptrtofnct) got_info);
		firetalk_register_callback(handles[i],FC_IM_IDLEINFO,(ptrtofnct) got_idle);
		firetalk_register_callback(handles[i],FC_SETIDLE,(ptrtofnct) set_idle);
		firetalk_register_callback(handles[i],FC_EVILED,(ptrtofnct) eviled);
		firetalk_register_callback(handles[i],FC_NEWNICK,(ptrtofnct) newnick);
		firetalk_register_callback(handles[i],FC_PASSCHANGED,(ptrtofnct) passchanged);
		firetalk_register_callback(handles[i],FC_DOINIT,(ptrtofnct) doinit);
		firetalk_register_callback(handles[i],FC_CONNECTED,(ptrtofnct) connected);
		firetalk_register_callback(handles[i],FC_CONNECTFAILED,(ptrtofnct) connectfailed);
		firetalk_register_callback(handles[i],FC_CHAT_JOINED,(ptrtofnct) chat_joined);
		firetalk_register_callback(handles[i],FC_CHAT_LEFT,(ptrtofnct) chat_left);
		firetalk_register_callback(handles[i],FC_CHAT_KICKED,(ptrtofnct) chat_kicked);
		firetalk_register_callback(handles[i],FC_CHAT_GETMESSAGE,(ptrtofnct) chat_getmessage);
		firetalk_register_callback(handles[i],FC_CHAT_GETACTION,(ptrtofnct) chat_getaction);
		firetalk_register_callback(handles[i],FC_CHAT_INVITED,(ptrtofnct) chat_invited);
		firetalk_register_callback(handles[i],FC_CHAT_USER_JOINED,(ptrtofnct) chat_user_joined);
		firetalk_register_callback(handles[i],FC_CHAT_USER_LEFT,(ptrtofnct) chat_user_left);
		firetalk_register_callback(handles[i],FC_CHAT_GOTTOPIC,(ptrtofnct) chat_gottopic);
		firetalk_register_callback(handles[i],FC_CHAT_USER_OPPED,(ptrtofnct) chat_user_opped);
		firetalk_register_callback(handles[i],FC_CHAT_USER_DEOPPED,(ptrtofnct) chat_user_deopped);
		firetalk_register_callback(handles[i],FC_CHAT_OPPED,(ptrtofnct) chat_opped);
		firetalk_register_callback(handles[i],FC_CHAT_DEOPPED,(ptrtofnct) chat_deopped);
		firetalk_register_callback(handles[i],FC_CHAT_USER_KICKED,(ptrtofnct) chat_user_kicked);
		firetalk_register_callback(handles[i],FC_CHAT_USER_NICKCHANGED,(ptrtofnct) chat_user_nickchanged);
		firetalk_register_callback(handles[i],FC_CHAT_LISTMEMBER,(ptrtofnct) listmember);
		firetalk_register_callback(handles[i],FC_FILE_OFFER,(ptrtofnct) file_offer);
		firetalk_register_callback(handles[i],FC_FILE_START,(ptrtofnct) file_start);
		firetalk_register_callback(handles[i],FC_FILE_FINISH,(ptrtofnct) file_finish);
		firetalk_register_callback(handles[i],FC_FILE_ERROR,(ptrtofnct) file_error);
		firetalk_register_callback(handles[i],FC_FILE_PROGRESS,(ptrtofnct) file_progress);
		firetalk_register_callback(handles[i],FC_NEEDPASS,(ptrtofnct) needpass);
		firetalk_subcode_register_request_callback(handles[i],NULL,subcode_request);
		firetalk_subcode_register_reply_callback(handles[i],NULL,subcode_reply);
	}

	while (1) {
		FD_ZERO(&read);
		FD_SET(STDIN_FILENO,&read);
		if (firetalk_select_custom(STDIN_FILENO + 1,&read,NULL,NULL,NULL) < 0) {
			printw("firetalk_select_custom: %s\n",firetalk_strerror(firetalkerror));
			exit(1);
		}
		if (FD_ISSET(STDIN_FILENO,&read)) {
			while ((inchar = getch()) != ERR) {
				if (inchar == '\n') {
					addch('\n');
					indata[dataloc] = '\0';
					dataloc = 0;
					numargs = parse_args(args,indata);
					if (!strcmp(args[0],"chat_deop")) {
						if (numargs == 2) {
							i = firetalk_chat_deop(handles[proto],args[1],args[2]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_deop <room> <who>\n");
					} else if (!strcmp(args[0],"chat_join")) {
						if (numargs == 1) {
							i = firetalk_chat_join(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_join <room>\n");
					} else if (!strcmp(args[0],"chat_op")) {
						if (numargs >= 2) {
							int m;
							for (m = 2; m <= numargs; m++)
								i = firetalk_chat_op(handles[proto],args[1],args[m]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_op <room> <who> [ <who> ... ]\n");
					} else if (!strcmp(args[0],"chat_part")) {
						if (numargs == 1) {
							i = firetalk_chat_part(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_part <room>\n");
					} else if (!strcmp(args[0],"chat_send_action")) {
						if (numargs == 3) {
							i = firetalk_chat_send_action(handles[proto],args[1],args[2],atoi(args[3]));
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_send_action <room> <message> <auto flag>\n");
					} else if (!strcmp(args[0],"chat_send_message")) {
						if (numargs == 3) {
							i = firetalk_chat_send_message(handles[proto],args[1],args[2],atoi(args[3]));
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_send_message <room> <message> <auto flag>\n");
					} else if (!strcmp(args[0],"chat_invite")) {
						if (numargs == 3) {
							i = firetalk_chat_invite(handles[proto],args[1],args[2],args[3]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_invite <room> <who> <message>\n");
					} else if (!strcmp(args[0],"chat_set_topic")) {
						if (numargs == 2) {
							i = firetalk_chat_set_topic(handles[proto],args[1],args[2]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_set_topic <room> <topic>\n");
					} else if (!strcmp(args[0],"chat_kick")) {
						if (numargs == 3) {
							i = firetalk_chat_kick(handles[proto],args[1],args[2],args[3]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_kick <room> <who> <reason>\n");
					} else if (!strcmp(args[0],"chat_list_members")) {
						if (numargs == 1) {
							i = firetalk_chat_listmembers(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: chat_list_members <room>\n");
					} else if (!strcmp(args[0],"disconnect")) {
						i = firetalk_disconnect(handles[proto]);
						if (i != FE_SUCCESS)
							printw("Error: %s\n",firetalk_strerror(i));
					} else if (!strcmp(args[0],"file_accept")) {
						if (numargs == 2) {
							void *handle;
							sscanf(args[1],"%8lx",(unsigned long int *) &handle);
							i = firetalk_file_accept(handles[proto],handle,NULL,args[2]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: file_accept <handle> <local filename>\n");
					} else if (!strcmp(args[0],"file_offer")) {
						if (numargs == 2) {
							i = firetalk_file_offer(handles[proto],NULL,args[1],args[2]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: file_offer <to> <local filename>\n");
					} else if (!strcmp(args[0],"get_info")) {
						if (numargs == 1) {
							i = firetalk_im_get_info(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: get_info <who>\n");
					} else if (!strcmp(args[0],"help")) {
						printw("Example commands:\n"
" chat_deop                Take operator status from a user in a chat room\n"
" chat_invite              Invites someone to a chat room\n"
" chat_join                Joins a chat room\n"
" chat_kick                Kicks a user from a chat room\n"
" chat_list_members        List members in a chat room\n");
						printw(" chat_op                  Give operator status to a user in a chat room\n"
" chat_part                Leaves a chat room\n"
" chat_send_action         Sends an action to a chat room\n"
" chat_send_message        Sends a message to a chat room\n");
						printw(" chat_set_topic           Sets the topic in a chat room\n"
" disconnect               Disconnects current connection\n"
" file_accept              Accept a pending file transfer\n"
" file_offer               Offer a file to another user\n"
" get_info                 Retrieve information on a user\n"
" help                     Displays this help\n");
						printw(" im_add_buddy             Adds a person to your buddy list\n"
" im_add_deny              Adds a person to your deny list\n"
" im_evil                  Evil another user\n"
" im_list_buddies          Lists all buddies in your buddy list\n"
" im_remove_buddy          Removes a person from your buddy list\n");
						printw(" im_remove_deny           Removes a person from your deny list\n"
" im_send_action           Sends an action to another person\n"
" im_send_message          Sends a message to another person\n"
" im_upload_buddies        Uploads your buddy list to the server\n"
" im_upload_denies         Uploads your deny list to the server\n");
						printw(" local_pass               Sets the local password reply\n"
" proto                    Sets current protocol\n"
" query                    Sets the current query user\n"
" room                     Sets the current room\n");
						printw(" save_config              Save configuration to the server\n"
" set_away                 Sets our away message\n"
" set_info                 Sets our information\n"
" set_nickname             Sets our nickname/nickname format\n"
" set_password             Sets out password\n");
						printw(" subcode_send_request     Sends a subcode request to another person\n"
" subcode_send_reply       Sends a subcode reply to another person\n"
" signon                   Connects to a server\n"
" quit                     Exits firetalk\n");
					} else if (!strcmp(args[0],"im_add_buddy")) {
						if (numargs == 1) {
							i = firetalk_im_add_buddy(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_add_buddy <nickname>\n");
					} else if (!strcmp(args[0],"im_add_deny")) {
						if (numargs == 1) {
							i = firetalk_im_add_deny(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_add_deny <nickname>\n");
					} else if (!strcmp(args[0],"im_evil")) {
						if (numargs == 1) {
							i = firetalk_im_evil(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_evil <nickname>\n");
					} else if (!strcmp(args[0],"im_list_buddies")) {
						i = firetalk_im_list_buddies(handles[proto]);
						if (i != FE_SUCCESS)
							printw("Error: %s\n",firetalk_strerror(i));
					} else if (!strcmp(args[0],"im_remove_buddy")) {
						if (numargs == 1) {
							i = firetalk_im_remove_buddy(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_remove_buddy <nickname>\n");
					} else if (!strcmp(args[0],"im_remove_deny")) {
						if (numargs == 1) {
							i = firetalk_im_remove_deny(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_remove_deny <nickname>\n");
					} else if (!strcmp(args[0],"im_send_action")) {
						if (numargs == 3) {
							i = firetalk_im_send_action(handles[proto],args[1],args[2],atoi(args[3]));
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_send_action <destination> <message> <auto flag>\n");
					} else if (!strcmp(args[0],"im_send_message")) {
						if (numargs == 3) {
							i = firetalk_im_send_message(handles[proto],args[1],args[2],atoi(args[3]));
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: im_send_message <destination> <message> <auto flag>\n");
					} else if (!strcmp(args[0],"im_upload_buddies")) {
						i = firetalk_im_upload_buddies(handles[proto]);
						if (i != FE_SUCCESS)
							printw("Error: %s\n",firetalk_strerror(i));
					} else if (!strcmp(args[0],"im_upload_denies")) {
						i = firetalk_im_upload_denies(handles[proto]);
						if (i != FE_SUCCESS)
							printw("Error: %s\n",firetalk_strerror(i));
					} else if (!strcmp(args[0],"local_pass")) {
						if (numargs == 1)
							safe_strncpy(pass,args[1],256);
						else
							printw("Usage: local_pass <pass>\n");
					} else if (!strcmp(args[0],"proto")) {
						if (numargs > 0) {
							i = atoi(args[1]);
							if (i < 0 || i >= FP_MAX)
								printw("Invalid protocol number '%d'\n",i);
							else
								proto = i;
						} else {
							printw("Usage: proto <protcol number>\n"
"Available protocols are:\n");
							for (i = 0; i < FP_MAX; i++)
								printw(" %2d  %s\n",i,firetalk_strprotocol(i));
						}
					} else if (!strcmp(args[0],"query")) {
						if (numargs == 1) {
							safe_strncpy(query,args[1],256);
							safe_strncpy(room,"",256);
						} else if (query[0])
							safe_strncpy(query,"",256);
						else
							printw("Usage: query <who>\n");
					} else if (!strcmp(args[0],"room")) {
						if (numargs == 1) {
							safe_strncpy(room,args[1],256);
							safe_strncpy(query,"",256);
						} else if (room[0])
							safe_strncpy(room,"",256);
						else
							printw("Usage: room <room>\n");
					} else if (!strcmp(args[0],"save_config")) {
						i = firetalk_im_upload_denies(handles[proto]);
						if (i != FE_SUCCESS)
							printw("Error: %s\n",firetalk_strerror(i));
					} else if (!strcmp(args[0],"set_away")) {
						if (numargs == 1) {
							i = firetalk_set_away(handles[proto],(strcasecmp(args[1],"null") ? args[1] : NULL));
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: set_away <message>\n");
					} else if (!strcmp(args[0],"set_info")) {
						if (numargs == 1) {
							i = firetalk_set_info(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: set_info <info>\n");
					} else if (!strcmp(args[0],"set_nickname")) {
						if (numargs == 1) {
							i = firetalk_set_nickname(handles[proto],args[1]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: set_nickname <nickname>\n");
					} else if (!strcmp(args[0],"set_password")) {
						if (numargs == 2) {
							i = firetalk_set_password(handles[proto],args[1],args[2]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: set_password <old password> <new password>\n");
					} else if (!strcmp(args[0],"signon")) {
						if (numargs == 3) {
							i = firetalk_signon(handles[proto],(strcasecmp(args[1],"null") ? args[1] : NULL),atoi(args[2]),args[3]);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: signon <server> <port> <username>\n");
					} else if (!strcmp(args[0],"subcode_send_request")) {
						if (numargs == 3) {
							i = firetalk_subcode_send_request(handles[proto],args[1],args[2],strcasecmp(args[3],"null") ? args[3] : NULL);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: subcode_send_request <to> <command> <args>\n");
					} else if (!strcmp(args[0],"subcode_send_reply")) {
						if (numargs == 3) {
							i = firetalk_subcode_send_reply(handles[proto],args[1],args[2],strcasecmp(args[3],"null") ? args[3] : NULL);
							if (i != FE_SUCCESS)
								printw("Error: %s\n",firetalk_strerror(i));
						} else
							printw("Usage: subcode_send_reply <to> <command> <args>\n");
					} else if (!strcmp(args[0],"quit")) {
						for (i = 0; i < FP_MAX; i++)
							firetalk_disconnect(handles[i]);
						addch('\n');
						endwin();
						exit(0);
					} else if (args[0][0] == '\0') {
						;
					} else {
						if (query[0])
							firetalk_im_send_message(handles[proto],query,indata,0);
						else if (room[0])
							firetalk_chat_send_message(handles[proto],room,indata,0);
						else
							printw("Unknown command '%s'\n",args[0]);
					}
					clearline();
					printline();
				} else if (inchar == '\b' || inchar == 127) {
					if (dataloc > 0) {
						printw("\b \b");
						dataloc--;
					}
				} else {
					if (dataloc < 1023) {
						indata[dataloc++] = inchar;
						addch(inchar);
					}
				}
			}
		}
	}

	return 0;
}
