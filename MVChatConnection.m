#import <Cocoa/Cocoa.h>
#import <string.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOTypes.h>
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "MVChatConnection.h"
#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMethodSignatureAdditions.h"

#define MODULE_NAME "MVChatConnection"

#import "common.h"
#import "core.h"
#import "irc.h"
#import "signals.h"
#import "servers.h"
#import "servers-setup.h"
#import "chat-protocols.h"
#import "channels.h"
#import "nicklist.h"
#import "notifylist.h"

#import "settings.h"

#pragma mark -

NSString *MVChatConnectionGotRawMessageNotification = @"MVChatConnectionGotRawMessageNotification";

NSString *MVChatConnectionWillConnectNotification = @"MVChatConnectionWillConnectNotification";
NSString *MVChatConnectionDidConnectNotification = @"MVChatConnectionDidConnectNotification";
NSString *MVChatConnectionDidNotConnectNotification = @"MVChatConnectionDidNotConnectNotification";
NSString *MVChatConnectionWillDisconnectNotification = @"MVChatConnectionWillDisconnectNotification";
NSString *MVChatConnectionDidDisconnectNotification = @"MVChatConnectionDidDisconnectNotification";
NSString *MVChatConnectionErrorNotification = @"MVChatConnectionErrorNotification";

NSString *MVChatConnectionNeedNicknamePasswordNotification = @"MVChatConnectionNeedNicknamePasswordNotification";
NSString *MVChatConnectionGotPrivateMessageNotification = @"MVChatConnectionGotPrivateMessageNotification";

NSString *MVChatConnectionBuddyIsOnlineNotification = @"MVChatConnectionBuddyIsOnlineNotification";
NSString *MVChatConnectionBuddyIsOfflineNotification = @"MVChatConnectionBuddyIsOfflineNotification";
NSString *MVChatConnectionBuddyIsAwayNotification = @"MVChatConnectionBuddyIsAwayNotification";
NSString *MVChatConnectionBuddyIsUnawayNotification = @"MVChatConnectionBuddyIsUnawayNotification";
NSString *MVChatConnectionBuddyIsIdleNotification = @"MVChatConnectionBuddyIsIdleNotification";

NSString *MVChatConnectionSelfAwayStatusNotification = @"MVChatConnectionSelfAwayStatusNotification";

NSString *MVChatConnectionGotUserWhoisNotification = @"MVChatConnectionGotUserWhoisNotification";
NSString *MVChatConnectionGotUserServerNotification = @"MVChatConnectionGotUserServerNotification";
NSString *MVChatConnectionGotUserChannelsNotification = @"MVChatConnectionGotUserChannelsNotification";
NSString *MVChatConnectionGotUserOperatorNotification = @"MVChatConnectionGotUserOperatorNotification";
NSString *MVChatConnectionGotUserIdleNotification = @"MVChatConnectionGotUserIdleNotification";
NSString *MVChatConnectionGotUserWhoisCompleteNotification = @"MVChatConnectionGotUserWhoisCompleteNotification";

NSString *MVChatConnectionGotRoomInfoNotification = @"MVChatConnectionGotRoomInfoNotification";

NSString *MVChatConnectionRoomExistingMemberListNotification = @"MVChatConnectionRoomExistingMemberListNotification";
NSString *MVChatConnectionJoinedRoomNotification = @"MVChatConnectionJoinedRoomNotification";
NSString *MVChatConnectionLeftRoomNotification = @"MVChatConnectionLeftRoomNotification";
NSString *MVChatConnectionUserJoinedRoomNotification = @"MVChatConnectionUserJoinedRoomNotification";
NSString *MVChatConnectionUserLeftRoomNotification = @"MVChatConnectionUserLeftRoomNotification";
NSString *MVChatConnectionUserQuitNotification = @"MVChatConnectionUserQuitNotification";
NSString *MVChatConnectionUserNicknameChangedNotification = @"MVChatConnectionUserNicknameChangedNotification";
NSString *MVChatConnectionUserKickedFromRoomNotification = @"MVChatConnectionUserKickedFromRoomNotification";
NSString *MVChatConnectionUserAwayStatusNotification = @"MVChatConnectionUserAwayStatusNotification";
NSString *MVChatConnectionGotMemberModeNotification = @"MVChatConnectionGotMemberModeNotification";
NSString *MVChatConnectionGotRoomModeNotification = @"MVChatConnectionGotRoomModeNotification";
NSString *MVChatConnectionGotRoomMessageNotification = @"MVChatConnectionGotRoomMessageNotification";
NSString *MVChatConnectionGotRoomTopicNotification = @"MVChatConnectionGotRoomTopicNotification";

NSString *MVChatConnectionKickedFromRoomNotification = @"MVChatConnectionKickedFromRoomNotification";
NSString *MVChatConnectionInvitedToRoomNotification = @"MVChatConnectionInvitedToRoomNotification";

NSString *MVChatConnectionNicknameAcceptedNotification = @"MVChatConnectionNicknameAcceptedNotification";
NSString *MVChatConnectionNicknameRejectedNotification = @"MVChatConnectionNicknameRejectedNotification";

NSString *MVChatConnectionFileTransferAvailableNotification = @"MVChatConnectionFileTransferAvailableNotification";
NSString *MVChatConnectionFileTransferOfferedNotification = @"MVChatConnectionFileTransferOfferedNotification";
NSString *MVChatConnectionFileTransferStartedNotification = @"MVChatConnectionFileTransferStartedNotification";
NSString *MVChatConnectionFileTransferFinishedNotification = @"MVChatConnectionFileTransferFinishedNotification";
NSString *MVChatConnectionFileTransferErrorNotification = @"MVChatConnectionFileTransferErrorNotification";
NSString *MVChatConnectionFileTransferStatusNotification = @"MVChatConnectionFileTransferStatusNotification";

NSString *MVChatConnectionSubcodeRequestNotification = @"MVChatConnectionSubcodeRequestNotification";
NSString *MVChatConnectionSubcodeReplyNotification = @"MVChatConnectionSubcodeReplyNotification";

void irc_init( void );
void irc_deinit( void );

#pragma mark -

static BOOL applicationQuitting = NO;
static unsigned int connectionCount = 0;
static GMainLoop *glibMainLoop = NULL;

@interface MVChatConnection (MVChatConnectionPrivate)
+ (MVChatConnection *) _connectionForServer:(SERVER_REC *) server;
+ (void) _registerCallbacks;
+ (void) _deregisterCallbacks;
+ (NSData *) _flattenedHTMLDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc;
- (io_connect_t) _powerConnection;
- (SERVER_REC *) _irssiConnection;
- (void) _setIrssiConnection:(SERVER_REC *) server;
- (void) _registerForSleepNotifications;
- (void) _deregisterForSleepNotifications;
- (void) _postNotification:(NSNotification *) notification;
- (void) _queueNotification:(NSNotification *) notification;
- (void) _addRoomToCache:(NSString *) room withUsers:(int) users andTopic:(NSData *) topic;
- (NSString *) _roomWithProperPrefix:(NSString *) room;
- (void) _setStatus:(MVChatConnectionStatus) status;
- (void) _nicknameIdentified:(BOOL) identified;
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
@end

#pragma mark -

void MVChatHandlePowerChange( void *refcon, io_service_t service, natural_t messageType, void *messageArgument ) {
	MVChatConnection *self = refcon;
	switch( messageType ) {
		case kIOMessageSystemWillRestart:
		case kIOMessageSystemWillPowerOff:
		case kIOMessageSystemWillSleep:
		case kIOMessageDeviceWillPowerOff:
			if( [self isConnected] ) {
				[self disconnect];
				[self _setStatus:MVChatConnectionSuspendedStatus];
			}
			IOAllowPowerChange( [self _powerConnection], (long) messageArgument );
			break;
		case kIOMessageCanSystemPowerOff:
		case kIOMessageCanSystemSleep:
		case kIOMessageCanDevicePowerOff:
			IOAllowPowerChange( [self _powerConnection], (long) messageArgument );
			break;
		case kIOMessageSystemWillNotSleep:
		case kIOMessageSystemWillNotPowerOff:
		case kIOMessageSystemHasPoweredOn:
		case kIOMessageDeviceWillNotPowerOff:
		case kIOMessageDeviceHasPoweredOn:
			if( [self status] == MVChatConnectionSuspendedStatus ) [self connect];
			break;
	}
}

#pragma mark -

