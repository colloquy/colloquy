#import <Cocoa/Cocoa.h>
#import "MVChatWindowController.h"
#import "MVChatConnection.h"
#import "MVChatPluginManager.h"
#import "MVTextView.h"
#import "MVTableView.h"
#import "MVImageTextCell.h"
#import "MVMenuButton.h"
#import "NSAttributedStringAdditions.h"
#import "NSStringAdditions.h"

static NSMutableDictionary *userChatWindowPrivateStorage = nil;
static NSMutableDictionary *roomChatWindowPrivateStorage = nil;

static NSString *MVToolbarEmoticonsItemIdentifier = @"MVToolbarEmoticonsItem";
static NSString *MVToolbarHideWindowItemIdentifier = @"MVToolbarHideWindowItem";
static NSString *MVToolbarCloseWindowItemIdentifier = @"MVToolbarCloseWindowItem";
static NSString *MVToolbarTextEncodingItemIdentifier = @"MVToolbarTextEncodingItem";
static NSString *MVToolbarBoldFontItemIdentifier = @"MVToolbarBoldFontItem";
static NSString *MVToolbarItalicFontItemIdentifier = @"MVToolbarItalicFontItem";
static NSString *MVToolbarUnderlineFontItemIdentifier = @"MVToolbarUnderlineFontItem";
static NSString *MVToolbarChatMembersItemIdentifier = @"MVToolbarChatMembersItem";

static NSArray *chatActionVerbs = nil;

static const NSStringEncoding MVAllowedEncodings[] = {
/* Universal */
	NSUTF8StringEncoding,
	NSNonLossyASCIIStringEncoding,
/* Western */	(NSStringEncoding) -1, // Divider
	NSASCIIStringEncoding,
	NSISOLatin1StringEncoding, // ISO Latin 1
	(NSStringEncoding) 0x80000203, // ISO Latin 3
	(NSStringEncoding) 0x8000020F, // ISO Latin 9
	NSMacOSRomanStringEncoding, // Mac
	NSWindowsCP1252StringEncoding, // Windows
/* European */	(NSStringEncoding) -1,
	NSISOLatin2StringEncoding, // ISO Latin 2
	(NSStringEncoding) 0x80000204, // ISO Latin 4
	(NSStringEncoding) 0x8000001D, // Mac
	NSWindowsCP1250StringEncoding, // Windows
/* Cyrillic */	(NSStringEncoding) -1,
	(NSStringEncoding) 0x80000A02, // KOI8-R
	(NSStringEncoding) 0x80000205, // ISO Latin 5
	(NSStringEncoding) 0x80000007, // Mac
	NSWindowsCP1251StringEncoding, // Windows
/* Japanese */	(NSStringEncoding) -1, // Divider
	(NSStringEncoding) 0x80000A01, // ShiftJIS
	NSISO2022JPStringEncoding, // ISO-2022-JP
	NSJapaneseEUCStringEncoding, // EUC
	(NSStringEncoding) 0x80000001, // Mac
	NSShiftJISStringEncoding, // Windows
/* Simplified Chinese */	(NSStringEncoding) -1, // Divider
	(NSStringEncoding) 0x80000632, // GB 18030
	(NSStringEncoding) 0x80000631, // GBK
	(NSStringEncoding) 0x80000930, // EUC
	(NSStringEncoding) 0x80000019, // Mac
	(NSStringEncoding) 0x80000421, // Windows
/* Traditional Chinese */	(NSStringEncoding) -1, // Divider
	(NSStringEncoding) 0x80000A03, // Big5
	(NSStringEncoding) 0x80000A06, // Big5 HKSCS
	(NSStringEncoding) 0x80000931, // EUC
	(NSStringEncoding) 0x80000002, // Mac
	(NSStringEncoding) 0x80000423, // Windows
/* Korean */	(NSStringEncoding) -1,
	(NSStringEncoding) 0x80000940, // EUC
	(NSStringEncoding) 0x80000003, // Mac
	(NSStringEncoding) 0x80000422, // Windows
/* End */
	0 };

extern char *irc_html_to_irc(const char * const string);
extern char *irc_irc_to_html(const char * const string);

#pragma mark -

void MVChatPlaySoundForAction( NSString *action ) {
	NSSound *sound = nil;
	NSCParameterAssert( action != nil );
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatPlayActionSounds"] ) return;
	if( ! ( sound = [NSSound soundNamed:action] ) ) {
		NSString *path = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatActionSounds"] objectForKey:action];
		if( ! [path isAbsolutePath] )
			path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];
// I know this leaks. but we release when sounds are changed at least
		sound = [[NSSound alloc] initWithContentsOfFile:path byReference:NO];
		[sound setName:action];
	}
	[sound play];
}

#pragma mark -

@interface MVChatWindowController (MVChatWindowControllerPrivate)
+ (NSData *) _flattenedHTMLFromIRCFormatForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding;
+ (NSData *) _flattenedIRCFormatForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding;
- (void) _refreshUserInfo:(id) sender;
- (void) _setConnection:(MVChatConnection *) connection;
- (void) _setTargetUser:(NSString *) user;
- (void) _setTargetRoom:(NSString *) room;
- (BOOL) _isSetup;
- (void) _setup;
- (void) _preferencesDidChange:(NSNotification *) aNotification;
- (void) _kickedFromChatPart:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
- (void) _disconnectedEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
@end

#pragma mark -

@implementation MVChatWindowController
+ (NSDictionary *) allChatWindowsForConnection:(MVChatConnection *) connection {
	NSMutableDictionary *ret = nil;
	NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithDictionary:[roomChatWindowPrivateStorage objectForKey:[connection description]]];
	[temp addEntriesFromDictionary:[userChatWindowPrivateStorage objectForKey:[connection description]]];
	ret = [NSDictionary dictionaryWithDictionary:temp];
	return [[ret retain] autorelease];
}

+ (NSDictionary *) roomChatWindowsForConnection:(MVChatConnection *) connection {
	NSDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:[roomChatWindowPrivateStorage objectForKey:[connection description]]];
	return [[ret retain] autorelease];
}

+ (NSDictionary *) userChatWindowsForConnection:(MVChatConnection *) connection {
	NSDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:[userChatWindowPrivateStorage objectForKey:[connection description]]];
	return [[ret retain] autorelease];
}

#pragma mark -

+ (MVChatWindowController *) chatWindowForRoom:(NSString *) room withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	NSDictionary *connectionWindows = nil;
	MVChatWindowController *ret = nil;
	NSParameterAssert( room != nil );
	NSParameterAssert( connection != nil );
	connectionWindows = [roomChatWindowPrivateStorage objectForKey:[connection description]];
	if( ! ( ret = [connectionWindows objectForKey:[room lowercaseString]] ) && ! exists )
		ret = [[[MVChatWindowController alloc] initWithRoom:room forConnection:connection] autorelease];
	if( ! [ret _isSetup] ) [ret _setup];
	return [[ret retain] autorelease];
}

+ (void) disposeWindowForRoom:(NSString *) room withConnection:(MVChatConnection *) connection {
	NSMutableDictionary *connectionWindows = nil;
	NSParameterAssert( room != nil );
	NSParameterAssert( connection != nil );
	connectionWindows = [roomChatWindowPrivateStorage objectForKey:[connection description]];
	[connectionWindows removeObjectForKey:[room lowercaseString]];
}

+ (MVChatWindowController *) chatWindowWithUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	NSDictionary *connectionWindows = nil;
	MVChatWindowController *ret = nil;
	NSParameterAssert( user != nil );
	NSParameterAssert( connection != nil );
	connectionWindows = [userChatWindowPrivateStorage objectForKey:[connection description]];
	if( ! ( ret = [connectionWindows objectForKey:user] ) && ! exists )
		ret = [[[MVChatWindowController alloc] initWithUser:user forConnection:connection] autorelease];
	if( ! [ret _isSetup] ) [ret _setup];
	return [[ret retain] autorelease];
}

+ (void) disposeWindowWithUser:(NSString *) user withConnection:(MVChatConnection *) connection {
	NSMutableDictionary *connectionWindows = nil;
	NSParameterAssert( user != nil );
	NSParameterAssert( connection != nil );
	connectionWindows = [userChatWindowPrivateStorage objectForKey:[connection description]];
	[connectionWindows removeObjectForKey:user];
}

#pragma mark -

+ (void) changeMemberInChatWindowsFrom:(NSString *) user to:(NSString *) nick forConnection:(MVChatConnection *) connection {
	NSMutableDictionary *connectionWindows = nil;
	NSEnumerator *enumerator = nil;
	id item = nil;

	NSParameterAssert( user != nil );
	NSParameterAssert( nick != nil );
	NSParameterAssert( connection != nil );

	if( [user isEqualToString:nick] ) return;

	connectionWindows = [userChatWindowPrivateStorage objectForKey:[connection description]];
	enumerator = [connectionWindows keyEnumerator];
	while( ( item = [enumerator nextObject] ) ) {
		if( [item isEqualToString:user] ) {
			id win = [connectionWindows objectForKey:user];
			[connectionWindows setObject:win forKey:nick];
			[connectionWindows removeObjectForKey:user];
			win = [connectionWindows objectForKey:nick];
			[win _setTargetUser:nick];
			[win changeChatMember:user to:nick];
		}
	}

	connectionWindows = [roomChatWindowPrivateStorage objectForKey:[connection description]];
	enumerator = [connectionWindows objectEnumerator];
	while( ( item = [enumerator nextObject] ) ) {
		[item changeChatMember:user to:nick];
	}
}

