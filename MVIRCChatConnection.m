#import <unistd.h>
#import <pthread.h>

#define HAVE_IPV6 1
#define MODULE_NAME "MVIRCChatConnection"

#import "MVIRCChatConnection.h"
#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCFileTransfer.h"

#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"

#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSDataAdditions.h"

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

static const NSStringEncoding supportedEncodings[] = {
	/* Universal */
	NSUTF8StringEncoding,
	NSNonLossyASCIIStringEncoding,
	/* Western */
	NSASCIIStringEncoding,
	NSISOLatin1StringEncoding,			// ISO Latin 1
	(NSStringEncoding) 0x80000203,		// ISO Latin 3
	(NSStringEncoding) 0x8000020F,		// ISO Latin 9
	NSMacOSRomanStringEncoding,			// Mac
	NSWindowsCP1252StringEncoding,		// Windows
	/* European */
	NSISOLatin2StringEncoding,			// ISO Latin 2
	(NSStringEncoding) 0x80000204,		// ISO Latin 4
	(NSStringEncoding) 0x8000001D,		// Mac
	NSWindowsCP1250StringEncoding,		// Windows
	/* Cyrillic */
	(NSStringEncoding) 0x80000A02,		// KOI8-R
	(NSStringEncoding) 0x80000205,		// ISO Latin 5
	(NSStringEncoding) 0x80000007,		// Mac
	NSWindowsCP1251StringEncoding,		// Windows
	/* Japanese */
	(NSStringEncoding) 0x80000A01,		// ShiftJIS
	NSISO2022JPStringEncoding,			// ISO-2022-JP
	NSJapaneseEUCStringEncoding,		// EUC
	(NSStringEncoding) 0x80000001,		// Mac
	NSShiftJISStringEncoding,			// Windows
	/* Simplified Chinese */
	(NSStringEncoding) 0x80000632,		// GB 18030
	(NSStringEncoding) 0x80000631,		// GBK
	(NSStringEncoding) 0x80000930,		// EUC
	(NSStringEncoding) 0x80000019,		// Mac
	(NSStringEncoding) 0x80000421,		// Windows
	/* Traditional Chinese */
	(NSStringEncoding) 0x80000A03,		// Big5
	(NSStringEncoding) 0x80000A06,		// Big5 HKSCS
	(NSStringEncoding) 0x80000931,		// EUC
	(NSStringEncoding) 0x80000002,		// Mac
	(NSStringEncoding) 0x80000423,		// Windows
	/* Korean */
	(NSStringEncoding) 0x80000940,		// EUC
	(NSStringEncoding) 0x80000003,		// Mac
	(NSStringEncoding) 0x80000422,		// Windows
	/* Hebrew */
	(NSStringEncoding) 0x80000208,		// ISO-8859-8
	(NSStringEncoding) 0x80000005,		// Mac
	(NSStringEncoding) 0x80000505,		// Windows
	0
};

typedef struct {
	MVIRCChatConnection *connection;
} MVIRCChatConnectionModuleData;

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

	if( ! pthread_main_np() ) { // if not main thread
		[MVIRCChatConnectionThreadLock unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
		[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:YES];
		[MVIRCChatConnectionThreadLock lock]; // lock back up like nothing happened
	} else [self performSelector:@selector( _didDisconnect )];
}

