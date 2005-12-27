#import "MVIRCChatConnection.h"
#import "MVIRCChatRoom.h"
#import "MVIRCChatUser.h"
#import "MVIRCFileTransfer.h"

#import "AsyncSocket.h"
#import "MVChatPluginManager.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"
#import "NSDataAdditions.h"

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
	/* Baltic */
	(NSStringEncoding) 0x8000020D,		// ISO Latin 7
	(NSStringEncoding) 0x80000507,		// Windows
	/* Central European */
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

// IRC error codes for most servers (some codes are not supported by all servers)
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

/*static void MVChatNickTaken( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
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

static void MVChatUserKicked( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL, *nick = NULL, *reason = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, &channel, &nick, &reason );

	NSData *msgData = [[NSData allocWithZone:nil] initWithBytes:reason length:strlen( reason )];
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

	[msgData release];
	g_free( params );
}

static void MVChatInvited( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:by]];
	if( [user status] != MVChatUserAwayStatus ) [user _setStatus:MVChatUserAvailableStatus];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomInvitedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", [self stringWithEncodedBytes:channel], @"room", nil]];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];

	g_free( params );
}

static void MVChatUserAway( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	char *nick = NULL, *message = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &message );

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setStatus:MVChatUserAwayStatus];

//	NSData *msgData = [[NSData allocWithZone:nil] initWithBytes:message length:strlen( message )];

//	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[self stringWithEncodedBytes:nick], @"who", msgData, @"message", nil]];
//	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
//	[msgData release];

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

	if( [user status] != MVChatUserAwayStatus ) [user _setStatus:MVChatUserAvailableStatus];
	[user _setIdleTime:0.];

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

	NSString *oldIdentifier = [oldNickname lowercaseString];
	while( ( room = [enumerator nextObject] ) ) {
		if( ! [room isJoined] || ! [room hasUser:user] ) continue;
		[room _updateMemberUser:user fromOldUniqueIdentifier:oldIdentifier];
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

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomModesChangedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:changedModes], @"changedModes", byMember, @"by", nil]];
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

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setRealName:[self stringWithEncodedBytes:realname]];
	[user _setUsername:[self stringWithEncodedBytes:username]];
	[user _setAddress:[self stringWithEncodedBytes:host]];
	if( [user status] != MVChatUserAwayStatus ) [user _setStatus:MVChatUserAvailableStatus];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionWatchedUserOnlineNotification object:user userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVChatBuddyOffline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
	[user _setStatus:MVChatUserOfflineStatus];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionWatchedUserOfflineNotification object:user userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
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
	NSMutableArray *results = [[NSMutableArray allocWithZone:nil] initWithCapacity:[chanArray count]];
	NSEnumerator *enumerator = [chanArray objectEnumerator];
	NSString *room = nil;

	NSCharacterSet *modeChars = [NSCharacterSet characterSetWithCharactersInString:@"@\%+ "];
	while( ( room = [enumerator nextObject] ) ) {
		room = [room stringByTrimmingCharactersInSet:modeChars];
		if( room ) [results addObject:room];
	}

	if( [results count] ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:nick]];
		[user setAttribute:results forKey:MVChatUserKnownRoomsAttribute];
	}

	[results release];
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

		if( [user status] != MVChatUserAwayStatus ) [user _setStatus:MVChatUserAvailableStatus];

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
	NSData *t = [[NSData allocWithZone:nil] initWithBytes:topic length:strlen( topic )];
	NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:strtoul( count, NULL, 10 )], @"users", t, @"topic", [NSDate date], @"cached", r, @"room", nil];

	[self performSelectorOnMainThread:@selector( _addRoomToCache: ) withObject:info waitUntilDone:NO];

	[info release];
	[t release];
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
	IrssiUnlock(); // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _processSubcodeRequest: ) withObject:info waitUntilDone:YES];
	IrssiLock(); // lock back up like nothing happened
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
	IrssiUnlock(); // prevents a deadlock, since waitUntilDone is required. threads synced
	[self performSelectorOnMainThread:@selector( _processSubcodeReply: ) withObject:info waitUntilDone:YES];
	IrssiLock(); // lock back up like nothing happened
}

#pragma mark -

static void MVChatFileTransferRequest( DCC_REC *dcc ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)dcc -> server];
	if( ! self ) return;
	if( IS_DCC_GET( dcc ) ) {
		MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:dcc -> nick]];
		MVIRCDownloadFileTransfer *transfer = [[MVIRCDownloadFileTransfer allocWithZone:nil] initWithDCCFileRecord:dcc fromUser:user];
		NSNotification *note = [NSNotification notificationWithName:MVDownloadFileTransferOfferNotification object:transfer];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
		[transfer release];
	}
}

#pragma mark -

static void MVChatErrorNoSuchUser( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	g_return_if_fail( data != NULL );

	char *nick = NULL;
	char *params = event_get_params( data, 2, NULL, &nick );

	[self _processErrorCode:ERR_NOSUCHNICK withContext:nick];

	g_free( params );
}

static void MVChatErrorUnknownCommand( IRC_SERVER_REC *server, const char *data ) {
	MVIRCChatConnection *self = [MVIRCChatConnection _connectionForServer:(SERVER_REC *)server];
	if( ! self ) return;

	g_return_if_fail( data != NULL );

	char *command = NULL;
	char *params = event_get_params( data, 2, NULL, &command );

	[self _processErrorCode:ERR_UNKNOWNCOMMAND withContext:command];

	g_free( params );
}

#pragma mark - */