+ (void) updateChatWindowsMember:(NSString *) member withInfo:(NSDictionary *) info forConnection:(MVChatConnection *) connection {
	NSDictionary *connectionWindows = nil;
	NSEnumerator *enumerator = nil;
	id item = nil;
	
	NSParameterAssert( member != nil );
	NSParameterAssert( info != nil );
	NSParameterAssert( connection != nil );

	connectionWindows = [roomChatWindowPrivateStorage objectForKey:[connection description]];
	enumerator = [connectionWindows objectEnumerator];
	while( ( item = [enumerator nextObject] ) ) {
		[item updateMember:member withInfo:info];
	}
}

+ (void) changeSelfInChatWindowsTo:(NSString *) nick forConnection:(MVChatConnection *) connection {
	NSDictionary *connectionWindows = nil;
	NSEnumerator *enumerator = nil;
	id item = nil;

	NSParameterAssert( nick != nil );
	NSParameterAssert( connection != nil );

	connectionWindows = [userChatWindowPrivateStorage objectForKey:[connection description]];
	enumerator = [connectionWindows objectEnumerator];
	while( ( item = [enumerator nextObject] ) ) {
		[item changeSelfTo:nick];
	}

	connectionWindows = [roomChatWindowPrivateStorage objectForKey:[connection description]];
	enumerator = [connectionWindows objectEnumerator];
	while( ( item = [enumerator nextObject] ) ) {
		[item changeSelfTo:nick];
	}
}

#pragma mark -

+ (NSData *) flattenedHTMLDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"]], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"]], @"NSHTMLIgnoreFontTraits", nil];
	NSData *encodedData = [message HTMLWithOptions:options usingEncoding:enc allowLossyConversion:YES];
	return [[encodedData retain] autorelease];
}

#pragma mark -

- (id) init {
	extern NSArray *chatActionVerbs;
	self = [super init];
	[NSBundle loadNibNamed:@"MVChatWindow" owner:self];
	setup = NO;
	memberDrawerWasOpen = NO;
	firstMessage = YES;
	invalidateMembers = YES;
	_windowClosed = NO;
	chatRoom = NO;
	outlet = nil;
	historyIndex = 0;
	encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatEncoding"];
	sendHistory = [[NSMutableArray array] retain];
	[sendHistory insertObject:[[[NSAttributedString alloc] initWithString:@""] autorelease] atIndex:0];
	memberList = [[NSMutableDictionary dictionary] retain];
	sortedMembers = [[NSMutableArray array] retain];
	if( ! chatActionVerbs )
		chatActionVerbs = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"verbs" ofType:@"plist"]];
	[chatActionVerbs retain];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _preferencesDidChange: ) name:@"MVChatPreferencesDidChangeNotification" object:nil];
	return self;
}

- (id) initWithRoom:(NSString *) room forConnection:(MVChatConnection *) connection {
	extern NSMutableDictionary *roomChatWindowPrivateStorage;
	MVChatWindowController *ret = nil;
	NSMutableDictionary *connectionWindows = nil;
	NSParameterAssert( room != nil );
	NSParameterAssert( connection != nil );
	if( ! roomChatWindowPrivateStorage )
		roomChatWindowPrivateStorage = [NSMutableDictionary dictionary];
	connectionWindows = [roomChatWindowPrivateStorage objectForKey:[connection description]];
	if( ! connectionWindows ) {
		connectionWindows = [NSMutableDictionary dictionary];
		[roomChatWindowPrivateStorage setObject:connectionWindows forKey:[connection description]];
	}
	if( ! ( ret = [connectionWindows objectForKey:[room lowercaseString]] ) ) {
		self = [self init];
		ret = self;
		[connectionWindows setObject:self forKey:[room lowercaseString]];
		[connectionWindows retain];
		[roomChatWindowPrivateStorage retain];
		[self _setConnection:connection];
		[self _setTargetRoom:[room lowercaseString]];
		[window setFrameAutosaveName:[NSString stringWithFormat:@"chat.room.%@.%@", [connection server], [room lowercaseString]]];
		if( ! [self _isSetup] ) [self _setup];
		_refreshTimer = [[NSTimer scheduledTimerWithTimeInterval:600. target:self selector:@selector( _refreshUserInfo: ) userInfo:nil repeats:YES] retain];
	}
	return ret;
}

- (id) initWithUser:(NSString *) user forConnection:(MVChatConnection *) connection {
	extern NSMutableDictionary *userChatWindowPrivateStorage;
	MVChatWindowController *ret = nil;
	NSMutableDictionary *connectionWindows = nil;
	NSParameterAssert( user != nil );
	NSParameterAssert( connection != nil );
	if( ! userChatWindowPrivateStorage )
		userChatWindowPrivateStorage = [NSMutableDictionary dictionary];
	connectionWindows = [userChatWindowPrivateStorage objectForKey:[connection description]];
	if( ! connectionWindows ) {
		connectionWindows = [NSMutableDictionary dictionary];
		[userChatWindowPrivateStorage setObject:connectionWindows forKey:[connection description]];
	}
	if( ! ( ret = [connectionWindows objectForKey:user] ) ) {
		self = [self init];
		ret = self;
		[connectionWindows setObject:self forKey:user];
		[connectionWindows retain];
		[userChatWindowPrivateStorage retain];
		[self _setConnection:connection];
		[self _setTargetUser:user];
		[window setFrameAutosaveName:[NSString stringWithFormat:@"chat.user.%@.%@", [connection server], user]];
		if( ! [self _isSetup] ) [self _setup];
		[self addMemberToChat:user asPreviousMember:YES];
	}
	return ret;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 ) {
		[_refreshTimer invalidate];
	}
	[super release];
}

