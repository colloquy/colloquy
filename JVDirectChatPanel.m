#import <AddressBook/AddressBook.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSDataAdditions.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <ChatCore/NSColorAdditions.h>
#import <ChatCore/NSScriptCommandAdditions.h>

#import "JVChatController.h"
#import "KAIgnoreRule.h"
#import "JVTabbedChatWindowController.h"
#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVChatEvent.h"
#import "JVNotificationController.h"
#import "MVConnectionsController.h"
#import "JVDirectChatPanel.h"
#import "MVBuddyListController.h"
#import "MVFileTransferController.h"
#import "JVBuddy.h"
#import "MVTextView.h"
#import "MVMenuButton.h"
#import "JVMarkedScroller.h"
#import "JVSplitView.h"
#import "JVStyleView.h"
#import "NSBundleAdditions.h"
#import "NSURLAdditions.h"
#import "NSAttributedStringMoreAdditions.h"

static NSArray *JVAutoActionVerbs = nil;

const NSStringEncoding JVAllowedTextEncodings[] = {
	/* Universal */
	NSUTF8StringEncoding,
	NSNonLossyASCIIStringEncoding,
	/* Western */	
	(NSStringEncoding) -1,				// Divider
	NSASCIIStringEncoding,
	NSISOLatin1StringEncoding,			// ISO Latin 1
	(NSStringEncoding) 0x80000203,		// ISO Latin 3
	(NSStringEncoding) 0x8000020F,		// ISO Latin 9
	NSMacOSRomanStringEncoding,			// Mac
	NSWindowsCP1252StringEncoding,		// Windows
	/* European */	
	(NSStringEncoding) -1,
	NSISOLatin2StringEncoding,			// ISO Latin 2
	(NSStringEncoding) 0x80000204,		// ISO Latin 4
	(NSStringEncoding) 0x8000001D,		// Mac
	NSWindowsCP1250StringEncoding,		// Windows
	/* Cyrillic */
	(NSStringEncoding) -1,
	(NSStringEncoding) 0x80000A02,		// KOI8-R
	(NSStringEncoding) 0x80000205,		// ISO Latin 5
	(NSStringEncoding) 0x80000007,		// Mac
	NSWindowsCP1251StringEncoding,		// Windows
	/* Japanese */
	(NSStringEncoding) -1,				// Divider
	(NSStringEncoding) 0x80000A01,		// ShiftJIS
	NSISO2022JPStringEncoding,			// ISO-2022-JP
	NSJapaneseEUCStringEncoding,		// EUC
	(NSStringEncoding) 0x80000001,		// Mac
	NSShiftJISStringEncoding,			// Windows
	/* Simplified Chinese */	
	(NSStringEncoding) -1,				// Divider
	(NSStringEncoding) 0x80000632,		// GB 18030
	(NSStringEncoding) 0x80000631,		// GBK
	(NSStringEncoding) 0x80000930,		// EUC
	(NSStringEncoding) 0x80000019,		// Mac
	(NSStringEncoding) 0x80000421,		// Windows
	/* Traditional Chinese */	
	(NSStringEncoding) -1,				// Divider
	(NSStringEncoding) 0x80000A03,		// Big5
	(NSStringEncoding) 0x80000A06,		// Big5 HKSCS
	(NSStringEncoding) 0x80000931,		// EUC
	(NSStringEncoding) 0x80000002,		// Mac
	(NSStringEncoding) 0x80000423,		// Windows
	/* Korean */	
	(NSStringEncoding) -1,				// Divider
	(NSStringEncoding) 0x80000940,		// EUC
	(NSStringEncoding) 0x80000003,		// Mac
	(NSStringEncoding) 0x80000422,		// Windows
	/* Hebrew */
	(NSStringEncoding) -1,				// Divider
	(NSStringEncoding) 0x80000208,		// ISO-8859-8
	(NSStringEncoding) 0x80000005,		// Mac
	(NSStringEncoding) 0x80000505,		// Windows
	/* End */ 0 };

static NSString *JVToolbarTextEncodingItemIdentifier = @"JVToolbarTextEncodingItem";
static NSString *JVToolbarClearItemIdentifier = @"JVToolbarClearItem";
static NSString *JVToolbarSendFileItemIdentifier = @"JVToolbarSendFileItem";

@interface JVDirectChatPanel (JVDirectChatPrivate) <ABImageClient>
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
- (void) _breakLongLinesInString:(NSMutableAttributedString *) message;
- (void) _hyperlinkRoomNames:(NSMutableAttributedString *) message;
- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message;
- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont;
- (void) _saveSelfIcon;
- (void) _saveBuddyIcon:(JVBuddy *) buddy;
- (void) _setCurrentMessage:(JVMutableChatMessage *) message;
@end

#pragma mark -

@interface JVChatTranscriptPanel (JVChatTranscriptPrivate)
- (void) _refreshWindowFileProxy;
- (void) _changeEmoticonsMenuSelection;
@end

#pragma mark -

@implementation JVDirectChatPanel
- (id) init {
	if( ( self = [super init] ) ) {
		send = nil;
		_target = nil;
		_firstMessage = YES;
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		_cantSendMessages = NO;
		_isActive = NO;
		_forceSplitViewPosition = YES;
		_historyIndex = 0;
		_sendHeight = 30.;

		_encoding = NSASCIIStringEncoding;
		_encodingMenu = nil;
		_spillEncodingMenu = nil;

		_sendHistory = [[NSMutableArray array] retain];
		[_sendHistory insertObject:[[[NSAttributedString alloc] initWithString:@""] autorelease] atIndex:0];

		_waitingAlerts = [[NSMutableArray array] retain];
		_waitingAlertNames = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}

- (id) initWithTarget:(id) target {
	if( ( self = [self init] ) ) {
		_target = [target retain];

		NSString *source = [NSString stringWithFormat:@"%@/%@", [[[self connection] url] absoluteString], [self target]];

		if( ( [self isMemberOfClass:[JVDirectChatPanel class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogPrivateChats"] ) ||
			( [self isMemberOfClass:[JVChatRoomPanel class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogChatRooms"] ) ) {
			NSString *logs = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];
			NSFileManager *fileManager = [NSFileManager defaultManager];

			if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];

			int org = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptFolderOrganization"];
			if( org == 1 ) {
				logs = [logs stringByAppendingPathComponent:[[self connection] server]];
				if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];
			} else if( org == 2 ) {
				logs = [logs stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%@)", [self target], [[self connection] server]]];
				if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];
			} else if( org == 3 ) {
				logs = [logs stringByAppendingPathComponent:[[self connection] server]];
				if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];

				logs = [logs stringByAppendingPathComponent:[self title]];
				if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];
			}

			NSString *logName = nil;
			int session = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptSessionHandling"];

			if( ! session ) {
				BOOL nameFound = NO;
				unsigned int i = 1;

				if( org ) logName = [NSString stringWithFormat:@"%@.colloquyTranscript", [self target]];
				else logName = [NSString stringWithFormat:@"%@ (%@).colloquyTranscript", [self target], [[self connection] server]];
				nameFound = ! [fileManager fileExistsAtPath:[logs stringByAppendingPathComponent:logName]];

				while( ! nameFound ) {
					if( org ) logName = [NSString stringWithFormat:@"%@ %d.colloquyTranscript", [self target], i++];
					else logName = [NSString stringWithFormat:@"%@ (%@) %d.colloquyTranscript", [self target], [[self connection] server], i++];
					nameFound = ! [fileManager fileExistsAtPath:[logs stringByAppendingPathComponent:logName]];
				}
			} else if( session == 1 ) {
				if( org ) logName = [NSString stringWithFormat:@"%@.colloquyTranscript", [self target]];
				else logName = [NSString stringWithFormat:@"%@ (%@).colloquyTranscript", [self target], [[self connection] server]];
			} else if( session == 2 ) {
				if( org ) logName = [NSMutableString stringWithFormat:@"%@ %@.colloquyTranscript", [self target], [[NSCalendarDate date] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]]];
				else logName = [NSMutableString stringWithFormat:@"%@ (%@) %@.colloquyTranscript", [self target], [[self connection] server], [[NSCalendarDate date] descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString]]];
				[(NSMutableString *)logName replaceOccurrencesOfString:@"/" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [logName length] )];
				[(NSMutableString *)logName replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [logName length] )];
			}

			logs = [logs stringByAppendingPathComponent:logName];

			if( [fileManager fileExistsAtPath:logs] )
				[[self transcript] startNewSession];

			[[self transcript] setFilePath:logs];
			[[self transcript] setAutomaticallyWritesChangesToFile:YES];
		}

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:[self connection]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didDisconnect: ) name:MVChatConnectionDidDisconnectNotification object:[self connection]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _awayStatusChanged: ) name:MVChatConnectionSelfAwayStatusChangedNotification object:[self connection]];

		_settings = [[NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:[[self identifier] stringByAppendingString:@" Settings"]]] retain];
	}
	return self;
}

