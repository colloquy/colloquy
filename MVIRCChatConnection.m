#import <unistd.h>

#import "MVChatConnection.h"
#import "MVIRCChatConnection.h"
#import "MVIRCFileTransfer.h"
#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSDataAdditions.h"

#define MODULE_NAME "MVChatConnection"

#import "core.h"
#import "irc.h"
#import "signals.h"
#import "servers.h"
#import "servers-setup.h"
#import "chat-protocols.h"
#import "net-sendbuffer.h"
#import "channels.h"
#import "nicklist.h"
#import "notifylist.h"
#import "mode-lists.h"
#import "settings.h"

#import "config.h"
#import "dcc.h"
#import "dcc-file.h"
#import "dcc-get.h"

void irc_init( void );
void irc_deinit( void );

#pragma mark -

NSRecursiveLock *MVIRCChatConnectionThreadLock = nil;
static unsigned int connectionCount = 0;
static GMainLoop *glibMainLoop = NULL;

typedef struct {
	MVIRCChatConnection *connection;
} MVChatConnectionModuleData;

@interface MVIRCChatConnection (MVIRCChatConnectionPrivate)
+ (MVIRCChatConnection *) _connectionForServer:(SERVER_REC *) server;

+ (void) _registerCallbacks;
+ (void) _deregisterCallbacks;

+ (const char *) _flattenedIRCStringForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc;

- (SERVER_REC *) _irssiConnection;
- (void) _setIrssiConnection:(SERVER_REC *) server;

- (SERVER_CONNECT_REC *) _irssiConnectSettings;
- (void) _setIrssiConnectSettings:(SERVER_CONNECT_REC *) settings;

- (void) _nicknameIdentified:(BOOL) identified;
- (void) _forceDisconnect;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
@end

#pragma mark -

#define ERR_NOSUCHNICK       401 // <nickname> :No such nick/channel
#define ERR_NOSUCHSERVER     402 // <server name> :No such server
#define ERR_NOSUCHCHANNEL    403 // <channel name> :No such channel
#define ERR_CANNOTSENDTOCHAN 404 // <channel name> :Cannot send to channel
#define ERR_TOOMANYCHANNELS  405 // <channel name> :You have joined too many channels
#define ERR_WASNOSUCHNICK    406 // <nickname> :There was no such nickname
#define ERR_TOOMANYTARGETS   407 // <target> :Duplicate recipients. No message delivered
#define ERR_NOSUCHSERVICE    408 
#define	ERR_NOORIGIN         409 // :No origin specified
#define ERR_CANNOTKNOCK      410 
#define ERR_NORECIPIENT      411 // :No recipient given (<command>)
#define ERR_NOTEXTTOSEND     412 // :No text to send
#define ERR_NOTOPLEVEL       413 // <mask> :No toplevel domain specified
#define ERR_WILDTOPLEVEL     414 // <mask> :Wildcard in toplevel domain
#define ERR_SERVICESUP       415

#define ERR_UNKNOWNCOMMAND   421 // <command> :Unknown command
#define	ERR_NOMOTD           422 // :MOTD File is missing
#define	ERR_NOADMININFO      423 // <server> :No administrative info available
#define	ERR_FILEERROR        424 // :File error doing <file op> on <file>

#define ERR_NONICKNAMEGIVEN  431 // :No nickname given
#define ERR_ERRONEUSNICKNAME 432 // <nick> :Erroneus nickname
#define ERR_NICKNAMEINUSE    433 // <nick> :Nickname is already in use
#define ERR_SERVICENAMEINUSE 434 
#define ERR_SERVICECONFUSED  435
#define	ERR_NICKCOLLISION    436 // <nick> :Nickname collision KILL
#define ERR_BANNICKCHANGE    437
#define ERR_NCHANGETOOFAST   438
#define ERR_TARGETTOOFAST    439
#define ERR_SERVICESDOWN     440

#define ERR_USERNOTINCHANNEL 441 // <nick> <channel> :They aren't on that channel
#define ERR_NOTONCHANNEL     442 // <channel> :You're not on that channel
#define	ERR_USERONCHANNEL    443 // <user> <channel> :is already on channel
#define ERR_NOLOGIN          444 // <user> :User not logged in
#define	ERR_SUMMONDISABLED   445 // :SUMMON has been disabled
#define ERR_USERSDISABLED    446 // :USERS has been disabled

#define ERR_NOTREGISTERED    451 // :You have not registered

#define ERR_HOSTILENAME      455

#define ERR_NEEDMOREPARAMS   461 // <command> :Not enough parameters
#define ERR_ALREADYREGISTRED 462 // :You may not reregister
#define ERR_NOPERMFORHOST    463 // :Your host isn't among the privileged
#define ERR_PASSWDMISMATCH   464 // :Password incorrect
#define ERR_YOUREBANNEDCREEP 465 // :You are banned from this server
#define ERR_YOUWILLBEBANNED  466
#define	ERR_KEYSET           467 // <channel> :Channel key already set
#define ERR_ONLYSERVERSCANCHANGE 468

#define ERR_CHANNELISFULL    471 // <channel> :Cannot join channel (+l)
#define ERR_UNKNOWNMODE      472 // <char> :is unknown mode char to me
#define ERR_INVITEONLYCHAN   473 // <channel> :Cannot join channel (+i)
#define ERR_BANNEDFROMCHAN   474 // <channel> :Cannot join channel (+b)
#define	ERR_BADCHANNELKEY    475 // <channel> :Cannot join channel (+k)
#define	ERR_BADCHANMASK      476
#define ERR_NEEDREGGEDNICK   477
#define ERR_BANLISTFULL      478
#define ERR_NOPRIVILEGES     481 // :Permission Denied- You're not an IRC operator
#define ERR_CHANOPRIVSNEEDED 482 // <channel> :You're not channel operator
#define	ERR_CANTKILLSERVER   483 // :You cant kill a server!
#define ERR_CANTKICKOPER     484 // Undernet extension was ERR_ISCHANSERVICE
#define ERR_CANTKICKADMIN	 485

#define ERR_NOOPERHOST       491 // :No O-lines for your host
#define ERR_NOSERVICEHOST    492

#define ERR_UMODEUNKNOWNFLAG 501 // :Unknown MODE flag
#define ERR_USERSDONTMATCH   502 // :Cant change mode for other users

#define ERR_SILELISTFULL     511
#define ERR_TOOMANYWATCH     512
#define ERR_NEEDPONG         513

#define ERR_LISTSYNTAX       521

static void MVChatConnecting( SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];
	[self performSelectorOnMainThread:@selector( _willConnect ) withObject:nil waitUntilDone:NO];
}

static void MVChatConnected( SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];
	[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:NO];
}