static const int MVChatColors[][3] = {
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

static int MVChatRGBToIRC( unsigned int red, unsigned int green, unsigned int blue ) {
	int distance = 1000, color = 1, i = 0, o = 0;
	for( i = 0; i < 16; i++ ) {
		o = abs( red - MVChatColors[i][0] ) +
		abs( green - MVChatColors[i][1] ) +
		abs( blue - MVChatColors[i][2] );
		if( o < distance ) {
			color = i;
			distance = o;
		}
	}
	return color;
}

#define MVChatIRCBold 0x1
#define MVChatIRCItalic 0x2
#define MVChatIRCUnderline 0x4
#define MVChatIRCColor 0x8

char *MVChatXHTMLToIRC( const char * const string ) {
	static char output[513];
	unsigned attributes = 0;
	unsigned colorStack = 0;
	size_t l = ( string ? strlen( string ) : 0 );
	size_t ll = 513;
	size_t i = 0;
	size_t o = 0;

	while( i < l && o < ll ) {
		switch( string[i] ) {
			case '&':
				if( ! strncasecmp( &string[i], "&amp;", 5 ) ) {
					output[o++] = '&';
					i += 5;
				} else if( ! strncasecmp( &string[i], "&gt;", 4 ) ) {
					output[o++] = '>';
					i += 4;
				} else if( ! strncasecmp( &string[i], "&lt;", 4 ) ) {
					output[o++] = '<';
					i += 4;
				} else if( ! strncasecmp( &string[i], "&nbsp;", 6 ) ) {
					output[o++] = ' ';
					i += 6;
				} else if( ! strncasecmp( &string[i], "&quot;", 6 ) ) {
					output[o++] = '"';
					i += 6;
				} else if( ! strncasecmp( &string[i], "&apos;", 6 ) ) {
					output[o++] = '\'';
					i += 6;
				} else output[o++] = string[i++];
				break;
			case '<':
				if( ! strncasecmp( &string[i], "<b>", 3 ) ) {
					output[o++] = '\002';
					i += 3;
					attributes |= MVChatIRCBold;
				} else if( ! strncasecmp( &string[i], "</b>", 4 ) ) {
					output[o++] = '\002';
					i += 4;
					attributes &= ~MVChatIRCBold;
				} else if( ! strncasecmp( &string[i], "<i>", 3 ) ) {
					output[o++] = '\026';
					i += 3;
					attributes |= MVChatIRCItalic;
				} else if( ! strncasecmp(&string[i], "</i>", 4 ) ) {
					output[o++] = '\026';
					i += 4;
					attributes &= ~MVChatIRCItalic;
				} else if( ! strncasecmp(&string[i], "<u>", 3 ) ) {
					output[o++] = '\037';
					i += 3;
					attributes |= MVChatIRCUnderline;
				} else if( ! strncasecmp( &string[i], "</u>", 4 ) ) {
					output[o++] = '\037';
					i += 4;
					attributes &= ~MVChatIRCUnderline;
				} else if( ! strncasecmp( &string[i], "<br>", 4 ) ) {
					output[o++] = ' ';
					i += 4;
				} else if( ! strncasecmp(&string[i], "<a href=", 8 ) ) {
					if( string[i + 8] == '"' || string[i + 8] == '\'' ) i += 9;
					else i += 8;
					output[o++] = '\037';

					while( i < l && string[i] != '"' && string[i] != '\'' )
						output[o++] = string[i++];

					while( i < l && strncasecmp(&string[i],"</a>",4) ) i++;

					output[o++] = '\037';
					i += 4;
				} else if( ! strncasecmp( &string[i], "<font", 5 ) ) {
					unsigned int fgcolor[3] = { 0x00, 0x00, 0x00 };
					unsigned int bgcolor[3] = { 0xff, 0xff, 0xff };
					char fgfound = 0;
					char bgfound = 0;
					int oi = i;
					int ti = l;

					oi = i;
					while( i < l && strncasecmp(&string[i],">",1) ) i++;
					ti = i + 1;

					i = oi;
					while( i < ti && strncasecmp(&string[i],"color=",6) ) i++;
					if( string[i + 6] == '"' || string[i + 6] == '\'' ) i += 7;
					else i += 6;
					if( string[i] == '#' ) i += 1;
					fgfound = sscanf( &string[i], "%2x%2x%2x", &fgcolor[0], &fgcolor[1], &fgcolor[2] );
					fgfound = ( fgfound == 3 ? 1 : 0 );

					i = oi;
					while( i < ti && strncasecmp(&string[i],"background-color:",17) ) i++;
					if( string[i + 17] == ' ' ) i += 18;
					else i += 17;
					if( string[i] == '#' ) i += 1;
					bgfound = sscanf( &string[i], "%2x%2x%2x", &bgcolor[0], &bgcolor[1], &bgcolor[2] );
					bgfound = ( bgfound == 3 ? 1 : 0 );
					if( bgfound ) fgfound = 1;

					i = ti;

					if( fgfound ) {
						attributes |= MVChatIRCColor;
						colorStack++;
						o += sprintf( &output[o], "\003%02d", MVChatRGBToIRC( fgcolor[0], fgcolor[1], fgcolor[2] ) );
						if( bgfound ) {
							o += sprintf( &output[o], ",%02d", MVChatRGBToIRC( bgcolor[0], bgcolor[1], bgcolor[2] ) );
						}
					}
				} else if( ! strncasecmp( &string[i], "</font>", 7 ) ) {
					colorStack--;
					if( colorStack < 0 ) colorStack = 0;
					if( ( attributes & MVChatIRCColor ) && ! colorStack ) {
						output[o++] = '\003';
						attributes &= ~MVChatIRCColor;
					}
					i += 7;
				} else output[o++] = string[i++];
				break;
			default:
				output[o++] = string[i++];
				break;
		}
	}

	output[o] = '\0';
	return output;
}

char *MVChatIRCToXHTML( const char * const string ) {
	size_t l = ( string ? strlen( string ) : 0 );
	size_t i = 0;
	size_t o = 0;
	size_t ll = ( 45 * 1024 ); // the maximum size for a 512 byte message with all attributes/entity replacement
	static char output[( 45 * 1024 ) + 1];
	const char *attributsCharSet = "\002\003\026\037\017";
	unsigned attributes = 0;
	int fgcolor = -1, bgcolor = -1;
	unsigned int iso2022esc = 0;

	while( i < l && o < ll ) {
		/* scan for attributes until we hit character data */
		while( i < l && strspn( &string[i], attributsCharSet ) ) {
			switch( string[i] ) {
			case '\017': /* reset all */
				attributes = 0;
				fgcolor = -1;
				bgcolor = -1;
				i++;
				break;
			case '\002': /* toggle bold */
				attributes ^= MVChatIRCBold;
				i++;
				break;
			case '\003': /* color */
				fgcolor = -1;
				attributes &= ~MVChatIRCColor;
				if( isdigit( string[i + 1] ) ) {
					if( isdigit( string[i + 2] ) ) {
						fgcolor = ( string[i + 1] - '0' ) * 10;
						fgcolor += ( string[i + 2] - '0' );
						if( string[i + 3] == ',' ) {
							if( isdigit( string[i + 4] ) ) {
								if( isdigit( string[i + 5] ) ) {
									bgcolor = ( string[i + 4] - '0' ) * 10;
									bgcolor += ( string[i + 5] - '0' );
									i++;
								} else bgcolor = ( string[i + 4] - '0' );
								i++;
							}
							i++;
						}
						i++;
					} else if( string[i + 2] == ',' ) {
						fgcolor = ( string[i + 1] - '0' );
						if( isdigit( string[i + 3] ) ) {
							if( isdigit( string[i + 4] ) ) {
								bgcolor = ( string[i + 3] - '0' ) * 10;
								bgcolor += ( string[i + 4] - '0' );
								i++;
							} else bgcolor = ( string[i + 3] - '0' );
							i++;
						}
						i++;
					} else fgcolor = ( string[i + 1] - '0' );
					i++;

					if( fgcolor >= 0 ) {
						fgcolor %= 16;
						attributes |= MVChatIRCColor;
					}

					if( bgcolor == 99 ) bgcolor = -1;
					if( ( attributes & MVChatIRCColor ) && bgcolor >= 0 )
						bgcolor %= 16;
				} else bgcolor = -1;
				i++;
				break;
			case '\026': /* toggle italic */
				attributes ^= MVChatIRCItalic;
				i++;
				break;
			case '\037': /* toggle underline */
				attributes ^= MVChatIRCUnderline;
				i++;
				break;
			}
		}

		/* write attributes to output as XHTML */
		if( attributes & MVChatIRCColor && fgcolor >= 0 ) {
			o += sprintf( &output[o], "<font color=\"#%02x%02x%02x\"", MVChatColors[fgcolor][0], MVChatColors[fgcolor][1], MVChatColors[fgcolor][2] );
			if( bgcolor >= 0 ) {
				o += sprintf( &output[o], " style=\"background-color: #%02x%02x%02x\"", MVChatColors[bgcolor][0], MVChatColors[bgcolor][1], MVChatColors[bgcolor][2] );
			}
			memcpy(&output[o],">",1);
			o += 1;
		}

		if( attributes & MVChatIRCBold) {
			memcpy(&output[o],"<b>",3);
			o += 3;
		}

		if( attributes & MVChatIRCItalic) {
			memcpy(&output[o],"<i>",3);
			o += 3;
		}

		if( attributes & MVChatIRCUnderline) {
			memcpy(&output[o],"<u>",3);
			o += 3;
		}

		/* write any character data up until next attribute change */
		while( i < l && o < ll && strcspn( &string[i], attributsCharSet ) ) {
			switch( string[i] ) {
			case '\033':
				// ISO-2022-JP Support; See RFC 1468.
				if( string[i+1] == '$' && ( string[i+2] == '@' || string[i+2] == 'B' ) ) iso2022esc = 1;
				else if( string[i+1] == '(' && ( string[i+2] == 'B' || string[i+2] == 'J' ) ) iso2022esc = 0;
				output[o++] = string[i++];
				break;
			case '&':
				if( iso2022esc ) goto echo;
				memcpy( &output[o], "&amp;", 5 );
				o += 5;
				i++;
				break;
			case '<':
				if( iso2022esc ) goto echo;
				memcpy( &output[o], "&lt;", 4 );
				o += 4;
				i++;
				break;
			case '>':
				if( iso2022esc ) goto echo;
				memcpy( &output[o], "&gt;", 4 );
				o += 4;
				i++;
				break;
			case '"':
				if( iso2022esc ) goto echo;
				memcpy( &output[o], "&quot;", 6 );
				o += 6;
				i++;
				break;
			case '\'':
				if( iso2022esc ) goto echo;
				memcpy( &output[o], "&apos;", 6 );
				o += 6;
				i++;
				break;
			default: echo:
				if( (unsigned) string[i] >= 0x20 || string[i] == '\t' || string[i] == '\n' || string[i] == '\r' ) output[o++] = string[i++];
				else i++;
			}
		}

		/* close all HTML tags and loop again */
		if( attributes & MVChatIRCUnderline) {
			memcpy( &output[o], "</u>", 4 );
			o += 4;
		}

		if( attributes & MVChatIRCItalic) {
			memcpy( &output[o], "</i>", 4 );
			o += 4;
		}

		if( attributes & MVChatIRCBold) {
			memcpy( &output[o], "</b>", 4);
			o += 4;
		}

		if( attributes & MVChatIRCColor && fgcolor >= 0 ) {
			memcpy( &output[o], "</font>", 7);
			o += 7;
		}
	}

	output[o] = '\0';
	return output;
}

#pragma mark -

static void MVChatConnected( SERVER_REC *server ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:server];
	[self performSelectorOnMainThread:@selector( _didConnect ) withObject:nil waitUntilDone:YES];
}