- (void) awakeFromNib {
	JVStyle *style = nil;
	NSString *variant = nil;
	JVEmoticonSet *emoticon = nil;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidConnectNotification object:[self connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidDisconnectNotification object:[self connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _updateInputFont: ) name:JVStyleViewDidChangeStylesNotification object:display];

	if( [self preferenceForKey:@"style"] ) {
		style = [JVStyle styleWithIdentifier:[self preferenceForKey:@"style"]];
		variant = [self preferenceForKey:@"style variant"];
		if( style ) [self setStyle:style withVariant:variant];
	}

	if( [(NSString *)[self preferenceForKey:@"emoticon"] length] ) {
		emoticon = [JVEmoticonSet emoticonSetWithIdentifier:[self preferenceForKey:@"emoticon"]];
		if( emoticon ) [self setEmoticons:emoticon];
	}

	[super awakeFromNib];

	[self changeEncoding:nil];

	if( [self isMemberOfClass:[JVDirectChatPanel class]] ) {
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], [self target]]];

		NSString *path = [[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Recent Acquaintances/%@ (%@).inetloc", [self target], [[self connection] server]] stringByExpandingTildeInPath];

		[url writeToInternetLocationFile:path];
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:path];
	}

	[send setHorizontallyResizable:YES];
	[send setVerticallyResizable:YES];
	[send setAutoresizingMask:NSViewWidthSizable];
	[send setSelectable:YES];
	[send setEditable:YES];
	[send setRichText:YES];
	[send setImportsGraphics:NO];
	[send setUsesFontPanel:YES];
	[send setAllowsUndo:YES];
	[send setUsesRuler:NO];
	[send setDelegate:self];
	[send setContinuousSpellCheckingEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatSpellChecking"]];
	[send setUsesSystemCompleteOnTab:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVUsePantherTextCompleteOnTab"]];
	[send reset:nil];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		[(JVSplitView *)[[[send superview] superview] superview] setIsPaneSplitter:YES];
}

- (void) dealloc {
	extern NSArray *JVAutoActionVerbs;
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_target release];
	[_sendHistory release];
	[_waitingAlertNames release];
	[_settings release];
	[_encodingMenu release];
	[_spillEncodingMenu release];

	NSEnumerator *enumerator = [_waitingAlerts objectEnumerator];
	id alert = nil;
	while( ( alert = [enumerator nextObject] ) )
		NSReleaseAlertPanel( alert );

	[_waitingAlerts release];

	[JVAutoActionVerbs autorelease];
	if( [JVAutoActionVerbs retainCount] == 1 )
		JVAutoActionVerbs = nil;

	_target = nil;
	_sendHistory = nil;
	_waitingAlerts = nil;
	_waitingAlertNames = nil;
	_settings = nil;
	_encodingMenu = nil;
	_spillEncodingMenu = nil;

	[super dealloc];
}

#pragma mark -

- (id) target {
	return [[_target retain] autorelease];
}

- (NSURL *) url {
	NSString *server = [[[self connection] url] absoluteString];
	return [NSURL URLWithString:[server stringByAppendingPathComponent:[[[self target] description] stringByEncodingIllegalURLCharacters]]];
}

- (MVChatConnection *) connection {
	return [(MVChatUser *)[self target] connection];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVDirectChat" owner:self];
	return contents;
}

- (NSResponder *) firstResponder {
	return send;
}

#pragma mark -

- (BOOL) isEnabled {
	return [[self connection] isConnected];
}

- (NSString *) title {
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [_buddy preferredName]; */
	return [[[[self target] displayName] retain] autorelease];
}

- (NSString *) windowTitle {
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [NSString stringWithFormat:@"%@ (%@)", [_buddy preferredName], [[self connection] server]]; */
	return [NSString stringWithFormat:@"%@ (%@)", [self title], [[self connection] server]];
}

- (NSString *) information {
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname && ! [[self target] isEqualToString:[_buddy preferredName]] )
		return [NSString stringWithFormat:@"%@ (%@)", [self target], [[self connection] server]]; */
	return [[self connection] server];
}

- (NSString *) toolTip {
	NSString *messageCount = @"";
	if( [self newMessagesWaiting] == 0 ) messageCount = NSLocalizedString( @"no messages waiting", "no messages waiting room tooltip" );
	else if( [self newMessagesWaiting] == 1 ) messageCount = NSLocalizedString( @"1 message waiting", "one message waiting room tooltip" );
	else messageCount = [NSString stringWithFormat:NSLocalizedString( @"%d messages waiting", "messages waiting room tooltip" ), [self newMessagesWaiting]];
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [NSString stringWithFormat:@"%@\n%@ (%@)\n%@", [_buddy preferredName], [self target], [[self connection] server], messageCount]; */
	return [NSString stringWithFormat:@"%@ (%@)\n%@", [self target], [[self connection] server], messageCount];
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

/*	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:NULL keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add to Favorites", "add to favorites contextual menu") action:@selector( addToFavorites: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item]; */

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( _sendFile: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
		return [NSImage imageNamed:@"privateChatTab"];
	return [NSImage imageNamed:@"messageUser"];
}

- (NSImage *) statusImage {
	if( _isActive && [[[self view] window] isKeyWindow] ) {
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		return nil;
	}

	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
		return ( [_waitingAlerts count] ? [NSImage imageNamed:@"AlertCautionIcon"] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"privateChatTabNewMessage"] : [NSImage imageNamed:@"privateChatTabNewMessage"] ) : nil ) );

	return ( [_waitingAlerts count] ? [NSImage imageNamed:@"viewAlert"] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"newHighlightMessage"] : [NSImage imageNamed:@"newMessage"] ) : nil ) );
}

#pragma mark -

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Direct Chat %@ (%@)", [self target], [[self connection] server]];
}

#pragma mark -

- (void) didUnselect {
	_newMessageCount = 0;
	_newHighlightMessageCount = 0;
	_isActive = NO;
	[super didUnselect];
}

- (void) willSelect {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] ) {
		[(JVSplitView *)[[[send superview] superview] superview] setPositionUsingName:@"JVChatSplitViewPosition"];
	} else [self textDidChange:nil];
}

- (void) didSelect {
	_newMessageCount = 0;
	_newHighlightMessageCount = 0;
	_isActive = YES;
	[super didSelect];
	[_windowController reloadListItem:self andChildren:NO];
	[[[self view] window] makeFirstResponder:send];
	if( [_waitingAlerts count] )
		[[NSApplication sharedApplication] beginSheet:[_waitingAlerts objectAtIndex:0] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

#pragma mark -
#pragma mark Drag & Drop Support

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return YES;
}

- (void) handleDraggedFile:(NSString *) path {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	[[self target] sendFile:path passively:passive];
}

#pragma mark -

- (IBAction) addToFavorites:(id) sender {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], [self target]]];
	NSString *path = [[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Favorites/%@ (%@).inetloc", [self target], [[self connection] server]] stringByExpandingTildeInPath] retain];

	[url writeToInternetLocationFile:path];
	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:path];
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged:path];

	[MVConnectionsController refreshFavoritesMenu];
}