static void MVChatDisconnect( SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];

	[MVIRCChatConnectionThreadLock unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:YES];
	[MVIRCChatConnectionThreadLock lock]; // lock back up like nothing happened
}

static void MVChatConnectFailed( SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];
	if( ! self ) return;

	server_ref( server );

	[MVIRCChatConnectionThreadLock unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:YES];
	[MVIRCChatConnectionThreadLock lock]; // lock back up like nothing happened
}

static void MVChatRawIncomingMessage( SERVER_REC *server, char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:data], @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatRawOutgoingMessage( SERVER_REC *server, char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];
	if( ! self ) return;

//	NSLog( @"self = %x, %s", self, data );
//	NSLog( @"%@", self );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:data], @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatNickTaken( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	if( ((SERVER_REC *)server) -> connected ) {
		// error
		return;
	} else {
		NSString *nick = [self nextAlternateNickname];
		if( nick ) {
			[self sendRawMessage:[NSString stringWithFormat:@"NICK %@", nick] immediately:YES];
			signal_stop();
		}
	}
}

#pragma mark -

static void MVChatJoinedRoom( CHANNEL_REC *channel ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	GSList *nicks = nicklist_getnicks( channel );
	GSList *nickItem = NULL;
	NSMutableArray *nickArray = [NSMutableArray arrayWithCapacity:g_slist_length( nicks )];

	for( nickItem = nicks; nickItem != NULL; nickItem = g_slist_next( nickItem ) ) {
		NICK_REC *nick = nickItem -> data;
		NSMutableDictionary *info = [NSMutableDictionary dictionary];

		[info setObject:[self stringWithEncodedBytes:nick -> nick] forKey:@"nickname"];
		[info setObject:[NSNumber numberWithBool:nick -> serverop] forKey:@"serverOperator"];
		[info setObject:[NSNumber numberWithBool:nick -> op] forKey:@"operator"];
		[info setObject:[NSNumber numberWithBool:nick -> halfop] forKey:@"halfOperator"];
		[info setObject:[NSNumber numberWithBool:nick -> voice] forKey:@"voice"];

		NSString *host = ( nick -> host ? [self stringWithEncodedBytes:nick -> host] : nil );
		if( host ) [info setObject:host forKey:@"address"];

		NSString *realName = ( nick -> realname ? [self stringWithEncodedBytes:nick -> realname] : nil );
		if( realName ) [info setObject:realName forKey:@"realName"];

		[nickArray addObject:info];
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionRoomExistingMemberListNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", nickArray, @"members", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatJoinedWhoList( CHANNEL_REC *channel ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	GSList *nicks = nicklist_getnicks( channel );
	GSList *nickItem = NULL;
	NSMutableArray *nickArray = [NSMutableArray arrayWithCapacity:g_slist_length( nicks )];

	for( nickItem = nicks; nickItem != NULL; nickItem = g_slist_next( nickItem ) ) {
		NICK_REC *nick = nickItem -> data;

		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		[info setObject:[self stringWithEncodedBytes:nick -> nick] forKey:@"nickname"];

		NSString *host = ( nick -> host ? [self stringWithEncodedBytes:nick -> host] : nil );
		if( host ) [info setObject:host forKey:@"address"];

		NSString *realName = ( nick -> realname ? [self stringWithEncodedBytes:nick -> realname] : nil );
		if( realName ) [info setObject:realName forKey:@"realName"];

		[nickArray addObject:info];
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotJoinWhoListNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", nickArray, @"list", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatLeftRoom( CHANNEL_REC *channel ) {
	if( channel -> kicked || channel -> server -> disconnected ) return;

	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatRoomTopicChanged( CHANNEL_REC *channel ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;
	if( ! channel -> topic ) return;

	NSData *msgData = [NSData dataWithBytes:channel -> topic length:strlen( channel -> topic )];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", ( channel -> topic_by ? (id) [self stringWithEncodedBytes:channel -> topic_by] : (id) [NSNull null] ), @"author", ( msgData ? (id) msgData : (id) [NSNull null] ), @"topic", [NSDate dateWithTimeIntervalSince1970:channel -> topic_time], @"time", [NSNumber numberWithBool:( ! channel -> synced )], @"justJoined", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatUserJoinedRoom( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 1, &channel );

	CHANNEL_REC *room = channel_find( (SERVER_REC *) server, channel );
	NICK_REC *nickname = nicklist_find( room, nick );

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) {
		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		goto finish;
	}

	if( ! nickname ) goto finish;

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[self stringWithEncodedBytes:nickname -> nick] forKey:@"nickname"];
	[info setObject:[NSNumber numberWithBool:nickname -> serverop] forKey:@"serverOperator"];
	[info setObject:[NSNumber numberWithBool:nickname -> op] forKey:@"operator"];
	[info setObject:[NSNumber numberWithBool:nickname -> halfop] forKey:@"halfOperator"];
	[info setObject:[NSNumber numberWithBool:nickname -> voice] forKey:@"voice"];
	if( nickname -> host ) [info setObject:[self stringWithEncodedBytes:nickname -> host] forKey:@"address"];
	if( nickname -> realname ) [info setObject:[self stringWithEncodedBytes:nickname -> realname] forKey:@"realName"];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", [self stringWithEncodedBytes:nick], @"who", info, @"info", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

finish:
	g_free( params );
}

static void MVChatUserLeftRoom( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) return;

	char *channel = NULL;
	char *reason = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &channel, &reason );

	NSData *reasonData = [NSData dataWithBytes:reason length:strlen( reason )];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", [self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:address], @"address", ( reasonData ? (id) reasonData : (id) [NSNull null] ), @"reason", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserQuit( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) return;

	if( *data == ':' ) data++;

	NSData *msgData = [NSData dataWithBytes:data length:strlen( data )];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserQuitNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:address], @"address", ( msgData ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatUserKicked( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL, *nick = NULL, *reason = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, &channel, &nick, &reason );

	NSData *msgData = [NSData dataWithBytes:reason length:strlen( reason )];
	NSNotification *note = nil;

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) {
		note = [NSNotification notificationWithName:MVChatConnectionKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", ( by ? (id)[self stringWithEncodedBytes:by] : (id)[NSNull null] ), @"by", ( msgData ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];		
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionUserKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", [self stringWithEncodedBytes:nick], @"who", ( by ? (id)[self stringWithEncodedBytes:by] : (id)[NSNull null] ), @"by", ( msgData ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

static void MVChatInvited( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionInvitedToRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", [self stringWithEncodedBytes:by], @"from", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

static void MVChatUserAway( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *message = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &message );

	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", msgData, @"message", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

#pragma mark -

static void MVChatSelfAwayChanged( IRC_SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	NSNumber *away = [NSNumber numberWithBool:( ((SERVER_REC *)server) -> usermode_away == TRUE )];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:away, @"away", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatGetMessage( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;
	if( ! nick ) return;

	char *target = NULL, *message = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &target, &message );
	if( ! address ) address = "";

	if( *target == '@' && ischannel( target[1] ) ) target = target + 1;

	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];
	NSNotification *note = nil;

	if( ischannel( *target ) ) {
		note = [NSNotification notificationWithName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:target], @"room", [self stringWithEncodedBytes:nick], @"from", msgData, @"message", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"from", msgData, @"message", nil]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatGetAutoMessage( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;
	if( ! nick ) return;

	char *target = NULL, *message = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &target, &message );
	if( ! address ) address = "";

	NSNotification *note = nil;
	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];

	if( ischannel( *target ) ) {
		note = [NSNotification notificationWithName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:target], @"room", [self stringWithEncodedBytes:nick], @"from", [NSNumber numberWithBool:YES], @"auto", msgData, @"message", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"from", [NSNumber numberWithBool:YES], @"auto", msgData, @"message", nil]];
		if( ! strncasecmp( nick, "NickServ", 8 ) && message ) {
			if( strstr( message, nick ) && strstr( message, "IDENTIFY" ) ) {
				if( ! [self nicknamePassword] ) {
					NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
				} else irc_send_cmdv( server, "PRIVMSG %s :IDENTIFY %s", nick, [self encodedBytesWithString:[self nicknamePassword]] );
			} else if( strstr( message, "Password accepted" ) ) {
				[self _nicknameIdentified:YES];
			} else if( strstr( message, "authentication required" ) ) {
				[self _nicknameIdentified:NO];
			}
		}
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatGetActionMessage( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;
	if( ! nick ) return;
	if( ! address ) address = "";

	NSData *msgData = [NSData dataWithBytes:data length:strlen( data )];
	NSNotification *note = nil;

	if( ischannel( *target ) ) {
		note = [NSNotification notificationWithName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:target], @"room", [self stringWithEncodedBytes:nick], @"from", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"from", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatUserNicknameChanged( CHANNEL_REC *channel, NICK_REC *nick, const char *oldnick ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self || ! channel || ! nick ) return;

	NSNotification *note = nil;
	if( ! strcmp( channel -> server -> nick, nick -> nick ) ) {
		note = [NSNotification notificationWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick -> nick], @"nickname", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionUserNicknameChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:oldnick], @"oldNickname", [self stringWithEncodedBytes:nick -> nick], @"newNickname", nil]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatGotUserMode( CHANNEL_REC *channel, NICK_REC *nick, char *by, char *mode, char *type ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	unsigned int m = MVChatMemberNoModes;
	if( *mode == '@' ) m = MVChatMemberOperatorMode;
	else if( *mode == '%' ) m = MVChatMemberHalfOperatorMode;
	else if( *mode == '+' ) m = MVChatMemberVoiceMode;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotMemberModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", [self stringWithEncodedBytes:nick -> nick], @"who", ( by ? (id)[self stringWithEncodedBytes:by] : (id)[NSNull null] ), @"by", [NSNumber numberWithBool:( *type == '+' ? YES : NO )], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatGotRoomMode( CHANNEL_REC *channel, const char *setby ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	unsigned int currentModes = 0;
	if( strchr( channel -> mode, 'p' ) )
		currentModes |= MVChatRoomPrivateMode;
	if( strchr( channel -> mode, 's' ) )
		currentModes |= MVChatRoomSecretMode;
	if( strchr( channel -> mode, 'i' ) )
		currentModes |= MVChatRoomInviteOnlyMode;
	if( strchr( channel -> mode, 'm' ) )
		currentModes |= MVChatRoomModeratedMode;
	if( strchr( channel -> mode, 'n' ) )
		currentModes |= MVChatRoomNoOutsideMessagesMode;
	if( strchr( channel -> mode, 't' ) )
		currentModes |= MVChatRoomSetTopicOperatorOnlyMode;
	if( strchr( channel -> mode, 'k' ) )
		currentModes |= MVChatRoomPasswordRequiredMode;
	if( strchr( channel -> mode, 'l' ) )
		currentModes |= MVChatRoomMemberLimitMode;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRoomModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", [NSNumber numberWithUnsignedInt:currentModes], @"mode", [NSNumber numberWithUnsignedInt:channel -> limit], @"limit", ( channel -> key ? [self stringWithEncodedBytes:channel -> key] : @"" ), @"key", ( setby ? (id)[self stringWithEncodedBytes:setby] : (id)[NSNull null] ), @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatBanNew( CHANNEL_REC *channel, BAN_REC *ban ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNewBanNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", [self stringWithEncodedBytes:ban -> ban], @"ban", ( ban -> setby ? (id)[self stringWithEncodedBytes:ban -> setby] : (id)[NSNull null] ), @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBanRemove( CHANNEL_REC *channel, BAN_REC *ban ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionRemovedBanNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel -> name], @"room", [self stringWithEncodedBytes:ban -> ban], @"ban", ( ban -> setby ? (id)[self stringWithEncodedBytes:ban -> setby] : (id)[NSNull null] ), @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBanlistReceived( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBanlistReceivedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:channel], @"room", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

#pragma mark -

static void MVChatBuddyOnline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	if( awaymsg ) { // Mark the buddy as away
		note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:awaymsg], @"msg", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

static void MVChatBuddyOffline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyAway( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	NSNotification *note = nil;
	if( awaymsg ) note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:awaymsg], @"msg", nil]];
	else note = [NSNotification notificationWithName:MVChatConnectionBuddyIsUnawayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyUnidle( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [NSNumber numberWithLong:0], @"idle", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatUserWhois( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *user = NULL, *host = NULL, *realname = NULL;
	char *params = event_get_params( data, 6 | PARAM_FLAG_GETREST, NULL, &nick, &user, &host, NULL, &realname );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserWhoisNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:user], @"username", [self stringWithEncodedBytes:host], @"hostname", [self stringWithEncodedBytes:realname], @"realname", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserServer( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *serv = NULL, *serverinfo = NULL;
	char *params = event_get_params( data, 4 | PARAM_FLAG_GETREST, NULL, &nick, &serv, &serverinfo );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserServerNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:serv], @"server", [self stringWithEncodedBytes:serverinfo], @"serverinfo", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserChannels( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *chanlist = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &chanlist );

	NSArray *chanArray = [[[self stringWithEncodedBytes:chanlist] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserChannelsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", chanArray, @"channels", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserOperator( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL;
	char *params = event_get_params( data, 2, NULL, &nick );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserOperatorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserIdle( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *idle = NULL, *connected = NULL;
	char *params = event_get_params( data, 4, NULL, &nick, &idle, &connected );

	NSNumber *idleTime = [NSNumber numberWithInt:[[self stringWithEncodedBytes:idle] intValue]];
	NSNumber *connectedTime = [NSNumber numberWithInt:[[self stringWithEncodedBytes:connected] intValue]];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", idleTime, @"idle", connectedTime, @"connected", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserWhoisComplete( IRC_SERVER_REC *server, const char *data ) {
	if( data ) {
		MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
		if( ! self ) return;

		char *nick = NULL;
		char *params = event_get_params( data, 2, NULL, &nick );

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserWhoisCompleteNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

		g_free( params );
	}
}

#pragma mark -

static void MVChatListRoom( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL, *count = NULL, *topic = NULL;
	char *params = event_get_params( data, 4 | PARAM_FLAG_GETREST, NULL, &channel, &count, &topic );

	NSString *r = [self stringWithEncodedBytes:channel];
	NSData *t = [NSData dataWithBytes:topic length:strlen( topic )];
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:strtoul( count, NULL, 10 )], @"users", t, @"topic", [NSDate date], @"cached", r, @"room", nil];

	[self performSelectorOnMainThread:@selector( _addRoomToCache: ) withObject:info waitUntilDone:NO];

	g_free( params );
}

#pragma mark -

static void MVChatSubcodeRequest( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *command = NULL, *args = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &command, &args );

	NSString *cmd = [self stringWithEncodedBytes:command];
	NSString *ags = ( args ? [self stringWithEncodedBytes:args] : nil );
	NSString *frm = [self stringWithEncodedBytes:nick];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeRequest:withArguments:fromUser:forConnection: )];
	[invocation setArgument:&cmd atIndex:2];
	[invocation setArgument:&ags atIndex:3];
	[invocation setArgument:&frm atIndex:4];
	[invocation setArgument:&self atIndex:5];

	// FIX!! Do this on the main thread.
	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) {
		signal_stop();
		return;
	}

	if( ! strcasecmp( command, "VERSION" ) ) {
		NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];
		NSString *reply = [NSString stringWithFormat:@"%@ %@ (%@) - %@ %@ - %@", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [clientVersion objectForKey:@"CFBundleVersion"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductUserVisibleVersion"], [clientVersion objectForKey:@"MVChatCoreCTCPVersionReplyInfo"]];
		[self sendSubcodeReply:@"VERSION" toUser:frm withArguments:reply];
		signal_stop();
		return;
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSubcodeRequestNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frm, @"from", cmd, @"command", ( ags ? (id) ags : (id) [NSNull null] ), @"arguments", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

static void MVChatSubcodeReply( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *command = NULL, *args = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &command, &args );

	NSString *cmd = [self stringWithEncodedBytes:command];
	NSString *ags = ( args ? [self stringWithEncodedBytes:args] : nil );
	NSString *frm = [self stringWithEncodedBytes:nick];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeReply:withArguments:fromUser:forConnection: )];
	[invocation setArgument:&cmd atIndex:2];
	[invocation setArgument:&ags atIndex:3];
	[invocation setArgument:&frm atIndex:4];
	[invocation setArgument:&self atIndex:5];

	// FIX!! Do this on the main thread.
	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) {
		signal_stop();
		return;
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSubcodeReplyNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frm, @"from", cmd, @"command", ( ags ? (id) ags : (id) [NSNull null] ), @"arguments", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

#pragma mark -

static void MVChatFileTransferRequest( DCC_REC *dcc ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)dcc -> server];
	if( ! self ) return;
	if( IS_DCC_GET( dcc ) ) {
		MVIRCDownloadFileTransfer *transfer = [[[MVIRCDownloadFileTransfer alloc] initWithDCCFileRecord:dcc fromConnection:self] autorelease];
		NSNotification *note = [NSNotification notificationWithName:MVDownloadFileTransferOfferNotification object:transfer];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

#pragma mark -

@implementation MVIRCChatConnection
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		MVIRCChatConnectionThreadLock = [[NSRecursiveLock alloc] init];

		irssi_gui = IRSSI_GUI_NONE;

		NSString *temp = NSTemporaryDirectory();
		temp = [temp stringByAppendingPathComponent:@"Colloquy/irssi"];
		temp = [@"--home=" stringByAppendingString:temp];
		char *args[] = { "Chat Core", (char *)[temp cString] };
		core_init_paths( sizeof( args ) / sizeof( char * ), args );

		core_init();
		irc_init();

		settings_set_bool( "override_coredump_limit", FALSE );
		settings_set_bool( "settings_autosave", FALSE );
		signal_emit( "setup changed", 0 );

		signal_emit( "irssi init finished", 0 );	

		[self _registerCallbacks];

		[NSThread detachNewThreadSelector:@selector( _irssiRunLoop ) toTarget:self withObject:nil];
		tooLate = YES;
	}
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_nickIdentified = NO;
		_proxyUsername = nil;
		_proxyPassword = nil;
		_chatConnection = NULL;
		_chatConnectionSettings = NULL;

		extern unsigned int connectionCount;
		connectionCount++;

		[MVIRCChatConnectionThreadLock lock];

		CHAT_PROTOCOL_REC *proto = chat_protocol_find_id( IRC_PROTOCOL );
		if( ! proto ) {
			[MVIRCChatConnectionThreadLock unlock];
			[self release];
			return nil;
		}

		SERVER_CONNECT_REC *settings = server_create_conn( proto -> id, "irc.freenode.net", 6667, NULL, NULL, [self encodedBytesWithString:NSUserName()] );
		if( ! settings ) {
			[MVIRCChatConnectionThreadLock unlock];
			[self release];
			return nil;
		}

		[self _setIrssiConnectSettings:settings];

		[MVIRCChatConnectionThreadLock unlock];
	}

	return self;
}