static void MVChatConnectFailed( SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:server];
	if( ! self ) return;

	server_ref( server );

	if( ! pthread_main_np() ) { // if not main thread
		[MVIRCChatConnectionThreadLock unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
		[self performSelectorOnMainThread:@selector( _didNotConnect ) withObject:nil waitUntilDone:YES];
		[MVIRCChatConnectionThreadLock lock]; // lock back up like nothing happened
	} else [self performSelector:@selector( _didNotConnect )];
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

static void MVChatNickFinal( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	// incase our nickname changes since we started
	[[self localUser] _setUniqueIdentifier:[[self nickname] lowercaseString]];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatJoinedRoom( CHANNEL_REC *channel ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	if( ! room ) {
		room = [[[MVIRCChatRoom allocWithZone:[self zone]] initWithName:[self stringWithEncodedBytes:channel -> name] andConnection:self] autorelease];
		[self _addJoinedRoom:room];
	}

	[room _setDateJoined:[NSDate date]];
	[room _setDateParted:nil];
	[room _clearMemberUsers];
	[room _clearBannedUsers];

	GSList *nicks = nicklist_getnicks( channel );
	GSList *nickItem = NULL;

	for( nickItem = nicks; nickItem != NULL; nickItem = g_slist_next( nickItem ) ) {
		NICK_REC *nick = nickItem -> data;
		MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick -> nick]];

		[room _addMemberUser:member];

		if( nick -> op ) [room _setMode:MVChatRoomMemberOperatorMode forMemberUser:member];
		if( nick -> halfop ) [room _setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:member];
		if( nick -> voice ) [room _setMode:MVChatRoomMemberVoicedMode forMemberUser:member];
	}

	NSData *topic = ( channel -> topic ? [NSData dataWithBytes:channel -> topic length:strlen( channel -> topic )] : nil );
	NSString *author = ( channel -> topic_by ? [self stringWithEncodedBytes:channel -> topic_by] : nil );
	MVChatUser *authorUser = ( author ? [self chatUserWithUniqueIdentifier:author] : nil );
	NSDate *time = ( channel -> topic_time ? [NSDate dateWithTimeIntervalSince1970:channel -> topic_time] : nil );

	[room _setTopic:topic byAuthor:authorUser withDate:time];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomJoinedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatJoinedWhoList( CHANNEL_REC *channel ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	GSList *nicks = nicklist_getnicks( channel );
	GSList *nickItem = NULL;

	for( nickItem = nicks; nickItem != NULL; nickItem = g_slist_next( nickItem ) ) {
		NICK_REC *nick = nickItem -> data;
		MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick -> nick]];

		if( nick -> realname ) [member _setRealName:[self stringWithEncodedBytes:nick -> realname]];
		[member _setServerOperator:nick -> serverop];

		if( nick -> host ) {
			NSString *hostmask = [self stringWithEncodedBytes:nick -> host];
			NSArray *parts = [hostmask componentsSeparatedByString:@"@"];
			if( [parts count] == 2 ) {
				[member _setUsername:[parts objectAtIndex:0]];
				[member _setAddress:[parts objectAtIndex:1]];
			}
		}
	}

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	if( ! room ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomMemberUsersSyncedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatLeftRoom( CHANNEL_REC *channel ) {
	if( channel -> kicked || channel -> server -> disconnected ) return;

	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	[room _setDateParted:[NSDate date]];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomPartedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatRoomTopicChanged( CHANNEL_REC *channel ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;
	if( ! channel -> topic ) return;

	NSData *msgData = [NSData dataWithBytes:channel -> topic length:strlen( channel -> topic )];
	NSString *author = ( channel -> topic_by ? [self stringWithEncodedBytes:channel -> topic_by] : nil );
	MVChatUser *authorUser = ( author ? [self chatUserWithUniqueIdentifier:author] : nil );
	NSDate *time = ( channel -> topic_time ? [NSDate dateWithTimeIntervalSince1970:channel -> topic_time] : nil );

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	[room _setTopic:msgData byAuthor:authorUser withDate:time];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomTopicChangedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatUserJoinedRoom( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 1, &channel );

	CHANNEL_REC *chan = channel_find( (SERVER_REC *) server, channel );
	NICK_REC *nickname = nicklist_find( chan, nick );

	if( ! nickname ) goto finish;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel]];
	MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];

	[room _addMemberUser:member];

	if( nickname -> op ) [room _setMode:MVChatRoomMemberOperatorMode forMemberUser:member];
	if( nickname -> halfop ) [room _setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:member];
	if( nickname -> voice ) [room _setMode:MVChatRoomMemberVoicedMode forMemberUser:member];

	if( nickname -> realname ) [member _setRealName:[self stringWithEncodedBytes:nickname -> realname]];
	[member _setServerOperator:nickname -> serverop];

	if( nickname -> host ) {
		NSString *hostmask = [self stringWithEncodedBytes:nickname -> host];
		NSArray *parts = [hostmask componentsSeparatedByString:@"@"];
		if( [parts count] == 2 ) {
			[member _setUsername:[parts objectAtIndex:0]];
			[member _setAddress:[parts objectAtIndex:1]];
		}
	}

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserJoinedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", nil]];
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

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel]];
	MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[room _removeMemberUser:member];

	NSData *reasonData = [NSData dataWithBytes:reason length:strlen( reason )];
	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserQuit( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) return;

	if( *data == ':' ) data++;

	MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	NSData *reasonData = [NSData dataWithBytes:data length:strlen( data )];
	NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
	MVChatRoom *room = nil;

	[member _setDateDisconnected:[NSDate date]];

	while( ( room = [enumerator nextObject] ) ) {
		if( ! [room isJoined] || ! [room hasUser:member] ) continue;
		[room _removeMemberUser:member];
		NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", reasonData, @"reason", nil]];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

static void MVChatUserKicked( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL, *nick = NULL, *reason = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, &channel, &nick, &reason );

	NSData *msgData = [NSData dataWithBytes:reason length:strlen( reason )];
	NSNotification *note = nil;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel]];
	MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	MVChatUser *byMember = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:by]];
	[room _removeMemberUser:member];

	if( [[self nickname] isEqualToString:[self stringWithEncodedBytes:nick]] ) {
		[room _setDateParted:[NSDate date]];
		note = [NSNotification notificationWithName:MVChatRoomKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:byMember, @"byUser", msgData, @"reason", nil]];		
	} else {
		note = [NSNotification notificationWithName:MVChatRoomUserKickedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"user", byMember, @"byUser", msgData, @"reason", nil]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

static void MVChatInvited( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:by]];
	NSNotification *note = [NSNotification notificationWithName:MVChatRoomInvitedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", [self stringWithEncodedBytes:channel], @"room", nil]];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

static void MVChatUserAway( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *message = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &message );

//	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];

//	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", msgData, @"message", nil]];		
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );	
}