- (void) dealloc {
	extern NSArray *chatActionVerbs;

	if( ! _windowClosed ) [window close];
	window = nil;

	[memberDrawer setParentWindow:nil];
	[[memberDrawer contentView] autorelease];
	[memberDrawer autorelease];

	[emoticonView autorelease];
	[encodingView autorelease];
	[sendHistory autorelease];
	[memberList autorelease];
	[sortedMembers autorelease];
	[chatActionVerbs autorelease];
	[_refreshTimer autorelease];
	[_topic autorelease];
	[_topicAuth autorelease];
	[_spillEncodingMenu autorelease];
	[_lastDateMessage autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if( [chatActionVerbs retainCount] == 1 ) chatActionVerbs = nil;

	memberDrawer = nil;
	emoticonView = nil;
	encodingView = nil;

	sendHistory = nil;
	memberList = nil;
	sortedMembers = nil;
	_refreshTimer = nil;
	_topic = nil;
	_topicAuth = nil;
	_spillEncodingMenu = nil;
	_lastDateMessage = nil;

	if( [self targetRoom] ) {
		[[roomChatWindowPrivateStorage objectForKey:[[self connection] description]] autorelease];
		if( ! [[roomChatWindowPrivateStorage objectForKey:[[self connection] description]] count] )
			[roomChatWindowPrivateStorage removeObjectForKey:[[self connection] description]];
		[roomChatWindowPrivateStorage autorelease];
		if( ! [roomChatWindowPrivateStorage count] ) roomChatWindowPrivateStorage = nil;
	} else if( [self targetUser] ) {
		[[userChatWindowPrivateStorage objectForKey:[[self connection] description]] autorelease];
		if( ! [[userChatWindowPrivateStorage objectForKey:[[self connection] description]] count] )
			[userChatWindowPrivateStorage removeObjectForKey:[[self connection] description]];
		[userChatWindowPrivateStorage autorelease];
		if( ! [userChatWindowPrivateStorage count] ) userChatWindowPrivateStorage = nil;
	}

	[outlet autorelease];
	outlet = nil;
	[super dealloc];
}

- (void) awakeFromNib {
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"chat.message.toolbar"] autorelease];
	NSTableColumn *theColumn = nil;
	id prototypeCell = nil;

	[emoticonView retain];
	[encodingView retain];

	[emoticonView setControlSize:NSRegularControlSize];
	[emoticonView setSmallImage:[NSImage imageNamed:@"emoticonSmall"]];

	[[[encodingView menu] itemAtIndex:0] setImage:[NSImage imageNamed:@"encoding"]];

	[window setDelegate:self];

	[displayText setHorizontallyResizable:YES];
	[displayText setVerticallyResizable:YES];
	[displayText setAutoresizingMask:NSViewWidthSizable];
	[displayText setSelectable:YES];
	[displayText setEditable:NO];
	[displayText setRichText:YES];
	[displayText setImportsGraphics:YES];
	[displayText setUsesFontPanel:NO];
	[displayText setUsesRuler:NO];
	[displayText setDelegate:self];
	[displayText setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatBackgroundColor"]]];

	[sendText setHorizontallyResizable:YES];
	[sendText setVerticallyResizable:YES];
	[sendText setAutoresizingMask:NSViewWidthSizable];
	[sendText setSelectable:YES];
	[sendText setEditable:YES];
	[sendText setRichText:YES];
	[sendText setImportsGraphics:NO];
	[sendText setUsesFontPanel:YES];
	[sendText setUsesRuler:NO];
	[sendText setDelegate:self];
    [sendText setContinuousSpellCheckingEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSpellChecking"]];
	[sendText reset:nil];

	[sendTextScrollView setBorderType:NSBezelBorder];
	[sendTextScrollView setHasVerticalScroller:YES];
	[sendTextScrollView setHasHorizontalScroller:NO];
	[sendTextScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[[sendTextScrollView contentView] setAutoresizesSubviews:YES];
	[sendTextScrollView setDocumentView:sendText];

	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[window setToolbar:toolbar];

	theColumn = [memberListTable tableColumnWithIdentifier:@"name"];
	prototypeCell = [MVImageTextCell new];
	[prototypeCell setEditable:YES];
	[prototypeCell setFont:[NSFont systemFontOfSize:11.]];
	[theColumn setDataCell:prototypeCell];

	[memberListTable registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

#pragma mark -

- (MVChatConnection *) connection {
	return [[_connection retain] autorelease];
}

- (NSString *) targetUser {
	if( ! chatRoom ) return [[outlet retain] autorelease];
	else return nil;
}

- (NSString *) targetRoom {
	if( chatRoom ) return [[outlet retain] autorelease];
	else return nil;
}

#pragma mark -

- (BOOL) isChatRoom {
	return chatRoom;
}

#pragma mark -

- (NSMutableArray *) memberList {
	return [[memberList retain] autorelease];
}

#pragma mark -

- (void) addMemberToChat:(NSString *) member asPreviousMember:(BOOL) previous {
	NSParameterAssert( member != nil );
	if( invalidateMembers ) {
		[memberList removeAllObjects];
		[sortedMembers removeAllObjects];
		invalidateMembers = NO;
	}
	if( ! [memberList objectForKey:member] ) {
		[memberList setObject:[NSMutableDictionary dictionary] forKey:member];
		if( [member isEqualToString:[[self connection] nickname]] )
			[[memberList objectForKey:member] setObject:[NSNumber numberWithBool:YES] forKey:@"self"];
		[sortedMembers addObject:member];
		[sortedMembers sortUsingSelector:@selector( caseInsensitiveCompare: )];
		if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
		if( ! previous ) {
			[self addMessageToDisplay:NSLocalizedString( @"joined the chat room.", "a user has join a chat room - presented as an action" ) fromUser:member asAction:YES asAlert:YES];
			MVChatPlaySoundForAction( @"MVChatMemberJoinedRoomAction" );
		}
	}
}

- (void) updateMember:(NSString *) member withInfo:(NSDictionary *) info {
	NSParameterAssert( member != nil );
	NSParameterAssert( info != nil );
	if( [memberList objectForKey:member] ) {
		[[memberList objectForKey:member] addEntriesFromDictionary:info];
		if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
	}
}

- (void) removeChatMember:(NSString *) member withReason:(NSData *) reason {
	NSParameterAssert( member != nil );
	if( chatRoom ) {
		if( [memberList objectForKey:member] ) {
			[memberList removeObjectForKey:member];
			[sortedMembers removeObject:member];
			if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
			if( reason ) {
				NSString *rstring = [[[NSString alloc] initWithData:reason encoding:encoding] autorelease];
				NSData *data = [[NSString stringWithFormat:NSLocalizedString( @"left the chat room for this reason: %@.", "a user has left a chat room with a reason - presented as an action" ), rstring] dataUsingEncoding:encoding allowLossyConversion:YES];
				[self addHTMLMessageToDisplay:data fromUser:member asAction:YES asAlert:YES];
			} else [self addMessageToDisplay:NSLocalizedString( @"left the chat room.", "a user has left a chat room - presented as an action" ) fromUser:member asAction:YES asAlert:YES];
			MVChatPlaySoundForAction( @"MVChatMemberLeftRoomAction" );
		}
	}
}

- (void) changeChatMember:(NSString *) member to:(NSString *) nick {
	NSParameterAssert( member != nil );
	NSParameterAssert( nick != nil );
	if( [memberList objectForKey:member] ) {
		[memberList setObject:[memberList objectForKey:member] forKey:nick];
		[memberList removeObjectForKey:member];
		[sortedMembers removeObject:member];
		[sortedMembers addObject:nick];
		[sortedMembers sortUsingSelector:@selector( caseInsensitiveCompare: )];
		if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
		[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"is now known as %@.", "user has changed nicknames - presented as an action" ), nick] fromUser:member asAction:YES asAlert:YES];
		if( [member isEqualToString:[self targetUser]] ) {
			[window setTitle:[NSString stringWithFormat:NSLocalizedString( @"%@ - Private Message", "private message with user - window title" ), nick]];
			[NSWindow removeFrameUsingName:[window frameAutosaveName]];
			[window setFrameAutosaveName:[NSString stringWithFormat:@"chat.user.%@.%@", [[self connection] server], nick]];
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"chat.user.%@.encoding", member]];
			if( encoding != (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatEncoding"] )
				[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:encoding] forKey:[NSString stringWithFormat:@"chat.user.%@.encoding", nick]];
		}
	}
}

- (void) changeSelfTo:(NSString *) nick {
	NSEnumerator *enumerator = [memberList objectEnumerator], *keyEnumerator = [memberList keyEnumerator];
	id item, key;
	NSParameterAssert( nick != nil );
	while( ( item = [enumerator nextObject] ) && ( key = [keyEnumerator nextObject] ) ) {
		if( [[item objectForKey:@"self"] boolValue] ) {
			if( ! [nick isEqualToString:key] ) {
				[memberList setObject:item forKey:nick];
				[memberList removeObjectForKey:key];
				[sortedMembers removeObject:key];
				[sortedMembers addObject:nick];
				[sortedMembers sortUsingSelector:@selector( caseInsensitiveCompare: )];
				if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
			}
			break;
		}
	}
}

#pragma mark -

- (void) promoteChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( chatRoom ) {
		if( [memberList objectForKey:member] ) {
			[[memberList objectForKey:member] setObject:[NSNumber numberWithBool:YES] forKey:@"op"];
			if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
			if( by ) {
				[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"promoted %@ to operator.", "user is now a chat room operator - presented as an action" ), member] fromUser:by asAction:YES asAlert:YES];
				MVChatPlaySoundForAction( @"MVChatMemberPromotedAction" );
			}
		}
	}
}

- (void) demoteChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( chatRoom ) {
		if( [memberList objectForKey:member] ) {
			[[memberList objectForKey:member] removeObjectForKey:@"op"];
			if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
			if( by ) {
				[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"demoted %@ from operator.", "user was removed from chat room operator status - presented as an action" ), member] fromUser:by asAction:YES asAlert:YES];
				MVChatPlaySoundForAction( @"MVChatMemberDemotedAction" );
			}
		}
	}
}

- (void) voiceChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( chatRoom ) {
		if( [memberList objectForKey:member] ) {
			[[memberList objectForKey:member] setObject:[NSNumber numberWithBool:YES] forKey:@"voice"];
			if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
			if( by ) {
				[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"granted %@ voice.", "user now has special voice status - presented as an action" ), member] fromUser:by asAction:YES asAlert:YES];
				MVChatPlaySoundForAction( @"MVChatMemberVoicedAction" );
			}
		}
	}
}

- (void) devoiceChatMember:(NSString *) member by:(NSString *) by {
	NSParameterAssert( member != nil );
	if( chatRoom ) {
		if( [memberList objectForKey:member] ) {
			[[memberList objectForKey:member] removeObjectForKey:@"voice"];
			if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
			if( by ) {
				[self addMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"removed voice from %@.", "user was removed from chat room special voice status - presented as an action" ), member] fromUser:by asAction:YES asAlert:YES];
				MVChatPlaySoundForAction( @"MVChatMemberDevoicedAction" );
			}
		}
	}
}

#pragma mark -

- (void) changeTopic:(NSData *) topic by:(NSString *) author { /* ~CRASH! */
	NSData *tData = nil;
	NSParameterAssert( topic != nil );
	if( [topic length] ) tData = topic;
	else {
		tData = [[NSString stringWithFormat:@"<font color=\"#6c6c6c\">%@</font>", NSLocalizedString( @"(no chat topic is set)", "no chat topic is set message" )] dataUsingEncoding:NSUTF8StringEncoding];
		author = nil;
	}
	if( chatRoom ) {
		NSRange limitRange, effectiveRange;
		NSMutableAttributedString *topicAttr = [[[NSAttributedString attributedStringWithHTML:tData usingEncoding:encoding documentAttributes:NULL] mutableCopy] autorelease];
		NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		NSMutableAttributedString *addons = nil;
		NSMutableDictionary *attributes = nil;

		[_topic autorelease];
		_topic = [topic retain];
		[_topicAuth autorelease];
		_topicAuth = [author retain];

		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] ) {
			[topicAttr preformHTMLBackgroundColoring];
		}

		attributes = [NSMutableDictionary dictionaryWithObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSBoldFontMask weight:5 size:0.] forKey:NSFontAttributeName];
		addons = [[[NSMutableAttributedString alloc] initWithString:NSLocalizedString( @"Topic: ", "chat room topic prefix" ) attributes:attributes] autorelease];
		[topicAttr insertAttributedString:addons atIndex:0];

		if( author ) {
			attributes = [NSMutableDictionary dictionaryWithObject:[[NSFontManager sharedFontManager] fontWithFamily:@"Helvetica" traits:NSItalicFontMask weight:5 size:0.] forKey:NSFontAttributeName];
			addons = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString( @" posted by %@", "who posted the current topic" ), author] attributes:attributes] autorelease];
			[topicAttr appendAttributedString:addons];
		}

		limitRange = NSMakeRange( 0, [topicAttr length] );
		while( limitRange.length > 0 ) {
			NSFont *font = [topicAttr attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
			font = [[NSFontManager sharedFontManager] convertFont:font toFamily:@"Helvetica"];
			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] )
				font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask | NSBoldFontMask];
			[topicAttr addAttribute:NSFontAttributeName value:font range:effectiveRange];
			limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
		}

		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] )
			[topicAttr addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:0] range:NSMakeRange( 0, [topicAttr length] )];		

		[paraStyle setMaximumLineHeight:15.];
		[topicAttr addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange( 0, [topicAttr length] )];
		[topicArea setAttributedStringValue:topicAttr];
	} else [topicArea setAttributedStringValue:nil];
}