- (void) dealloc {
	[self disconnect];

	[_proxyUsername release];
	_proxyUsername = nil;

	[_proxyPassword release];
	_proxyPassword = nil;

	[self _setIrssiConnection:NULL];
	[self _setIrssiConnectSettings:NULL];

	extern unsigned int connectionCount;
	connectionCount--;

	[super dealloc];
}

#pragma mark -

- (NSString *) urlScheme {
	return @"irc";
}

#pragma mark -

- (MVChatConnectionType) type {
	return MVChatConnectionIRCType;
}

- (void) connect {
	if( [self status] != MVChatConnectionDisconnectedStatus && [self status] != MVChatConnectionServerDisconnectedStatus && [self status] != MVChatConnectionSuspendedStatus ) return;
	if( ! _chatConnectionSettings ) return;

	if( _lastConnectAttempt && ABS( [_lastConnectAttempt timeIntervalSinceNow] ) < 5. ) {
		// prevents conencting too quick
		// cancel any reconnect attempts, this lets a user cancel the attempts with a "double connect"
		[self cancelPendingReconnectAttempts];
		return;
	}

	[_lastConnectAttempt autorelease];
	_lastConnectAttempt = [[NSDate date] retain];

	[self _willConnect]; // call early so other code has a chance to change our info

	[MVIRCChatConnectionThreadLock lock];

	CHAT_PROTOCOL_REC *proto = chat_protocol_find_id( _chatConnectionSettings -> chat_type );

	if( ! proto ) {
		[self _didNotConnect];
		return;
	}

// Setup the proxy header with the most current connection address and port.
	if( _proxy == MVChatConnectionHTTPSProxy || _proxy == MVChatConnectionHTTPProxy ) {
		NSString *userCombo = [NSString stringWithFormat:@"%@:%@", _proxyUsername, _proxyPassword];
		NSData *combo = [userCombo dataUsingEncoding:NSASCIIStringEncoding];

		g_free_not_null( _chatConnectionSettings -> proxy_string );
		if( [combo length] > 1 ) {
			NSString *userCombo = [combo base64EncodingWithLineLength:0];
			_chatConnectionSettings -> proxy_string = g_strdup_printf( "CONNECT %s:%d HTTP/1.0\r\nProxy-Authorization: Basic %s\r\n\r\n", _chatConnectionSettings -> address, _chatConnectionSettings -> port, [userCombo UTF8String] );
		} else _chatConnectionSettings -> proxy_string = g_strdup_printf( "CONNECT %s:%d HTTP/1.0\r\n\r\n", _chatConnectionSettings -> address, _chatConnectionSettings -> port );

		g_free_not_null( _chatConnectionSettings -> proxy_string_after );
		_chatConnectionSettings -> proxy_string_after = NULL;
	}

	SERVER_REC *newConnection = proto -> server_init_connect( _chatConnectionSettings );
	[self _setIrssiConnection:newConnection];
	if( ! newConnection ) {
		[self _didNotConnect];
		return;
	}

	proto -> server_connect( _chatConnection );

	[MVIRCChatConnectionThreadLock unlock];
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
	[self cancelPendingReconnectAttempts];

	if( ! _chatConnection ) return;
	if( [self status] == MVChatConnectionConnectingStatus ) {
		[self _forceDisconnect];
		return;
	}

	if( [[reason string] length] ) {
		const char *msg = [[self class] _flattenedIRCStringForMessage:reason withEncoding:[self encoding]];
		[self sendRawMessage:[NSString stringWithFormat:@"QUIT :%s", msg] immediately:YES];
	} else [self sendRawMessage:@"QUIT" immediately:YES];

	[MVIRCChatConnectionThreadLock lock];

	_chatConnection -> connection_lost = NO;
	_chatConnection -> no_reconnect = YES;

	server_disconnect( _chatConnection );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	NSParameterAssert( name != nil );
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	g_free_not_null( _chatConnectionSettings -> realname );
	_chatConnectionSettings -> realname = g_strdup( [self encodedBytesWithString:name] );		

	[MVIRCChatConnectionThreadLock unlock];
}