#pragma mark -

static void MVChatSelfAwayChanged( IRC_SERVER_REC *server ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusChangedNotification object:self userInfo:nil];
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
		MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:target]];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		note = [NSNotification notificationWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", msgData, @"message", nil]];
	} else {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", nil]];
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
		MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:target]];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		if( ! user ) user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		note = [NSNotification notificationWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", msgData, @"message", [NSNumber numberWithBool:YES], @"auto", nil]];
	} else {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"auto", msgData, @"message", nil]];
		if( ! strncasecmp( nick, "NickServ", 8 ) && message ) {
			if( strstr( message, nick ) && strstr( message, "IDENTIFY" ) ) {
				if( ! [self nicknamePassword] ) {
					NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
					[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
				} else irc_send_cmdv( server, "PRIVMSG %s :IDENTIFY %s", nick, [self encodedBytesWithString:[self nicknamePassword]] );
			} else if( strstr( message, "Password accepted" ) ) {
				[[self localUser] _setIdentified:YES];
			} else if( strstr( message, "authentication required" ) ) {
				[[self localUser] _setIdentified:NO];
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
		MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:target]];
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		if( ! user ) user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		note = [NSNotification notificationWithName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", msgData, @"message", [NSNumber numberWithBool:YES], @"action", nil]];
	} else {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", [NSNumber numberWithBool:YES], @"action", nil]];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatUserNicknameChanged( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *newNick = NULL;
	char *params = event_get_params( data, 1, &newNick );

	NSNotification *note = nil;
	MVChatUser *user = nil;

	if( ! strcasecmp( ((SERVER_REC *)server) -> nick, newNick ) ) user = [self localUser];
	else user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];

	if( ! user ) return;

	NSString *nickname = [self stringWithEncodedBytes:newNick];
	NSString *oldNickname = [self stringWithEncodedBytes:nick];

	if( [user isLocalUser] ) {
		[user _setIdentified:NO];
		[user _setUniqueIdentifier:[nickname lowercaseString]];
		note = [NSNotification notificationWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:nil];
	} else {
		[self _updateKnownUser:user withNewNickname:nickname];
		note = [NSNotification notificationWithName:MVChatUserNicknameChangedNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:oldNickname, @"oldNickname", nil]];
	}

	NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
	MVChatRoom *room = nil;

	while( ( room = [enumerator nextObject] ) ) {
		if( ! [room isJoined] || ! [room hasUser:user] ) continue;
		[room _updateMemberUser:user fromOldNickname:oldNickname];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatGotUserMode( CHANNEL_REC *channel, NICK_REC *nick, char *by, char *mode, char *type ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *member = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick -> nick]];
	MVChatUser *byMember = ( by ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:by]] : nil );

	unsigned int m = MVChatRoomMemberNoModes;
	if( *mode == '@' ) m = MVChatRoomMemberOperatorMode;
	else if( *mode == '%' ) m = MVChatRoomMemberHalfOperatorMode;
	else if( *mode == '+' ) m = MVChatRoomMemberVoicedMode;

	if( m == MVChatRoomMemberNoModes ) return;

	if( *type == '+' ) [room _setMode:m forMemberUser:member];
	else [room _removeMode:m forMemberUser:member];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:member, @"who", [NSNumber numberWithBool:( *type == '+' ? YES : NO )], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", byMember, @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatGotRoomMode( CHANNEL_REC *channel, const char *setby ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self ) return;

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *byMember = ( setby ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:setby]] : nil );

	unsigned int oldModes = [room modes];

	[room _clearModes];

	if( strchr( channel -> mode, 'p' ) )
		[room _setMode:MVChatRoomPrivateMode withAttribute:nil];

	if( strchr( channel -> mode, 's' ) )
		[room _setMode:MVChatRoomSecretMode withAttribute:nil];

	if( strchr( channel -> mode, 'i' ) )
		[room _setMode:MVChatRoomInviteOnlyMode withAttribute:nil];

	if( strchr( channel -> mode, 'm' ) )
		[room _setMode:MVChatRoomNormalUsersSilencedMode withAttribute:nil];

	if( strchr( channel -> mode, 'n' ) )
		[room _setMode:MVChatRoomNoOutsideMessagesMode withAttribute:nil];

	if( strchr( channel -> mode, 't' ) )
		[room _setMode:MVChatRoomOperatorsOnlySetTopicMode withAttribute:nil];

	if( strchr( channel -> mode, 'k' ) )
		[room _setMode:MVChatRoomPassphraseToJoinMode withAttribute:[self stringWithEncodedBytes:channel -> key]];

	if( strchr( channel -> mode, 'l' ) )
		[room _setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:[NSNumber numberWithInt:channel -> limit]];

	unsigned int changedModes = ( oldModes ^ [room modes] );

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomModeChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:changedModes], @"changedModes", byMember, @"by", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatBanNew( CHANNEL_REC *channel, BAN_REC *ban ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self || ! ban || ! ban -> ban ) return;

	NSString *banString = [self stringWithEncodedBytes:ban -> ban];
	NSArray *parts = [banString componentsSeparatedByString:@"!"];
	NSString *nickname = ( [parts count] >= 1 ? [parts objectAtIndex:0] : nil );
	NSString *host = ( [parts count] >= 2 ? [parts objectAtIndex:1] : nil );
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:nickname andHostMask:host];

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *byMember = ( ban -> setby ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:ban -> setby]] : nil );

	[room _addBanForUser:user];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserBannedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", byMember, @"byUser", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBanRemove( CHANNEL_REC *channel, BAN_REC *ban, const char *who ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:channel -> server];
	if( ! self || ! ban || ! ban -> ban ) return;

	NSString *banString = [self stringWithEncodedBytes:ban -> ban];
	NSArray *parts = [banString componentsSeparatedByString:@"!"];
	NSString *nickname = ( [parts count] >= 1 ? [parts objectAtIndex:0] : nil );
	NSString *host = ( [parts count] >= 2 ? [parts objectAtIndex:1] : nil );
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:nickname andHostMask:host];

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel -> name]];
	MVChatUser *byMember = ( who ? [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:who]] : nil );

	[room _removeBanForUser:user];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomUserBanRemovedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", byMember, @"byUser", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBanListFinished( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	MVChatRoom *room = [self joinedChatRoomWithName:[self stringWithEncodedBytes:channel]];
	g_free( params );

	if( ! room ) return;

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomBannedUsersSyncedNotification object:room userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];	
}