static void MVChatDisconnect( SERVER_REC *server ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:server];
	[self performSelectorOnMainThread:@selector( _didDisconnect ) withObject:nil waitUntilDone:YES];
}

static void MVChatRawIncomingMessage( SERVER_REC *server, char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSData dataWithBytes:data length:strlen( data )], @"message", [NSNumber numberWithBool:NO], @"outbound", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatRawOutgoingMessage( SERVER_REC *server, char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRawMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSData dataWithBytes:data length:strlen( data )], @"message", [NSNumber numberWithBool:YES], @"outbound", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

#pragma mark -

static void MVChatJoinedRoom( CHANNEL_REC *channel ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:channel -> server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	char *topic = MVChatIRCToXHTML( channel -> topic );
	NSData *msgData = [NSData dataWithBytes:topic length:strlen( topic )];
	note = [NSNotification notificationWithName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", ( channel -> topic_by ? (id) [NSString stringWithUTF8String:channel -> topic_by] : (id) [NSNull null] ), @"author", ( msgData ? (id) msgData : (id) [NSNull null] ), @"topic", [NSDate dateWithTimeIntervalSince1970:channel -> topic_time], @"time", [NSNumber numberWithBool:YES], @"justJoined", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	GSList *nicks = nicklist_getnicks( channel );
	GSList *nickItem = NULL;
	NSMutableArray *nickArray = [NSMutableArray arrayWithCapacity:g_slist_length( nicks )];

	for( nickItem = nicks; nickItem != NULL; nickItem = g_slist_next( nickItem ) ) {
		NICK_REC *nick = nickItem -> data;
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		[info setObject:[NSString stringWithUTF8String:nick -> nick] forKey:@"nickname"];
		[info setObject:[NSNumber numberWithBool:nick -> serverop] forKey:@"serverOperator"];
		[info setObject:[NSNumber numberWithBool:nick -> op] forKey:@"operator"];
		[info setObject:[NSNumber numberWithBool:nick -> halfop] forKey:@"halfOperator"];
		[info setObject:[NSNumber numberWithBool:nick -> voice] forKey:@"voice"];
		if( nick -> host ) [info setObject:[NSString stringWithUTF8String:nick -> host] forKey:@"address"];
		if( nick -> realname ) [info setObject:[NSString stringWithUTF8String:nick -> realname] forKey:@"realName"];
		[nickArray addObject:info];
	}

	note = [NSNotification notificationWithName:MVChatConnectionRoomExistingMemberListNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", nickArray, @"members", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];	
}

static void MVChatLeftRoom( CHANNEL_REC *channel ) {
	if( channel -> kicked ) return;
	MVChatConnection *self = [MVChatConnection _connectionForServer:channel -> server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatRoomTopicChanged( CHANNEL_REC *channel ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:channel -> server];

	char *topic = MVChatIRCToXHTML( channel -> topic );
	NSData *msgData = [NSData dataWithBytes:topic length:strlen( topic )];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRoomTopicNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", ( channel -> topic_by ? (id) [NSString stringWithUTF8String:channel -> topic_by] : (id) [NSNull null] ), @"author", ( msgData ? (id) msgData : (id) [NSNull null] ), @"topic", [NSDate dateWithTimeIntervalSince1970:channel -> topic_time], @"time", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

#pragma mark -

static void MVChatUserJoinedRoom( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	if( [[self nickname] isEqualToString:[NSString stringWithUTF8String:nick]] ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 1, &channel );

	CHANNEL_REC *room = channel_find( (SERVER_REC *) server, channel );
	NICK_REC *nickname = nicklist_find( room, nick );

	if( ! nickname ) return;

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSString stringWithUTF8String:nickname -> nick] forKey:@"nickname"];
	[info setObject:[NSNumber numberWithBool:nickname -> serverop] forKey:@"serverOperator"];
	[info setObject:[NSNumber numberWithBool:nickname -> op] forKey:@"operator"];
	[info setObject:[NSNumber numberWithBool:nickname -> halfop] forKey:@"halfOperator"];
	[info setObject:[NSNumber numberWithBool:nickname -> voice] forKey:@"voice"];
	if( address ) [info setObject:[NSString stringWithUTF8String:address] forKey:@"address"];
	if( nickname -> realname )
		[info setObject:[NSString stringWithUTF8String:nickname -> realname] forKey:@"realName"];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserJoinedRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel], @"room", [NSString stringWithUTF8String:nick], @"who", info, @"info", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserLeftRoom( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	if( [[self nickname] isEqualToString:[NSString stringWithUTF8String:nick]] ) return;

	char *channel = NULL;
	char *params = event_get_params( data, 1, &channel );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserLeftRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel], @"room", [NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:address], @"address", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserQuit( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	if( [[self nickname] isEqualToString:[NSString stringWithUTF8String:nick]] ) return;

	if( *data == ':' ) data++;
	char *msg = MVChatIRCToXHTML( data );
	NSData *msgData = [NSData dataWithBytes:msg length:strlen( msg )];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserQuitNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:address], @"address", ( msgData ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatUserKicked( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *channel = NULL, *nick = NULL, *reason = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, &channel, &nick, &reason );

	char *msg = MVChatIRCToXHTML( reason );
	NSData *msgData = [NSData dataWithBytes:msg length:strlen( msg )];
	NSNotification *note = nil;

	if( [[self nickname] isEqualToString:[NSString stringWithUTF8String:nick]] ) {
		note = [NSNotification notificationWithName:MVChatConnectionKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel], @"room", ( by ? [NSString stringWithUTF8String:by] : [NSNull null] ), @"by", ( msgData ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];		
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionUserKickedFromRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel], @"room", [NSString stringWithUTF8String:nick], @"who", ( by ? [NSString stringWithUTF8String:by] : [NSNull null] ), @"by", ( msgData ? (id) msgData : (id) [NSNull null] ), @"reason", nil]];
	}

	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );	
}

static void MVChatInvited( IRC_SERVER_REC *server, const char *data, const char *by, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *channel = NULL;
	char *params = event_get_params( data, 2, NULL, &channel );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionInvitedToRoomNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel], @"room", [NSString stringWithUTF8String:by], @"from", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );	
}

static void MVChatUserAway( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *nick = NULL, *message = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &message );

	char *msg = MVChatIRCToXHTML( message );
	NSData *msgData = [NSData dataWithBytes:msg length:strlen( msg )];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionUserAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", msgData, @"message", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );	
}