- (NSString *) realName {
	if( ! _chatConnectionSettings ) return nil;
	return [self stringWithEncodedBytes:_chatConnectionSettings -> realname];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	NSParameterAssert( nickname != nil );
	NSParameterAssert( [nickname length] > 0 );
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	g_free_not_null( _chatConnectionSettings -> nick );
	_chatConnectionSettings -> nick = g_strdup( [self encodedBytesWithString:nickname] );		

	[MVIRCChatConnectionThreadLock unlock];

	if( [self isConnected] ) {
		if( ! [nickname isEqualToString:[self nickname]] ) {
			_nickIdentified = NO;
			[self sendRawMessageWithFormat:@"NICK %@", nickname];
		}
	}
}

- (NSString *) nickname {
	if( [self isConnected] && _chatConnection )
		return [self stringWithEncodedBytes:_chatConnection -> nick];
	if( ! _chatConnectionSettings ) return nil;
	return [self stringWithEncodedBytes:_chatConnectionSettings -> nick];
}

- (NSString *) preferredNickname {
	if( ! _chatConnectionSettings ) return nil;
	return [self stringWithEncodedBytes:_chatConnectionSettings -> nick];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
	if( ! _nickIdentified && password && [self isConnected] )
		[self sendRawMessageWithFormat:@"PRIVMSG NickServ :IDENTIFY %@", password];
	[super setNicknamePassword:password];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	g_free_not_null( _chatConnectionSettings -> password );
	if( [password length] ) _chatConnectionSettings -> password = g_strdup( [self encodedBytesWithString:password] );		
	else _chatConnectionSettings -> password = NULL;		

	[MVIRCChatConnectionThreadLock unlock];
}