#pragma mark -

static void MVChatBuddyOnline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

//	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	if( awaymsg ) { // Mark the buddy as away
//		note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:awaymsg], @"msg", nil]];
//		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

static void MVChatBuddyOffline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

//	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyAway( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

//	NSNotification *note = nil;
//	if( awaymsg ) note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [self stringWithEncodedBytes:awaymsg], @"msg", nil]];
//	else note = [NSNotification notificationWithName:MVChatConnectionBuddyIsUnawayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyUnidle( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

//	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", [NSNumber numberWithLong:0], @"idle", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

static void MVChatUserWhois( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *username = NULL, *host = NULL, *realname = NULL;
	char *params = event_get_params( data, 6 | PARAM_FLAG_GETREST, NULL, &nick, &username, &host, NULL, &realname );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setServerOperator:NO]; // set these to off/nil now so we get the true values later in the WHOIS

	[user _setRealName:[self stringWithEncodedBytes:realname]];
	[user _setUsername:[self stringWithEncodedBytes:username]];
	[user _setAddress:[self stringWithEncodedBytes:host]];

	g_free( params );
}

static void MVChatUserServer( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *serv = NULL, *serverinfo = NULL;
	char *params = event_get_params( data, 4 | PARAM_FLAG_GETREST, NULL, &nick, &serv, &serverinfo );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setServerAddress:[self stringWithEncodedBytes:serv]];

	g_free( params );
}