@implementation MVIRCChatConnection
+ (NSArray *) defaultServerPorts {
	return [NSArray arrayWithObjects:[NSNumber numberWithUnsignedShort:6667],[NSNumber numberWithUnsignedShort:6660],[NSNumber numberWithUnsignedShort:6669],[NSNumber numberWithUnsignedShort:7000],[NSNumber numberWithUnsignedShort:994], nil];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_chatConnection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

		_serverPort = 6667;
		_server = @"irc.freenode.net";
		_username = [NSUserName() retain];
		_nickname = [_username retain];
		_currentNickname = [_nickname retain];
		_realName = [NSFullUserName() retain];

		_knownUsers = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:200];
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

	if( _lastConnectAttempt && ABS( [_lastConnectAttempt timeIntervalSinceNow] ) < 5. ) {
		// prevents connecting too quick
		// cancel any reconnect attempts, this lets a user cancel the attempts with a "double connect"
		[self cancelPendingReconnectAttempts];
		return;
	}

	[_lastConnectAttempt release];
	_lastConnectAttempt = [[NSDate allocWithZone:nil] init];

	[self _willConnect]; // call early so other code has a chance to change our info

	if( ! [_chatConnection connectToHost:[self server] onPort:[self serverPort] error:NULL] )
		[self _didNotConnect];

/*
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
*/
}