#pragma mark -

- (void) chatMemberKicked:(NSString *) member by:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;
	NSData *data = nil;
	NSParameterAssert( member != nil );
	NSParameterAssert( by != nil );
	rstring = [[[NSString alloc] initWithData:reason encoding:encoding] autorelease];
	data = [[NSString stringWithFormat:NSLocalizedString( @"booted %@ with this reason '%@'.", "user has been removed by force from a chat room - presented as an action" ), member, rstring] dataUsingEncoding:encoding allowLossyConversion:YES];
	[self addHTMLMessageToDisplay:data fromUser:by asAction:YES asAlert:YES];
	[memberList removeObjectForKey:member];
	[sortedMembers removeObject:member];
	if( [memberListTable editedRow] < 0 ) [memberListTable reloadData];
	MVChatPlaySoundForAction( @"MVChatMemberKickedAction" );
}

- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason {
	NSString *rstring = nil;
	NSData *data = nil;
	NSParameterAssert( by != nil );
	rstring = [[[NSString alloc] initWithData:reason encoding:encoding] autorelease];
	data = [[NSString stringWithFormat:NSLocalizedString( @"booted you with this reason '%@'.", "you were removed by force from a chat room - presented as an action" ), rstring] dataUsingEncoding:encoding allowLossyConversion:YES];
	[self addHTMLMessageToDisplay:data fromUser:by asAction:YES asAlert:YES];
	MVChatPlaySoundForAction( @"MVChatMemberKickedAction" );
	NSBeginCriticalAlertSheet( NSLocalizedString( @"Booted", "title of the booted message sheet" ), nil, nil, nil, window, self, NULL, @selector( _kickedFromChatPart:returnCode:contextInfo: ), NULL, NSLocalizedString( @"You have been booted out of this room by %@.", "description for getting booted" ), by );
}

#pragma mark -

- (void) connected {
	invalidateMembers = YES;
	[[window attachedSheet] close];
}

- (void) disconnected {
	invalidateMembers = YES;
	[self addStatusMessageToDisplay:[[NSDate date] descriptionWithCalendarFormat:NSLocalizedString( @"%1I:%M %p, you're offline.", "offline time stamp" ) timeZone:nil locale:nil]];
	NSBeginCriticalAlertSheet( NSLocalizedString( @"You're offline", "title of the you're offline message sheet" ), nil, NSLocalizedString( @"Close", "close window button text" ), nil, window, self, NULL, @selector( _disconnectedEnd:returnCode:contextInfo: ), NULL, NSLocalizedString( @"No messages can be sent at this time. Reconnecting might be in progress.", "error description for loosing connection" ) );
}

- (void) unavailable {
	invalidateMembers = YES;
	if( ! chatRoom ) {
		[self addStatusMessageToDisplay:[[NSDate date] descriptionWithCalendarFormat:NSLocalizedString( @"%1I:%M %p, user offline.", "user offline time stamp" ) timeZone:nil locale:nil]];
		NSBeginCriticalAlertSheet( NSLocalizedString( @"Message undeliverable", "title of the user offline message sheet" ), nil, NSLocalizedString( @"Close", "close window button text" ), nil, window, self, NULL, @selector( _disconnectedEnd:returnCode:contextInfo: ), NULL, NSLocalizedString( @"This user is now offline or you have messaged an invalid user. Any messages sent will not be received by the other user.", "error description for messaging a user that went offline or invalid" ) );
	}
}

#pragma mark -

- (IBAction) addEmoticon:(id) sender {
	if( [[sendText textStorage] length] )
		[sendText replaceCharactersInRange:NSMakeRange([[sendText textStorage] length], 0) withString:@" "];
	[sendText replaceCharactersInRange:NSMakeRange([[sendText textStorage] length], 0) withString:[NSString stringWithFormat:@"%@ ", [sender representedObject]]];
}

#pragma mark -

- (void) addStatusMessageToDisplay:(NSString *) message { /* ~CRASH! */
	NSParameterAssert( message != nil );
	{
		NSMutableAttributedString *msgString = nil;
		NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
		NSMutableParagraphStyle *para = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		float brightness = 0.;

		[para setAlignment:NSCenterTextAlignment];

		brightness = [[[displayText backgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] brightnessComponent];
		brightness = ( brightness > 0.5 ? 0. : 1. );

		[attribs setObject:[NSColor colorWithCalibratedHue:0. saturation:0. brightness:brightness alpha:0.66] forKey:NSForegroundColorAttributeName];
		[attribs setObject:[NSFont fontWithName:@"Helvetica" size:11.] forKey:NSFontAttributeName];
		[attribs setObject:para forKey:NSParagraphStyleAttributeName];

		msgString = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", message] attributes:attribs] autorelease];
		[[displayText textStorage] appendAttributedString:msgString];
	}
}

#pragma mark -

- (void) addMessageToDisplay:(NSString *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert {
	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );
	{
		NSMutableAttributedString *msgString = [[[NSMutableAttributedString alloc] initWithString:message attributes:[NSDictionary dictionaryWithObject:[NSFont fontWithName:@"Helvetica" size:0.] forKey:NSFontAttributeName]] autorelease];
		[self addAttributedMessageToDisplay:msgString fromUser:user asAction:action asAlert:alert];
	}
}

- (void) addHTMLMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert {
	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );
	{
		NSRange limitRange, effectiveRange;
		NSMutableAttributedString *msgString = [[[NSAttributedString attributedStringWithHTML:message usingEncoding:encoding documentAttributes:NULL] mutableCopy] autorelease];

		limitRange = NSMakeRange( 0, [msgString length] );
		while( limitRange.length > 0 ) {
			NSFont *font = [msgString attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
			font = [[NSFontManager sharedFontManager] convertFont:font toFamily:@"Helvetica"];
			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] )
				font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask | NSBoldFontMask];
			[msgString addAttribute:NSFontAttributeName value:font range:effectiveRange];
			limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
		}

		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] )
			[msgString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:0] range:NSMakeRange( 0, [msgString length] )];

		[self addAttributedMessageToDisplay:msgString fromUser:user asAction:action asAlert:alert];
	}
}