#pragma mark -

static void MVChatSelfAwayChanged( IRC_SERVER_REC *server ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	NSNumber *away = [NSNumber numberWithBool:( ((SERVER_REC *)server) -> usermode_away == TRUE )];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionSelfAwayStatusNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:away, @"away", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

#pragma mark -

static void MVChatGetMessage( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	if( ! nick ) return;

	char *target = NULL, *message = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &target, &message );
	if( ! address ) address = "";

	if( *target == '@' && ischannel( target[1] ) ) target = target + 1;

	message = MVChatIRCToXHTML( message );
	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];
	NSNotification *note = nil;

	if( ischannel( *target ) ) {
		note = [NSNotification notificationWithName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:target], @"room", [NSString stringWithUTF8String:nick], @"from", msgData, @"message", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"from", msgData, @"message", nil]];
	}

	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatGetAutoMessage( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	if( ! nick ) return;

	char *target = NULL, *message = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &target, &message );
	if( ! address ) address = "";

	if( ! strncasecmp( nick, "NickServ", 8 ) && message ) {
		if( strstr( message, nick ) && strstr( message, "IDENTIFY" ) ) {
			if( ! [self nicknamePassword] ) {
				NSNotification *note = [NSNotification notificationWithName:MVChatConnectionNeedNicknamePasswordNotification object:self userInfo:nil];
				[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
			} else irc_send_cmdv( server, "PRIVMSG %s :IDENTIFY %s", nick, [[self nicknamePassword] UTF8String] );
		} else if( strstr( message, "Password accepted" ) ) {
			[self _nicknameIdentified:YES];
		} else if( strstr( message, "authentication required" ) ) {
			[self _nicknameIdentified:NO];
		}
	}

	message = MVChatIRCToXHTML( message );
	NSData *msgData = [NSData dataWithBytes:message length:strlen( message )];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"from", [NSNumber numberWithBool:YES], @"auto", msgData, @"message", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatGetActionMessage( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	if( ! nick ) return;
	if( ! address ) address = "";

	data = MVChatIRCToXHTML( data );
	NSData *msgData = [NSData dataWithBytes:data length:strlen( data )];
	NSNotification *note = nil;

	if( ischannel( *target ) ) {
		note = [NSNotification notificationWithName:MVChatConnectionGotRoomMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:target], @"room", [NSString stringWithUTF8String:nick], @"from", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionGotPrivateMessageNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"from", [NSNumber numberWithBool:YES], @"action", msgData, @"message", nil]];
	}

	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

#pragma mark -

static void MVChatUserNicknameChanged( CHANNEL_REC *channel, NICK_REC *nick, const char *oldnick ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:channel -> server];
	NSNotification *note = nil;

	if( [[self nickname] isEqualToString:[NSString stringWithUTF8String:oldnick]] ) {
		note = [NSNotification notificationWithName:MVChatConnectionNicknameAcceptedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick -> nick], @"nickname", nil]];
	} else {
		note = [NSNotification notificationWithName:MVChatConnectionUserNicknameChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", [NSString stringWithUTF8String:oldnick], @"oldNickname", [NSString stringWithUTF8String:nick -> nick], @"newNickname", nil]];
	}

	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatGotUserMode( CHANNEL_REC *channel, NICK_REC *nick, char *by, char *mode, char *type ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:channel -> server];
	unsigned int m = MVChatMemberNoModes;

	if( *mode == '@' ) m = MVChatMemberOperatorMode;
	else if( *mode == '%' ) m = MVChatMemberHalfOperatorMode;
	else if( *mode == '+' ) m = MVChatMemberVoiceMode;

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotMemberModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:channel -> name], @"room", [NSString stringWithUTF8String:nick -> nick], @"who", ( by ? [NSString stringWithUTF8String:by] : [NSNull null] ), @"by", [NSNumber numberWithBool:( *type == '+' ? YES : NO )], @"enabled", [NSNumber numberWithUnsignedInt:m], @"mode", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatGotRoomMode( CHANNEL_REC *channel, const char *setby ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:channel -> server];
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

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotRoomModeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:( channel -> name ? [NSString stringWithUTF8String:channel -> name] : @"" ), @"room", [NSNumber numberWithUnsignedInt:currentModes], @"mode", [NSNumber numberWithUnsignedInt:channel -> limit], @"limit", ( channel -> key ? [NSString stringWithUTF8String:channel -> key] : @"" ), @"key", ( setby ? [NSString stringWithUTF8String:setby] : [NSNull null] ), @"by", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

#pragma mark -

static void MVChatBuddyOnline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
	if( awaymsg ) { // Mark the buddy as away
		note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:awaymsg], @"msg", nil]];
		[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
	}
}

static void MVChatBuddyOffline( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatBuddyAway( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	NSNotification *note = nil;
	if( awaymsg ) note = [NSNotification notificationWithName:MVChatConnectionBuddyIsAwayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:awaymsg], @"msg", nil]];
	else note = [NSNotification notificationWithName:MVChatConnectionBuddyIsUnawayNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

static void MVChatBuddyUnidle( IRC_SERVER_REC *server, const char *nick, const char *username, const char *host, const char *realname, const char *awaymsg ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionBuddyIsIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSNumber numberWithLong:0], @"idle", nil]];
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];
}

#pragma mark -

static void MVChatUserWhois( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *nick = NULL, *user = NULL, *host = NULL, *realname = NULL;
	char *params = event_get_params( data, 6 | PARAM_FLAG_GETREST, NULL, &nick, &user, &host, NULL, &realname );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserWhoisNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:user], @"username", [NSString stringWithUTF8String:host], @"hostname", [NSString stringWithUTF8String:realname], @"realname", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserServer( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *nick = NULL, *serv = NULL, *serverinfo = NULL;
	char *params = event_get_params( data, 4 | PARAM_FLAG_GETREST, NULL, &nick, &serv, &serverinfo );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserServerNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", [NSString stringWithUTF8String:serv], @"server", [NSString stringWithUTF8String:serverinfo], @"serverinfo", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserChannels( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *nick = NULL, *chanlist = NULL;
	char *params = event_get_params( data, 3 | PARAM_FLAG_GETREST, NULL, &nick, &chanlist );

	NSArray *chanArray = [[[NSString stringWithUTF8String:chanlist] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserChannelsNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", chanArray, @"channels", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserOperator( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *nick = NULL;
	char *params = event_get_params( data, 2, NULL, &nick );

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserOperatorNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserIdle( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *nick = NULL, *idle = NULL, *connected = NULL;
	char *params = event_get_params( data, 4, NULL, &nick, &idle, &connected );

	NSNumber *idleTime = [NSNumber numberWithInt:[[NSString stringWithUTF8String:idle] intValue]];
	NSNumber *connectedTime = [NSNumber numberWithInt:[[NSString stringWithUTF8String:connected] intValue]];

	NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserIdleNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", idleTime, @"idle", connectedTime, @"connected", nil]];		
	[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

	g_free( params );
}

static void MVChatUserWhoisComplete( IRC_SERVER_REC *server, const char *data ) {
	if( data != NULL ) {
		MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];
		char *nick = NULL;
		char *params = event_get_params( data, 2, NULL, &nick );

		NSNotification *note = [NSNotification notificationWithName:MVChatConnectionGotUserWhoisCompleteNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:nick], @"who", nil]];		
		[self performSelectorOnMainThread:@selector( _postNotification: ) withObject:note waitUntilDone:YES];

		g_free( params );
	}
}

#pragma mark -

static void MVChatListRoom( IRC_SERVER_REC *server, const char *data ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

    char *channel = NULL, *count = NULL, *topic = NULL;
    char *params = event_get_params( data, 4 | PARAM_FLAG_GETREST, NULL, &channel, &count, &topic );

    NSString *r = [NSString stringWithUTF8String:channel];
    NSData *t = [NSData dataWithBytes:topic length:strlen( topic )];
    [self _addRoomToCache:r withUsers:strtoul( count, NULL, 0 ) andTopic:t];

    g_free( params );
}

#pragma mark -

void MVChatSubcodeRequest( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *command = NULL, *args = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &command, &args );

	NSString *cmd = [NSString stringWithUTF8String:command];
	NSString *ags = ( args ? [NSString stringWithUTF8String:args] : nil );
	NSString *frm = [NSString stringWithUTF8String:nick];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeRequest:withArguments:fromUser:forConnection: )];
	[invocation setArgument:&cmd atIndex:2];
	[invocation setArgument:&ags atIndex:3];
	[invocation setArgument:&frm atIndex:4];
	[invocation setArgument:&self atIndex:5];

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

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionSubcodeRequestNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frm, @"from", cmd, @"command", ( ags ? (id) ags : (id) [NSNull null] ), @"arguments", nil]];

	g_free( params );	
}