- (NSString *) password {
	if( ! _chatConnectionSettings ) return nil;
	char *pass = _chatConnectionSettings -> password;
	if( pass ) return [self stringWithEncodedBytes:pass];
	return nil;
}

#pragma mark -

- (void) setUsername:(NSString *) username {
	NSParameterAssert( username != nil );
	NSParameterAssert( [username length] > 0 );
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	g_free_not_null( _chatConnectionSettings -> username );
	_chatConnectionSettings -> username = g_strdup( [self encodedBytesWithString:username] );		

	[MVIRCChatConnectionThreadLock unlock];
}

- (NSString *) username {
	if( ! _chatConnectionSettings ) return nil;
	return [self stringWithEncodedBytes:_chatConnectionSettings -> username];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	NSParameterAssert( server != nil );
	NSParameterAssert( [server length] > 0 );
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	g_free_not_null( _chatConnectionSettings -> address );
	_chatConnectionSettings -> address = g_strdup( [self encodedBytesWithString:server] );		

	[MVIRCChatConnectionThreadLock unlock];
}

- (NSString *) server {
	if( ! _chatConnectionSettings ) return nil;
	return [self stringWithEncodedBytes:_chatConnectionSettings -> address];
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	_chatConnectionSettings -> port = ( port ? port : 6667 );

	[MVIRCChatConnectionThreadLock unlock];
}

- (unsigned short) serverPort {
	if( ! _chatConnectionSettings ) return 0;
	return _chatConnectionSettings -> port;
}

#pragma mark -

- (void) setSecure:(BOOL) ssl {
	if( ! _chatConnectionSettings ) return;
	_chatConnectionSettings -> use_ssl = ssl;
	_chatConnectionSettings -> ssl_verify = NO;
}

- (BOOL) isSecure {
	if( ! _chatConnectionSettings ) return NO;
	return _chatConnectionSettings -> use_ssl;
}

#pragma mark -