- (void) addAttributedMessageToDisplay:(NSAttributedString *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert { /* ~CRASH! */
	NSMutableAttributedString *msgString = nil;
	NSScanner *urlScanner = nil;
	NSString *urlHandle = nil;
	unsigned length = 0, lastLoc = 0, begin = 0;
	NSEnumerator *enumerator = nil;
	id item = nil;

	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	if( ! _lastDateMessage || [_lastDateMessage timeIntervalSinceNow] < -300. ) {
		[_lastDateMessage autorelease];
		_lastDateMessage = [[NSDate date] retain];

		[self addStatusMessageToDisplay:[_lastDateMessage descriptionWithCalendarFormat:NSLocalizedString( @"%1I:%M %p", "time format for chat time stamps: hour:minute am/pm" ) timeZone:nil locale:nil]];
	}

	msgString = [[message mutableCopy] autorelease];
	begin = [[displayText textStorage] length];

	if( user ) {
		if( action ) [displayText replaceCharactersInRange:NSMakeRange( [[displayText textStorage] length], 0 ) withString:@"\xA5"];
		[displayText replaceCharactersInRange:NSMakeRange( [[displayText textStorage] length], 0 ) withString:user];
		if( ! action ) [displayText replaceCharactersInRange:NSMakeRange( [[displayText textStorage] length], 0 ) withString:@":"];
		length = [[displayText textStorage] length] - begin;
		if( ( [[msgString string] rangeOfString:@"'"].location && action ) || ! action ) {
			[displayText replaceCharactersInRange:NSMakeRange( [[displayText textStorage] length], 0 ) withString:@" "];
			[[displayText textStorage] setAttributes:nil range:NSMakeRange( begin + length, 1. )];
		}
		[[displayText textStorage] setAttributes:nil range:NSMakeRange( begin, length )];
		[displayText setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]] range:NSMakeRange( begin, length )];
		if( alert ) {
			[displayText setTextColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatAlertColor"]] range:NSMakeRange( begin, length )];
		} else if( ! [user caseInsensitiveCompare:[[self connection] nickname]] ) {
			[displayText setTextColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatSelfColor"]] range:NSMakeRange( begin, length )];
		} else {
			[displayText setTextColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatOthersColor"]] range:NSMakeRange( begin, length )];
		}
	}

	if( [self isChatRoom] ) enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processRoomMessage:fromUser:inRoom:asAction:forConnection: )] objectEnumerator];
	else enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processPrivateMessage:fromUser:asAction:forConnection: )] objectEnumerator];

	while( ( item = [enumerator nextObject] ) ) {
		if( [self isChatRoom] ) msgString = [item processRoomMessage:msgString fromUser:user inRoom:[self targetRoom] asAction:action forConnection:[self connection]];
		else msgString = [item processPrivateMessage:msgString fromUser:user asAction:action forConnection:[self connection]];
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"] ) {
		[msgString preformHTMLBackgroundColoring];
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] ) {
		[msgString preformLinkHighlightingUsingColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatLinkColor"]] withUnderline:YES];
	}

	urlScanner = [NSScanner scannerWithString:[msgString string]];
	while( [urlScanner isAtEnd] == NO ) {
		lastLoc = [urlScanner scanLocation];
		if( [urlScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&urlHandle] ) {
			if( ( [urlHandle rangeOfString:@"#"].location == 0 || [urlHandle rangeOfString:@"&"].location == 0 || [urlHandle rangeOfString:@"+"].location == 0 ) && [urlHandle length] > 2 && [urlHandle rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != 1 && ! [[urlHandle substringFromIndex:1] rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].length ) {
				id irc = [NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], urlHandle];
				if( lastLoc ) lastLoc += 1;
				[msgString addAttributes:[NSAttributedString linkAttributesForTarget:irc] range:NSMakeRange( lastLoc, [urlHandle length] )];
			}
		}
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableGraphicEmoticons"] ) {
		id dict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"emoticons" ofType:@"plist"]];
		[msgString preformImageSubstitutionWithDictionary:dict];
	}

	[[displayText textStorage] appendAttributedString:msgString];
	[displayText replaceCharactersInRange:NSMakeRange( [[displayText textStorage] length], 0 ) withString:@"\n"];
	if( NSMinY( [displayText visibleRect] ) >= ( NSHeight( [displayText bounds] ) - ( NSHeight( [displayText visibleRect] ) * 1.1 ) ) ) {
		[displayText scrollRangeToVisible:NSMakeRange( [[displayText textStorage] length], 0 )];
	}
	[displayText resetCursorRects];

	[[displayText textStorage] addAttribute:@"MVChatAddedDate" value:[NSDate date] range:NSMakeRange( begin, [[displayText textStorage] length] - begin )];
	[[displayText textStorage] addAttribute:@"MVChatFrom" value:[[user copy] autorelease] range:NSMakeRange( begin, [[displayText textStorage] length] - begin )];
	[[displayText textStorage] addAttribute:@"MVChatMessage" value:[[message copy] autorelease] range:NSMakeRange( begin, [[displayText textStorage] length] - begin )];
	[[displayText textStorage] addAttribute:@"MVChatAction" value:[NSNumber numberWithBool:action] range:NSMakeRange( begin, [[displayText textStorage] length] - begin )];
	[[displayText textStorage] addAttribute:@"MVChatAlert" value:[NSNumber numberWithBool:alert] range:NSMakeRange( begin, [[displayText textStorage] length] - begin )];
	
	[window setDocumentEdited:![window isKeyWindow]];

	if( action ) [displayText setTextColor:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatActionColor"]] range:NSMakeRange( begin + 1, [[displayText textStorage] length] - begin - 1 )];

	if( ! [user isEqualToString:[[self connection] nickname]] ) {
		NSMutableArray *names = nil;
		if( ! chatRoom && firstMessage ) MVChatPlaySoundForAction( @"MVChatFisrtMessageAction" );
		if( ! chatRoom && ! firstMessage ) MVChatPlaySoundForAction( @"MVChatAdditionalMessagesAction" );
		if( [[msgString string] rangeOfString:@"\007"].length ) MVChatPlaySoundForAction( @"MVChatInlineMessageBeepAction" );
		firstMessage = NO;

		names = [[[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"MVChatHighlightNames"] mutableCopy] autorelease];
		[names addObject:[[self connection] nickname]];
		enumerator = [names objectEnumerator];
		while( ( item = [enumerator nextObject] ) ) {
			if( [[[msgString string] lowercaseString] rangeOfString:item].length ) {
				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconOnMessage"] && [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconUntilFront"] )
					[NSApp requestUserAttention:NSCriticalRequest];
				else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconOnMessage"] ) [NSApp requestUserAttention:NSInformationalRequest];
				[[displayText textStorage] addAttribute:NSBackgroundColorAttributeName value:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatHighlightColor"]] range:NSMakeRange( begin, [[displayText textStorage] length] - begin )];
				MVChatPlaySoundForAction( @"MVChatMentionedAction" );
				break;
			}
		}
	}

	if( ! chatRoom && ! [user isEqualToString:[[self connection] nickname]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconOnMessage"] ) {
		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatBounceIconUntilFront"] )
			[NSApp requestUserAttention:NSCriticalRequest];
		else [NSApp requestUserAttention:NSInformationalRequest];
	}

	if( ( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatShowHiddenOnPrivateMessage"] && ! chatRoom ) ||
		( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatShowHiddenOnRoomMessage"] && chatRoom ) )
			if( ! [self isVisible] ) [self showWindow:nil];
}

#pragma mark -

- (IBAction) send:(id) sender {
//	NSData *msgData = nil;
	NSMutableAttributedString *subMsg = nil;
	NSEnumerator *enumerator = nil;
	id item = nil;
	BOOL action = NO;
	NSRange range;

	if( ! [[self connection] isConnected] ) {
		[self disconnected];
		return;
	}

	historyIndex = 0;
	if( ! [[sendText textStorage] length] ) return;
	if( [sendHistory count] )
		[sendHistory replaceObjectAtIndex:0 withObject:[[[NSAttributedString alloc] initWithString:@""] autorelease]];
	[sendHistory insertObject:[[[sendText textStorage] copy] autorelease] atIndex:1];
	if( [sendHistory count] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatMaximumHistory"] unsignedIntValue] )
		[sendHistory removeObjectAtIndex:[sendHistory count] - 1];

	if( [sender isKindOfClass:[NSNumber class]] && [sender boolValue] ) action = YES;

	[[[sendText textStorage] mutableString] replaceString:@"<" withString:@"&lt;" maxTimes:0];
	[[[sendText textStorage] mutableString] replaceString:@">" withString:@"&gt;" maxTimes:0];
	[[[sendText textStorage] mutableString] replaceString:@"\r" withString:@"\n" maxTimes:0];

	while( [[sendText textStorage] length] ) {
		range = [[[sendText textStorage] string] rangeOfString:@"\n"];
		if( ! range.length ) range.location = [[sendText textStorage] length];
		subMsg = [[[[sendText textStorage] attributedSubstringFromRange:NSMakeRange( 0, range.location )] mutableCopy] autorelease];

		if( ( [subMsg length] >= 1 && range.length ) || ( [subMsg length] && ! range.length ) ) {
			if( [[sendText string] hasPrefix:@"/"] ) {
				BOOL handled = NO;
				NSScanner *scanner = [NSScanner scannerWithString:[sendText string]];
				NSString *command = nil;
				NSAttributedString *arguments = nil;

				if( [self isChatRoom] ) enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processUserCommand:withArguments:toRoom:forConnection: )] objectEnumerator];
				else enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processUserCommand:withArguments:toUser:forConnection: )] objectEnumerator];

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [[sendText string] length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [sendText attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], range.location - [scanner scanLocation] )];

				while( ( item = [enumerator nextObject] ) ) {
					if( [self isChatRoom] ) handled = [item processUserCommand:command withArguments:arguments toRoom:[self targetRoom] forConnection:[self connection]];
					else handled = [item processUserCommand:command withArguments:arguments toUser:[self targetUser] forConnection:[self connection]];
					if( handled ) break;
				}

				if( ! handled ) {
					NSRunInformationalAlertPanel( NSLocalizedString( @"Command not recognised", "IRC command not recognised dialog title" ), NSLocalizedString( @"The command you specified is not recognised by Colloquy or it's plugins. No action can be performed.", "IRC command not recognised dialog message" ), nil, nil, nil );
					return;
				}
			} else {
				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"] && ! action ) {
					extern NSArray *chatActionVerbs;
					NSString *tempString = [[subMsg string] stringByAppendingString:@" "];
					enumerator = [chatActionVerbs objectEnumerator];
					while( ( item = [enumerator nextObject] ) ) {
						if( [tempString hasPrefix:[item stringByAppendingString:@" "]] ) {
							action = YES;
							break;
						}
					}
				}

				if( [self isChatRoom] ) enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processRoomMessage:toRoom:asAction:forConnection: )] objectEnumerator];
				else enumerator = [[[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processPrivateMessage:toUser:asAction:forConnection: )] objectEnumerator];

				while( ( item = [enumerator nextObject] ) ) {
					if( [self isChatRoom] ) subMsg = [item processRoomMessage:subMsg toRoom:[self targetRoom] asAction:action forConnection:[self connection]];
					else subMsg = [item processPrivateMessage:subMsg toUser:[self targetUser] asAction:action forConnection:[self connection]];
				}

				if( [self isChatRoom] ) [[self connection] sendMessageToChatRoom:[self targetRoom] attributedMessage:subMsg withEncoding:encoding asAction:action];
				else [[self connection] sendMessageToUser:[self targetUser] attributedMessage:subMsg withEncoding:encoding asAction:action];