void MVChatSubcodeReply( IRC_SERVER_REC *server, const char *data, const char *nick, const char *address, const char *target ) {
	MVChatConnection *self = [MVChatConnection _connectionForServer:(SERVER_REC *)server];

	char *command = NULL, *args = NULL;
	char *params = event_get_params( data, 2 | PARAM_FLAG_GETREST, &command, &args );

	NSString *cmd = [NSString stringWithUTF8String:command];
	NSString *ags = ( args ? [NSString stringWithUTF8String:args] : nil );
	NSString *frm = [NSString stringWithUTF8String:nick];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSString * ), @encode( NSString * ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( processSubcodeReply:withArguments:fromUser:forConnection: )];
	[invocation setArgument:&cmd atIndex:2];
	[invocation setArgument:&ags atIndex:3];
	[invocation setArgument:&frm atIndex:4];
	[invocation setArgument:&self atIndex:5];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	if( [[results lastObject] boolValue] ) return;

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionSubcodeReplyNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:frm, @"from", cmd, @"command", ( ags ? (id) ags : (id) [NSNull null] ), @"arguments", nil]];

	g_free( params );	
}

#pragma mark -

@implementation MVChatConnection
+ (void) setFileTransferPortRange:(NSRange) range {
//	unsigned short min = (unsigned short)range.location;
//	unsigned short max = (unsigned short)(range.location + range.length);
//	firetalk_set_dcc_port_range( min, max );
}

+ (NSRange) fileTransferPortRange {
	unsigned short min = 1024;
	unsigned short max = 1048;
//	firetalk_get_dcc_port_range( &min, &max );
	return NSMakeRange( (unsigned int) min, (unsigned int)( max - min ) );
}

#pragma mark -

+ (NSString *) descriptionForError:(MVChatError) error {
	return @"";
//	return [NSString stringWithUTF8String:firetalk_strerror( (enum firetalk_error) error )];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_npassword = nil;
		_cachedDate = nil;
		_awayMessage = nil;
		_nickIdentified = NO;

		_status = MVChatConnectionDisconnectedStatus;
		_proxy = MVChatConnectionNoProxy;
		_roomsCache = [[NSMutableDictionary dictionary] retain];

		[self _registerForSleepNotifications];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationWillTerminate: ) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];

		extern unsigned int connectionCount;
		connectionCount++;

		if( connectionCount == 1 ) {
			extern GMainLoop *glibMainLoop;
			glibMainLoop = g_main_new( TRUE );
			irssi_gui = IRSSI_GUI_NONE;

			char *args[] = { "Chat Core" };
			core_init_paths( 1, args );
			core_init();
			irc_init();

			settings_set_bool( "override_coredump_limit", FALSE );
			signal_emit( "setup changed", 0 );

			signal_emit( "irssi init finished", 0 );	

			[[self class] _registerCallbacks];

			[NSThread detachNewThreadSelector:@selector( _glibRunloop: ) toTarget:[self class] withObject:nil];
		}

		CHAT_PROTOCOL_REC *proto = chat_protocol_get_default();
		SERVER_CONNECT_REC *conn = server_create_conn( proto -> id, "irc.javelin.cc", 6667, [[NSString stringWithFormat:@"%x", self] UTF8String], NULL, [NSUserName() UTF8String] );
		server_connect_ref( conn );

		[self _setIrssiConnection:proto -> server_init_connect( conn )];
		server_connect_unref( conn );
	}
	return self;
}

- (id) initWithURL:(NSURL *) url {
	if( ! [url isChatURL] ) return nil;
	if( ( self = [self initWithServer:[url host] port:[[url port] unsignedShortValue] user:[url user]] ) ) {
		[self setNicknamePassword:[url password]];

		if( [url fragment] && [[url fragment] length] > 0 ) {
			[self joinChatRoom:[url fragment]];
		} else if( [url path] && [[url path] length] >= 2 && ( [[[url path] substringFromIndex:1] hasPrefix:@"&"] || [[[url path] substringFromIndex:1] hasPrefix:@"+"] || [[[url path] substringFromIndex:1] hasPrefix:@"!"] ) ) {
			[self joinChatRoom:[[url path] substringFromIndex:1]];
		}
	}
	return self;
}

- (id) initWithServer:(NSString *) server port:(unsigned short) port user:(NSString *) nickname {
	if( ( self = [self init] ) ) {
		if( [nickname length] ) [self setNickname:nickname];
		if( [server length] ) [self setServer:server];
		[self setServerPort:port];
	}
	return self;
}

- (void) dealloc {
	[self disconnect];
	[self _deregisterForSleepNotifications];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_npassword release];
	[_roomsCache release];
	[_cachedDate release];
	[_awayMessage release];

	[self _setIrssiConnection:NULL];

	_npassword = nil;
	_roomsCache = nil;
	_cachedDate = nil;
	_awayMessage = nil;

	extern unsigned int connectionCount;
	connectionCount--;

	[super dealloc];
}

#pragma mark -

- (void) connect {
	if( [self status] != MVChatConnectionDisconnectedStatus
		&& [self status] != MVChatConnectionServerDisconnectedStatus ) return;

	[self _willConnect];

	if( ! [self _irssiConnection] -> connect_time ) {
		CHAT_PROTOCOL_REC *proto = chat_protocol_get_default();
		proto -> server_connect( [self _irssiConnection] );
	} else {
		CHAT_PROTOCOL_REC *proto = chat_protocol_get_default();
		SERVER_REC *newConnection = proto -> server_init_connect( [self _irssiConnection] -> connrec );
		proto -> server_connect( newConnection );
		[self _setIrssiConnection:newConnection];
	}
}

- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname {
	if( [nickname length] ) [self setNickname:nickname];
	if( [server length] ) [self setServer:server];
	[self setServerPort:port];
	[self disconnect];
	[self connect];
}

- (void) disconnect {
	if( [self status] != MVChatConnectionConnectedStatus ) return;

	[self _willDisconnect];

//  signal_emit( "server quit", 2, [self _irssiConnection], "Quiting" );
	server_disconnect( [self _irssiConnection] );
}

#pragma mark -

- (NSURL *) url {
	NSString *url = [NSString stringWithFormat:@"irc://%@@%@:%hu", MVURLEncodeString( [self preferredNickname] ), MVURLEncodeString( [self server] ), [self serverPort]];
	if( url ) return [NSURL URLWithString:url];
	return nil;
}

#pragma mark -

- (void) setRealName:(NSString *) name {
	NSParameterAssert( name != nil );
	if( ! [self _irssiConnection] ) return;

	g_free_not_null( [self _irssiConnection] -> connrec -> realname );
	[self _irssiConnection] -> connrec -> realname = g_strdup( [name UTF8String] );		
}

- (NSString *) realName {
	if( ! [self _irssiConnection] ) return nil;
	return [NSString stringWithUTF8String:[self _irssiConnection] -> connrec -> realname];
}

#pragma mark -

- (void) setNickname:(NSString *) nickname {
	NSParameterAssert( nickname != nil );
	if( ! [self _irssiConnection] ) return;

	if( [self isConnected] ) {
		g_free_not_null( [self _irssiConnection] -> connrec -> nick );
		[self _irssiConnection] -> connrec -> nick = g_strdup( [nickname UTF8String] );		

		if( ! [nickname isEqualToString:[self nickname]] ) {
			_nickIdentified = NO;
			[self sendRawMessageWithFormat:@"NICK %@", nickname];
		}
	} else {
		g_free_not_null( [self _irssiConnection] -> nick );
		[self _irssiConnection] -> nick = g_strdup( [nickname UTF8String] );		

		g_free_not_null( [self _irssiConnection] -> connrec -> nick );
		[self _irssiConnection] -> connrec -> nick = g_strdup( [nickname UTF8String] );		
	}
}

- (NSString *) nickname {
	if( ! [self _irssiConnection] ) return nil;
	if( [self isConnected] )
		return [NSString stringWithUTF8String:[self _irssiConnection] -> nick];
	return [NSString stringWithUTF8String:[self _irssiConnection] -> connrec -> nick];
}

- (NSString *) preferredNickname {
	if( ! [self _irssiConnection] ) return nil;
	return [NSString stringWithUTF8String:[self _irssiConnection] -> connrec -> nick];
}

#pragma mark -

- (void) setNicknamePassword:(NSString *) password {
	if( ! _nickIdentified && password && [self isConnected] )
		[self sendRawMessageWithFormat:@"PRIVMSG NickServ :IDENTIFY %@", password];

	[_npassword autorelease];
	if( [password length] ) _npassword = [password copy];
	else _npassword = nil;
}

- (NSString *) nicknamePassword {
	return [[_npassword retain] autorelease];
}

#pragma mark -

- (void) setPassword:(NSString *) password {
	if( ! [self _irssiConnection] ) return;

	g_free_not_null( [self _irssiConnection] -> connrec -> password );
	if( [password length] ) [self _irssiConnection] -> connrec -> password = g_strdup( [password UTF8String] );		
	else [self _irssiConnection] -> connrec -> password = NULL;		
}