- (void) disconnectWithReason:(NSAttributedString *) reason {
	[self cancelPendingReconnectAttempts];

	if( [self status] == MVChatConnectionConnectedStatus ) {
		if( [[reason string] length] ) {
			NSData *msg = [[self class] _flattenedIRCDataForMessage:reason withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
			[self sendRawMessageWithComponents:@"QUIT :", msg, nil];
		} else [self sendRawMessage:@"QUIT"];
	}

	[_chatConnection disconnectAfterWriting];
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	NSParameterAssert( name != nil );

	id old = _realName;
	_realName = [name copyWithZone:nil];
	[old release];
}

- (NSString *) realName {
	return [[_realName retain] autorelease];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	NSParameterAssert( nickname != nil );
	NSParameterAssert( [nickname length] > 0 );

	if( [nickname isEqualToString:[self nickname]] )
		return;

	id old = _nickname;
	_nickname = [nickname copyWithZone:nil];
	[old release];

	if( ! _currentNickname || ! [self isConnected] ) {
		id old = _currentNickname;
		_currentNickname = [_nickname retain];
		[old release];
	}

	if( [self isConnected] )
		[self sendRawMessageWithFormat:@"NICK %@", nickname];
}

- (NSString *) nickname {
	return [[_currentNickname retain] autorelease];
}

- (NSString *) preferredNickname {
	return [[_nickname retain] autorelease];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
	if( ! [[self localUser] isIdentified] && password && [self isConnected] )
		[self sendRawMessageWithFormat:@"PRIVMSG NickServ :IDENTIFY %@", password];
	[super setNicknamePassword:password];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	id old = _password;
	_password = [password copyWithZone:nil];
	[old release];
}

- (NSString *) password {
	return [[_password retain] autorelease];
}

#pragma mark -

- (void) setUsername:(NSString *) username {
	NSParameterAssert( username != nil );
	NSParameterAssert( [username length] > 0 );

	id old = _username;
	_username = [username copyWithZone:nil];
	[old release];
}

- (NSString *) username {
	return [[_username retain] autorelease];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	NSParameterAssert( server != nil );
	NSParameterAssert( [server length] > 0 );

	id old = _server;
	_server = [server copyWithZone:nil];
	[old release];
}

- (NSString *) server {
	return [[_server retain] autorelease];
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	_serverPort = ( port ? port : 6667 );
}

- (unsigned short) serverPort {
	return _serverPort;
}

#pragma mark -

- (void) setSecure:(BOOL) ssl {
	_secure = ssl;
}

- (BOOL) isSecure {
	return _secure;
}

#pragma mark -

- (void) setProxyServer:(NSString *) address {
	id old = _proxyServer;
	_proxyServer = [address copyWithZone:nil];
	[old release];
}

- (NSString *) proxyServer {
	return [[_proxyServer retain] autorelease];
}

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port {
	_proxyServerPort = port;
}

- (unsigned short) proxyServerPort {
	return _proxyServerPort;
}

#pragma mark -

- (void) setProxyUsername:(NSString *) username {
	id old = _proxyUsername;
	_proxyUsername = [username copyWithZone:nil];
	[old release];
}

- (NSString *) proxyUsername {
	return [[_proxyUsername retain] autorelease];
}

#pragma mark -

- (void) setProxyPassword:(NSString *) password {
	id old = _proxyPassword;
	_proxyPassword = [password copyWithZone:nil];
	[old release];
}

- (NSString *) proxyPassword {
	return [[_proxyPassword retain] autorelease];
}

#pragma mark -

- (void) sendRawMessage:(id) raw immediately:(BOOL) now {
	NSParameterAssert( raw != nil );
	NSParameterAssert( [raw isKindOfClass:[NSData class]] || [raw isKindOfClass:[NSString class]] );

	NSMutableData *data = nil;
	NSString *string = nil;

	if( [raw isKindOfClass:[NSMutableData class]] ) {
		data = [raw retain];
		string = [[NSString allocWithZone:nil] initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSData class]] ) {
		data = [raw mutableCopyWithZone:nil];
		string = [[NSString allocWithZone:nil] initWithData:data encoding:[self encoding]];
	} else if( [raw isKindOfClass:[NSString class]] ) {
		data = [[raw dataUsingEncoding:[self encoding] allowLossyConversion:YES] mutableCopyWithZone:nil];
		string = [raw retain];
	}

	// IRC messages are always lines of characters terminated with a CR-LF
	// (Carriage Return - Line Feed) pair, and these messages SHALL NOT
	// exceed 512 characters in length, counting all characters including
	// the trailing CR-LF. Thus, there are 510 characters maximum allowed
	// for the command and its parameters.

	if( [data length] > 510 ) [data setLength:510];
	[data appendBytes:"\x0D\x0A" length:2];

	[_chatConnection writeData:data withTimeout:-1. tag:0];

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:string, @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];

	[string release];
	[data release];
}

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray *) rooms {
	NSParameterAssert( rooms != nil );

	if( ! [rooms count] ) return;

	NSMutableArray *roomList = [[NSMutableArray allocWithZone:nil] initWithCapacity:[rooms count]];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) ) {
		if( [room length] && [room rangeOfString:@" "].location == NSNotFound ) { // join non-password room in bulk
			[roomList addObject:[self properNameForChatRoomNamed:room]];
		} else if( [room length] && [room rangeOfString:@" "].location != NSNotFound ) { // has a password, join separately
			// join all requested rooms before this one so we do things in order
			if( [roomList count] ) [self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
			[self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
			[roomList removeAllObjects]; // clear list since we joined them
		}
	}

	if( [roomList count] ) [self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
	[roomList release];
}

- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase {
	NSParameterAssert( room != nil );
	NSParameterAssert( [room length] > 0 );
	if( [passphrase length] ) [self sendRawMessageWithFormat:@"JOIN %@ %@", [self properNameForChatRoomNamed:room], passphrase];
	else [self sendRawMessageWithFormat:@"JOIN %@", [self properNameForChatRoomNamed:room]];
}

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes {
	static NSCharacterSet *prefixes = nil;
	if( ! prefixes ) prefixes = [[NSCharacterSet characterSetWithCharactersInString:@"#&+!"] retain];
	return prefixes;
}

- (NSString *) properNameForChatRoomNamed:(NSString *) room {
	if( ! [room length] ) return room;
	return ( [[self chatRoomNamePrefixes] characterIsMember:[room characterAtIndex:0]] ? room : [@"#" stringByAppendingString:room] );
}

#pragma mark -

- (NSSet *) knownChatUsers {
	return [NSSet setWithArray:[_knownUsers allValues]];
}

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

		user = [[MVIRCChatUser allocWithZone:nil] initWithNickname:identifier andConnection:self];
		if( user ) [_knownUsers setObject:user forKey:uniqueIdentfier];
	}

	return [user autorelease];
}