#pragma mark -

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name {
	if( _isActive && ! [[_windowController window] attachedSheet] ) {
		if( alert ) [[NSApplication sharedApplication] beginSheet:alert modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	} else {
		if( name && [_waitingAlertNames objectForKey:name] ) {
			NSPanel *sheet = [[[_waitingAlertNames objectForKey:name] retain] autorelease];
			if( alert ) {
				[_waitingAlerts replaceObjectAtIndex:[_waitingAlerts indexOfObjectIdenticalTo:[_waitingAlertNames objectForKey:name]] withObject:alert];
				[_waitingAlertNames setObject:alert forKey:name];
			} else {
				[_waitingAlerts removeObjectAtIndex:[_waitingAlerts indexOfObjectIdenticalTo:[_waitingAlertNames objectForKey:name]]];
				[_waitingAlertNames removeObjectForKey:name];
			}
			NSReleaseAlertPanel( sheet );
		} else {
			if( name && alert ) [_waitingAlertNames setObject:alert forKey:name];
			if( alert ) [_waitingAlerts addObject:alert];
		}
	}

	[_windowController reloadListItem:self andChildren:NO];
}

#pragma mark -
#pragma mark Prefences/User Defaults

- (void) setPreference:(id) value forKey:(NSString *) key {
	NSParameterAssert( key != nil );
	NSParameterAssert( [key length] );

	if( value ) [_settings setObject:value forKey:key];
	else [_settings removeObjectForKey:key];

	if( [_settings count] ) [[NSUserDefaults standardUserDefaults] setObject:_settings forKey:[[self identifier] stringByAppendingString:@" Settings"]];
	else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[[self identifier] stringByAppendingString:@" Settings"]];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (id) preferenceForKey:(NSString *) key {
	NSParameterAssert( key != nil );
	NSParameterAssert( [key length] );
	return [[[_settings objectForKey:key] retain] autorelease];
}

#pragma mark -
#pragma mark Styles

- (IBAction) changeStyle:(id) sender {
	JVStyle *style = [sender representedObject];

	[self setPreference:[style identifier] forKey:@"style"];
	[self setPreference:nil forKey:@"style variant"];

	[super changeStyle:sender];
}

- (IBAction) changeStyleVariant:(id) sender {
	JVStyle *style = [[sender representedObject] objectForKey:@"style"];
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];

	[self setPreference:[style identifier] forKey:@"style"];
	[self setPreference:variant forKey:@"style variant"];

	[super changeStyleVariant:sender];
}

- (IBAction) changeEmoticons:(id) sender {
	JVEmoticonSet *emoticon = [sender representedObject];

	[self setPreference:[emoticon identifier] forKey:@"emoticon"];

	[super changeEmoticons:sender];
}

#pragma mark -
#pragma mark Encoding Support

- (NSStringEncoding) encoding {
	return _encoding;
}

- (IBAction) changeEncoding:(id) sender {
	NSMenuItem *menuItem = nil;
	unsigned i = 0, count = 0;
	BOOL new = NO;
	if( ! [sender tag] ) {
		_encoding = (NSStringEncoding) [[self preferenceForKey:@"encoding"] intValue];
		if( ! _encoding ) _encoding = [[self connection] encoding];
	} else _encoding = (NSStringEncoding) [sender tag];

	if( ! _encodingMenu ) {
		_encodingMenu = [[NSMenu alloc] initWithTitle:@""];
		menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease];
		[menuItem setImage:[NSImage imageNamed:@"encoding"]];
		[_encodingMenu addItem:menuItem];
		new = YES;
	}

	for( i = 0; JVAllowedTextEncodings[i]; i++ ) {
		if( JVAllowedTextEncodings[i] == (NSStringEncoding) -1 ) {
			if( new ) [_encodingMenu addItem:[NSMenuItem separatorItem]];
			continue;
		}
		if( new ) menuItem = [[[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:JVAllowedTextEncodings[i]] action:@selector( changeEncoding: ) keyEquivalent:@""] autorelease];
		else menuItem = (NSMenuItem *)[_encodingMenu itemAtIndex:i + 1];
		if( _encoding == JVAllowedTextEncodings[i] ) {
			[menuItem setState:NSOnState];
		} else [menuItem setState:NSOffState];
		if( new ) {
			[menuItem setTag:JVAllowedTextEncodings[i]];
			[_encodingMenu addItem:menuItem];
		}
	}

	if( ! _spillEncodingMenu ) _spillEncodingMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding menu toolbar item" )];
	count = [_spillEncodingMenu numberOfItems];
	for( i = 0; i < count; i++ ) [_spillEncodingMenu removeItemAtIndex:0];
	count = [_encodingMenu numberOfItems];
	for( i = 1; i < count; i++ ) [_spillEncodingMenu addItem:[[(NSMenuItem *)[_encodingMenu itemAtIndex:i] copy] autorelease]];

	if( _encoding != [[self connection] encoding] ) {
		[self setPreference:[NSNumber numberWithInt:_encoding] forKey:@"encoding"];
	} else [self setPreference:nil forKey:@"encoding"];
}