static void MVChatUserChannels( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *chanlist = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &chanlist );

	NSArray *chanArray = [[[self stringWithEncodedBytes:chanlist] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[chanArray count]];
	NSEnumerator *enumerator = [chanArray objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) ) {
		room = [[self stringWithEncodedBytes:chanlist] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\%+"]];
		if( room ) [results addObject:room];
	}

	if( [results count] ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		[user _setAttribute:results forKey:MVChatUserKnownRoomsAttribute];
	}

	g_free( params );
}

static void MVChatUserIdentified( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *info = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &info );

	if( info && strstr( info, "identified" ) ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		[user _setIdentified:YES];
	}

	g_free( params );
}

static void MVChatUserOperator( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL;
	char *params = event_get_params( data, 2, NULL, &nick );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setServerOperator:YES];

	g_free( params );
}

static void MVChatUserIdle( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *idle = NULL, *connected = NULL;
	char *params = event_get_params( data, 4, NULL, &nick, &idle, &connected );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setIdleTime:[[self stringWithEncodedBytes:idle] intValue]];
	if( [[self stringWithEncodedBytes:connected] intValue] > 631138520 ) // prevent showing 34+ years connected time, this makes sure it is a viable date
		[user _setDateConnected:[NSDate dateWithTimeIntervalSince1970:[[self stringWithEncodedBytes:connected] intValue]]];
	else [user _setDateConnected:nil];

	NSNotification *note = [NSNotification notificationWithName:MVChatUserIdleTimeUpdatedNotification object:user userInfo:nil];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserWhoisComplete( IRC_SERVER_REC *server, const char *data ) {
	if( data ) {
		MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
		if( ! self ) return;

		char *nick = NULL;
		char *params = event_get_params( data, 2, NULL, &nick );

		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		[user _setDateUpdated:[NSDate date]];

		NSNotification *note = [NSNotification notificationWithName:MVChatUserInformationUpdatedNotification object:user userInfo:nil];		
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
	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];

	g_free( params );

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:cmd, @"command", user, @"user", ags, @"arguments", nil];
	[MVIRCChatConnectionThreadLock unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _processSubcodeRequest: ) withObject:info waitUntilDone:YES];
	[MVIRCChatConnectionThreadLock lock]; // lock back up like nothing happened
}