#pragma mark -

- (void) startWatchingUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [[user nickname] length] > 0 );

}

- (void) stopWatchingUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [[user nickname] length] > 0 );

}

#pragma mark -

- (void) fetchChatRoomList {
	if( ! _cachedDate || ABS( [_cachedDate timeIntervalSinceNow] ) > 300. ) {
		[self sendRawMessage:@"LIST"];
		[_cachedDate release];
		_cachedDate = [[NSDate allocWithZone:nil] init];
	}
}

- (void) stopFetchingChatRoomList {
	if( _cachedDate && ABS( [_cachedDate timeIntervalSinceNow] ) < 600. )
		[self sendRawMessage:@"LIST STOP"];
}

#pragma mark -

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	[_awayMessage release];
	_awayMessage = nil;

	if( [[message string] length] ) {
		[[self localUser] _setStatus:MVChatUserAwayStatus];

		_awayMessage = [message copyWithZone:nil];

		NSData *msg = [[self class] _flattenedIRCDataForMessage:message withEncoding:[self encoding] andChatFormat:[self outgoingChatFormat]];
		[self sendRawMessageWithComponents:@"AWAY :", msg, nil];
	} else {
		[[self localUser] _setStatus:MVChatUserAvailableStatus];
		[self sendRawMessage:@"AWAY"];
	}
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionPrivate)
- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"willDisconnectWithError: %@", error );
	_status = MVChatConnectionServerDisconnectedStatus;
	if( ABS( [_lastConnectAttempt timeIntervalSinceNow] ) > 300. )
		[self performSelector:@selector( connect ) withObject:nil afterDelay:5.];
	[self scheduleReconnectAttemptEvery:30.];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	if( _status != MVChatConnectionServerDisconnectedStatus )
		_status = MVChatConnectionDisconnectedStatus;

	id old = _localUser;
	_localUser = nil;
	[old release];

	[self _didDisconnect];
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	if( [[self password] length] ) [self sendRawMessageWithFormat:@"PASS %@", [self password]];
	[self sendRawMessageWithFormat:@"NICK %@", [self nickname]];
	[self sendRawMessageWithFormat:@"USER %@ %@ %@ :%@", [self username], [[NSHost currentHost] name], [self server], [self realName]];

	id old = _localUser;
	_localUser = [[MVIRCChatUser allocWithZone:nil] initLocalUserWithConnection:self];
	[old release];

	[self _didConnect];
	[self _readNextMessageFromServer];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	NSString *rawString = [[NSString allocWithZone:nil] initWithData:data encoding:[self encoding]];
	const char *line = (const char *)[data bytes];
	unsigned int len = [data length];
	const char *end = line + len - 2; // minus the line endings

	const char *sender = NULL;
	unsigned senderLength = 0;
	const char *user = NULL;
	unsigned userLength = 0;
	const char *host = NULL;
	unsigned hostLength = 0;
	const char *command = NULL;
	unsigned commandLength = 0;

	NSMutableArray *parameters = [[NSMutableArray allocWithZone:nil] initWithCapacity:15];

	// Parsing as defined in 2.3.1 at http://www.irchelp.org/irchelp/rfc/rfc2812.txt

	if( len <= 2 || len > 512 )
		goto end; // bad message