//				NSLog( @"raw: %s", [[[subMsg string] dataUsingEncoding:encoding allowLossyConversion:YES] bytes] );
//				NSLog( @"irc: %s", [[[self class] _flattenedIRCFormatForMessage:subMsg withEncoding:encoding] bytes] );
//				NSLog( @"html: %s", [[[self class] _flattenedHTMLFromIRCFormatForMessage:subMsg withEncoding:encoding] bytes] );

//				msgData = [[self class] _flattenedHTMLFromIRCFormatForMessage:subMsg withEncoding:encoding];
//				[self addHTMLMessageToDisplay:msgData fromUser:[[self connection] nickname] asAction:action asAlert:NO];
			}
		}
		if( range.length ) range.location++;
		[[sendText textStorage] deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}
	[sendText reset:nil];
	[displayText scrollRangeToVisible:NSMakeRange( [[displayText textStorage] length], 0 )];
}

- (IBAction) clear:(id) sender {
	[sendText reset:nil];
}

- (IBAction) clearDisplay:(id) sender {
	[displayText reset:nil];
}

#pragma mark -

- (NSStringEncoding) encoding {
	return encoding;
}

- (IBAction) changeEncoding:(id) sender {
	NSMenuItem *menuItem = nil;
	unsigned i = 0, count = 0;
	BOOL new = YES;
	if( ! [sender tag] ) {
		if( chatRoom ) encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"chat.room.%@.%@.encoding", [[self connection] server], [self targetRoom]]];
		else encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"chat.user.%@.%@.encoding", [[self connection] server], [self targetUser]]];
		if( ! encoding ) encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatEncoding"];
	} else encoding = (NSStringEncoding) [sender tag];

	if( [[encodingView menu] numberOfItems] > 1 ) new = NO;

	for( i = 0; MVAllowedEncodings[i]; i++ ) {
		if( MVAllowedEncodings[i] == (NSStringEncoding) -1 ) {
			if( new ) [[encodingView menu] addItem:[NSMenuItem separatorItem]];
			continue;
		}
		if( new ) menuItem = [[[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:MVAllowedEncodings[i]] action:@selector( changeEncoding: ) keyEquivalent:@""] autorelease];
		else menuItem = [[encodingView menu] itemAtIndex:i + 1];
		if( encoding == MVAllowedEncodings[i] ) {
			[menuItem setState:NSOnState];
		} else [menuItem setState:NSOffState];
		if( new ) {
			[menuItem setTag:MVAllowedEncodings[i]];
			[[encodingView menu] addItem:menuItem];
		}
	}

	if( ! _spillEncodingMenu ) _spillEncodingMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding menu toolbar item" )];
	count = [_spillEncodingMenu numberOfItems];
	for( i = 0; i < count; i++ ) [_spillEncodingMenu removeItemAtIndex:0];
	count = [[encodingView menu] numberOfItems];
	for( i = 0; i < count; i++ ) [_spillEncodingMenu addItem:[[(NSMenuItem *)[[encodingView menu] itemAtIndex:i] copy] autorelease]];
	[_spillEncodingMenu removeItemAtIndex:0];

	if( encoding != (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"MVChatEncoding"] ) {
		if( chatRoom ) [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:encoding] forKey:[NSString stringWithFormat:@"chat.room.%@.%@.encoding", [[self connection] server], [self targetRoom]]];
		else [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:encoding] forKey:[NSString stringWithFormat:@"chat.user.%@.%@.encoding", [[self connection] server], [self targetUser]]];
	} else {
		if( chatRoom ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"chat.room.%@.%@.encoding", [[self connection] server], [self targetRoom]]];
		else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"chat.user.%@.%@.encoding", [[self connection] server], [self targetUser]]];
	}

	if( _topic ) [self changeTopic:_topic by:_topicAuth];
}

#pragma mark -

- (IBAction) partChat:(id) sender {
	[self addStatusMessageToDisplay:NSLocalizedString( @"You left the chat.", "left the chat message displayed before window is closed" )];
	if( chatRoom ) [[self connection] partChatForRoom:[self targetRoom]];
	else [[self class] disposeWindowWithUser:[self targetUser] withConnection:[self connection]];
}

- (BOOL) isVisible {
	return [window isVisible];
}

- (IBAction) showWindow:(id) sender {
	[window orderFront:nil];
	if( memberDrawerWasOpen ) [memberDrawer open];
}

- (IBAction) showWindowAndMakeKey:(id) sender {
	[window makeKeyAndOrderFront:nil];
	if( memberDrawerWasOpen ) [memberDrawer open];
}

- (IBAction) hideWindow:(id) sender {
	if( [memberDrawer state] == NSDrawerOpenState || [memberDrawer state] == NSDrawerOpeningState )
		memberDrawerWasOpen = YES;
	else memberDrawerWasOpen = NO;
	[memberDrawer close];
	[window orderOut:nil];
	[[NSApplication sharedApplication] changeWindowsItem:window title:[window title] filename:NO];
}

- (NSWindow *) window {
	return window;
}

#pragma mark -

- (IBAction) toggleMemberDrawer:(id) sender {
	[memberDrawer toggle:sender];
}

- (IBAction) openMemberDrawer:(id) sender {
	[memberDrawer open:sender];
}

- (IBAction) closeMemberDrawer:(id) sender {
	[memberDrawer close:sender];
}

- (IBAction) startChatWithSelectedUser:(id) sender {
	if( [memberListTable selectedRow] != -1 ) {
		MVChatWindowController *chat = [[self class] chatWindowWithUser:[sortedMembers objectAtIndex:[memberListTable selectedRow]] withConnection:[self connection] ifExists:NO];
		[chat showWindowAndMakeKey:nil];
	}
}

- (IBAction) promoteSelectedUser:(id) sender {
	if( [memberListTable selectedRow] != -1 ) {
		if( [[memberList objectForKey:[sortedMembers objectAtIndex:[memberListTable selectedRow]]] objectForKey:@"op"] )
			[[self connection] demoteMember:[sortedMembers objectAtIndex:[memberListTable selectedRow]] inRoom:[self targetRoom]];
		else [[self connection] promoteMember:[sortedMembers objectAtIndex:[memberListTable selectedRow]] inRoom:[self targetRoom]];
	}
}

- (IBAction) voiceSelectedUser:(id) sender {
	if( [memberListTable selectedRow] != -1 ) {
		if( [[memberList objectForKey:[sortedMembers objectAtIndex:[memberListTable selectedRow]]] objectForKey:@"voice"] )
			[[self connection] devoiceMember:[sortedMembers objectAtIndex:[memberListTable selectedRow]] inRoom:[self targetRoom]];
		else [[self connection] voiceMember:[sortedMembers objectAtIndex:[memberListTable selectedRow]] inRoom:[self targetRoom]];
	}
}

- (IBAction) kickSelectedUser:(id) sender {
	if( [memberListTable selectedRow] != -1 ) {
		[[self connection] kickMember:[sortedMembers objectAtIndex:[memberListTable selectedRow]] inRoom:[self targetRoom] forReason:@""];
	}
}
@end

#pragma mark -

@implementation MVChatWindowController (MVChatWindowControllerDelegate)
- (BOOL) windowShouldClose:(id) sender {
	BOOL option = [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatHideOnWindowClose"];
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];

	if( ( [event modifierFlags] & NSCommandKeyMask ) && [event type] != NSKeyDown )
		option = (BOOL) ! option;

	if( option ) {
		[self hideWindow:nil];
		return NO;
	} else {
		[self partChat:nil];
		return YES;
	}
}

- (void) windowWillClose:(NSNotification *) notification {
	_windowClosed = YES;
}

- (void) windowDidBecomeKey:(NSNotification *) notification {
    [window makeFirstResponder:sendText];
	[window setDocumentEdited:NO];
	if( memberDrawerWasOpen ) {
		[self openMemberDrawer:nil];
		memberDrawerWasOpen = NO;
	}
}

#pragma mark -

- (BOOL) drawerShouldOpen:(NSDrawer *) sender {
	return YES;
}

- (BOOL) drawerShouldClose:(NSDrawer *) sender {
	return YES;
}

#pragma mark -

- (BOOL) textView:(NSTextView *) textView clickedOnLink:(id) link {
	NSURL *url = [NSURL URLWithString:link];
	if( [[url scheme] isEqualToString:@"irc"] && [[[self connection] server] isEqualToString:[url host]] && ( ! [url user] || [[[self connection] nickname] isEqualToString:[url user]] ) && ( ! [[self connection] serverPort] || ! [[url port] unsignedShortValue] || [[self connection] serverPort] == [[url port] unsignedShortValue] ) ) {
		BOOL joinRoom = YES;
		NSString *target = nil;

		if( [url fragment] ) {
			if( [[url fragment] length] > 0 ) {
				target = [url fragment];
				joinRoom = YES;
			}
		} else if( [url path] && [[url path] length] >= 2 ) {
			target = [[url path] substringFromIndex:1];
			if( [[[url path] substringFromIndex:1] hasPrefix:@"&"] || [[[url path] substringFromIndex:1] hasPrefix:@"+"] ) {
				joinRoom = YES;
			} else {
				joinRoom = NO;
			}
		}

		if( target && joinRoom ) [[self connection] joinChatForRoom:target];
		else if( target && ! joinRoom ) [[self class] chatWindowWithUser:target withConnection:[self connection] ifExists:NO];

		return YES;
	}
	return NO;
}