#pragma mark -
#pragma mark Messages & Events

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes {
	if( ! _nibLoaded ) [self view];

	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] );

	JVMutableChatEvent *event = [JVMutableChatEvent chatEventWithName:name andMessage:message];
	[event setAttributes:attributes];

	[display setScrollbackLimit:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatScrollbackLimit"]];
	[[self transcript] setElementLimit:( [display scrollbackLimit] * 2 )];

	JVChatEvent *newEvent = [[self transcript] appendEvent:event];
	[display appendChatTranscriptElement:newEvent];

	if( ! [[[_windowController window] representedFilename] length] )
		[self _refreshWindowFileProxy];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type {
	if( ! _nibLoaded ) [self view];

	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	NSFont *baseFont = [[NSFontManager sharedFontManager] fontWithFamily:[[display preferences] standardFontFamily] traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:[[display preferences] defaultFontSize]];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:_encoding], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSTextStorage *messageString = [NSTextStorage attributedStringWithChatFormat:message options:options];

	if( ! messageString ) {
		[options setObject:[NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]] forKey:@"StringEncoding"];
		messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];

		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:baseFont, NSFontAttributeName, nil];
		NSMutableAttributedString *error = [[[NSMutableAttributedString alloc] initWithString:[@" " stringByAppendingString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" )] attributes:attributes] autorelease];
		[error addAttribute:@"CSSClasses" value:[NSSet setWithObjects:@"error", @"encoding", nil] range:NSMakeRange( 1, ( [error length] - 1 ) )];
		[messageString appendAttributedString:error];
	}

	if( ! [messageString length] ) {
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:baseFont, NSFontAttributeName, [NSSet setWithObjects:@"error", @"encoding", nil], @"CSSClasses", nil];
		messageString = [[[NSTextStorage alloc] initWithString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" ) attributes:attributes] autorelease];
	}

	JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:messageString sender:user];
	[cmessage setMessageIdentifier:identifier];
	[cmessage setAction:action];
	[cmessage setType:type];

	messageString = [cmessage body]; // just incase

	[self _setCurrentMessage:cmessage];

	if( ! [user isLocalUser] )
		[cmessage setIgnoreStatus:[[JVChatController defaultManager] shouldIgnoreUser:user withMessage:messageString inView:self]];

	if( ! [user isLocalUser] && [cmessage ignoreStatus] == JVNotIgnored )
		_newMessageCount++;

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] ) {
		[messageString makeLinkAttributesAutomatically];
		[self _hyperlinkRoomNames:messageString];
	}

	[[self emoticons] performEmoticonSubstitution:messageString];

	if( ! [user isLocalUser] ) {
		NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
		NSMutableArray *names = [[[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"MVChatHighlightNames"] mutableCopy] autorelease];
		[names addObject:[[self connection] nickname]];

		NSEnumerator *enumerator = [names objectEnumerator];
		AGRegex *regex = nil;
		NSString *name = nil;

		while( ( name = [enumerator nextObject] ) ) {
			if( ! [name length] ) continue;

			if( [name hasPrefix:@"/"] && [name hasSuffix:@"/"] && [name length] > 1 ) {
				regex = [AGRegex regexWithPattern:[name substringWithRange:NSMakeRange( 1, [name length] - 2 )] options:AGRegexCaseInsensitive];
			} else {
				NSString *pattern = [NSString stringWithFormat:@"\\b%@\\b", [name stringByEscapingCharactersInSet:escapeSet]];
				regex = [AGRegex regexWithPattern:pattern options:AGRegexCaseInsensitive];
			}

			NSArray *matches = [regex findAllInString:[messageString string]];
			NSEnumerator *enumerator = [matches objectEnumerator];
			AGRegexMatch *match = nil;

			while( ( match = [enumerator nextObject] ) ) {
				NSRange foundRange = [match range];
				NSMutableSet *classes = [NSMutableSet setWithSet:[messageString attribute:@"CSSClasses" atIndex:foundRange.location effectiveRange:NULL]];
				[classes addObject:@"highlight"];
				[messageString addAttribute:@"CSSClasses" value:[NSSet setWithSet:classes] range:foundRange];
				[cmessage setHighlighted:YES];
			}
		}
	}

	[self processIncomingMessage:cmessage];

	if( [[cmessage sender] isKindOfClass:[JVChatRoomMember class]] )
		user = [(JVChatRoomMember *)[cmessage sender] user]; // if this is a chat room, JVChatRoomPanel makes the sender a member object
	else user = [cmessage sender]; // if plugins changed the sending user for some reason, allow it

	if( ! [messageString length] && [cmessage ignoreStatus] == JVNotIgnored ) {  // plugins decided to excluded this message, decrease the new message counts
		_newMessageCount--;
		return;
	}

	[self _breakLongLinesInString:messageString];

	if( [cmessage isHighlighted] && [cmessage ignoreStatus] == JVNotIgnored ) {
		_newHighlightMessageCount++;
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"You Were Mentioned", "mentioned bubble title" ) forKey:@"title"];
		if( [self isMemberOfClass:[JVChatRoomPanel class]] ) [context setObject:[NSString stringWithFormat:NSLocalizedString( @"One of your highlight words was mentioned in %@.", "chat room mentioned bubble text" ), [self title]] forKey:@"description"];
		else [context setObject:[NSString stringWithFormat:NSLocalizedString( @"One of your highlight words was mentioned by %@.", "private chat mentioned bubble text" ), [self title]] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activityNewImportant"] forKey:@"image"];
		[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatMentioned"] forKey:@"coalesceKey"];
		[context setObject:self forKey:@"target"];
		[context setObject:NSStringFromSelector( @selector( activate: ) ) forKey:@"action"];
		[[JVNotificationController defaultManager] performNotification:@"JVChatMentioned" withContextInfo:context];
	}

	if( [cmessage ignoreStatus] != JVNotIgnored ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:( ( [cmessage ignoreStatus] == JVUserIgnored ) ? NSLocalizedString( @"User Ignored", "user ignored bubble title" ) : NSLocalizedString( @"Message Ignored", "message ignored bubble title" ) ) forKey:@"title"];
		if( [self isMemberOfClass:[JVChatRoomPanel class]] ) [context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@'s message was ignored in %@.", "chat room user ignored bubble text" ), user, [self title]] forKey:@"description"];
		else [context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@'s message was ignored.", "direct chat user ignored bubble text" ), user] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activity"] forKey:@"image"];
		[[JVNotificationController defaultManager] performNotification:( ( [cmessage ignoreStatus] == JVUserIgnored ) ? @"JVUserIgnored" : @"JVMessageIgnored" ) withContextInfo:context];
	}

	[display setScrollbackLimit:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatScrollbackLimit"]];
	[[self transcript] setElementLimit:( [display scrollbackLimit] * 2 )];

	JVChatMessage *newMessage = [[self transcript] appendMessage:cmessage];

	if( [display appendChatMessage:newMessage] ) {
		if( [cmessage isHighlighted] ) [display markScrollbarForMessage:newMessage];
		_firstMessage = NO; // not the first message anymore
	} else if( [cmessage ignoreStatus] == JVNotIgnored ) {
		// the style decided to excluded this message, decrease the new message counts
		if( [cmessage isHighlighted] ) _newHighlightMessageCount--;
		_newMessageCount--;		
	}

	[self _setCurrentMessage:nil];
	[cmessage release];

	[_windowController reloadListItem:self andChildren:NO];

	if( ! [[[_windowController window] representedFilename] length] )
		[self _refreshWindowFileProxy];	
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message {
	if( [[message sender] respondsToSelector:@selector( isLocalUser )] && ! [[message sender] isLocalUser] ) {
		if( [message ignoreStatus] == JVNotIgnored && _firstMessage ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"New Private Message", "first message bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ wrote you a private message.", "first message bubble text" ), [self title]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"messageUser"] forKey:@"image"];
			[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatPrivateMessage"] forKey:@"coalesceKey"];
			[context setObject:self forKey:@"target"];
			[context setObject:NSStringFromSelector( @selector( activate: ) ) forKey:@"action"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatFirstMessage" withContextInfo:context];
		} else if( [message ignoreStatus] == JVNotIgnored ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"Private Message", "new message bubble title" ) forKey:@"title"];
			if( [self newMessagesWaiting] == 1 ) [context setObject:[NSString stringWithFormat:NSLocalizedString( @"You have 1 message waiting from %@.", "new single message bubble text" ), [self title]] forKey:@"description"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You have %d messages waiting from %@.", "new messages bubble text" ), [self newMessagesWaiting], [self title]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"messageUser"] forKey:@"image"];
			[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatPrivateMessage"] forKey:@"coalesceKey"];
			[context setObject:self forKey:@"target"];
			[context setObject:NSStringFromSelector( @selector( activate: ) ) forKey:@"action"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatAdditionalMessages" withContextInfo:context];
		}
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processIncomingMessage:inView: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&self atIndex:3];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (void) echoSentMessageToDisplay:(JVMutableChatMessage *) message {
	NSString *cformat = nil;

	switch( [[self connection] outgoingChatFormat] ) {
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

	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[self encoding]], @"StringEncoding", cformat, @"FormatType", nil];
	NSData *msgData = [[message body] chatFormatWithOptions:options]; // we could save this back to the message object before sending
	[self addMessageToDisplay:msgData fromUser:[message sender] asAction:[message isAction] withIdentifier:[message messageIdentifier] andType:JVChatMessageNormalType];
}

- (unsigned int) newMessagesWaiting {
	return _newMessageCount;
}

- (unsigned int) newHighlightMessagesWaiting {
	return _newHighlightMessageCount;
}

- (JVMutableChatMessage *) currentMessage {
	return [[_currentMessage retain] autorelease];
}

#pragma mark -
#pragma mark Input Handling

- (IBAction) send:(id) sender {
	NSTextStorage *subMsg = nil;
	BOOL action = NO;
	NSRange range;

	// allow commands to be passed to plugins if we arn't connected, allow commands to pass to plugins and server if we are just out of the room
	if( ( _cantSendMessages || ! [[self connection] isConnected] ) && ( ! [[[send textStorage] string] hasPrefix:@"/"] || [[[send textStorage] string] hasPrefix:@"//"] ) ) return;

	_historyIndex = 0;
	if( ! [[send textStorage] length] ) return;
	if( [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[NSAttributedString alloc] initWithString:@""] autorelease]];
	[_sendHistory insertObject:[[[send textStorage] copy] autorelease] atIndex:1];
	if( [_sendHistory count] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatMaximumHistory"] unsignedIntValue] )
		[_sendHistory removeObjectAtIndex:[_sendHistory count] - 1];

	if( [sender isKindOfClass:[NSNumber class]] && [sender boolValue] ) action = YES;

	[[[send textStorage] mutableString] replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange( 0, [[send textStorage] length] )];

	unichar zeroWidthSpaceChar = 0x200b;	
	[[[send textStorage] mutableString] replaceOccurrencesOfString:[NSString stringWithCharacters:&zeroWidthSpaceChar length:1] withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [[send textStorage] length] )];

	while( [[send textStorage] length] ) {
		range = [[[send textStorage] string] rangeOfString:@"\n"];
		if( ! range.length ) range.location = [[send textStorage] length];
		subMsg = [[[[send textStorage] attributedSubstringFromRange:NSMakeRange( 0, range.location )] mutableCopy] autorelease];

		if( ( [subMsg length] >= 1 && range.length ) || ( [subMsg length] && ! range.length ) ) {
			if( [[subMsg string] hasPrefix:@"/"] && ! [[subMsg string] hasPrefix:@"//"] ) {
				BOOL handled = NO;
				NSScanner *scanner = [NSScanner scannerWithString:[subMsg string]];
				NSString *command = nil;
				NSAttributedString *arguments = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [[subMsg string] length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [subMsg attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], range.location - [scanner scanLocation] )];

				if( ! ( handled = [self processUserCommand:command withArguments:arguments] ) && [[self connection] isConnected] )
					[[self connection] sendRawMessage:[command stringByAppendingFormat:@" %@", [arguments string]]];
			} else {
				if( [[subMsg string] hasPrefix:@"//"] ) [subMsg deleteCharactersInRange:NSMakeRange( 0, 1 )];
				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"] && ! action ) {
					extern NSArray *JVAutoActionVerbs;
					if( ! JVAutoActionVerbs ) JVAutoActionVerbs = [[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"verbs" ofType:@"plist"]] retain];
					else [JVAutoActionVerbs retain];
					NSString *tempString = [[subMsg string] stringByAppendingString:@" "];
					NSEnumerator *enumerator = [JVAutoActionVerbs objectEnumerator];
					NSString *verb = nil;
					while( ( verb = [enumerator nextObject] ) ) {
						if( [tempString hasPrefix:[verb stringByAppendingString:@" "]] ) {
							action = YES;
							break;
						}
					}
				}

				if( [[subMsg string] length] ) {
					JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:subMsg sender:[[self connection] localUser]];
					[cmessage setAction:action];

					[self sendMessage:cmessage];
					[self echoSentMessageToDisplay:cmessage]; // echo after the plugins process the message

					[cmessage release];
				}
			}
		}

		if( range.length ) range.location++;
		[[send textStorage] deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}

	[send reset:nil];
	[self textDidChange:nil];
	[display scrollToBottom];
}