#define checkAndMarkIfDone() if( line == end ) done = YES
#define consumeWhitespace() while( *line == ' ' && line != end && ! done ) line++
#define notEndOfLine() line != end && ! done

	BOOL done = NO;
	if( notEndOfLine() ) {
		if( *line == ':' ) {
			// prefix: ':' <sender> [ '!' <user> ] [ '@' <host> ] ' ' { ' ' }
			sender = ++line;
			while( notEndOfLine() && *line != ' ' && *line != '!' && *line != '@' ) line++;
			senderLength = (line - sender);
			checkAndMarkIfDone();

			if( ! done && *line == '!' ) {
				user = ++line;
				while( notEndOfLine() && *line != ' ' && *line != '@' ) line++;
				userLength = (line - host);
				checkAndMarkIfDone();
			}

			if( ! done && *line == '@' ) {
				host = ++line;
				while( notEndOfLine() && *line != ' ' ) line++;
				hostLength = (line - host);
				checkAndMarkIfDone();
			}

			if( ! done ) line++;
			consumeWhitespace();
		}

		if( notEndOfLine() ) {
			// command: <letter> { <letter> } | <number> <number> <number>
			// letter: 'a' ... 'z' | 'A' ... 'Z'
			// number: '0' ... '9'
			command = line;
			while( notEndOfLine() && *line != ' ' ) line++;
			commandLength = (line - command);
			checkAndMarkIfDone();

			if( ! done ) line++;
			consumeWhitespace();
		}

		while( notEndOfLine() ) {
			// params: [ ':' <trailing data> | <letter> { <letter> } ] [ ' ' { ' ' } ] [ <params> ]
			const char *currentParameter = NULL;
			id param = nil;
			if( *line == ':' ) {
				currentParameter = ++line;
				param = [[NSMutableData allocWithZone:nil] initWithBytes:currentParameter length:(end - currentParameter)];
				done = YES;
			} else {
				currentParameter = line;
				while( notEndOfLine() && *line != ' ' ) line++;
				param = [[NSString allocWithZone:nil] initWithBytes:currentParameter length:(line - currentParameter) encoding:[self encoding]];
				checkAndMarkIfDone();
				if( ! done ) line++;
			}

			if( param ) [parameters addObject:param];
			[param release];

			consumeWhitespace();
		}
	}

#undef checkAndMarkIfDone()
#undef consumeWhitespace()
#undef notEndOfLine()

end:
	if( command && commandLength ) {
		NSString *commandString = [[NSString allocWithZone:nil] initWithBytes:command length:commandLength encoding:[self encoding]];
		NSString *selectorString = [[NSString allocWithZone:nil] initWithFormat:@"_handle%@WithParameters:fromSender:", [commandString capitalizedString]];
		SEL selector = NSSelectorFromString( selectorString );
		[selectorString release];
		[commandString release];

		if( [self respondsToSelector:selector] ) {
			NSString *senderString = nil;
			if( sender ) senderString = [[NSString allocWithZone:nil] initWithBytes:sender length:senderLength encoding:[self encoding]];

			MVChatUser *chatUser = nil;
			if( user && userLength ) {
				chatUser = [self chatUserWithUniqueIdentifier:senderString];
				if( ! [chatUser address] && host && hostLength ) {
					NSString *hostString = [[NSString allocWithZone:nil] initWithBytes:host length:hostLength encoding:[self encoding]];
					[chatUser _setAddress:hostString];
					[hostString release];
				}

				if( ! [chatUser username] ) {
					NSString *userString = [[NSString allocWithZone:nil] initWithBytes:user length:userLength encoding:[self encoding]];
					[chatUser _setUsername:userString];
					[userString release];
				}
			}

			[self performSelector:selector withObject:parameters withObject:( chatUser ? (id) chatUser : (id) senderString )];
			[senderString release];
		}
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:rawString, @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];

	[rawString release];
	[parameters release];

	[self _readNextMessageFromServer];
}

- (void) _readNextMessageFromServer {
	static NSData *delimeter = nil;
	if( ! delimeter ) delimeter = [[NSData allocWithZone:nil] initWithBytes:"\x0D\x0A" length:2];
	[_chatConnection readDataToData:delimeter withTimeout:-1. tag:0];
}