static void MVChatSubcodeReply( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *command = NULL, *args = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &command, &args );

	NSString *cmd = [self stringWithEncodedBytes:command];
	NSString *ags = ( args ? [self stringWithEncodedBytes:args] : nil );
	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];

	g_free( params );

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:cmd, @"command", user, @"user", ags, @"arguments", nil];
	[MVIRCChatConnectionThreadLock unlock]; // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _processSubcodeReply: ) withObject:info waitUntilDone:YES];
	[MVIRCChatConnectionThreadLock lock]; // lock back up like nothing happened
}

#pragma mark -

static void MVChatFileTransferRequest( DCC_REC *dcc ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)dcc -> server];
	if( ! self ) return;
	if( IS_DCC_GET( dcc ) ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:dcc -> nick]];
		MVIRCDownloadFileTransfer *transfer = [[[MVIRCDownloadFileTransfer alloc] initWithDCCFileRecord:dcc fromUser:user] autorelease];
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

+ (NSArray *) defaultServerPorts {
	return [NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:6667],[NSNumber numberWithUnsignedShort:6660],[NSNumber numberWithUnsignedShort:6669],[NSNumber numberWithUnsignedShort:7000],[NSNumber numberWithUnsignedShort:994], nil];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_proxyUsername = nil;
		_proxyPassword = nil;
		_chatConnection = NULL;
		_chatConnectionSettings = NULL;

		_knownUsers = [[NSMutableDictionary dictionaryWithCapacity:200] retain];

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

	[_knownUsers release];
	_knownUsers = nil;

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

- (MVChatConnectionType) type {
	return MVChatConnectionIRCType;
}

- (NSSet *) supportedFeatures {
	return nil;
}

- (const NSStringEncoding *) supportedStringEncodings {
	return supportedEncodings;
}

#pragma mark -

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

	if( [self isConnected] && ! [nickname isEqualToString:[self nickname]] )
		[self sendRawMessageWithFormat:@"NICK %@", nickname];
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
	if( ! [[self localUser] isIdentified] && password && [self isConnected] )
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
	_proxyUsername = [username copyWithZone:[self zone]];
}

- (NSString *) proxyUsername {
	return [[_proxyUsername retain] autorelease];
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
	[_proxyPassword autorelease];
	_proxyPassword = [password copyWithZone:[self zone]];
}

- (NSString *) proxyPassword {
	return [[_proxyPassword retain] autorelease];
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

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! [rooms count] ) return;

	NSMutableArray *roomList = [NSMutableArray arrayWithCapacity:[rooms count]];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) )
		if( [room length] ) [roomList addObject:[self properNameForChatRoomNamed:room]];

	if( ! [roomList count] ) return;

	[self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	if( [passphrase length] ) [self sendRawMessageWithFormat:@"JOIN %@ %@", [self properNameForChatRoomNamed:room], passphrase];
	else [self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	return [NSCharacterSet characterSetWithCharactersInString:@"#&+!"];
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	if( ! [room length] ) return room;
	return ( [[self chatRoomNamePrefixes] characterIsMember:[room characterAtIndex:0]] ? room : [@"#" stringByAppendingString:room] );
}

#pragma mark -

- (NSSet *) chatUsersWithNickname:(NSString *) nickname {
	return [NSSet setWithObject:[self chatUserWithUniqueIdentifier:nickname]];
}

- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier {
	NSParameterAssert( [identifier isKindOfClass:[NSString class]] );

	NSString *uniqueIdentfier = [identifier lowercaseString];
	if( [uniqueIdentfier isEqualToString:[[self localUser] uniqueIdentifier]] )
		return [self localUser];

	MVChatUser *user = nil;
	@synchronized( _knownUsers ) {
		user = [_knownUsers objectForKey:uniqueIdentfier];
		if( user ) return [[user retain] autorelease];

		user = [[[MVIRCChatUser allocWithZone:[self zone]] initWithNickname:identifier andConnection:self] autorelease];
		[_knownUsers setObject:user forKey:uniqueIdentfier];
	}

	return [[user retain] autorelease];
}

#pragma mark -

- (void) addUserToNotificationList:(MVChatUser *) user {
	NSParameterAssert( user != nil );

	[MVIRCChatConnectionThreadLock lock];

	notifylist_add( [self encodedBytesWithString:[NSString stringWithFormat:@"%@!*@*", [user nickname]]], NULL, TRUE, 600 );

	[MVIRCChatConnectionThreadLock unlock];
}

- (void) removeUserFromNotificationList:(MVChatUser *) user {
	NSParameterAssert( user != nil );

	[MVIRCChatConnectionThreadLock lock];

	notifylist_remove( [self encodedBytesWithString:[NSString stringWithFormat:@"%@!*@*", [user nickname]]] );

	[MVIRCChatConnectionThreadLock unlock];
}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 900. ) {
		[self sendRawMessage:@"LIST"];
		[_cachedDate autorelease];
		_cachedDate = [[NSDate date] retain];
	}
}