- (BOOL) textView:(NSTextView *) textView enterHit:(NSEvent *) event {
	BOOL ret = NO;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnEnter"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnEnter"] ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	}
	return ret;
}

- (BOOL) textView:(NSTextView *) textView returnHit:(NSEvent *) event {
	BOOL ret = NO;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	}
	return ret;
}

- (BOOL) textView:(NSTextView *) textView tabHit:(NSEvent *) event {
	NSArray *tabArr = [[sendText string] componentsSeparatedByString:@" "];
	NSMutableArray *found = [NSMutableArray array];
	NSEnumerator *enumerator = [sortedMembers objectEnumerator];
	NSString *name = nil, *shortest = nil;
	unsigned len = [(NSString *)[tabArr lastObject] length], count = 0;
	if( ! len ) return YES;
	while( ( name = [enumerator nextObject] ) ) {
		if( [[tabArr lastObject] caseInsensitiveCompare:[name substringToIndex:len]] == NSOrderedSame ) {
			[found addObject:name];
			if( [name length] < [shortest length] || ! shortest ) shortest = [[name copy] autorelease];
			count++;
		}
	}
	if( count == 1 ) {
		[[sendText textStorage] replaceCharactersInRange:NSMakeRange([[sendText textStorage] length] - len, len) withString:shortest];
		if( ! [[sendText string] rangeOfString:@" "].length ) [sendText replaceCharactersInRange:NSMakeRange([[sendText textStorage] length], 0) withString:@": "];
		else [sendText replaceCharactersInRange:NSMakeRange([[sendText textStorage] length], 0) withString:@" "];
	} else if( count > 1 ) {
		BOOL match = YES;
		unsigned i = 0;
		NSString *cut = nil;
		count = NSNotFound;
		while( 1 ) {
			if( count == NSNotFound ) count = [shortest length];
			if( (signed) count <= 0 ) return YES;
			cut = [shortest substringToIndex:count];
			for( i = 0, match = YES; i < [found count]; i++ ) {
				if( ! [[found objectAtIndex:i] hasPrefix:cut] ) {
					match = NO;
					break;
				}
			}
			count--;
			if( match ) break;
		}
		[[sendText textStorage] replaceCharactersInRange:NSMakeRange([[sendText textStorage] length] - len, len) withString:cut];
	}
	return YES;
}

- (BOOL) textView:(NSTextView *) textView upArrowHit:(NSEvent *) event {
	if( ! historyIndex && [sendHistory count] )
		[sendHistory replaceObjectAtIndex:0 withObject:[[[sendText textStorage] copy] autorelease]];
	historyIndex++;
	if( historyIndex >= [sendHistory count] ) {
		historyIndex = [sendHistory count] - 1;
		if( (signed) historyIndex < 0 ) historyIndex = 0;
		return YES;
	}
	[sendText reset:nil];
	[[sendText textStorage] insertAttributedString:[sendHistory objectAtIndex:historyIndex] atIndex:0];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView downArrowHit:(NSEvent *) event {
	if( ! historyIndex && [sendHistory count] )
		[sendHistory replaceObjectAtIndex:0 withObject:[[[sendText textStorage] copy] autorelease]];
	if( [[sendText textStorage] length] ) historyIndex--;
	if( historyIndex < 0 ) {
		[sendText reset:nil];
		historyIndex = -1;
		return YES;
	} else if( ! [sendHistory count] ) {
		historyIndex = 0;
		return YES;
	}
	[sendText reset:nil];
	[[sendText textStorage] insertAttributedString:[sendHistory objectAtIndex:historyIndex] atIndex:0];
	return YES;
}

- (void) textDidChange:(NSNotification *) aNotification {
	historyIndex = 0;
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [sortedMembers count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqual:@"name"] ) {
		unsigned idle = [[[memberList objectForKey:[sortedMembers objectAtIndex:row]] objectForKey:@"idle"] unsignedIntValue];
		unsigned idleLimit = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatIdleLimit"] unsignedIntValue];
		if( idle > idleLimit && ( [view selectedRow] != row || ! [[view window] isKeyWindow] || ( [view selectedRow] == row && [[view window] firstResponder] != view ) ) )
			return [[[NSAttributedString alloc] initWithString:[sortedMembers objectAtIndex:row] attributes:[NSDictionary dictionaryWithObject:[NSColor darkGrayColor] forKey:NSForegroundColorAttributeName]] autorelease];
		else return [sortedMembers objectAtIndex:row];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqual:@"name"] ) {
		unsigned idle = [[[memberList objectForKey:[sortedMembers objectAtIndex:row]] objectForKey:@"idle"] unsignedIntValue];
		unsigned idleLimit = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatIdleLimit"] unsignedIntValue];
		if( [[[memberList objectForKey:[sortedMembers objectAtIndex:row]] objectForKey:@"flags"] unsignedIntValue] & 0x0004 /* FF_ADMIN */ )
			[cell setImage:[NSImage imageNamed:( idle > idleLimit ? @"admin-idle" : @"admin" )]];
		else if( [[memberList objectForKey:[sortedMembers objectAtIndex:row]] objectForKey:@"op"] )
			[cell setImage:[NSImage imageNamed:( idle > idleLimit ? @"op-idle" : @"op" )]];
		else if( [[memberList objectForKey:[sortedMembers objectAtIndex:row]] objectForKey:@"voice"] )
			[cell setImage:[NSImage imageNamed:( idle > idleLimit ? @"voice-idle" : @"voice" )]];
		else [cell setImage:[NSImage imageNamed:( idle > idleLimit ? @"person-idle" : @"person" )]];
	}
}

- (NSMenu *) tableView:(NSTableView *) view menuForTableColumn:(NSTableColumn *) column row:(int) row {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:NULL keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChatWithSelectedUser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	if( [[memberList objectForKey:[[self connection] nickname]] objectForKey:@"op"] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room", "kick from room contextual menu - admin only" ) action:@selector( kickSelectedUser: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		[menu addItem:[NSMenuItem separatorItem]];

		if( [[memberList objectForKey:[sortedMembers objectAtIndex:[memberListTable selectedRow]]] objectForKey:@"op"] ) {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Demote Operator", "demote operator contextual menu - admin only" ) action:@selector( promoteSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		} else {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" ) action:@selector( promoteSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [[memberList objectForKey:[sortedMembers objectAtIndex:[memberListTable selectedRow]]] objectForKey:@"voice"] ) {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Remove Voice", "remove voice contextual menu - admin only" ) action:@selector( voiceSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		} else {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" ) action:@selector( voiceSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}
	}

	return [[menu retain] autorelease];
}