+ (NSData *) _flattenedIRCDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format {
	NSString *cformat = nil;

	switch( format ) {
	case MVChatConnectionDefaultMessageFormat:
	case MVChatWindowsIRCMessageFormat:
		cformat = NSChatWindowsIRCFormatType;
		break;
	case MVChatCTCPTwoMessageFormat:
		cformat = NSChatCTCPTwoFormatType;
		break;
	default:
	case MVChatNoMessageFormat:
		cformat = nil;
	}

	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:enc], @"StringEncoding", cformat, @"FormatType", nil];
	return [message chatFormatWithOptions:options];
}
/*
#pragma mark -

- (void) _didConnect {
	id old = _localUser;
	_localUser = [[MVIRCChatUser allocWithZone:nil] initLocalUserWithConnection:self];
	[old release];

	// Identify if we have a user password
	if( [[self nicknamePassword] length] )
		[self sendRawMessageWithFormat:@"PRIVMSG NickServ :IDENTIFY %@", [self nicknamePassword]];

	[super _didConnect];
}

#pragma mark -

- (void) _processErrorCode:(int) errorCode withContext:(char *) context {
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	NSError *error = nil;

	[userInfo setObject:self forKey:@"connection"];

	switch( errorCode ) {
		case ERR_NOSUCHNICK: {
			MVChatUser *user = [self chatUserWithUniqueIdentifier:[self stringWithEncodedBytes:context]];
			[user _setStatus:MVChatUserOfflineStatus];
			[userInfo setObject:user forKey:@"user"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The user \"%@\" is no longer connected (or never was connected) to the \"%@\" server.", "user not on the server" ), [user nickname], [self server]] forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionNoSuchUserError userInfo:userInfo];
			break;
		}
		case ERR_UNKNOWNCOMMAND: {
			NSString *command = [self stringWithEncodedBytes:context];
			[userInfo setObject:command forKey:@"command"];
			[userInfo setObject:[NSString stringWithFormat:NSLocalizedString( @"The command \"%@\" is not a valid command on the \"%@\" server.", "user not on the server" ), command, [self server]] forKey:NSLocalizedDescriptionKey];
			error = [NSError errorWithDomain:MVChatConnectionErrorDomain code:MVChatConnectionUnknownCommandError userInfo:userInfo];
			break;
		}
	}

	if( error ) [self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
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
		NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
		if( ! [systemVersion count] ) systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];

#if __ppc__
		NSString *processor = @"PowerPC";
#elif __i386__
		NSString *processor = @"Intel";
#else
		NSString *processor = @"Unknown Architecture";
#endif

		NSString *reply = [NSString stringWithFormat:@"%@ %@ (%@) - %@ %@ (%@) - %@", [clientVersion objectForKey:@"CFBundleName"], [clientVersion objectForKey:@"CFBundleShortVersionString"], [clientVersion objectForKey:@"CFBundleVersion"], [systemVersion objectForKey:@"ProductName"], [systemVersion objectForKey:@"ProductUserVisibleVersion"], processor, [clientVersion objectForKey:@"MVChatCoreCTCPVersionReplyInfo"]];
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
} */

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

- (void) _sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action {
	NSData *msg = [[self class] _flattenedIRCDataForMessage:message withEncoding:encoding andChatFormat:[self outgoingChatFormat]];
	if( action ) {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@ :\001ACTION ", target];
		[self sendRawMessageWithComponents:prefix, msg, @"\001", nil];
		[prefix release];
	} else {
		NSString *prefix = [[NSString allocWithZone:nil] initWithFormat:@"PRIVMSG %@ :", target];
		[self sendRawMessageWithComponents:prefix, msg, nil];
		[prefix release];
	}
}
@end

#pragma mark -