- (void) stopFetchingChatRoomList {
	[self sendRawMessage:@"LIST STOP"];
}

#pragma mark -

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	[_awayMessage autorelease];
	_awayMessage = nil;

	if( [[message string] length] ) {
		_awayMessage = [message copyWithZone:[self zone]];
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

	MVIRCChatConnectionModuleData *data = MODULE_DATA( server );
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

	signal_add_last( "event join", (SIGNAL_FUNC) MVChatUserJoinedRoom );
	signal_add_last( "event part", (SIGNAL_FUNC) MVChatUserLeftRoom );
	signal_add_last( "event quit", (SIGNAL_FUNC) MVChatUserQuit );
	signal_add_last( "event kick", (SIGNAL_FUNC) MVChatUserKicked );
	signal_add_last( "event invite", (SIGNAL_FUNC) MVChatInvited );
	signal_add_last( "event nick", (SIGNAL_FUNC) MVChatUserNicknameChanged );

	signal_add_last( "event privmsg", (SIGNAL_FUNC) MVChatGetMessage );
	signal_add_last( "event notice", (SIGNAL_FUNC) MVChatGetAutoMessage );
	signal_add_last( "ctcp action", (SIGNAL_FUNC) MVChatGetActionMessage );

	signal_add_last( "nick mode changed", (SIGNAL_FUNC) MVChatGotUserMode );

	signal_add_last( "away mode changed", (SIGNAL_FUNC) MVChatSelfAwayChanged );

	signal_add_last( "notifylist joined", (SIGNAL_FUNC) MVChatBuddyOnline );
	signal_add_last( "notifylist left", (SIGNAL_FUNC) MVChatBuddyOffline );
	signal_add_last( "notifylist away changed", (SIGNAL_FUNC) MVChatBuddyAway );
	signal_add_last( "notifylist unidle", (SIGNAL_FUNC) MVChatBuddyUnidle );

	signal_add_last( "event 301", (SIGNAL_FUNC) MVChatUserAway );
	signal_add_last( "event 311", (SIGNAL_FUNC) MVChatUserWhois );
	signal_add_last( "event 312", (SIGNAL_FUNC) MVChatUserServer );
	signal_add_last( "event 313", (SIGNAL_FUNC) MVChatUserOperator );
	signal_add_last( "event 317", (SIGNAL_FUNC) MVChatUserIdle );
	signal_add_last( "event 318", (SIGNAL_FUNC) MVChatUserWhoisComplete );
	signal_add_last( "event 319", (SIGNAL_FUNC) MVChatUserChannels );
	signal_add_last( "event 320", (SIGNAL_FUNC) MVChatUserIdentified );
	signal_add_last( "event 322", (SIGNAL_FUNC) MVChatListRoom );
	signal_add_last( "event 368", (SIGNAL_FUNC) MVChatBanListFinished );
	signal_add_first( "event 433", (SIGNAL_FUNC) MVChatNickTaken );
	signal_add_last( "event 001", (SIGNAL_FUNC) MVChatNickFinal );

	// And to catch the notifylist whois ones as well
	signal_add_last( "notifylist event whois end", (SIGNAL_FUNC) MVChatUserWhoisComplete );
	signal_add_last( "notifylist event whois away", (SIGNAL_FUNC) MVChatUserAway );
	signal_add_last( "notifylist event whois", (SIGNAL_FUNC) MVChatUserWhois );
	signal_add_last( "notifylist event whois idle", (SIGNAL_FUNC) MVChatUserIdle );

	signal_add_first( "ctcp msg", (SIGNAL_FUNC) MVChatSubcodeRequest );
	signal_add_first( "ctcp reply", (SIGNAL_FUNC) MVChatSubcodeReply );

	signal_add_last( "dcc request", (SIGNAL_FUNC) MVChatFileTransferRequest );
}