- (void) sendMessage:(JVMutableChatMessage *) message {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processOutgoingMessage:inView: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&self atIndex:3];

	[self _setCurrentMessage:message];
	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
	[self _setCurrentMessage:nil];

	if( [[message body] length] )
		[[self target] sendMessage:[message body] withEncoding:_encoding asAction:[message isAction]];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( MVChatConnection * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	MVChatConnection *connection = [self connection];

	[invocation setSelector:@selector( processUserCommand:withArguments:toConnection:inView: )];
	[invocation setArgument:&command atIndex:2];
	[invocation setArgument:&arguments atIndex:3];
	[invocation setArgument:&connection atIndex:4];
	[invocation setArgument:&self atIndex:5];

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
	return [[results lastObject] boolValue];
}

#pragma mark -
#pragma mark ScrollBack

- (IBAction) clear:(id) sender {
	[send reset:nil];
}

- (IBAction) clearDisplay:(id) sender {
	[display clear];
}

#pragma mark -
#pragma mark TextView Support

- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event {
	BOOL ret = NO;

	if( [textView hasMarkedText] ) {
		ret = NO;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnEnter"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnEnter"] ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	}

	return ret;
}

- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event {
	BOOL ret = NO;

	if( [textView hasMarkedText] ) {
		ret = NO;
	} else if( ( [event modifierFlags] & NSAlternateKeyMask ) != 0 ) {
		ret = NO;
	} else if ( ([event modifierFlags] & NSControlKeyMask) != 0 ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] ) {
		[self send:[NSNumber numberWithBool:YES]];
		ret = YES;
	}

	return ret;
}

- (BOOL) upArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[send textStorage] copy] autorelease]];
	_historyIndex++;
	if( _historyIndex >= [_sendHistory count] ) {
		_historyIndex = [_sendHistory count] - 1;
		if( (signed) _historyIndex < 0 ) _historyIndex = 0;
		return YES;
	}
	[send reset:nil];
	[[send textStorage] insertAttributedString:[_sendHistory objectAtIndex:_historyIndex] atIndex:0];
	return YES;
}

- (BOOL) downArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		[_sendHistory replaceObjectAtIndex:0 withObject:[[[send textStorage] copy] autorelease]];
	if( [[send textStorage] length] ) _historyIndex--;
	if( _historyIndex < 0 ) {
		[send reset:nil];
		_historyIndex = -1;
		return YES;
	} else if( ! [_sendHistory count] ) {
		_historyIndex = 0;
		return YES;
	}
	[send reset:nil];
	[[send textStorage] insertAttributedString:[_sendHistory objectAtIndex:_historyIndex] atIndex:0];
	return YES;
}

- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event {
	unichar chr = 0;

	if( [[event charactersIgnoringModifiers] length] ) {
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];
	} else return NO;

	// exclude device-dependent flags, caps-lock and fn key (necessary for pg up/pg dn/home/end on portables)
	if( [event modifierFlags] & ~( NSFunctionKeyMask | NSNumericPadKeyMask | NSAlphaShiftKeyMask | 0xffff ) ) return NO;

	if( chr == NSUpArrowFunctionKey ) {
		return [self upArrowKeyPressed];
	} else if( chr == NSDownArrowFunctionKey ) {
		return [self downArrowKeyPressed];
	} else if( chr == NSPageUpFunctionKey || chr == NSPageDownFunctionKey || chr == NSHomeFunctionKey || chr == NSBeginFunctionKey || chr == NSEndFunctionKey ) {
		[[[display mainFrame] frameView] keyDown:event];
		return YES;
	}

	return NO;
}

- (NSArray *) completionsFor:(NSString *) inFragment {
	NSArray *retVal = nil;

	if( [[self title] rangeOfString:inFragment options:( NSCaseInsensitiveSearch | NSAnchoredSearch )].location == 0 )
		retVal = [NSArray arrayWithObject:[self title]];

	return retVal;	
}

- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event {
	[send reset:nil];
	return YES;	
}

- (NSArray *) textView:(NSTextView *) textView completions:(NSArray *) words forPartialWordRange:(NSRange) charRange indexOfSelectedItem:(int *) index {
	NSString *search = [[[send textStorage] string] substringWithRange:charRange];
	NSMutableArray *ret = [NSMutableArray array];
	if( [search length] <= [[self title] length] && [search caseInsensitiveCompare:[[[self target] description] substringToIndex:[search length]]] == NSOrderedSame )
		[ret addObject:[self title]];
	if( [self isMemberOfClass:[JVDirectChatPanel class]] ) [ret addObjectsFromArray:words];
	return ret;
}

- (void) textDidChange:(NSNotification *) notification {
	_historyIndex = 0;

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return;

	// We need to resize the textview to fit the content.
	// The scroll views are two superviews up: NSTextView(WebView) -> NSClipView -> NSScrollView
	NSSplitView *splitView = (NSSplitView *)[[[send superview] superview] superview];
	NSRect splitViewFrame = [splitView frame];
	NSSize contentSize = [send minimumSizeForContent];
	NSRect sendFrame = [[[send superview] superview] frame];
	float dividerThickness = [splitView dividerThickness];
	float maxContentHeight = ( NSHeight( splitViewFrame ) - dividerThickness - 75. );
	float newContentHeight =  MIN( maxContentHeight, MAX( 25., contentSize.height + 8. ) );

	if( newContentHeight == NSHeight( sendFrame ) ) return;

	NSRect webFrame = [[[display superview] superview] frame];

	// Set size of the web view to the maximum size possible
	webFrame.size.height = NSHeight( splitViewFrame ) - dividerThickness - newContentHeight;
	webFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = newContentHeight;
	sendFrame.origin.y = NSHeight( webFrame ) + dividerThickness;

	[[display window] disableFlushWindow]; // prevent any draw (white) flashing that might occur

	JVMarkedScroller *scroller = [display verticalMarkedScroller];
	if( ! scroller || [scroller floatValue] == 1. ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;

	// Commit the changes
	[[[send superview] superview] setFrame:sendFrame];
	[[[display superview] superview] setFrame:webFrame];

	if( _scrollerIsAtBottom ) {
		NSScrollView *scrollView = [[[[display mainFrame] frameView] documentView] enclosingScrollView];
		[scrollView scrollClipView:[scrollView contentView] toPoint:[[scrollView contentView] constrainScrollPoint:NSMakePoint( 0, [[scrollView documentView] bounds].size.height )]];
		[scrollView reflectScrolledClipView:[scrollView contentView]];
	}

	[display displayIfNeeded]; // makes the WebView draw correctly
	[splitView setNeedsDisplay:YES]; // makes the divider redraw correctly later
	[[display window] enableFlushWindow]; // flush everything we have drawn
}

#pragma mark -
#pragma mark SplitView Support

- (float) splitView:(NSSplitView *) splitView constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) index {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return ( NSHeight( [[[splitView subviews] objectAtIndex:index] frame] ) ); // prevents manual resize
	return proposedPosition;
}