@implementation MVIRCChatConnection (MVIRCChatConnectionProtocolHandlers)
- (void) _handlePrivmsgWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( ! [targetName length] ) return;

		if( [targetName characterAtIndex:0] == '@' ) {
			targetName = [targetName substringFromIndex:1]; // a message to only room operators
			if( ! [targetName length] ) return;
		}

		NSMutableData *msgData = [parameters objectAtIndex:1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && [msgData length] > 2 );

		if( [sender status] != MVChatUserAwayStatus ) [sender _setStatus:MVChatUserAvailableStatus];
		[sender _setIdleTime:0.];

		if( [[self chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]] ) {
			MVChatRoom *room = [self joinedChatRoomWithName:targetName];
			if( ctcp ) [self _handleCTCP:msgData asRequest:YES fromSender:sender forRoom:room];
			else [[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", msgData, @"message", [NSString locallyUniqueString], @"identifier", nil]];
		} else {
			if( ctcp ) [self _handleCTCP:msgData asRequest:YES fromSender:sender forRoom:nil];
			else [[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", [NSString locallyUniqueString], @"identifier", nil]];
		}
	}
}

- (void) _handleNoticeWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		NSString *targetName = [parameters objectAtIndex:0];
		if( ! [targetName length] ) return;

		if( [targetName characterAtIndex:0] == '@' ) {
			targetName = [targetName substringFromIndex:1]; // a message to only room operators
			if( ! [targetName length] ) return;
		}

		NSMutableData *msgData = [parameters objectAtIndex:1];
		const char *bytes = (const char *)[msgData bytes];
		BOOL ctcp = ( *bytes == '\001' && [msgData length] > 2 );

		if( [[self chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]] ) {
			MVChatRoom *room = [self joinedChatRoomWithName:targetName];
			if( ctcp ) [self _handleCTCP:msgData asRequest:NO fromSender:sender forRoom:room];
			else [[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomGotMessageNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", msgData, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"notice", nil]];
		} else {
			if( ctcp ) [self _handleCTCP:msgData asRequest:NO fromSender:sender forRoom:nil];
			else {
				[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionGotPrivateMessageNotification object:sender userInfo:[NSDictionary dictionaryWithObjectsAndKeys:msgData, @"message", [NSString locallyUniqueString], @"identifier", [NSNumber numberWithBool:YES], @"notice", nil]];
				if( [[sender nickname] isEqualToString:@"NickServ"] ) {
					NSString *msg = [[NSString allocWithZone:nil] initWithData:msgData encoding:[self encoding]];
					if( [msg rangeOfString:@"NickServ"].location != NSNotFound && [msg rangeOfString:@"IDENTIFY"].location != NSNotFound ) {
						if( ! [self nicknamePassword] ) {
							[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
						} else [self sendRawMessageWithFormat:@"PRIVMSG %@ :IDENTIFY %@", [self nickname], [self nicknamePassword]];
					} else if( [msg rangeOfString:@"Password accepted"].location != NSNotFound ) {
						[[self localUser] _setIdentified:YES];
					} else if( [msg rangeOfString:@"authentication required"].location != NSNotFound ) {
						[[self localUser] _setIdentified:NO];
					}
					[msg release];
				}
			}
		}
	}
}

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender forRoom:(MVChatRoom *) room {
	NSMutableArray *parameters = [[NSMutableArray allocWithZone:nil] initWithCapacity:15];
	const char *line = (const char *)[data bytes] + 1; // skip the \001 char
	const char *end = line + [data length] - 2; // minus the first and last \001 char
	BOOL done = NO;

	while( line != end && ! done ) {
		// params: [ ':' <trailing data> | <letter> { <letter> } ] [ ' ' { ' ' } ] [ <params> ]
		const char *currentParameter = NULL;
		id param = nil;
		if( *line == ':' ) {
			currentParameter = ++line;
			param = [[NSMutableData allocWithZone:nil] initWithBytes:currentParameter length:(end - currentParameter)];
			done = YES;
		} else {
			currentParameter = line;
			while( line != end && *line != ' ' ) line++;
			param = [[NSString allocWithZone:nil] initWithBytes:currentParameter length:(line - currentParameter) encoding:[self encoding]];
			if( line == end ) done = YES;
			else line++;
		}

		if( param ) [parameters addObject:param];
		[param release];

		while( *line == ' ' && line != end && ! done ) line++;
	}

	NSLog(@"ctcp %@ %d %@", sender, request, [parameters description] );
}

- (void) _handleJoinWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] ) {
		NSString *name = [[NSString allocWithZone:nil] initWithData:[parameters objectAtIndex:0] encoding:[self encoding]];
		MVChatRoom *room = [self joinedChatRoomWithName:name];

		if( [sender isLocalUser] ) {
			if( ! room ) {
				room = [[MVIRCChatRoom allocWithZone:nil] initWithName:name andConnection:self];
				[self _addJoinedRoom:room];
				[room release];
			}

			[room _setDateJoined:[NSDate date]];
			[room _setDateParted:nil];
			[room _setNamesSynced:NO];
			[room _clearMemberUsers];
			[room _clearBannedUsers];

			[self sendRawMessageWithFormat:@"WHO %@", name];
		} else {
			if( [sender status] != MVChatUserAwayStatus ) [sender _setStatus:MVChatUserAvailableStatus];
			[sender _setIdleTime:0.];
			[room _addMemberUser:sender];
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomUserJoinedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", nil]];
		}

		[name release];
	}
}