- (void) tableViewSelectionDidChange:(NSNotification *) aNotification {
	if( [memberListTable selectedRow] != -1 ) {
		[msgButton setEnabled:YES];
		[infoButton setEnabled:YES];
	} else {
		[msgButton setEnabled:NO];
		[infoButton setEnabled:NO];
	}
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(int) row proposedDropOperation:(NSTableViewDropOperation) operation {
	return ( operation == NSTableViewDropOn && row >= 0 ? NSDragOperationEvery : NSDragOperationNone );
}

- (BOOL) tableView:(NSTableView *) view acceptDrop:(id <NSDraggingInfo>) info row:(int) row dropOperation:(NSTableViewDropOperation) operation {
	NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	NSEnumerator *enumerator = [files objectEnumerator];
	id file = nil;
	while( ( file = [enumerator nextObject] ) ) {
		[[self connection] sendFileToUser:[sortedMembers objectAtIndex:row] withFilePath:file];
	}
	return YES;
}

- (BOOL) tableView:(NSTableView *) view shouldEditTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[[memberList objectForKey:[sortedMembers objectAtIndex:row]] objectForKey:@"self"] boolValue] ) {
		return YES;
	} else if( [memberListTable selectedRow] == row ) [self startChatWithSelectedUser:nil];
	return NO;
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( ! [memberList objectForKey:object] ) {
		[[self connection] setNickname:object];
		[self changeSelfTo:object];
		[memberListTable reloadData];
	} else if( ! [object isEqualToString:[sortedMembers objectAtIndex:row]] ) {
		NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat nickname could not be used", "chat invalid nickname dialog title" ), NSLocalizedString( @"The nickname you specified is in use or invalid on this server.", "chat invalid nickname dialog message" ), nil, nil, nil );
	}
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

	if( [itemIdent isEqual:MVToolbarEmoticonsItemIdentifier] ) {
		NSMenu *newMenu = [[[NSMenu alloc] initWithTitle:NSLocalizedString( @"Emoticons", "emoticons options title - used in a few places like toolbar and menus" )] autorelease];
		NSMenuItem *menuItem = nil;
		NSImage *icon = [[[NSImage imageNamed:@"emoticon"] copy] autorelease];
		MVMenuButton *button = [emoticonView copyWithZone:[self zone]];

		[button setToolbarItem:toolbarItem];

		[toolbarItem setLabel:NSLocalizedString( @"Emoticons", "emoticons options title - used in a few places like toolbar and menus" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Emoticons", "emoticons options title - used in a few places like toolbar and menus" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Add Emotions with Emoticons", "emoticons toolbar button tooltip" )];
		[toolbarItem setView:button];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Smile", "smile emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@":)"];
		[menuItem setImage:[NSImage imageNamed:@"smile"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Wink", "wink emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@";)"];
		[menuItem setImage:[NSImage imageNamed:@"wink"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Grin", "grin emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@":D"];
		[menuItem setImage:[NSImage imageNamed:@"happy"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Stoic", "stoic emoticon name - flat face" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@"=|"];
		[menuItem setImage:[NSImage imageNamed:@"stoic"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Frown", "frown emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@":("];
		[menuItem setImage:[NSImage imageNamed:@"frown"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Annoyed", "annoyed emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@":\\"];
		[menuItem setImage:[NSImage imageNamed:@"annoyed"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Razz", "razz emoticon name - tounge out" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@":P"];
		[menuItem setImage:[NSImage imageNamed:@"razz"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Angry", "angry emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@":x"];
		[menuItem setImage:[NSImage imageNamed:@"angry"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Cool", "cool guy emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@"8)"];
		[menuItem setImage:[NSImage imageNamed:@"cool"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Jamming", "jamming emoticon name - headphones on" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@"[=)"];
		[menuItem setImage:[NSImage imageNamed:@"headphones"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Relaxed", "relaxed emoticon name - hat on" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@"d:)"];
		[menuItem setImage:[NSImage imageNamed:@"hat"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Angel", "angel emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@"O:)"];
		[menuItem setImage:[NSImage imageNamed:@"angel"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Evil", "evil emoticon name" ) action:@selector( addEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setRepresentedObject:@">:)"];
		[menuItem setImage:[NSImage imageNamed:@"evil"]];
		[newMenu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Emoticons", "emoticons options title - used in a few places like toolbar and menus" ) action:NULL keyEquivalent:@""] autorelease];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize( 16., 16. )];
		[menuItem setImage:icon];
		[menuItem setSubmenu:newMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];
		[button setMenu:newMenu];
		[button setMenuDelay:0.];
	} else if( [itemIdent isEqual:MVToolbarCloseWindowItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Leave Chat", "leave chat toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Leave Chat", "leave chat toolbar item" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Leave this Chat", "leave chat tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"part"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( partChat: )];
	} else if( [itemIdent isEqual:MVToolbarHideWindowItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Hide Chat", "hide current chat toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Hide Chat", "hide current chat toolbar item" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Hide this Chat Window", "hide chat tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"hide"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( hideWindow: )];
	} else if( [itemIdent isEqual:MVToolbarBoldFontItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Bold", "bold font toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Bold", "bold font toolbar item" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Bold Style", "bold font tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"bold"]];

		[toolbarItem setTarget:sendText];
		[toolbarItem setAction:@selector( bold: )];
	} else if( [itemIdent isEqual:MVToolbarItalicFontItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Italic", "italic font style toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Italic", "italic font style toolbar item" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Italic Style", "italic style tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"italic"]];

		[toolbarItem setTarget:sendText];
		[toolbarItem setAction:@selector( italic: )];
	} else if( [itemIdent isEqual:MVToolbarUnderlineFontItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Underline", "underline font style toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Underline", "underline font style toolbar item" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Underline Style", "underline style tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"underline"]];

		[toolbarItem setTarget:sendText];
		[toolbarItem setAction:@selector( underline: )];
	} else if( [itemIdent isEqual:MVToolbarChatMembersItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Members", "chat room members toolbar item name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Chat Members", "chat room members toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Toggle Chat Members", "chat room members toolbar item tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"members"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( toggleMemberDrawer: )];
	} else if( [itemIdent isEqual:MVToolbarTextEncodingItemIdentifier] ) {
		NSMenuItem *menuItem = nil;
		[toolbarItem setLabel:NSLocalizedString( @"Encoding", "encoding menu toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Text Encoding", "encoding menu toolbar customize palette name" )];

		[toolbarItem setTarget:nil];
		[toolbarItem setAction:NULL];

		[toolbarItem setToolTip:NSLocalizedString( @"Text Encoding Options", "encoding menu toolbar item tooltip" )];
		[toolbarItem setView:encodingView];
		[toolbarItem setMinSize:NSMakeSize( 60., 24. )];
		[toolbarItem setMaxSize:NSMakeSize( 60., 32. )];

		[self changeEncoding:nil];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding menu toolbar item" ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setImage:[NSImage imageNamed:@"encoding"]];
		[menuItem setSubmenu:_spillEncodingMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];
	} else toolbarItem = nil;
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithObjects:MVToolbarEmoticonsItemIdentifier, NSToolbarShowColorsItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, MVToolbarTextEncodingItemIdentifier, nil];
	if( chatRoom ) [list addObject:MVToolbarChatMembersItemIdentifier];
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithObjects:MVToolbarCloseWindowItemIdentifier, MVToolbarHideWindowItemIdentifier, MVToolbarEmoticonsItemIdentifier, MVToolbarTextEncodingItemIdentifier, NSToolbarShowColorsItemIdentifier, MVToolbarBoldFontItemIdentifier, MVToolbarItalicFontItemIdentifier, MVToolbarUnderlineFontItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
	if( chatRoom ) [list addObject:MVToolbarChatMembersItemIdentifier];
	return list;
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	if( chatRoom && [[toolbarItem itemIdentifier] isEqual:MVToolbarChatMembersItemIdentifier] ) return YES;
	else if( ! chatRoom && [[toolbarItem itemIdentifier] isEqual:MVToolbarChatMembersItemIdentifier] ) return NO;

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqual:NSToolbarShowColorsItemIdentifier] ) return NO;
	else if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"] && [[toolbarItem itemIdentifier] isEqual:NSToolbarShowColorsItemIdentifier] ) return YES;

	return YES;
}
@end

#pragma mark -

@implementation MVChatWindowController (MVChatWindowControllerPrivate)
+ (NSData *) _flattenedHTMLFromIRCFormatForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc {
	NSData *data = [self flattenedHTMLDataForMessage:message withEncoding:enc];
	char *msg = irc_html_to_irc( (const char * const) [data bytes] );
	msg = irc_irc_to_html( msg );
	return [[[NSData dataWithBytes:msg length:strlen( msg )] retain] autorelease];
}

+ (NSData *) _flattenedIRCFormatForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc {
	NSData *data = [self flattenedHTMLDataForMessage:message withEncoding:enc];
	char *msg = irc_html_to_irc( (const char * const) [data bytes] );
	return [[[NSData dataWithBytes:msg length:strlen( msg )] retain] autorelease];
}

- (void) _refreshUserInfo:(id) sender {
	NSEnumerator *enumerator = [sortedMembers objectEnumerator];
	id item = nil;
	while( ( item = [enumerator nextObject] ) ) {
		[[self connection] fetchInformationForUser:item];
	}
}

- (void) _setConnection:(MVChatConnection *) connection {
	[_connection autorelease];
	_connection = [connection retain];
}

- (void) _setTargetUser:(NSString *) user {
	NSParameterAssert( user != nil );
	[window setTitle:[NSString stringWithFormat:NSLocalizedString( @"%@ - Private Message", "private message with user - window title" ), user]];
	[outlet autorelease];
	outlet = [user copy];
	chatRoom = NO;
	[self changeEncoding:nil];
}

- (void) _setTargetRoom:(NSString *) room {
	NSParameterAssert( room != nil );
	[window setTitle:[NSString stringWithFormat:NSLocalizedString( @"%@ - Chat Room", "chat room window - window title" ), [room lowercaseString]]];
	[outlet autorelease];
	outlet = [[room lowercaseString] copy];
	chatRoom = YES;
	[self changeEncoding:nil];
}

- (BOOL) _isSetup {
	return setup;
}

- (void) _setup {
	if( chatRoom ) {
		[memberDrawer open];
		[self changeTopic:[@"" dataUsingEncoding:NSUTF8StringEncoding] by:nil];
	}
	if( ! chatRoom ) {
		[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
		[[sendTextScrollView superview] setFrame:NSMakeRect( 12, 15, NSWidth( [[sendTextScrollView superview] frame] ), NSHeight( [[sendTextScrollView superview] frame] ) + NSMinY( [[sendTextScrollView superview] frame] ) - 15 )];
		[[sendTextScrollView superview] setNeedsDisplay:YES];
	}
	[window makeKeyAndOrderFront:nil];
	setup = YES;
}

- (void) _preferencesDidChange:(NSNotification *) aNotification {
	NSColor *newBG = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatBackgroundColor"]];
	if( [[displayText textStorage] length] && ! [[displayText backgroundColor] isEqual:newBG] )
		[[displayText textStorage] addAttribute:NSBackgroundColorAttributeName value:[displayText backgroundColor] range:NSMakeRange( 0, [[displayText textStorage] length] )];
	[displayText setBackgroundColor:newBG];
	[displayText setNeedsDisplay:YES];
}

- (void) _kickedFromChatPart:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[MVChatWindowController disposeWindowForRoom:[self targetRoom] withConnection:[self connection]];
}

- (void) _disconnectedEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSAlertAlternateReturn ) {
		if( chatRoom ) [MVChatWindowController disposeWindowForRoom:[self targetRoom] withConnection:[self connection]];
		else [MVChatWindowController disposeWindowWithUser:[self targetUser] withConnection:[self connection]];
	}
}
@end