- (NSString *) password {
	if( ! [self _irssiConnection] ) return nil;
	char *pass = [self _irssiConnection] -> connrec -> password;
	if( pass ) return [NSString stringWithUTF8String:pass];
	return nil;
}

#pragma mark -

- (void) setUsername:(NSString *) username {
	NSParameterAssert( username != nil );
	if( ! [self _irssiConnection] ) return;
	
	g_free_not_null( [self _irssiConnection] -> connrec -> username );
	[self _irssiConnection] -> connrec -> username = g_strdup( [username UTF8String] );		
}

- (NSString *) username {
	if( ! [self _irssiConnection] ) return nil;
	return [NSString stringWithUTF8String:[self _irssiConnection] -> connrec -> username];
}

#pragma mark -

- (void) setServer:(NSString *) server {
	NSParameterAssert( server != nil );
	if( ! [self _irssiConnection] ) return;

	g_free_not_null( [self _irssiConnection] -> connrec -> address );
	[self _irssiConnection] -> connrec -> address = g_strdup( [server UTF8String] );		
}

- (NSString *) server {
	if( ! [self _irssiConnection] ) return nil;
	return [NSString stringWithUTF8String:[self _irssiConnection] -> connrec -> address];
}

#pragma mark -

- (void) setServerPort:(unsigned short) port {
	if( ! [self _irssiConnection] ) return;
	[self _irssiConnection] -> connrec -> port = ( port ? port : 6667 );
}

- (unsigned short) serverPort {
	if( ! [self _irssiConnection] ) return 0;
	return [self _irssiConnection] -> connrec -> port;
}

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) type {
	if( ! [self _irssiConnection] ) return;

	_proxy = type;

	if( _proxy == MVChatConnectionHTTPSProxy ) {
		g_free_not_null( [self _irssiConnection] -> connrec -> proxy );
		[self _irssiConnection] -> connrec -> proxy = g_strdup( "127.0.0.1" );

		[self _irssiConnection] -> connrec -> proxy_port = 8000;

		g_free_not_null( [self _irssiConnection] -> connrec -> proxy_string );
		[self _irssiConnection] -> connrec -> proxy_string = g_strdup( "CONNECT %s:%d\nProxy-Authorization: %%BASE64(user:pass)%%\n\n" );

		g_free_not_null( [self _irssiConnection] -> connrec -> proxy_string_after );
		[self _irssiConnection] -> connrec -> proxy_string_after = NULL;

		g_free_not_null( [self _irssiConnection] -> connrec -> proxy_password );
		[self _irssiConnection] -> connrec -> proxy_password = NULL;
	}
}

- (MVChatConnectionProxy) proxyType {
	return _proxy;
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toUser:(NSString *) user asAction:(BOOL) action {
	if( ! [self _irssiConnection] ) return;

	NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:message withEncoding:encoding] mutableCopy] autorelease];
	[encodedData appendBytes:"\0" length:1];

	if( ! action ) [self _irssiConnection] -> send_message( [self _irssiConnection], [user UTF8String], MVChatXHTMLToIRC( (char *) [encodedData bytes] ), 0 );
	else irc_send_cmdv( (IRC_SERVER_REC *) [self _irssiConnection], "PRIVMSG %s :\001ACTION %s\001", [user UTF8String], MVChatXHTMLToIRC( (char *) [encodedData bytes] ) );
}

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toChatRoom:(NSString *) room asAction:(BOOL) action {
	if( ! [self _irssiConnection] ) return;

	NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:message withEncoding:encoding] mutableCopy] autorelease];
	[encodedData appendBytes:"\0" length:1];

	if( ! action ) [self _irssiConnection] -> send_message( [self _irssiConnection], [[room lowercaseString] UTF8String], MVChatXHTMLToIRC( (char *) [encodedData bytes] ), 0 );
	else irc_send_cmdv( (IRC_SERVER_REC *) [self _irssiConnection], "PRIVMSG %s :\001ACTION %s\001", [[room lowercaseString] UTF8String], MVChatXHTMLToIRC( (char *) [encodedData bytes] ) );
}

#pragma mark -

- (void) sendRawMessage:(NSString *) raw {
	if( ! raw ) return;
	if( ! [self _irssiConnection] ) return;
	irc_send_cmd_full( (IRC_SERVER_REC *) [self _irssiConnection], [raw UTF8String], FALSE, FALSE, FALSE);
}

- (void) sendRawMessageWithFormat:(NSString *) format, ... {
	if( ! format ) return;
	va_list ap;		
	va_start( ap, format );
	NSString *command = [[[NSString alloc] initWithFormat:format arguments:ap] autorelease];
	[self sendRawMessage:command];
	va_end( ap );
}

#pragma mark -

- (void) sendFile:(NSString *) path toUser:(NSString *) user {
	if( [user isEqualToString:[self nickname]] ) return;
	if( ! [[NSFileManager defaultManager] isReadableFileAtPath:path] ) return;

	NSNumber *size = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:@"NSFileSize"];
	void *handle = NULL;
//  firetalk_file_offer( _chatConnection, &handle, [user UTF8String], [path fileSystemRepresentation] );
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionFileTransferOfferedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%x", handle], @"identifier", user, @"to", path, @"path", size, @"size", nil]];
}

- (void) acceptFileTransfer:(NSString *) identifier saveToPath:(NSString *) path resume:(BOOL) resume  {
	void *pointer = NULL;
	sscanf( [identifier UTF8String], "%8lx", (unsigned long int *) &pointer );
//  if( resume ) firetalk_file_resume( _chatConnection, pointer, NULL, [path fileSystemRepresentation] );
//  else firetalk_file_accept( _chatConnection, pointer, NULL, [path fileSystemRepresentation] );
}

- (void) cancelFileTransfer:(NSString *) identifier {
//  void *pointer = NULL;
//  sscanf( [identifier UTF8String], "%8lx", (unsigned long int *) &pointer );
//  firetalk_file_cancel( _chatConnection, pointer );
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
	if( ! [rooms count] ) return;

	NSMutableArray *roomList = [NSMutableArray arrayWithCapacity:[rooms count]];
	NSEnumerator *enumerator = [rooms objectEnumerator];
	NSString *room = nil;

	while( ( room = [enumerator nextObject] ) )
		if( [room length] ) [roomList addObject:[self _roomWithProperPrefix:room]];

	if( ! [roomList count] ) return;

	[self sendRawMessageWithFormat:@"JOIN %@", [roomList componentsJoinedByString:@","]];
}

- (void) joinChatRoom:(NSString *) room {
	if( [room length] ) [self sendRawMessageWithFormat:@"JOIN %@", [self _roomWithProperPrefix:room]];
}

- (void) partChatRoom:(NSString *) room {
	if( [room length] ) [self sendRawMessageWithFormat:@"PART %@", [self _roomWithProperPrefix:room]];
}

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	if( ! [self _irssiConnection] ) return;

	NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:topic withEncoding:encoding] mutableCopy] autorelease];
	[encodedData appendBytes:"\0" length:1];

	irc_send_cmdv( (IRC_SERVER_REC *) [self _irssiConnection], "TOPIC %s :%s", [room UTF8String], MVChatXHTMLToIRC( (char *) [encodedData bytes] ) );
}

#pragma mark -

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +o %@", [self _roomWithProperPrefix:room], member];
}

- (void) demoteMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -o %@", [self _roomWithProperPrefix:room], member];
}

- (void) halfopMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +h %@", [self _roomWithProperPrefix:room], member];
}

- (void) dehalfopMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -h %@", [self _roomWithProperPrefix:room], member];
}

- (void) voiceMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ +v %@", [self _roomWithProperPrefix:room], member];
}

- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	[self sendRawMessageWithFormat:@"MODE %@ -v %@", [self _roomWithProperPrefix:room], member];
}

- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason {
	NSParameterAssert( member != nil );
	NSParameterAssert( room != nil );
	if( reason ) [self sendRawMessageWithFormat:@"KICK %@ %@ :%@", [self _roomWithProperPrefix:room], member, reason];
	else [self sendRawMessageWithFormat:@"KICK %@ %@", [self _roomWithProperPrefix:room], member];		
}

#pragma mark -

- (void) addUserToNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );
	notifylist_add( [[NSString stringWithFormat:@"%@!*@*", user] UTF8String], [self _irssiConnection] -> connrec -> chatnet, TRUE, 600 );
}