- (void) splitViewDidResizeSubviews:(NSNotification *) notification {
	// Cache the height of the send box so we can keep it constant during window resizes.
	NSRect sendFrame = [[[send superview] superview] frame];
	_sendHeight = sendFrame.size.height;

	if( _scrollerIsAtBottom ) {
		NSScrollView *scrollView = [[[[display mainFrame] frameView] documentView] enclosingScrollView];
		[scrollView scrollClipView:[scrollView contentView] toPoint:[[scrollView contentView] constrainScrollPoint:NSMakePoint( 0, [[scrollView documentView] bounds].size.height )]];
		[scrollView reflectScrolledClipView:[scrollView contentView]];
	}

	if( ! _forceSplitViewPosition && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		[(JVSplitView *)[notification object] savePositionUsingName:@"JVChatSplitViewPosition"];

	_forceSplitViewPosition = NO;
}

- (void) splitViewWillResizeSubviews:(NSNotification *) notification {
	JVMarkedScroller *scroller = [display verticalMarkedScroller];
	if( ! scroller || [scroller floatValue] == 1. ) _scrollerIsAtBottom = YES;
	else _scrollerIsAtBottom = NO;
}

- (void) splitView:(NSSplitView *) sender resizeSubviewsWithOldSize:(NSSize) oldSize {
	float dividerThickness = [sender dividerThickness];
	NSRect newFrame = [sender frame];

	// Keep the size of the send box constant during window resizes

	// We need to resize the scroll view frames of the webview and the textview.
	// The scroll views are two superviews up: NSTextView(WebView) -> NSClipView -> NSScrollView
	NSRect sendFrame = [[[send superview] superview] frame];
	NSRect webFrame = [[[display superview] superview] frame];

	// Set size of the web view to the maximum size possible
	webFrame.size.height = NSHeight( newFrame ) - dividerThickness - _sendHeight;
	webFrame.size.width = NSWidth( newFrame );
	webFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = _sendHeight;
	sendFrame.size.width = NSWidth( newFrame );
	sendFrame.origin.y = NSHeight( webFrame ) + dividerThickness;

	// Commit the changes
	[[[send superview] superview] setFrame:sendFrame];
	[[[display superview] superview] setFrame:webFrame];
}

#pragma mark -
#pragma mark Toolbar Support

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Direct Chat"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = nil;

	if( [identifier isEqual:JVToolbarTextEncodingItemIdentifier] ) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

		[toolbarItem setLabel:NSLocalizedString( @"Encoding", "encoding menu toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Text Encoding", "encoding menu toolbar customize palette name" )];

		[toolbarItem setTarget:nil];
		[toolbarItem setAction:NULL];

		NSPopUpButton *button = [[NSPopUpButton alloc] initWithFrame:NSMakeRect( 0., 0., 53., 20. ) pullsDown:YES];
		[button setMenu:_encodingMenu];

		[toolbarItem setToolTip:NSLocalizedString( @"Text Encoding Options", "encoding menu toolbar item tooltip" )];
		[toolbarItem setView:button];
		[toolbarItem setMinSize:NSMakeSize( 60., 24. )];
		[toolbarItem setMaxSize:NSMakeSize( 60., 32. )];

		NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding menu toolbar item" ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setImage:[NSImage imageNamed:@"encoding"]];
		[menuItem setSubmenu:_spillEncodingMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];
	} else if( [identifier isEqual:JVToolbarClearItemIdentifier] ) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

		[toolbarItem setLabel:NSLocalizedString( @"Clear", "clear display toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Clear Display", "clear display toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Clear Display", "clear display tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"clear"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( clearDisplay: )];
	} else if( [identifier isEqual:JVToolbarSendFileItemIdentifier] ) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

		[toolbarItem setLabel:NSLocalizedString( @"Send File", "send file toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Send File", "send file toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Send File", "send file toolbar tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"fileSend"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( _sendFile: )];
	} else return [super toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:willBeInserted];
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarDefaultItemIdentifiers:toolbar]];
	if( [self isMemberOfClass:[JVDirectChatPanel class]] ) [list addObject:JVToolbarSendFileItemIdentifier];
	[list addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
	if( [self isMemberOfClass:[JVDirectChatPanel class]] ) [list addObject:JVToolbarSendFileItemIdentifier];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	[list addObject:JVToolbarClearItemIdentifier];
	return list;
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	return [super validateToolbarItem:toolbarItem];
}

#pragma mark-
#pragma mark WebKit Support

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	NSMutableArray *ret = [NSMutableArray array];

	NSMenuItem *item = nil;
	unsigned i = 0;
	BOOL found = NO;

	for( i = 0; i < [defaultMenuItems count]; i++ ) {
		item = [defaultMenuItems objectAtIndex:i];
		switch( [item tag] ) {
			case WebMenuItemTagCopy:
			case WebMenuItemTagDownloadLinkToDisk:
			case WebMenuItemTagDownloadImageToDisk:
				found = YES;
				break;
		}
	}

	if( ! found && ! [[element objectForKey:WebElementIsSelectedKey] boolValue] ) {
		NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Display", "clear display contextual menu" ) action:NULL keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[item setAction:@selector( clearDisplay: )];
		[ret addObject:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding contextual menu" ) action:NULL keyEquivalent:@""] autorelease];
		[item setSubmenu:_spillEncodingMenu];
		[ret addObject:item];
	}

	[ret addObjectsFromArray:[super webView:sender contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems]];

	return ret;
}
@end

#pragma mark -

@implementation JVDirectChatPanel (JVDirectChatPrivate)
- (NSString *) _selfCompositeName {
	ABPerson *_person = [[ABAddressBook sharedAddressBook] me];
	NSString *firstName = [_person valueForProperty:kABFirstNameProperty];
	NSString *lastName = [_person valueForProperty:kABLastNameProperty];

	if( ! firstName && lastName ) return lastName;
	else if( firstName && ! lastName ) return firstName;
	else if( firstName && lastName ) {
		return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
	}

	firstName = [_person valueForProperty:kABNicknameProperty];
	if( firstName ) return firstName;

	return [[self connection] nickname];
}

- (NSString *) _selfStoredNickname {
	NSString *nickname = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABNicknameProperty];
	if( nickname ) return nickname;
	return [[self connection] nickname];
}

- (NSMenu *) _encodingMenu {
	if( ! _nibLoaded ) [self view];
	return [[_encodingMenu retain] autorelease];
}

- (void) _breakLongLinesInString:(NSMutableAttributedString *) message { // Not good on strings that have prior HTML or HTML entities
	NSScanner *scanner = [NSScanner scannerWithString:[message string]];
	NSCharacterSet *stopSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	unsigned int lastLoc = 0;
	unichar zeroWidthSpaceChar = 0x200b;
	NSString *zero = [NSString stringWithCharacters:&zeroWidthSpaceChar length:1];

	while( ! [scanner isAtEnd] ) {
		lastLoc = [scanner scanLocation];
		[scanner scanUpToCharactersFromSet:stopSet intoString:nil];
		if( ( [scanner scanLocation] - lastLoc ) > 34 ) { // Who says "supercalifragilisticexpialidocious" anyway?
			unsigned int times = (unsigned int) ( ( [scanner scanLocation] - lastLoc ) / 34 );
			while( times > 0 ) {
				[[message mutableString] insertString:zero atIndex:( lastLoc + ( times * 34 ) )];
				times--;
			}
		}
	}
}

- (void) _hyperlinkRoomNames:(NSMutableAttributedString *) message {
	// catch IRC rooms like "#room" but not HTML colors like "#ab12ef" or HTML entities like "&#135;" or "&amp;"
	AGRegex *regex = [AGRegex regexWithPattern:@"(?:(?<!&)#(?![\\da-fA-F]{6}\\b|\\d{1,3}\\b))[\\w-_.+&#]{2,}" options:AGRegexCaseInsensitive];
	NSArray *matches = [regex findAllInString:[message string]];
	NSEnumerator *enumerator = [matches objectEnumerator];
	AGRegexMatch *match = nil;

	while( ( match = [enumerator nextObject] ) ) {
		NSRange foundRange = [match range];
		id currentLink = [message attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		if( ! currentLink ) [message addAttribute:NSLinkAttributeName value:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], [match group]] range:foundRange];
	}	
}

- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message {
	return [self _convertRawMessage:message withBaseFont:nil];
}

- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont {
	if( ! message || ! [message length] ) return nil;

	if( ! baseFont ) baseFont = [[NSFontManager sharedFontManager] fontWithFamily:[[display preferences] standardFontFamily] traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:[[display preferences] defaultFontSize]];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:_encoding], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSMutableAttributedString *messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];

	if( ! messageString ) {
		[options setObject:[NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]] forKey:@"StringEncoding"];
		messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] ) {
		[messageString makeLinkAttributesAutomatically];
		[self _hyperlinkRoomNames:messageString];
	}

	[[self emoticons] performEmoticonSubstitution:messageString];

	return messageString;
}

- (void) _alertSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	NSEnumerator *kenumerator = nil, *enumerator = nil;
	id key = nil, value = nil;

	[[NSApplication sharedApplication] endSheet:sheet];
	[sheet orderOut:nil];

	[_waitingAlerts removeObjectIdenticalTo:sheet];

	kenumerator = [_waitingAlertNames keyEnumerator];
	enumerator = [_waitingAlertNames objectEnumerator];
	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) )
		if( value == sheet ) break;

	if( key ) [_waitingAlertNames removeObjectForKey:key];

	NSReleaseAlertPanel( sheet );

	if( [_waitingAlerts count] )
		[[NSApplication sharedApplication] beginSheet:[_waitingAlerts objectAtIndex:0] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) _didConnect:(NSNotification *) notification {
	[self addEventMessageToDisplay:NSLocalizedString( @"You reconnected to the server.", "reconnected to server status message" ) withName:@"reconnected" andAttributes:nil];
	_cantSendMessages = NO;
}

- (void) _didDisconnect:(NSNotification *) notification {
	[self addEventMessageToDisplay:NSLocalizedString( @"You left the chat by being disconnected from the server.", "disconenct from the server status message" ) withName:@"disconnected" andAttributes:nil];
	_cantSendMessages = YES;
}

- (void) _awayStatusChanged:(NSNotification *) notification {
	if( [[self connection] awayStatusMessage] ) {
		NSMutableAttributedString *messageString = [[[[self connection] awayStatusMessage] mutableCopy] autorelease];

		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
			[messageString makeLinkAttributesAutomatically];

		[[self emoticons] performEmoticonSubstitution:messageString];

		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
		NSString *msgString = [messageString HTMLFormatWithOptions:options];

		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You have set yourself away with \"%@\".", "self away status set message" ), msgString] withName:@"awaySet" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:messageString, @"away-message", nil]];

/*		unsigned long messageCount = [self visibleMessageCount];
		long loc = [self locationOfElementByIndex:( messageCount - 1 )];
		[[self verticalMarkedScroller] startShadedAreaAt:loc]; */
	} else {
		[self addEventMessageToDisplay:NSLocalizedString( @"You have returned from away.", "self away status removed message" ) withName:@"awayRemoved" andAttributes:nil];

/*		unsigned long messageCount = [self visibleMessageCount];
		long loc = [self locationOfElementByIndex:( messageCount - 1 )];
		[[display verticalMarkedScroller] stopShadedAreaAt:loc]; */
	}
}

- (void) _updateEmoticonsMenu {
	NSEnumerator *enumerator = nil;
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil;
	BOOL new = YES;

	if( ! ( menu = _emoticonMenu ) ) {
		menu = [[NSMenu alloc] initWithTitle:@""];
		_emoticonMenu = menu;
	} else {
		new = NO;
		enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];
		if( ! [menu indexOfItemWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )] )
			[enumerator nextObject];
		while( ( menuItem = [enumerator nextObject] ) )
			if( ! [menuItem tag] && ! [menuItem isSeparatorItem] )
				[menu removeItem:menuItem];
	}

	NSDictionary *info = nil;
	unsigned int count = 0;

	if( ! [menu indexOfItemWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )] )
		count++;

	NSArray *menuItems = [[self emoticons] emoticonMenuItems];
	enumerator = [menuItems objectEnumerator];
	while( ( menuItem = [enumerator nextObject] ) ) {
		[menuItem setAction:@selector( _insertEmoticon: )];
		[menuItem setTarget:self];
		[menu insertItem:menuItem atIndex:count++];
	}

	if( ! [menuItems count] ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Selectable Emoticons", "no selectable emoticons menu item title" ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setEnabled:NO];
		[menu insertItem:menuItem atIndex:count++];
	}

	if( new ) {
		JVEmoticonSet *emoticon = nil;

		[menu addItem:[NSMenuItem separatorItem]];

		subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Preferences", "preferences menu item title" ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setSubmenu:subMenu];
		[menuItem setTag:20];
		[menu addItem:menuItem];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[[NSMenuItem alloc] initWithTitle:[[JVEmoticonSet textOnlyEmoticonSet] displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[JVEmoticonSet textOnlyEmoticonSet]];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		enumerator = [[[[JVEmoticonSet emoticonSets] allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
		while( ( emoticon = [enumerator nextObject] ) ) {
			if( ! [[emoticon displayName] length] ) continue;
			menuItem = [[[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""] autorelease];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:emoticon];
			[subMenu addItem:menuItem];
		}

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setTag:10];
		[subMenu addItem:menuItem];
	}

	[self _changeEmoticonsMenuSelection];
}

- (IBAction) _insertEmoticon:(id) sender {
	if( [[send textStorage] length] )
		[send replaceCharactersInRange:NSMakeRange( [[send textStorage] length], 0 ) withString:@" "];
	[send replaceCharactersInRange:NSMakeRange( [[send textStorage] length], 0 ) withString:[NSString stringWithFormat:@"%@ ", [sender representedObject]]];
}

- (BOOL) _usingSpecificStyle {
	return ( [self preferenceForKey:@"style"] ? YES : NO );
}

- (BOOL) _usingSpecificEmoticons {
	return ( [self preferenceForKey:@"emoticon"] ? YES : NO );
}

- (void) _updateInputFont:(NSNotification *) notification {
	NSFont *baseFont = nil;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputUsesStyleFont"] ) {
		WebPreferences *preferences = [display preferences];
		// in some versions of WebKit (v125.9 at least), this is a font name, not a font family, try both
		NSString *fontFamily = [preferences standardFontFamily];
		int fontSize = [preferences defaultFontSize];
		baseFont = [NSFont fontWithName:fontFamily size:fontSize];
		if( ! baseFont ) baseFont = [[NSFontManager sharedFontManager] fontWithFamily:fontFamily traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:fontSize];
	}

	[send setBaseFont:baseFont];	
}

- (void) consumeImageData:(NSData *) data forTag:(int) tag {
	[_personImageData autorelease];
	_personImageData = [data retain];
	_loadingPersonImage = NO;
}

- (void) _saveSelfIcon {
	if( _loadingPersonImage ) return;
	_loadingPersonImage = YES;

	ABPerson *me = [[ABAddressBook sharedAddressBook] me];

	@try {
		[me beginLoadingImageDataForClient:self];
	} @catch ( NSException *exception ) {
		_loadingPersonImage = NO;
		return;
	}

	while( ! _personImageData && _loadingPersonImage ) // asynchronously load the image incase it is on the network
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

	if( ! [_personImageData length] ) {
		[[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [me uniqueId]] handler:nil];
	} else {
		NSImage *icon = [[[NSImage alloc] initWithData:_personImageData] autorelease];
		NSData *imageData = [icon TIFFRepresentation];
		[imageData writeToFile:[NSString stringWithFormat:@"/tmp/%@.tif", [me uniqueId]] atomically:NO];

		[_personImageData autorelease];
		_personImageData = nil;
	}
}

- (void) _saveBuddyIcon:(JVBuddy *) buddy {
	NSData *imageData = [[buddy picture] TIFFRepresentation];
	if( ! [imageData length] ) {
		[[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]] handler:nil];
		return;
	}

	[imageData writeToFile:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]] atomically:NO];
}

- (void) _refreshIcon:(NSNotification *) notification {
	[_windowController reloadListItem:self andChildren:NO];
}

- (IBAction) _sendFile:(id) sender {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	NSString *path = nil;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setResolvesAliases:YES];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];

	NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect( 0., 0., 200., 28. )] autorelease];
	[view setAutoresizingMask:( NSViewWidthSizable | NSViewMaxXMargin )];

	NSButton *passiveButton = [[[NSButton alloc] initWithFrame:NSMakeRect( 0., 6., 200., 18. )] autorelease];
	[[passiveButton cell] setButtonType:NSSwitchButton];
	[passiveButton setState:passive];
	[passiveButton setTitle:NSLocalizedString( @"Send File Passively", "send files passively file send open dialog button" )];
	[passiveButton sizeToFit];

	NSRect frame = [view frame];
	frame.size.width = NSWidth( [passiveButton frame] );

	[view setFrame:frame];
	[view addSubview:passiveButton];

	[panel setAccessoryView:view];

	if( [panel runModalForTypes:nil] == NSOKButton ) {
		NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
		passive = [passiveButton state];
		while( ( path = [enumerator nextObject] ) )
			[[MVFileTransferController defaultManager] addFileTransfer:[[self target] sendFile:path passively:passive]];
	}
}