- (void) setProxyServer:(NSString *) address {
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	g_free_not_null( _chatConnectionSettings -> proxy );
	_chatConnectionSettings -> proxy = g_strdup( [self encodedBytesWithString:address] );

	[MVIRCChatConnectionThreadLock unlock];
}

- (NSString *) proxyServer {
	if( ! _chatConnectionSettings ) return nil;
	return [self stringWithEncodedBytes:_chatConnectionSettings -> proxy];
}

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port {
	if( ! _chatConnectionSettings ) return;

	[MVIRCChatConnectionThreadLock lock];

	_chatConnectionSettings -> proxy_port = port;

	[MVIRCChatConnectionThreadLock unlock];
}

- (unsigned short) proxyServerPort {
	if( ! _chatConnectionSettings ) return 0;
	return _chatConnectionSettings -> proxy_port;
}

#pragma mark -

- (void) setProxyUsername:(NSString *) username {
	[_proxyUsername autorelease];
	_proxyUsername = [username copy];
}

- (NSString *) proxyUsername {
	return _proxyUsername;
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
	[_proxyPassword autorelease];
	_proxyPassword = [password copy];
}

- (NSString *) proxyPassword {
	return _proxyPassword;
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action {
	NSParameterAssert( message != nil );
	NSParameterAssert( target != nil );
	if( ! _chatConnection ) return;

	const char *msg = [[self class] _flattenedIRCStringForMessage:message withEncoding:encoding];

	[MVIRCChatConnectionThreadLock lock];

	if( ! action ) _chatConnection -> send_message( _chatConnection, [self encodedBytesWithString:target], msg, 0 );
	else irc_send_cmdv( (IRC_SERVER_REC *) _chatConnection, "PRIVMSG %s :\001ACTION %s\001", [self encodedBytesWithString:target], msg );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );
	if( ! _chatConnection ) return;

	[MVIRCChatConnectionThreadLock lock];

	irc_send_cmd_full( (IRC_SERVER_REC *) _chatConnection, [self encodedBytesWithString:raw], now, now, FALSE);

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSParameterAssert( user != nil );
	NSString *request = ( [arguments length] ? [NSString stringWithFormat:@"%@ %@", command, arguments] : command );
	[self sendRawMessageWithFormat:@"PRIVMSG %@ :\001%@\001", user, request];
}

- (void) sendSubcodeReply:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments {
	NSParameterAssert( command != nil );
	NSParameterAssert( user != nil );
	NSString *request = ( [arguments length] ? [NSString stringWithFormat:@"%@ %@", command, arguments] : command );
	[self sendRawMessageWithFormat:@"NOTICE %@ :\001%@\001", user, request];
}

#pragma mark -

- (void) joinChatRooms:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! [rooms count] ) return;

	NSMutableArray *roomList = [NSMutableArray arrayWithCapacity:[rooms count]];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) )
		if( [room length] ) [roomList addObject:[self properNameForChatRoom:room]];

	if( ! [roomList count] ) return;

	[self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
}

- (void) joinChatRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	[self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoom:room]];
}

- (void) partChatRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	[self sendRawMessageWithFormat:@"PART %@", [self properNameForChatRoom:room]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return [NSCharacterSet characterSetWithCharactersInString:@"#&+!"];
}

- (NSString *) displayNameForChatRoom:(NSString *) room {
	if( ! [room length] ) return room;
	return ( [[self chatRoomNamePrefixes] characterIsMember:[room characterAtIndex:0]] ? [room substringFromIndex:1] : room );
}

- (NSString *) properNameForChatRoom:(NSString *) room {
	if( ! [room length] ) return room;
	return ( [[self chatRoomNamePrefixes] characterIsMember:[room characterAtIndex:0]] ? room : [@"#" stringByAppendingString:room] );
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room {
	NSParameterAssert( topic != nil );
	NSParameterAssert( room != nil );
	if( ! _chatConnection ) return;

	const char *msg = [[self class] _flattenedIRCStringForMessage:topic withEncoding:encoding];

	[MVIRCChatConnectionThreadLock lock];

	irc_send_cmdv( (IRC_SERVER_REC *) _chatConnection, "TOPIC %s :%s", [self encodedBytesWithString:room], msg );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +o %@", [self properNameForChatRoom:room], member];
}

- (void) demoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -o %@", [self properNameForChatRoom:room], member];
}

- (void) halfopMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +h %@", [self properNameForChatRoom:room], member];
}

- (void) dehalfopMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -h %@", [self properNameForChatRoom:room], member];
}

- (void) voiceMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +v %@", [self properNameForChatRoom:room], member];
}

- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -v %@", [self properNameForChatRoom:room], member];
}

- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( reason ) [self sendRawMessageWithFormat:@"KICK %@ %@ :%@", [self properNameForChatRoom:room], member, reason];
	else [self sendRawMessageWithFormat:@"KICK %@ %@", [self properNameForChatRoom:room], member];		
}

- (void) banMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +b %@", [self properNameForChatRoom:room], member];
}

- (void) unbanMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -b %@", [self properNameForChatRoom:room], member];
}

#pragma mark -

- (void) addUserToNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );

	[MVIRCChatConnectionThreadLock lock];

	notifylist_add( [self encodedBytesWithString:[NSString stringWithFormat:@"%@!*@*", user]], NULL, TRUE, 600 );

	[MVIRCChatConnectionThreadLock unlock];
}

- (void) removeUserFromNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );

	[MVIRCChatConnectionThreadLock lock];

	notifylist_remove( [self encodedBytesWithString:[NSString stringWithFormat:@"%@!*@*", user]] );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) fetchInformationForUser:(NSString *) user withPriority:(BOOL) priority fromLocalServer:(BOOL) localOnly {
	NSParameterAssert( user != nil );
	if( localOnly ) [self sendRawMessageWithFormat:@"WHOIS %@", user];
	else [self sendRawMessageWithFormat:@"WHOIS %@ %@", user, user];
}

#pragma mark -

- (void) fetchRoomList {
	if( ! _cachedDate || [_cachedDate timeIntervalSinceNow] < -900. ) {
		[self sendRawMessage:@"LIST"];
		[_cachedDate autorelease];
		_cachedDate = [[NSDate date] retain];
	}
}

- (void) fetchRoomListWithRooms:(NSArray *) rooms {
	[self sendRawMessageWithFormat:@"LIST %@", [rooms componentsJoinedByString:@","]];
}

- (void) stopFetchingRoomList {
	[self sendRawMessage:@"LIST STOP"];
}

#pragma mark -

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	[_awayMessage autorelease];
	_awayMessage = nil;

	if( [[message string] length] ) {
		_awayMessage = [message copy];
		const char *msg = [[self class] _flattenedIRCStringForMessage:message withEncoding:[self encoding]];

		[MVIRCChatConnectionThreadLock lock];

		irc_send_cmdv( (IRC_SERVER_REC *) _chatConnection, "AWAY :%s", msg );

		[MVIRCChatConnectionThreadLock unlock];
	} else [self sendRawMessage:@"AWAY"];
}