- (void) removeUserFromNotificationList:(NSString *) user {
	NSParameterAssert( user != nil );
	notifylist_remove( [[NSString stringWithFormat:@"%@!*@*", user] UTF8String] );
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

- (NSMutableDictionary *) roomListResults {
	return [[_roomsCache retain] autorelease];
}

#pragma mark -

- (NSAttributedString *) awayStatusMessage {
	return _awayMessage;
}

- (void) setAwayStatusWithMessage:(NSAttributedString *) message {
	[_awayMessage autorelease];
	_awayMessage = nil;

	if( [[message string] length] ) {
		_awayMessage = [message copy];
		NSMutableData *encodedData = [[[MVChatConnection _flattenedHTMLDataForMessage:message withEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
		[encodedData appendBytes:"\0" length:1];
		irc_send_cmdv( (IRC_SERVER_REC *) [self _irssiConnection], "AWAY :%s", MVChatXHTMLToIRC( (char *) [encodedData bytes] ) );
	} else [self sendRawMessage:@"AWAY"];
}

- (void) clearAwayStatus {
	[self setAwayStatusWithMessage:nil];
}

#pragma mark -

- (BOOL) isConnected {
	return (BOOL) ( _status == MVChatConnectionConnectedStatus );
}

- (MVChatConnectionStatus) status {
	return _status;
}

- (BOOL) waitingToReconnect {
	if( ! [self _irssiConnection] ) return NO;
	return ( ! [self _irssiConnection] -> no_reconnect && [self _irssiConnection] -> connection_lost );
}

- (unsigned int) lag {
	if( ! [self _irssiConnection] ) return 0;
	return [self _irssiConnection] -> lag;
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionPrivate)
+ (MVChatConnection *) _connectionForServer:(SERVER_REC *) server {
	if( ! server -> tag ) return nil;

	MVChatConnection *ret = NULL;
	sscanf( server -> tag, "%8lx", (unsigned long *) &ret );

	if( ! ret ) return nil;
	if( [ret _irssiConnection] == server || ! [ret _irssiConnection] ) return ret;

	[ret _setIrssiConnection:server];
	return ret;
}

+ (void) _registerCallbacks {
	signal_add_last( "server connected", (SIGNAL_FUNC) MVChatConnected );
	signal_add_last( "server disconnected", (SIGNAL_FUNC) MVChatDisconnect );
	signal_add( "server incoming", (SIGNAL_FUNC) MVChatRawIncomingMessage );
	signal_add( "server outgoing", (SIGNAL_FUNC) MVChatRawOutgoingMessage );

	signal_add_last( "channel joined", (SIGNAL_FUNC) MVChatJoinedRoom );
	signal_add_last( "channel topic changed", (SIGNAL_FUNC) MVChatRoomTopicChanged );
	signal_add_last( "channel destroyed", (SIGNAL_FUNC) MVChatLeftRoom );
	signal_add_last( "channel mode changed", (SIGNAL_FUNC) MVChatGotRoomMode );

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

//	firetalk_register_callback( _chatConnection, FC_ERROR, (firetalk_callback) MVChatErrorOccurred );

//	firetalk_register_callback( _chatConnection, FC_IM_GOTINFO, (firetalk_callback) MVChatGotInfo );
//	firetalk_register_callback( _chatConnection, FC_CHAT_ROOM_MODE, (firetalk_callback) MVChatGotRoomMode );

//	firetalk_register_callback( _chatConnection, FC_FILE_OFFER, (firetalk_callback) MVChatFileTransferAccept );
//	firetalk_register_callback( _chatConnection, FC_FILE_START, (firetalk_callback) MVChatFileTransferStart );
//	firetalk_register_callback( _chatConnection, FC_FILE_FINISH, (firetalk_callback) MVChatFileTransferFinish );
//	firetalk_register_callback( _chatConnection, FC_FILE_ERROR, (firetalk_callback) MVChatFileTransferError );
//	firetalk_register_callback( _chatConnection, FC_FILE_PROGRESS, (firetalk_callback) MVChatFileTransferStatus );
}

+ (void) _deregisterCallbacks {
	signal_remove( "server connected", (SIGNAL_FUNC) MVChatConnected );
	signal_remove( "server disconnected", (SIGNAL_FUNC) MVChatDisconnect );
	signal_remove( "server incoming", (SIGNAL_FUNC) MVChatRawIncomingMessage );
	signal_remove( "server outgoing", (SIGNAL_FUNC) MVChatRawOutgoingMessage );

	signal_remove( "channel joined", (SIGNAL_FUNC) MVChatJoinedRoom );
	signal_remove( "channel destroyed", (SIGNAL_FUNC) MVChatLeftRoom );
	signal_remove( "channel topic changed", (SIGNAL_FUNC) MVChatRoomTopicChanged );
	signal_remove( "channel mode changed", (SIGNAL_FUNC) MVChatGotRoomMode );

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
}

+ (NSData *) _flattenedHTMLDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"]], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"]], @"NSHTMLIgnoreFontTraits", nil];
	NSData *encodedData = [message HTMLWithOptions:options usingEncoding:enc allowLossyConversion:YES];
	return [[encodedData retain] autorelease];
}

+ (void) _glibRunloop:(id) sender {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	extern BOOL applicationQuitting;
	extern unsigned int connectionCount;

	while( ! applicationQuitting && connectionCount ) g_main_iteration( TRUE );

	[self performSelectorOnMainThread:@selector( _deallocIrssi ) withObject:nil waitUntilDone:YES];

	[pool release];
	[NSThread exit];
}

+ (void) _deallocIrssi {
	[self _deregisterCallbacks];

	signal_emit( "gui exit", 0 );

	extern GMainLoop *glibMainLoop;
	g_main_destroy( glibMainLoop );
	glibMainLoop = NULL;

	irc_deinit();
	core_deinit();
}

#pragma mark -

- (io_connect_t) _powerConnection {
	return _powerConnection;
}

#pragma mark -

- (SERVER_REC *) _irssiConnection {
	return _chatConnection;
}

- (void) _setIrssiConnection:(SERVER_REC *) server {
	SERVER_REC *old = _chatConnection;

	_chatConnection = server;
	if( _chatConnection ) {
		((SERVER_REC *) _chatConnection) -> no_reconnect = 0;
		server_ref( _chatConnection );
	}

	if( old ) {
		old -> no_reconnect = 1;
		server_unref( old );
	}
}

#pragma mark -

- (void) _registerForSleepNotifications {
	IONotificationPortRef sleepNotePort = NULL;
	CFRunLoopSourceRef rls = NULL;
	_powerConnection = IORegisterForSystemPower( (void *) self, &sleepNotePort, MVChatHandlePowerChange, &_sleepNotifier );
	if( ! _powerConnection ) return;
	rls = IONotificationPortGetRunLoopSource( sleepNotePort );
	CFRunLoopAddSource( CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode );
	CFRelease( rls );
}

- (void) _deregisterForSleepNotifications {
	IODeregisterForSystemPower( &_sleepNotifier );
	_powerConnection = NULL;
}

- (void) _applicationWillTerminate:(NSNotification *) notification {
	extern BOOL applicationQuitting;
	applicationQuitting = YES;
	[self disconnect];
}

#pragma mark -

- (void) _postNotification:(NSNotification *) notification {
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void) _queueNotification:(NSNotification *) notification {
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

#pragma mark -

- (void) _addRoomToCache:(NSString *) room withUsers:(int) users andTopic:(NSData *) topic {
	if( room ) {
		NSDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:users], @"users", topic, @"topic", [NSDate date], @"cached", nil];
		[_roomsCache setObject:info forKey:room];

		NSNotification *notification = [NSNotification notificationWithName:MVChatConnectionGotRoomInfoNotification object:self];
		[self performSelectorOnMainThread:@selector( _queueNotification: ) withObject:notification waitUntilDone:NO];
	}
}

- (NSString *) _roomWithProperPrefix:(NSString *) room {
	NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"#&+!"];
	return ( [set characterIsMember:[room characterAtIndex:0]] ? room : [@"#" stringByAppendingString:room] );
}

#pragma mark -

- (void) _setStatus:(MVChatConnectionStatus) status {
	_status = status;
}

- (void) _nicknameIdentified:(BOOL) identified {
	_nickIdentified = identified;
}

- (void) _willConnect {
	_status = MVChatConnectionConnectingStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillConnectNotification object:self];
}