+ (void) _deregisterCallbacks {
	signals_remove_module( MODULE_NAME );
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

	SERVER_REC *old = _chatConnection;

	if( old ) {
		MVIRCChatConnectionModuleData *data = MODULE_DATA( old );
		if( data ) memset( &data, 0, sizeof( MVIRCChatConnectionModuleData ) );
		g_free_not_null( data );
	}

	_chatConnection = server;

	if( _chatConnection ) {
		server_ref( _chatConnection );

		MVIRCChatConnectionModuleData *data = g_new0( MVIRCChatConnectionModuleData, 1 );
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

- (void) _didConnect {
	[_localUser release];
	_localUser = [[MVIRCChatUser allocWithZone:[self zone]] initLocalUserWithConnection:self];
	[super _didConnect];
}

- (void) _didNotConnect {
	[self _setIrssiConnection:NULL];
	[super _didNotConnect];
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

	[self _setIrssiConnection:NULL];
	[super _didDisconnect];
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

#pragma mark -

- (void) _processSubcodeRequest:(NSDictionary *) info {
	NSString *command = [info objectForKey:@"command"];
	NSString *arguments = [info objectForKey:@"arguments"];
	MVChatUser *user = [info objectForKey:@"user"];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSubcodeRequestNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:command, @"command", arguments, @"arguments", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatUser * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeRequest:withArguments:fromUser: )];
	[invocation setArgument:&command atIndex:2];
	[invocation setArgument:&arguments atIndex:3];
	[invocation setArgument:&user atIndex:4];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) {
		signal_stop();
		return;
	}

	if( ! [command caseInsensitiveCompare:@"version"] ) {
		NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];
		NSString *reply = [NSString stringWithFormat:@"%@ %@ (%@) - %@ %@ - %@", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [clientVersion objectForKey:@"CFBundleVersion"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductUserVisibleVersion"], [clientVersion objectForKey:@"MVChatCoreCTCPVersionReplyInfo"]];
		[user sendSubcodeReply:@"VERSION" withArguments:reply];
		signal_stop();
		return;
	}
}

- (void) _processSubcodeReply:(NSDictionary *) info {
	NSString *command = [info objectForKey:@"command"];
	NSString *arguments = [info objectForKey:@"arguments"];
	MVChatUser *user = [info objectForKey:@"user"];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSubcodeReplyNotification object:user userInfo:[NSDictionary dictionaryWithObjectsAndKeys:command, @"command", arguments, @"arguments", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];	

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatUser * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeReply:withArguments:fromUser: )];
	[invocation setArgument:&command atIndex:2];
	[invocation setArgument:&arguments atIndex:3];
	[invocation setArgument:&user atIndex:4];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) {
		signal_stop();
		return;
	}
}

#pragma mark -

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname {
	@synchronized( _knownUsers ) {
		[user retain];
		[_knownUsers removeObjectForKey:[user uniqueIdentifier]];
		[user _setUniqueIdentifier:[nickname lowercaseString]];
		[user _setNickname:nickname];
		[_knownUsers setObject:user forKey:[user uniqueIdentifier]];
		[user release];
	}
}
@end