#pragma mark -

- (unsigned int) lag {
	if( ! _chatConnection ) return 0;
	return _chatConnection -> lag;
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionPrivate)
+ (MVIRCChatConnection *) _connectionForServer:(SERVER_REC *) server {
	if( ! server ) return nil;

	MVChatConnectionModuleData *data = MODULE_DATA( server );
	if( data ) return data -> connection;

	return nil;
}

+ (void) _registerCallbacks {
	signal_add_last( "server looking", (SIGNAL_FUNC) MVChatConnecting );
	signal_add_last( "server connected", (SIGNAL_FUNC) MVChatConnected );
	signal_add_last( "server disconnected", (SIGNAL_FUNC) MVChatDisconnect );
	signal_add_last( "server connect failed", (SIGNAL_FUNC) MVChatConnectFailed );

	signal_add( "server incoming", (SIGNAL_FUNC) MVChatRawIncomingMessage );
	signal_add( "server outgoing", (SIGNAL_FUNC) MVChatRawOutgoingMessage );

	signal_add_last( "channel joined", (SIGNAL_FUNC) MVChatJoinedRoom );
	signal_add_last( "channel wholist", (SIGNAL_FUNC) MVChatJoinedWhoList );
	signal_add_last( "channel topic changed", (SIGNAL_FUNC) MVChatRoomTopicChanged );
	signal_add_last( "channel destroyed", (SIGNAL_FUNC) MVChatLeftRoom );
	signal_add_last( "channel mode changed", (SIGNAL_FUNC) MVChatGotRoomMode );

	signal_add_last( "ban new", (SIGNAL_FUNC) MVChatBanNew );
	signal_add_last( "ban remove", (SIGNAL_FUNC) MVChatBanRemove );
	signal_add_last( "chanquery ban end", (SIGNAL_FUNC) MVChatBanlistReceived );

	signal_add_last( "event join", (SIGNAL_FUNC) MVChatUserJoinedRoom );
	signal_add_last( "event part", (SIGNAL_FUNC) MVChatUserLeftRoom );
	signal_add_last( "event quit", (SIGNAL_FUNC) MVChatUserQuit );
	signal_add_last( "event kick", (SIGNAL_FUNC) MVChatUserKicked );
	signal_add_last( "event invite", (SIGNAL_FUNC) MVChatInvited );
	signal_add_last( "event 301", (SIGNAL_FUNC) MVChatUserAway );

	signal_add_last( "event privmsg", (SIGNAL_FUNC) MVChatGetMessage );
	signal_add_last( "event notice", (SIGNAL_FUNC) MVChatGetAutoMessage );
	signal_add_last( "ctcp action", (SIGNAL_FUNC) MVChatGetActionMessage );

	signal_add_last( "nicklist changed", (SIGNAL_FUNC) MVChatUserNicknameChanged );
	signal_add_last( "nick mode changed", (SIGNAL_FUNC) MVChatGotUserMode );

	signal_add_last( "away mode changed", (SIGNAL_FUNC) MVChatSelfAwayChanged );

	signal_add_last( "notifylist joined", (SIGNAL_FUNC) MVChatBuddyOnline );
	signal_add_last( "notifylist left", (SIGNAL_FUNC) MVChatBuddyOffline );
	signal_add_last( "notifylist away changed", (SIGNAL_FUNC) MVChatBuddyAway );
	signal_add_last( "notifylist unidle", (SIGNAL_FUNC) MVChatBuddyUnidle );

	signal_add_last( "event 311", (SIGNAL_FUNC) MVChatUserWhois );
	signal_add_last( "event 312", (SIGNAL_FUNC) MVChatUserServer );
	signal_add_last( "event 313", (SIGNAL_FUNC) MVChatUserOperator );
	signal_add_last( "event 317", (SIGNAL_FUNC) MVChatUserIdle );
	signal_add_last( "event 318", (SIGNAL_FUNC) MVChatUserWhoisComplete );
	signal_add_last( "event 319", (SIGNAL_FUNC) MVChatUserChannels );

	// And to catch the notifylist whois ones as well
	signal_add_last( "notifylist event whois end", (SIGNAL_FUNC) MVChatUserWhoisComplete );
	signal_add_last( "notifylist event whois away", (SIGNAL_FUNC) MVChatUserAway );
	signal_add_last( "notifylist event whois", (SIGNAL_FUNC) MVChatUserWhois );
	signal_add_last( "notifylist event whois idle", (SIGNAL_FUNC) MVChatUserIdle );

	signal_add_last( "event 322", (SIGNAL_FUNC) MVChatListRoom );

	signal_add_first( "ctcp msg", (SIGNAL_FUNC) MVChatSubcodeRequest );
	signal_add_first( "ctcp reply", (SIGNAL_FUNC) MVChatSubcodeReply );

	signal_add_last( "dcc request", (SIGNAL_FUNC) MVChatFileTransferRequest );

	signal_add_first( "event 433", (SIGNAL_FUNC) MVChatNickTaken );
}