- (void) _handlePartWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:0]];
		if( ! room ) return;
		if( [sender isLocalUser] ) {
			[room _setDateParted:[NSDate date]];
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomPartedNotification object:room];
		} else {
			[room _removeMemberUser:sender];
			NSData *reason = [parameters objectAtIndex:1];
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomUserPartedNotification object:room userInfo:[NSDictionary dictionaryWithObjectsAndKeys:sender, @"user", reason, @"reason", nil]];
		}
	}
}

- (void) _handleQuitWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [sender isLocalUser] ) return;
	if( [parameters count] ) {
		[sender _setDateDisconnected:[NSDate date]];
		[sender _setStatus:MVChatUserOfflineStatus];

		NSData *reason = [parameters objectAtIndex:0];
		NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:sender, @"user", reason, @"reason", nil];

		MVChatRoom *room = nil;
		NSEnumerator *enumerator = [[self joinedChatRooms] objectEnumerator];
		while( ( room = [enumerator nextObject] ) ) {
			if( ! [room isJoined] || ! [room hasUser:sender] ) continue;
			[room _removeMemberUser:sender];
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomUserPartedNotification object:room userInfo:info];
		}

		[info release];
	}
}

- (void) _handleTopicWithParameters:(NSArray *) parameters fromSender:(MVChatUser *) sender {
	if( [parameters count] == 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:0]];
		[room _setTopic:[parameters objectAtIndex:1] byAuthor:sender withDate:[NSDate date]];
	}
}

- (void) _handle353WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_NAMREPLY
	if( [parameters count] == 4 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:2]];
		if( room && ! [room _namesSynced] ) {
			NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
			NSString *names = [[NSString allocWithZone:nil] initWithData:[parameters objectAtIndex:3] encoding:[self encoding]];
			NSArray *members = [names componentsSeparatedByString:@" "];
			NSEnumerator *enumerator = [members objectEnumerator];
			NSString *memberName = nil;

			while( ( memberName = [enumerator nextObject] ) ) {
				unsigned int i = 0, len = [memberName length];
				if( ! len ) break;

				unsigned long modes = MVChatRoomMemberNoModes;
				BOOL done = NO;

				while( i < len && ! done ) {
					unichar c = [memberName characterAtIndex:i];
					switch( c ) {
						case '+': modes |= MVChatRoomMemberVoicedMode; break;
						case '%': modes |= MVChatRoomMemberHalfOperatorMode; break;
						case '@': modes |= MVChatRoomMemberOperatorMode; break;
						default: done = YES; break;
					}
					if( ! done ) i++;
				}

				if( i > 0 ) memberName = [memberName substringFromIndex:i];
				MVChatUser *member = [self chatUserWithUniqueIdentifier:memberName];
				[room _addMemberUser:member];
				[room _setModes:modes forMemberUser:member];
			}

			[names release];
			[pool drain];
			[pool release];
		}
	}
}

- (void) _handle366WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFNAMES
	if( [parameters count] >= 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:1]];
		if( room && ! [room _namesSynced] ) {
			[room _setNamesSynced:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomJoinedNotification object:room];
		}
	}
}

- (void) _handle352WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_WHOREPLY
	if( [parameters count] >= 6 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:1]];
		MVChatUser *member = [self chatUserWithUniqueIdentifier:[parameters objectAtIndex:5]];
		[member _setUsername:[parameters objectAtIndex:2]];
		[member _setAddress:[parameters objectAtIndex:3]];
	}
}

- (void) _handle315WithParameters:(NSArray *) parameters fromSender:(id) sender { // RPL_ENDOFWHO
	if( [parameters count] >= 2 ) {
		MVChatRoom *room = [self joinedChatRoomWithName:[parameters objectAtIndex:1]];
		if( room ) [[NSNotificationCenter defaultCenter] postNotificationName:MVChatRoomMemberUsersSyncedNotification object:room];
	}
}
@end