- (void) _didConnect {
	_status = MVChatConnectionConnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidConnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( connected: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didNotConnect {
	_status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidNotConnectNotification object:self];
}

- (void) _willDisconnect {
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionWillDisconnectNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( MVChatConnection * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( disconnecting: )];
	[invocation setArgument:&self atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (void) _didDisconnect {
	if( [self _irssiConnection] -> connection_lost ) _status = MVChatConnectionServerDisconnectedStatus;
	else _status = MVChatConnectionDisconnectedStatus;
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatConnectionDidDisconnectNotification object:self];
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (void) connectScriptCommand:(NSScriptCommand *) command {
	[self connect];
}

- (void) disconnectScriptCommand:(NSScriptCommand *) command {
	[self disconnect];
}

- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSString *message = [[command evaluatedArguments] objectForKey:@"message"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];
	NSString *room = [[command evaluatedArguments] objectForKey:@"room"];
	BOOL action = [[[command evaluatedArguments] objectForKey:@"action"] boolValue];
	unsigned long enc = [[[command evaluatedArguments] objectForKey:@"encoding"] unsignedLongValue];
	NSStringEncoding encoding = NSUTF8StringEncoding;

	if( ! [message isKindOfClass:[NSString class]] || ! [message length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid message."];
		return;
	}

	if( ! user && ( ! [room isKindOfClass:[NSString class]] || ! [room length] ) ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid room."];
		return;
	}

	if( ! room && ( ! [user isKindOfClass:[NSString class]] || ! [user length] ) ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user."];
		return;
	}

	switch( enc ) {
		default:
		case 'utF8': encoding = NSUTF8StringEncoding; break;
		case 'ascI': encoding = NSASCIIStringEncoding; break;
		case 'nlAs': encoding = NSNonLossyASCIIStringEncoding; break;

		case 'isL1': encoding = NSISOLatin1StringEncoding; break;
		case 'isL2': encoding = NSISOLatin2StringEncoding; break;
		case 'isL3': encoding = (NSStringEncoding) 0x80000203; break;
		case 'isL4': encoding = (NSStringEncoding) 0x80000204; break;
		case 'isL5': encoding = (NSStringEncoding) 0x80000205; break;
		case 'isL9': encoding = (NSStringEncoding) 0x8000020F; break;

		case 'cp50': encoding = NSWindowsCP1250StringEncoding; break;
		case 'cp51': encoding = NSWindowsCP1251StringEncoding; break;
		case 'cp52': encoding = NSWindowsCP1252StringEncoding; break;

		case 'mcRo': encoding = NSMacOSRomanStringEncoding; break;
		case 'mcEu': encoding = (NSStringEncoding) 0x8000001D; break;
		case 'mcCy': encoding = (NSStringEncoding) 0x80000007; break;
		case 'mcJp': encoding = (NSStringEncoding) 0x80000001; break;
		case 'mcSc': encoding = (NSStringEncoding) 0x80000019; break;
		case 'mcTc': encoding = (NSStringEncoding) 0x80000002; break;
		case 'mcKr': encoding = (NSStringEncoding) 0x80000003; break;

		case 'ko8R': encoding = (NSStringEncoding) 0x80000A02; break;

		case 'wnSc': encoding = (NSStringEncoding) 0x80000421; break;
		case 'wnTc': encoding = (NSStringEncoding) 0x80000423; break;
		case 'wnKr': encoding = (NSStringEncoding) 0x80000422; break;

		case 'jpUC': encoding = NSJapaneseEUCStringEncoding; break;
		case 'sJiS': encoding = (NSStringEncoding) 0x80000A01; break;

		case 'krUC': encoding = (NSStringEncoding) 0x80000940; break;

		case 'scUC': encoding = (NSStringEncoding) 0x80000930; break;
		case 'tcUC': encoding = (NSStringEncoding) 0x80000931; break;
		case 'gb30': encoding = (NSStringEncoding) 0x80000632; break;
		case 'gbKK': encoding = (NSStringEncoding) 0x80000631; break;
		case 'biG5': encoding = (NSStringEncoding) 0x80000A03; break;
		case 'bG5H': encoding = (NSStringEncoding) 0x80000A06; break;
	}

	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	if( [user length] ) [self sendMessage:attributeMsg withEncoding:encoding toUser:user asAction:action];
	else if( [room length] ) [self sendMessage:attributeMsg withEncoding:encoding toChatRoom:room asAction:action];
}

- (void) sendRawMessageScriptCommand:(NSScriptCommand *) command {
	NSString *msg = [[command evaluatedArguments] objectForKey:@"message"];

	if( ! [msg isKindOfClass:[NSString class]] || ! [msg length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid raw message."];
		return;
	}

	[self sendRawMessage:[[command evaluatedArguments] objectForKey:@"message"]];
}

- (void) sendSubcodeMessageScriptCommand:(NSScriptCommand *) command {
	NSString *cmd = [[command evaluatedArguments] objectForKey:@"command"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];
	id arguments = [[command evaluatedArguments] objectForKey:@"arguments"];
	unsigned long type = [[[command evaluatedArguments] objectForKey:@"type"] unsignedLongValue];

	if( ! [cmd isKindOfClass:[NSString class]] || ! [cmd length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode command."];
		return;
	}

	if( ! [user isKindOfClass:[NSString class]] || ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode user."];
		return;
	}

	if( [arguments isKindOfClass:[NSNull class]] ) arguments = nil;

	if( arguments && ! [arguments isKindOfClass:[NSString class]] && ! [arguments isKindOfClass:[NSArray class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid subcode arguments."];
		return;
	}

	NSString *argumnentsString = nil;
	if( [arguments isKindOfClass:[NSArray class]] ) {
		NSEnumerator *enumerator = [arguments objectEnumerator];
		id arg = nil;

		argumnentsString = [NSMutableString stringWithFormat:@"%@", [enumerator nextObject]];

		while( ( arg = [enumerator nextObject] ) )
			[(NSMutableString *)argumnentsString appendFormat:@" %@", arg];
	} else argumnentsString = arguments;

	if( type == 'srpL' ) [self sendSubcodeReply:cmd toUser:user withArguments:argumnentsString];
	else [self sendSubcodeRequest:cmd toUser:user withArguments:argumnentsString];
}

- (void) returnFromAwayStatusScriptCommand:(NSScriptCommand *) command {
	[self clearAwayStatus];
}

- (void) joinChatRoomScriptCommand:(NSScriptCommand *) command {
	id rooms = [[command evaluatedArguments] objectForKey:@"room"];

	if( rooms && ! [rooms isKindOfClass:[NSString class]] && ! [rooms isKindOfClass:[NSArray class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid chat room to join."];
		return;
	}

	NSArray *rms = nil;
	if( [rooms isKindOfClass:[NSString class]] )
		rms = [NSArray arrayWithObject:rooms];
	else rms = rooms;

	[self joinChatRooms:rms];
}

- (void) sendFileScriptCommand:(NSScriptCommand *) command {
	NSString *path = [[command evaluatedArguments] objectForKey:@"path"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];

	if( ! [path isKindOfClass:[NSString class]] || ! [path length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid file path."];
		return;
	}

	if( ! [user isKindOfClass:[NSString class]] || ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user."];
		return;
	}

	[self sendFile:path toUser:user];
}

- (NSString *) urlString {
	return [[self url] absoluteString];
}

- (NSTextStorage *) scriptTypedAwayMessage {
	return [[[NSTextStorage alloc] initWithAttributedString:_awayMessage] autorelease];
}

- (void) setScriptTypedAwayMessage:(NSString *) message {
	NSAttributedString *attributeMsg = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	[self setAwayStatusWithMessage:attributeMsg];
}
@end

#pragma mark -

@implementation MVChatScriptPlugin (MVChatScriptPluginConnectionSupport)
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psR1", user, @"psR2", connection, @"psR3", nil];
	id result = [self callScriptHandler:'psRX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", ( arguments ? (id)arguments : (id)[NSNull null] ), @"psL1", user, @"psL2", connection, @"psL3", nil];
	id result = [self callScriptHandler:'psLX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) connected:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	if( ! [self callScriptHandler:'cTsX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

- (void) disconnecting:(MVChatConnection *) connection {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"----", nil];
	if( ! [self callScriptHandler:'dFsX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}
@end

#pragma mark -

@implementation NSURL (NSURLChatAdditions)
- (BOOL) isChatURL {
	if( [[self scheme] isEqualToString:@"irc"] ) return YES;
	return NO;
}

- (BOOL) isChatRoomURL {
	BOOL isRoom = NO;
	if( [[self scheme] isEqualToString:@"irc"] ) {
		if( [self fragment] ) {
			if( [[self fragment] length] > 0 ) isRoom = YES;
		} else if( [self path] && [[self path] length] >= 2 ) {
			if( [[[self path] substringFromIndex:1] hasPrefix:@"&"] || [[[self path] substringFromIndex:1] hasPrefix:@"+"] || [[[self path] substringFromIndex:1] hasPrefix:@"!"] )
				isRoom = YES;
		}
	}
	return isRoom;
}

- (BOOL) isDirectChatURL {
	BOOL isDirect = NO;
	if( [[self scheme] isEqualToString:@"irc"] ) {
		if( [self fragment] ) {
			if( [[self fragment] length] > 0 ) isDirect = NO;
		} else if( [self path] ) {
			if( [[self path] length] >= 2 && [[[self path] substringFromIndex:1] hasPrefix:@"&"] || [[[self path] substringFromIndex:1] hasPrefix:@"+"] || [[[self path] substringFromIndex:1] hasPrefix:@"!"] ) {
				isDirect = NO;
			} else isDirect = YES;
		}
	}
	return isDirect;
}
@end