+ (void) _deregisterCallbacks {
	signal_remove( "server looking", (SIGNAL_FUNC) MVChatConnecting );
	signal_remove( "server connected", (SIGNAL_FUNC) MVChatConnected );
	signal_remove( "server disconnected", (SIGNAL_FUNC) MVChatDisconnect );
	signal_remove( "server connect failed", (SIGNAL_FUNC) MVChatConnectFailed );

	signal_remove( "server incoming", (SIGNAL_FUNC) MVChatRawIncomingMessage );
	signal_remove( "server outgoing", (SIGNAL_FUNC) MVChatRawOutgoingMessage );

	signal_remove( "channel joined", (SIGNAL_FUNC) MVChatJoinedRoom );
	signal_remove( "channel wholist", (SIGNAL_FUNC) MVChatJoinedWhoList );
	signal_remove( "channel destroyed", (SIGNAL_FUNC) MVChatLeftRoom );
	signal_remove( "channel topic changed", (SIGNAL_FUNC) MVChatRoomTopicChanged );
	signal_remove( "channel mode changed", (SIGNAL_FUNC) MVChatGotRoomMode );

	signal_remove( "ban new", (SIGNAL_FUNC) MVChatBanNew );
	signal_remove( "ban remove", (SIGNAL_FUNC) MVChatBanRemove );
	signal_remove( "chanquery ban end", (SIGNAL_FUNC) MVChatBanlistReceived );

	signal_remove( "event join", (SIGNAL_FUNC) MVChatUserJoinedRoom );
	signal_remove( "event part", (SIGNAL_FUNC) MVChatUserLeftRoom );
	signal_remove( "event quit", (SIGNAL_FUNC) MVChatUserQuit );
	signal_remove( "event kick", (SIGNAL_FUNC) MVChatUserKicked );
	signal_remove( "event invite", (SIGNAL_FUNC) MVChatInvited );
	signal_remove( "event 301", (SIGNAL_FUNC) MVChatUserAway );

	signal_remove( "event privmsg", (SIGNAL_FUNC) MVChatGetMessage );
	signal_remove( "event notice", (SIGNAL_FUNC) MVChatGetAutoMessage );
	signal_remove( "ctcp action", (SIGNAL_FUNC) MVChatGetActionMessage );

	signal_remove( "nicklist changed", (SIGNAL_FUNC) MVChatUserNicknameChanged );
	signal_remove( "nick mode changed", (SIGNAL_FUNC) MVChatGotUserMode );

	signal_remove( "away mode changed", (SIGNAL_FUNC) MVChatSelfAwayChanged );

	signal_remove( "notifylist joined", (SIGNAL_FUNC) MVChatBuddyOnline );
	signal_remove( "notifylist left", (SIGNAL_FUNC) MVChatBuddyOffline );
	signal_remove( "notifylist away changed", (SIGNAL_FUNC) MVChatBuddyAway );
	signal_remove( "notifylist unidle", (SIGNAL_FUNC) MVChatBuddyUnidle );

	signal_remove( "event 311", (SIGNAL_FUNC) MVChatUserWhois );
	signal_remove( "event 312", (SIGNAL_FUNC) MVChatUserServer );
	signal_remove( "event 313", (SIGNAL_FUNC) MVChatUserOperator );
	signal_remove( "event 317", (SIGNAL_FUNC) MVChatUserIdle );
	signal_remove( "event 318", (SIGNAL_FUNC) MVChatUserWhoisComplete );
	signal_remove( "event 319", (SIGNAL_FUNC) MVChatUserChannels );

	signal_remove( "event 322", (SIGNAL_FUNC) MVChatListRoom );

	signal_remove( "ctcp msg", (SIGNAL_FUNC) MVChatSubcodeRequest );
	signal_remove( "ctcp reply", (SIGNAL_FUNC) MVChatSubcodeReply );

	signal_remove( "dcc request", (SIGNAL_FUNC) MVChatFileTransferRequest );

	signal_remove( "event 433", (SIGNAL_FUNC) MVChatNickTaken );
}

+ (const char *) _flattenedIRCStringForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:enc], @"StringEncoding", [NSNumber numberWithBool:YES], @"NullTerminatedReturn", nil];
	NSData *data = [message IRCFormatWithOptions:options];
	return [data bytes];
}

+ (void) _irssiRunLoop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	extern GMainLoop *glibMainLoop;
	glibMainLoop = g_main_new( TRUE );

	extern BOOL MVChatApplicationQuitting;
	extern unsigned int connectionCount;
	while( ! MVChatApplicationQuitting || connectionCount ) {
		if( [MVIRCChatConnectionThreadLock tryLock] ) { // prevents some deadlocks
			g_main_iteration( TRUE ); // this will block if TRUE is passed
			[MVIRCChatConnectionThreadLock unlock];
		}

		usleep( 500 ); // give time for other theads to lock
	}

	[MVIRCChatConnectionThreadLock lock];

	[self _deregisterCallbacks];

	signal_emit( "gui exit", 0 );

	g_main_destroy( glibMainLoop );
	glibMainLoop = NULL;

	irc_deinit();
	core_deinit();

	[MVIRCChatConnectionThreadLock unlock];

	[pool release];
}

#pragma mark -

- (SERVER_REC *) _irssiConnection {
	return _chatConnection;
}

- (void) _setIrssiConnection:(SERVER_REC *) server {
	[MVIRCChatConnectionThreadLock lock];

//	NSLog( @"_setIrssiConnection %@ %x", self, server );

	SERVER_REC *old = _chatConnection;

	if( old ) {
		MVChatConnectionModuleData *data = MODULE_DATA( old );
		if( data ) memset( &data, 0, sizeof( MVChatConnectionModuleData ) );
		g_free_not_null( data );
	}

	_chatConnection = server;

	if( _chatConnection ) {
		server_ref( _chatConnection );

		MVChatConnectionModuleData *data = g_new0( MVChatConnectionModuleData, 1 );
		data -> connection = self;

		MODULE_DATA_SET( server, data );

		((SERVER_REC *) _chatConnection) -> no_reconnect = 1;
	}

	if( old ) server_unref( old );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (SERVER_CONNECT_REC *) _irssiConnectSettings {
	return _chatConnectionSettings;
}

- (void) _setIrssiConnectSettings:(SERVER_CONNECT_REC *) settings {
	[MVIRCChatConnectionThreadLock lock];

	SERVER_CONNECT_REC *old = _chatConnectionSettings;
	_chatConnectionSettings = settings;

	if( _chatConnectionSettings ) {
		server_connect_ref( (SERVER_CONNECT_REC *) _chatConnectionSettings );

		((SERVER_CONNECT_REC *) _chatConnectionSettings) -> no_autojoin_channels = TRUE;
	}

	if( old ) server_connect_unref( old );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) _nicknameIdentified:(BOOL) identified {
	_nickIdentified = identified;
}

- (void) _didDisconnect {
	if( _chatConnection -> connection_lost ) {
		if( _status != MVChatConnectionSuspendedStatus )
			_status = MVChatConnectionServerDisconnectedStatus;
		if( ABS( [_lastConnectAttempt timeIntervalSinceNow] ) > 300. )
			[self performSelector:@selector( connect ) withObject:nil afterDelay:5.];
		[self scheduleReconnectAttemptEvery:30.];
	} else if( _status != MVChatConnectionSuspendedStatus ) {
		_status = MVChatConnectionDisconnectedStatus;
	}

	[super _didDisconnect];

	[self _setIrssiConnection:NULL];
}

- (void) _forceDisconnect {
	if( ! _chatConnection ) return;

	[self _willDisconnect];

	[MVIRCChatConnectionThreadLock lock];

	if( _chatConnection -> handle ) {
		g_io_channel_unref( net_sendbuffer_handle( _chatConnection -> handle ) );
		net_sendbuffer_destroy( _chatConnection -> handle, FALSE);
		_chatConnection -> handle = NULL;
	}

	_chatConnection -> connection_lost = FALSE;
	_chatConnection -> no_reconnect = FALSE;

	server_disconnect( _chatConnection );

	[super _didDisconnect];

	[self _setIrssiConnection:NULL];

	[MVIRCChatConnectionThreadLock unlock];
}
@end