- (void) _setCurrentMessage:(JVMutableChatMessage *) message {
	[_currentMessage setObjectSpecifier:nil];
	[_currentMessage autorelease];
	_currentMessage = [message retain];

	id classDescription = [NSClassDescription classDescriptionForClass:[self class]];
	id msgSpecifier = [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:[self objectSpecifier] key:@"currentMessage"] autorelease];
	[_currentMessage setObjectSpecifier:msgSpecifier];
}
@end

#pragma mark -

@implementation NSApplication (NSApplicationActivePanelScripting)
- (id) sendMessageScriptCommand:(NSScriptCommand *) command {
	// if there is a subject or target parameter, perform the default implementation
	if( [command subjectSpecifier] || [[command evaluatedArguments] objectForKey:@"target"] )
		return [command performDefaultImplementation];

	// if nothing responds to this command make it perform on the active panel of the front window
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	id container = [[[NSIndexSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:nil key:@"orderedWindows" index:0] autorelease];
	if( ! container ) return nil;

	classDescription = [NSClassDescription classDescriptionForClass:[NSWindow class]];
	id specifier = [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"activeChatViewController"] autorelease];
	if( ! specifier ) return nil;

	[command setSubjectSpecifier:specifier];
	[command performDefaultImplementation];
	return nil;
}

- (id) addEventMessageScriptCommand:(NSScriptCommand *) command {
	// if there is a subject, perform the default implementation
	if( [command subjectSpecifier] ) return [command performDefaultImplementation];

	// if nothing responds to this command make it perform on the active panel of the front window
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	id container = [[[NSIndexSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:nil key:@"orderedWindows" index:0] autorelease];
	if( ! container ) return nil;

	classDescription = [NSClassDescription classDescriptionForClass:[NSWindow class]];
	id specifier = [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"activeChatViewController"] autorelease];
	if( ! specifier ) return nil;

	[command setSubjectSpecifier:specifier];
	[command performDefaultImplementation];
	return nil;
}
@end

#pragma mark -

@implementation JVDirectChatPanel (JVDirectChatScripting)
- (id) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSDictionary *args = [command evaluatedArguments];
	id message = [command evaluatedDirectParameter];
	id action = [args objectForKey:@"action"];
	id localEcho = [args objectForKey:@"echo"];

	if( [args objectForKey:@"message"] ) // support the old command that had a message parameter instead
		message = [args objectForKey:@"message"];

	if( ! message ) {
		[command setScriptErrorNumber:-1715]; // errAEParamMissed
		[command setScriptErrorString:@"The message was missing."];
		return nil;
	}

	if( ! [message isKindOfClass:[NSString class]] ) {
		message = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:message toClass:[NSString class]];
		if( ! [message isKindOfClass:[NSString class]] ) {
			[command setScriptErrorNumber:-1700]; // errAECoercionFail
			[command setScriptErrorString:@"The message was not a string value and coercion failed."];
			return nil;
		}
	}

	if( ! [(NSString *)message length] ) {
		[command setScriptErrorNumber:-1715]; // errAEParamMissed
		[command setScriptErrorString:@"The message can't be blank."];
		return nil;
	}

	if( action && ! [action isKindOfClass:[NSNumber class]] ) {
		action = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:action toClass:[NSNumber class]];
		if( ! [action isKindOfClass:[NSNumber class]] ) {
			[command setScriptErrorNumber:-1700]; // errAECoercionFail
			[command setScriptErrorString:@"The action tense parameter was not a boolean value and coercion failed."];
			return nil;
		}
	}

	if( localEcho && ! [localEcho isKindOfClass:[NSNumber class]] ) {
		localEcho = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:localEcho toClass:[NSNumber class]];
		if( ! [localEcho isKindOfClass:[NSNumber class]] ) {
			[command setScriptErrorNumber:-1700]; // errAECoercionFail
			[command setScriptErrorString:@"The local echo parameter was not a boolean value and coercion failed."];
			return nil;
		}
	}

	NSAttributedString *realMessage = [NSAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	BOOL realAction = ( action ? [action boolValue] : NO );
	BOOL realLocalEcho = ( localEcho ? [localEcho boolValue] : YES );

	JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:realMessage sender:[[self connection] localUser]];
	[cmessage setAction:realAction];

	[self sendMessage:cmessage];
	if( realLocalEcho ) [self echoSentMessageToDisplay:cmessage];

	[cmessage release];
}

#pragma mark -

- (unsigned long) scriptTypedEncoding {
	return [NSString scriptTypedEncodingFromStringEncoding:[self encoding]];
}

- (void) setScriptTypedEncoding:(unsigned long) encoding {
	[self setPreference:[NSNumber numberWithLong:encoding] forKey:@"encoding"];
	[self changeEncoding:nil];
}
@end

#pragma mark -

@interface JVAddEventMessageScriptCommand : NSScriptCommand {}
@end

@implementation JVAddEventMessageScriptCommand
- (id) performDefaultImplementation {
	// check if the subject responds to the command directly, if so execute that implementation
	if( [self subjectSupportsCommand] ) return [self executeCommandOnSubject];

	// the subject didn't respond to the command, so do our default implementation
	NSDictionary *args = [self evaluatedArguments];
	id target = [self subjectParameter];
	id message = [self evaluatedDirectParameter];
	id name = [args objectForKey:@"name"];
	id attributes = [args objectForKey:@"attributes"];

	if( [message isKindOfClass:[JVDirectChatPanel class]] ) {
		// this is from an old compiled script, flip the parameters
		target = message;
		message = [args objectForKey:@"message"];
	}

	if( ! target || ( target && [target isKindOfClass:[NSArray class]] && ! [(NSArray *)target count] ) )
		return nil; // silently fail like normal tell blocks do when the target is nil or an empty list

	if( ! [target isKindOfClass:[JVDirectChatPanel class]] && ! [target isKindOfClass:[NSArray class]] ) {
		[self setScriptErrorNumber:-1703]; // errAEWrongDataType
		[self setScriptErrorString:@"The nearest enclosing tell block target does not inherit from the direct chat panel class."];
		return nil;
	}

	if( ! message ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The event message was missing."];
		return nil;
	}

	if( ! [message isKindOfClass:[NSString class]] ) {
		message = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:message toClass:[NSString class]];
		if( ! [message isKindOfClass:[NSString class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The event message was not a string value and coercion failed."];
			return nil;
		}
	}

	if( ! [(NSString *)message length] ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The event message can't be blank."];
		return nil;
	}

	if( ! name ) name = @"unknown";
	if( ! [name isKindOfClass:[NSString class]] ) {
		name = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:name toClass:[NSString class]];
		if( ! [name isKindOfClass:[NSString class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The event name was not a string value and coercion failed."];
			return nil;
		}
	}

	if( ! [(NSString *)name length] ) {
		[self setScriptErrorNumber:-1715]; // errAEParamMissed
		[self setScriptErrorString:@"The event name can't be blank."];
		return nil;
	}

	if( attributes && ! [attributes isKindOfClass:[NSDictionary class]] ) {
		attributes = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:attributes toClass:[NSDictionary class]];
		if( ! [attributes isKindOfClass:[NSDictionary class]] ) {
			[self setScriptErrorNumber:-1700]; // errAECoercionFail
			[self setScriptErrorString:@"The event attributes was not a record value and coercion failed."];
			return nil;
		}
	}

	NSArray *targets = nil;
	if( [target isKindOfClass:[NSArray class]] ) targets = target;
	else targets = [NSArray arrayWithObject:target];

	NSEnumerator *enumerator = [targets objectEnumerator];
	while( ( target = [enumerator nextObject] ) ) {
		if( ! [target isKindOfClass:[JVDirectChatPanel class]] ) continue;
		[target addEventMessageToDisplay:message withName:name andAttributes:attributes];
	}

	return nil;
}
@end