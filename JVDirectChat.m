#import <AddressBook/AddressBook.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatScriptPlugin.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSDataAdditions.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <ChatCore/NSColorAdditions.h>

#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import "JVChatController.h"
#import "KAIgnoreRule.h"
#import "JVTabbedChatWindowController.h"
#import "JVStyle.h"
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "JVChatMessage.h"
#import "JVNotificationController.h"
#import "MVConnectionsController.h"
#import "JVDirectChat.h"
#import "MVBuddyListController.h"
#import "MVFileTransferController.h"
#import "JVBuddy.h"
#import "MVTextView.h"
#import "MVMenuButton.h"
#import "JVMarkedScroller.h"
#import "JVSplitView.h"
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

@interface JVDirectChat (JVDirectChatPrivate) <ABImageClient>
- (void) addEventMessageToLogAndDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes entityEncodeAttributes:(BOOL) encode;
- (void) addMessageToLogAndDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier;
- (void) addMessageToLogAndDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier asNotice:(BOOL) notice;
- (void) scrollToBottom;
- (void) appendMessage:(NSString *) html subsequent:(BOOL) subsequent;
- (void) processQueue;
- (void) displayQueue;
- (void) writeToLog:(void *) root withDoc:(void *) doc initializing:(BOOL) init continuation:(BOOL) cont;
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
- (void) _breakLongLinesInString:(NSMutableAttributedString *) message;
- (void) _hyperlinkRoomNames:(NSMutableAttributedString *) message;
- (void) _performEmoticonSubstitutionOnString:(NSMutableAttributedString *) string;
- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message;
- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont;
- (void) _saveSelfIcon;
- (void) _saveBuddyIcon:(JVBuddy *) buddy;
- (void) _setCurrentMessage:(JVMutableChatMessage *) message;
@end

#pragma mark -

@interface JVChatTranscript (JVChatTranscriptPrivate)
- (NSString *) _fullDisplayHTMLWithBody:(NSString *) html;
- (JVMarkedScroller *) _verticalMarkedScroller;
- (void) _changeChatEmoticonsMenuSelection;
- (void) _switchingStyleEnded:(in NSString *) html;
- (unsigned long) visibleMessageCount;
- (long) locationOfMessage:(JVChatMessage *) message;
- (long) locationOfElementByIndex:(unsigned long) index;
@end

#pragma mark -

@implementation JVDirectChat
- (id) init {
	if( ( self = [super init] ) ) {
		send = nil;
		_target = nil;
		_firstMessage = YES;
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		_requiresFullMessage = NO;
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

		_messageQueue = [[NSMutableArray array] retain];
	}
	return self;
}

- (id) initWithTarget:(id) target {
	if( ( self = [self init] ) ) {
		_target = [target retain];

		NSString *source = [NSString stringWithFormat:@"%@/%@", [[[self connection] url] absoluteString], [self target]];
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "source", [source UTF8String] );

		if( ( [self isMemberOfClass:[JVDirectChat class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogPrivateChats"] ) ||
			( [self isMemberOfClass:[JVChatRoom class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogChatRooms"] ) ) {
			// Set up log directories
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
			if( ! [fileManager fileExistsAtPath:logs] ) {
				[fileManager createFileAtPath:logs contents:[NSData data] attributes:nil];
				[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, [NSNumber numberWithUnsignedLong:'coTr'], NSFileHFSTypeCode, [NSNumber numberWithUnsignedLong:'coRC'], NSFileHFSCreatorCode, nil] atPath:logs];

				_logFile = [[NSFileHandle fileHandleForUpdatingAtPath:logs] retain];

				// Write the <log> element to the logfile
				[self writeToLog:xmlDocGetRootElement( _xmlLog ) withDoc:_xmlLog initializing:YES continuation:NO];
			} else { // Use existing file.
				_logFile = [[NSFileHandle fileHandleForUpdatingAtPath:logs] retain];

				xmlNodePtr sessionNode = xmlNewNode( NULL, "session" );
				xmlSetProp( sessionNode, "started", [[[NSDate date] description] UTF8String] );
				xmlAddChild( xmlDocGetRootElement( _xmlLog ), sessionNode );

				[self writeToLog:sessionNode withDoc:_xmlLog initializing:NO continuation:NO];
			}

			[_filePath autorelease];
			_filePath = [logs retain];

			if( ! [[NSFileManager defaultManager] fileExistsAtPath:_filePath] ) {
				[_filePath autorelease];
				_filePath = nil;
			}
		} else _logFile = nil;

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
	NSBundle *emoticon = nil;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidConnectNotification object:[self connection]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidDisconnectNotification object:[self connection]];

	[display setUIDelegate:self];
	[display setPolicyDelegate:self];
	[display setFrameLoadDelegate:self];

	if( [(NSString *)[self preferenceForKey:@"emoticon"] length] ) {
		emoticon = [NSBundle bundleWithIdentifier:[self preferenceForKey:@"emoticon"]];
		if( emoticon ) [self setChatEmoticons:emoticon performRefresh:NO];
	}

	if( [self preferenceForKey:@"style"] ) {
		style = [JVStyle styleWithIdentifier:[self preferenceForKey:@"style"]];
		variant = [self preferenceForKey:@"style variant"];
		if( style ) [self setChatStyle:style withVariant:variant];
	}

	[super awakeFromNib];

	[self changeEncoding:nil];

	if( [self isMemberOfClass:[JVDirectChat class]] ) {
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

	[self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
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
	[_messageQueue release];

	if( ! xmlLsCountNode( xmlDocGetRootElement( _xmlLog ) ) ) // Log is empty, remove the file.
		[[NSFileManager defaultManager] removeFileAtPath:_filePath handler:nil];

	// TODO: Read in the logfile and write it back out again after adding the 'ended' attribute to the log node.
	[_logFile synchronizeFile];
	[_logFile release];

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
	_messageQueue = nil;
	_logFile = nil;

	[super dealloc];
}

#pragma mark -

- (NSString *) target {
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

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSOKButton ) xmlSetProp( xmlDocGetRootElement( _xmlLog ), "ended", [[[NSDate date] description] UTF8String] );
	[(id) super savePanelDidEnd:sheet returnCode:returnCode contextInfo:contextInfo];
	if( returnCode == NSOKButton ) xmlUnsetProp( xmlDocGetRootElement( _xmlLog ), "ended" );
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

- (IBAction) changeChatStyle:(id) sender {
	JVStyle *style = [sender representedObject];
	
	[self setPreference:[style identifier] forKey:@"style"];
	[self setPreference:nil forKey:@"style variant"];
	
	[super changeChatStyle:sender];
}

- (IBAction) changeChatStyleVariant:(id) sender {
	JVStyle *style = [[sender representedObject] objectForKey:@"style"];
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
	
	[self setPreference:[style identifier] forKey:@"style"];
	[self setPreference:variant forKey:@"style variant"];
	
	[super changeChatStyleVariant:sender];
}

- (IBAction) changeChatEmoticons:(id) sender {
	if( [sender representedObject] && ! [(NSString *)[sender representedObject] length] ) {
		[self setPreference:@"" forKey:@"emoticon"];
		[self setChatEmoticons:nil];
		return;
	}

	NSBundle *emoticon = [NSBundle bundleWithIdentifier:[sender representedObject]];

	if( emoticon ) {
		[self setPreference:[emoticon bundleIdentifier] forKey:@"emoticon"];
		[self setChatEmoticons:emoticon];
	} else {
		emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle identifier]]]];
		[self setPreference:nil forKey:@"emoticon"];
		[self setChatEmoticons:emoticon];
	}
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
	[self addEventMessageToDisplay:message withName:name andAttributes:attributes entityEncodeAttributes:YES];
}

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes entityEncodeAttributes:(BOOL) encode {
	if( ! _nibLoaded ) [self view];
	if( [_logLock tryLock] ) {
		[self displayQueue];
		[self addEventMessageToLogAndDisplay:message withName:name andAttributes:attributes entityEncodeAttributes:encode];
		[_logLock unlock];
	} else { // Queue the message
		NSDictionary *queueEntry = [NSDictionary dictionaryWithObjectsAndKeys:@"event", @"type", message, @"message", name, @"name", attributes, @"attributes", [NSNumber numberWithBool:encode], @"encode", nil];
		[_messageQueue addObject:queueEntry];
		if( [_messageQueue count] == 1 ) // We just added to an empty queue, so we need to attempt to process it soon
			[self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
	}
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier {
	[self addMessageToDisplay:message fromUser:user asAction:action withIdentifier:identifier asNotice:NO];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier asNotice:(BOOL) notice {
	if( ! _nibLoaded ) [self view];
	if( [_logLock tryLock] ) {
		[self displayQueue];
		[self addMessageToLogAndDisplay:message fromUser:user asAction:action withIdentifier:identifier asNotice:notice];
		[_logLock unlock];
	} else { // Queue the message
		NSDictionary *queueEntry = [NSDictionary dictionaryWithObjectsAndKeys:@"message", @"type", message, @"message", user, @"user", identifier, @"identifier", [NSNumber numberWithBool:action], @"action", [NSNumber numberWithBool:notice], @"notice", nil];
		[_messageQueue addObject:queueEntry];
		if( [_messageQueue count] == 1 ) // We just added to an empty queue, so we need to attempt to process it soon
			[self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
	}
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

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processIncomingMessage: )];
	[invocation setArgument:&message atIndex:2];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (void) echoSentMessageToDisplay:(JVMutableChatMessage *) message {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[self encoding]], @"StringEncoding", nil];
	NSData *msgData = [[message body] IRCFormatWithOptions:options]; // we could save this back to the message object before sending
	[self addMessageToDisplay:msgData fromUser:[message sender] asAction:[message isAction] withIdentifier:[message messageIdentifier]];
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
					JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:subMsg sender:[[self connection] localUser] andTranscript:self];
					[cmessage setAction:action];

					[self echoSentMessageToDisplay:cmessage];
					[self sendMessage:cmessage];

					[cmessage release];
				}
			}
		}

		if( range.length ) range.location++;
		[[send textStorage] deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}

	[send reset:nil];
	[self textDidChange:nil];
	[self scrollToBottom];
}

- (void) sendMessage:(JVMutableChatMessage *) message {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processOutgoingMessage: )];
	[invocation setArgument:&message atIndex:2];

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
	_requiresFullMessage = YES;
	[[display mainFrame] loadHTMLString:[self _fullDisplayHTMLWithBody:@""] baseURL:nil];
	[[self _verticalMarkedScroller] removeAllMarks];
	[[self _verticalMarkedScroller] removeAllShadedAreas];
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
	if( [self isMemberOfClass:[JVDirectChat class]] ) [ret addObjectsFromArray:words];
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

	JVMarkedScroller *scroller = [self _verticalMarkedScroller];
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
	JVMarkedScroller *scroller = [self _verticalMarkedScroller];
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
	if( [self isMemberOfClass:[JVDirectChat class]] ) [list addObject:JVToolbarSendFileItemIdentifier];
	[list addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
	if( [self isMemberOfClass:[JVDirectChat class]] ) [list addObject:JVToolbarSendFileItemIdentifier];
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

@implementation JVDirectChat (JVDirectChatPrivate)
- (void) addEventMessageToLogAndDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes entityEncodeAttributes:(BOOL) encode {
	// DO *NOT* call this method without first acquiring _logLock!
	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] );

	xmlDocPtr doc = xmlNewDoc( "1.0" );
	xmlNodePtr root = xmlNewNode( NULL, "event" );
	xmlSetProp( root, "id", [[NSString locallyUniqueString] UTF8String] );
	xmlSetProp( root, "name", [name UTF8String] );
	xmlSetProp( root, "occurred", [[[NSDate date] description] UTF8String] );
	xmlDocSetRootElement( doc, root );

	xmlDocPtr msgDoc = NULL;
	xmlNodePtr child = NULL;
	const char *msgStr = NULL;

	if( message ) {
		message = [message stringByStrippingIllegalXMLCharacters];
		msgStr = [[NSString stringWithFormat:@"<message>%@</message>", message] UTF8String];
		if( msgStr ) {
			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}
	}

	NSEnumerator *kenumerator = [attributes keyEnumerator];
	NSEnumerator *enumerator = [attributes objectEnumerator];
	NSString *key = nil;
	id value = nil;

	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		msgStr = NULL;

		if( [value respondsToSelector:@selector( xmlDescriptionWithTagName: )] ) {
			msgStr = [(NSString *)[value performSelector:@selector( xmlDescriptionWithTagName: ) withObject:key] UTF8String];
		} else if( [value isKindOfClass:[NSAttributedString class]] ) {
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
			value = [value HTMLFormatWithOptions:options];
			value = [value stringByStrippingIllegalXMLCharacters];
			if( [(NSString *)value length] )
				msgStr = [[NSString stringWithFormat:@"<%@>%@</%@>", key, value, key] UTF8String];
		} else if( [value isKindOfClass:[NSString class]] ) {
			if( encode ) value = [value stringByEncodingXMLSpecialCharactersAsEntities];
			value = [value stringByStrippingIllegalXMLCharacters];
			if( [(NSString *)value length] )
				msgStr = [[NSString stringWithFormat:@"<%@>%@</%@>", key, value, key] UTF8String];
		} else if( [value isKindOfClass:[NSData class]] ) {
			value = [value base64EncodingWithLineLength:0];
			if( [(NSString *)value length] )
				msgStr = [[NSString stringWithFormat:@"<%@ encoding=\"base64\">%@</%@>", key, value, key] UTF8String];
		}

		if( ! msgStr ) msgStr = [[NSString stringWithFormat:@"<%@ />", key] UTF8String];			

		msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
		child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
		xmlAddChild( root, child );
		xmlFreeDoc( msgDoc );
	}

	xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( root, _xmlLog, 1 ) );
	[self writeToLog:root withDoc:doc initializing:NO continuation:NO];

	NSString *messageString = nil;

	@try {
		messageString = [_chatStyle transformXMLDocument:doc withParameters:_styleParams];
	} @catch ( NSException *exception ) {
		messageString = nil;
		[self performSelectorOnMainThread:@selector( _styleError: ) withObject:exception waitUntilDone:YES];
	}

	if( [messageString length] ) [self appendMessage:messageString subsequent:NO];

	xmlFreeDoc( doc );

	_requiresFullMessage = YES;
}

- (void) addMessageToLogAndDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier {
	[self addMessageToLogAndDisplay:message fromUser:user asAction:action withIdentifier:identifier asNotice:NO];
}

- (void) addMessageToLogAndDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier asNotice:(BOOL) notice {
	// DO *NOT* call this method without first acquiring _logLock!
	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	NSFont *baseFont = [[NSFontManager sharedFontManager] fontWithFamily:[[display preferences] standardFontFamily] traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:[[display preferences] defaultFontSize]];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:_encoding], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSTextStorage *messageString = [NSTextStorage attributedStringWithIRCFormat:message options:options];

	if( ! messageString ) {
		[options setObject:[NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]] forKey:@"StringEncoding"];
		messageString = [NSMutableAttributedString attributedStringWithIRCFormat:message options:options];

		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:baseFont, NSFontAttributeName, nil];
		NSMutableAttributedString *error = [[[NSMutableAttributedString alloc] initWithString:[@" " stringByAppendingString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" )] attributes:attributes] autorelease];
		[error addAttribute:@"CSSClasses" value:[NSSet setWithObjects:@"error", @"encoding", nil] range:NSMakeRange( 1, ( [error length] - 1 ) )];
		[messageString appendAttributedString:error];
	}

	if( ! [messageString length] ) {
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:baseFont, NSFontAttributeName, [NSSet setWithObjects:@"error", @"encoding", nil], @"CSSClasses", nil];
		messageString = [[[NSTextStorage alloc] initWithString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" ) attributes:attributes] autorelease];
	}

	JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:messageString sender:user andTranscript:self];
	[cmessage setMessageIdentifier:identifier];
	[cmessage setAction:action];

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

	[self _performEmoticonSubstitutionOnString:messageString];

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
				NSMutableSet *classes = [messageString attribute:@"CSSClasses" atIndex:foundRange.location effectiveRange:NULL];
				if( ! classes ) classes = [NSMutableSet setWithObject:@"highlight"];
				else [classes addObject:@"highlight"];
				[messageString addAttribute:@"CSSClasses" value:classes range:foundRange];
				[cmessage setHighlighted:YES];
			}
		}
	}

	[self processIncomingMessage:cmessage];

	if( [[cmessage sender] isKindOfClass:[JVChatRoomMember class]] )
		user = [(JVChatRoomMember *)[cmessage sender] user]; // if this is a chat room, JVChatRoom makes the sender a member object
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
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"One of your highlight words was mentioned in %@.", "mentioned bubble text" ), [self title]] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activityNewImportant"] forKey:@"image"];
		[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatMentioned"] forKey:@"coalesceKey"];
		[context setObject:self forKey:@"target"];
		[context setObject:NSStringFromSelector( @selector( activate: ) ) forKey:@"action"];
		[[JVNotificationController defaultManager] performNotification:@"JVChatMentioned" withContextInfo:context];
	}

	if( [cmessage ignoreStatus] != JVNotIgnored ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:( ( [cmessage ignoreStatus] == JVUserIgnored ) ? NSLocalizedString( @"User Ignored", "user ignored bubble title" ) : NSLocalizedString( @"Message Ignored", "message ignored bubble title" ) ) forKey:@"title"];
		if( [self isMemberOfClass:[JVChatRoom class]] ) [context setObject:[NSString stringWithFormat:@"%@'s message was ignored in %@.", user, [self title]] forKey:@"description"];
		else [context setObject:[NSString stringWithFormat:@"%@'s message was ignored.", user] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activity"] forKey:@"image"];
		[[JVNotificationController defaultManager] performNotification:( ( [cmessage ignoreStatus] == JVUserIgnored ) ? @"JVUserIgnored" : @"JVMessageIgnored" ) withContextInfo:context];
	}

	xmlXPathContextPtr ctx = xmlXPathNewContext( _xmlLog );
	if( ! ctx ) return;

	xmlXPathObjectPtr result = xmlXPathEval( [[NSString stringWithFormat:@"/log/child::*[name() = 'envelope' and position() = last() and (sender = '%@' or sender/@nickname = '%@')]", user, user] UTF8String], ctx );
	xmlDocPtr doc = xmlNewDoc( "1.0" ), msgDoc = NULL;
	xmlNodePtr root = NULL, child = NULL, parent = NULL;

	if( ! _requiresFullMessage && result && ! xmlXPathNodeSetIsEmpty( result -> nodesetval ) ) {
		parent = xmlXPathNodeSetItem( result -> nodesetval, 0 );
		root = xmlDocCopyNode( parent, doc, 1 );
		xmlDocSetRootElement( doc, root );
	} else {
		root = xmlNewNode( NULL, "envelope" );
		xmlDocSetRootElement( doc, root );

		/* if( [user isEqualToString:[self target]] && _buddy ) {
			NSString *theirName = user;
			if( [_buddy preferredNameWillReturn] != JVBuddyActiveNickname ) theirName = [_buddy preferredName];
			child = xmlNewTextChild( root, NULL, "sender", [theirName UTF8String] );
			if( ! [theirName isEqualToString:user] )
				xmlSetProp( child, "nickname", [user UTF8String] );
			xmlSetProp( child, "card", [[_buddy uniqueIdentifier] UTF8String] );
			[self _saveBuddyIcon:_buddy];
		} else if( [user isLocalUser]] ) {
			NSString *selfName = user;
			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"] == (int)JVBuddyFullName )
				selfName = [self _selfCompositeName];
			else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"] == (int)JVBuddyGivenNickname )
				selfName = [self _selfStoredNickname];
			child = xmlNewTextChild( root, NULL, "sender", [selfName UTF8String] );
			if( ! [selfName isEqualToString:user] )
				xmlSetProp( child, "nickname", [user UTF8String] );
			xmlSetProp( child, "self", "yes" );
			xmlSetProp( child, "card", [[[[ABAddressBook sharedAddressBook] me] uniqueId] UTF8String] );
			[self _saveSelfIcon];
		} else {
			NSString *theirName = user;
			JVBuddy *buddy = [[MVBuddyListController sharedBuddyList] buddyForNickname:user onServer:[[self connection] server]];
			if( buddy && [buddy preferredNameWillReturn] != JVBuddyActiveNickname )
				theirName = [buddy preferredName];
			child = xmlNewTextChild( root, NULL, "sender", [theirName UTF8String] );
			if( ! [theirName isEqualToString:user] )
				xmlSetProp( child, "nickname", [user UTF8String] );		
			if( buddy ) {
				xmlSetProp( child, "card", [[buddy uniqueIdentifier] UTF8String] );
				[self _saveBuddyIcon:buddy];
			}
		} */

		const char *sendDesc = [(NSString *)[[cmessage sender] performSelector:@selector( xmlDescriptionWithTagName: ) withObject:@"sender"] UTF8String];

		if( sendDesc ) {
			xmlDocPtr tempDoc = xmlParseMemory( sendDesc, strlen( sendDesc ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( tempDoc ), doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( tempDoc );
		}
	}

	xmlXPathFreeObject( result );
	xmlXPathFreeContext( ctx );

	[[messageString mutableString] stripIllegalXMLCharacters];

	options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
	NSString *htmlMessage = [messageString HTMLFormatWithOptions:options];
	const char *msgStr = [[NSString stringWithFormat:@"<message>%@</message>", htmlMessage] UTF8String];
	msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );

	child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
	xmlSetProp( child, "id", [[cmessage messageIdentifier] UTF8String] );
	xmlSetProp( child, "received", [[[cmessage date] description] UTF8String] );
	if( [cmessage isAction] ) xmlSetProp( child, "action", "yes" );
	if( [cmessage isHighlighted] ) xmlSetProp( child, "highlight", "yes" );
	if( [cmessage ignoreStatus] == JVMessageIgnored ) xmlSetProp( child, "ignored", "yes" );
	else if( [cmessage ignoreStatus] == JVUserIgnored ) xmlSetProp( root, "ignored", "yes" );
	if( notice ) xmlSetProp( child, "notice", "yes" );
	xmlAddChild( root, child );

	[self writeToLog:root withDoc:doc initializing:NO continuation:( parent ? YES : NO )];

	xmlFreeDoc( msgDoc );

	if( parent ) xmlAddChild( parent, xmlDocCopyNode( child, _xmlLog, 1 ) );
	else xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( root, _xmlLog, 1 ) );

	NSString *transformedMessage = nil;
	NSMutableDictionary *params = _styleParams;
	if( parent ) {
		// compatibility parameter for pre-2C9 styles, styles can test for consecutive messages alone now
		// we now for a <?message type="subsequent"?> processing instruction to determ the proper handeling
		params = [[_styleParams mutableCopy] autorelease];
		[params setObject:@"'yes'" forKey:@"subsequent"];
	}

	@try {
		transformedMessage = [_chatStyle transformXMLDocument:doc withParameters:params];
	} @catch ( NSException *exception ) {
		transformedMessage = nil;
		[self performSelectorOnMainThread:@selector( _styleError: ) withObject:exception waitUntilDone:YES];
	}

	if( [transformedMessage length] ) {
		BOOL subsequent = ( [transformedMessage rangeOfString:@"<?message type=\"subsequent\"?>"].location != NSNotFound );
		[self appendMessage:transformedMessage subsequent:subsequent];

		if( [cmessage isHighlighted] ) {
			long loc = [self locationOfMessage:cmessage];
			if( loc ) [[self _verticalMarkedScroller] addMarkAt:loc];
		}

		_firstMessage = NO; // not the first message anymore
		_requiresFullMessage = NO; // next message will not require a new envelope if it is consecutive
	} else if( [cmessage ignoreStatus] == JVNotIgnored ) {
		// the style decided to excluded this message, decrease the new message counts
		if( [cmessage isHighlighted] ) _newHighlightMessageCount--;
		_newMessageCount--;		
	}

	xmlFreeDoc( doc );

	[self _setCurrentMessage:nil];
	[cmessage release];

	[_windowController reloadListItem:self andChildren:NO];
}

- (void) scrollToBottom {
	NSScrollView *scrollView = [[[[display mainFrame] frameView] documentView] enclosingScrollView];
	[scrollView scrollClipView:[scrollView contentView] toPoint:[[scrollView contentView] constrainScrollPoint:NSMakePoint( 0, [[scrollView documentView] bounds].size.height )]];
	[scrollView reflectScrolledClipView:[scrollView contentView]];
}

- (void) appendMessage:(NSString *) html subsequent:(BOOL) subsequent {
	unsigned int messageCount = [self visibleMessageCount];
	unsigned int scrollbackLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatScrollbackLimit"];

	if( ! subsequent && ( messageCount + 1 ) > scrollbackLimit ) {
		long loc = [self locationOfElementByIndex:( ( messageCount + 1 ) - scrollbackLimit )];
		if( loc > 0 ) [[self _verticalMarkedScroller] shiftMarksAndShadedAreasBy:( loc * -1 )];
	}

#ifdef WebKitVersion146
	if( [[display mainFrame] respondsToSelector:@selector( DOMDocument )] ) {
		DOMHTMLElement *element = (DOMHTMLElement *)[[[display mainFrame] DOMDocument] createElement:@"span"];
		DOMHTMLElement *replaceElement = (DOMHTMLElement *)[[[display mainFrame] DOMDocument] getElementById:@"consecutiveInsert"];
		if( ! replaceElement ) subsequent = NO;

		NSMutableString *transformedMessage = [html mutableCopy];
		[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];

		// parses the message so we can get the DOM tree
		[element setInnerHTML:transformedMessage];

		[transformedMessage release];
		transformedMessage = nil;

		// check if we are near the bottom of the chat area, and if we should scroll down later
		NSNumber *scrollNeeded = [[[display mainFrame] DOMDocument] evaluateWebScript:@"( document.body.scrollTop >= ( document.body.offsetHeight - ( window.innerHeight * 1.1 ) ) )"];
		DOMHTMLElement *body = [(DOMHTMLDocument *)[[display mainFrame] DOMDocument] body];

		unsigned int i = 0;
		if( ! subsequent ) { // append message normally
			[[replaceElement parentNode] removeChild:replaceElement];
			while( [[element children] length] ) // append all children
				[body appendChild:[element firstChild]];
		} else if( [[element children] length] >= 1 ) { // append as a subsequent message
			DOMNode *parent = [replaceElement parentNode];
			DOMNode *nextSib = [replaceElement nextSibling];
			[parent replaceChild:[element firstChild] :replaceElement]; // replaces the consecutiveInsert node
			while( [[element children] length] ) { // append all remaining children (in reverse order)
				if( nextSib ) [parent insertBefore:[element firstChild] :nextSib];
				else [parent appendChild:[element firstChild]];
			}
		}

		// enforce the scrollback limit
		if( scrollbackLimit > 0 && [[body children] length] > scrollbackLimit )
			for( i = 0; [[body children] length] > scrollbackLimit && i < ( [[body children] length] - scrollbackLimit ); i++ )
				[body removeChild:[[body children] item:0]];		

		// scroll down if we need to
		if( [scrollNeeded boolValue] ) [self scrollToBottom];
	} else
#endif	
	{ // old JavaScript method
		NSMutableString *transformedMessage = [html mutableCopy];
		[transformedMessage escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[transformedMessage replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"  " withString:@"&nbsp; " options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		[transformedMessage replaceOccurrencesOfString:@"<?message type=\"subsequent\"?>" withString:@"" options:NSLiteralSearch range:NSMakeRange( 0, [transformedMessage length] )];
		if( subsequent ) [display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollBackLimit = %d; appendConsecutiveMessage( \"%@\" );", scrollbackLimit, transformedMessage]];
		else [display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"scrollBackLimit = %d; appendMessage( \"%@\" );", scrollbackLimit, transformedMessage]];
		[transformedMessage release];
	}
}

- (void) processQueue {
	if( [_logLock tryLock] ) {
		[self displayQueue];
		[_logLock unlock];
	} else [self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
}

- (void) displayQueue {
	// DO *NOT* call this without first acquiring _logLock
	while( [_messageQueue count] > 0 ) {
		NSDictionary *msg = [[[_messageQueue objectAtIndex:0] retain] autorelease];
		[_messageQueue removeObjectAtIndex:0];
		if( [[msg objectForKey:@"type"] isEqualToString:@"message"] ) {
			[self addMessageToLogAndDisplay:[msg objectForKey:@"message"] fromUser:[msg objectForKey:@"user"] asAction:[[msg objectForKey:@"action"] boolValue] withIdentifier:[msg objectForKey:@"identifier"] asNotice:[[msg objectForKey:@"notice"] boolValue]];
		} else if( [[msg objectForKey:@"type"] isEqualToString:@"event"] ) {
			if( [[msg objectForKey:@"message"] isEqual:[NSNull null]] ) {
				[self addEventMessageToLogAndDisplay:nil withName:[msg objectForKey:@"name"] andAttributes:[msg objectForKey:@"attributes"] entityEncodeAttributes:[[msg objectForKey:@"encode"] boolValue]];
			} else {
				[self addEventMessageToLogAndDisplay:[msg objectForKey:@"message"] withName:[msg objectForKey:@"name"] andAttributes:[msg objectForKey:@"attributes"] entityEncodeAttributes:[[msg objectForKey:@"encode"] boolValue]];
			}
		}
	}
}

- (void) writeToLog:(void *) root withDoc:(void *) doc initializing:(BOOL) init continuation:(BOOL) cont {
	if( ! _logFile ) return;

	// Append a node to the logfile for this chat
	xmlBufferPtr buf = xmlBufferCreate();
	xmlNodeDump( buf, doc, root, 0, (int) [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] );

	// To keep the XML valid at all times, we need to preserve a </log> close tag at the end of
	// the file at all times. So, we seek to the end of the file minus 6 characters.
	[_logFile seekToEndOfFile];
	if( cont ) [_logFile seekToFileOffset:_previousLogOffset];
	else if( ! init ) {
		[_logFile seekToFileOffset:[_logFile offsetInFile] - 6];
		_previousLogOffset = [_logFile offsetInFile];
	}

	_previousLogOffset = [_logFile offsetInFile];
	[_logFile writeData:[NSData dataWithBytesNoCopy:buf -> content length:buf -> use freeWhenDone:NO]];
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] )
		[_logFile writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
	if( ! init ) [_logFile writeData:[@"</log>" dataUsingEncoding:NSUTF8StringEncoding]];
	xmlBufferFree( buf );

	// If we are initializing, we wrote a singleton <log/> tag and we need to back up over the />
	// and write ></log> instead.
	if( init ) {
		[_logFile seekToEndOfFile];
		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatFormatXMLLogs"] )
			[_logFile seekToFileOffset:[_logFile offsetInFile] - 3];
		else [_logFile seekToFileOffset:[_logFile offsetInFile] - 2];
		_previousLogOffset = [_logFile offsetInFile];
		[_logFile writeData:[@">\n</log>" dataUsingEncoding:NSUTF8StringEncoding]];
	}
}

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

- (void) _performEmoticonSubstitutionOnString:(NSMutableAttributedString *) string {
	if( ! string || ! [string string] ) return;

	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	NSEnumerator *keyEnumerator = [_emoticonMappings keyEnumerator];
	NSEnumerator *objEnumerator = [_emoticonMappings objectEnumerator];
	NSEnumerator *srcEnumerator = nil;
	NSString *str = nil;
	NSString *key = nil;
	NSArray *obj = nil;

	while( ( key = [keyEnumerator nextObject] ) && ( obj = [objEnumerator nextObject] ) ) {
		srcEnumerator = [obj objectEnumerator];
		while( ( str = [srcEnumerator nextObject] ) ) {
			NSMutableString *search = [str mutableCopy];
			[search escapeCharactersInSet:escapeSet];

			AGRegex *regex = [[AGRegex alloc] initWithPattern:[NSString stringWithFormat:@"(?<=\\s|^)%@(?=\\s|$)", search]];
			NSArray *matches = [regex findAllInString:[string string]];
			NSEnumerator *enumerator = [matches objectEnumerator];
			AGRegexMatch *match = nil;

			while( ( match = [enumerator nextObject] ) ) {
				NSRange foundRange = [match range];
				NSString *startHTML = [string attribute:@"XHTMLStart" atIndex:foundRange.location effectiveRange:NULL];
				NSString *endHTML = [string attribute:@"XHTMLEnd" atIndex:foundRange.location effectiveRange:NULL];
				if( ! startHTML ) startHTML = @"";
				if( ! endHTML ) endHTML = @"";
				[string addAttribute:@"XHTMLStart" value:[startHTML stringByAppendingFormat:@"<span class=\"emoticon %@\"><samp>", key] range:foundRange];
				[string addAttribute:@"XHTMLEnd" value:[@"</samp></span>" stringByAppendingString:endHTML] range:foundRange];
			}

			[search release];
			[regex release];
		}
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
	NSMutableAttributedString *messageString = [NSMutableAttributedString attributedStringWithIRCFormat:message options:options];

	if( ! messageString ) {
		[options setObject:[NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]] forKey:@"StringEncoding"];
		messageString = [NSMutableAttributedString attributedStringWithIRCFormat:message options:options];
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] ) {
		[messageString makeLinkAttributesAutomatically];
		[self _hyperlinkRoomNames:messageString];
	}

	[self _performEmoticonSubstitutionOnString:messageString];

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

		[self _performEmoticonSubstitutionOnString:messageString];

		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"IgnoreFonts", [NSNumber numberWithBool:YES], @"IgnoreFontSizes", nil];
		NSString *msgString = [messageString HTMLFormatWithOptions:options];

		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You have set yourself away with \"%@\".", "self away status set message" ), msgString] withName:@"awaySet" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:messageString, @"away-message", nil]];

		unsigned long messageCount = [self visibleMessageCount];
		long loc = [self locationOfElementByIndex:( messageCount - 1 )];
		[[self _verticalMarkedScroller] startShadedAreaAt:loc];
	} else {
		[self addEventMessageToDisplay:NSLocalizedString( @"You have returned from away.", "self away status removed message" ) withName:@"awayRemoved" andAttributes:nil];

		unsigned long messageCount = [self visibleMessageCount];
		long loc = [self locationOfElementByIndex:( messageCount - 1 )];
		[[self _verticalMarkedScroller] stopShadedAreaAt:loc];
	}
}

- (void) _updateChatEmoticonsMenu {
	extern NSMutableSet *JVChatEmoticonBundles;
	NSEnumerator *enumerator = nil;
	NSMenu *menu = nil, *subMenu = nil;
	NSMenuItem *menuItem = nil;
	BOOL new = YES;

	if( ! ( menu = _emoticonMenu ) ) {
		menu = [[NSMenu alloc] initWithTitle:@""];
		_emoticonMenu = menu;
	} else {
		NSEnumerator *enumerator = [[[[menu itemArray] copy] autorelease] objectEnumerator];
		new = NO;
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

	NSArray *menuArray = [NSArray arrayWithContentsOfFile:[_chatEmoticons pathForResource:@"menu" ofType:@"plist"]];
	enumerator = [menuArray objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( ! [(NSString *)[info objectForKey:@"name"] length] ) continue;
		menuItem = [[[NSMenuItem alloc] initWithTitle:[info objectForKey:@"name"] action:@selector( _insertEmoticon: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		if( [(NSString *)[info objectForKey:@"image"] length] )
			[menuItem setImage:[[[NSImage alloc] initWithContentsOfFile:[_chatEmoticons pathForResource:[info objectForKey:@"image"] ofType:nil]] autorelease]];
		[menuItem setRepresentedObject:[info objectForKey:@"insert"]];
		[menu insertItem:menuItem atIndex:count++];
	}

	if( ! [menuArray count] ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Selectable Emoticons", "no selectable emoticons menu item title" ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setEnabled:NO];
		[menu insertItem:menuItem atIndex:count++];
	}

	if( new ) {
		NSBundle *emoticon = nil;

		[menu addItem:[NSMenuItem separatorItem]];

		subMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Preferences", "preferences menu item title" ) action:NULL keyEquivalent:@""] autorelease];
		[menuItem setSubmenu:subMenu];
		[menuItem setTag:20];
		[menu addItem:menuItem];

		emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle identifier]]]];
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Text Only", "text only emoticons menu item title" ) action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:@""];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		enumerator = [[[JVChatEmoticonBundles allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
		while( ( emoticon = [enumerator nextObject] ) ) {
			if( ! [[emoticon displayName] length] ) continue;
			menuItem = [[[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:[emoticon bundleIdentifier]];
			[subMenu addItem:menuItem];
		}

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setTag:10];
		[subMenu addItem:menuItem];
	}

	[self _changeChatEmoticonsMenuSelection];
}

- (IBAction) _insertEmoticon:(id) sender {
	if( [[send textStorage] length] )
		[send replaceCharactersInRange:NSMakeRange( [[send textStorage] length], 0 ) withString:@" "];
	[send replaceCharactersInRange:NSMakeRange( [[send textStorage] length], 0 ) withString:[NSString stringWithFormat:@"%@ ", [sender representedObject]]];
}

- (void) _switchingStyleEnded:(NSString *) html {
	[super _switchingStyleEnded:html];
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

- (BOOL) _usingSpecificStyle {
	return ( [self preferenceForKey:@"style"] ? YES : NO );
}

- (BOOL) _usingSpecificEmoticons {
	return ( [self preferenceForKey:@"emoticon"] ? YES : NO );
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
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

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

- (void) _styleError:(NSException *) exception {
	[self showAlert:NSGetCriticalAlertPanel( NSLocalizedString( @"An internal Style error occurred.", "the stylesheet parse failed" ), NSLocalizedString( @"The %@ Style has been damaged or has an internal error preventing new messages from displaying. Please contact the %@ author about this.", "the style contains and error" ), @"OK", nil, nil, [_chatStyle displayName], [_chatStyle displayName] ) withName:@"styleError"];
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

@implementation JVDirectChat (JVDirectChatScripting)
- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSString *message = [[command evaluatedArguments] objectForKey:@"message"];

	if( ! [message isKindOfClass:[NSString class]] ) {
		[NSException raise:NSInvalidArgumentException format:@"Message must be a string, not a message object"];
		return;
	}

	if( ! [message length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Message can't be blank"];
		return;
	}

	NSTextStorage *attributeMsg = [NSTextStorage attributedStringWithHTMLFragment:message baseURL:nil];
	BOOL action = [[[command evaluatedArguments] objectForKey:@"action"] boolValue];
	BOOL localEcho = ( [[command evaluatedArguments] objectForKey:@"echo"] ? [[[command evaluatedArguments] objectForKey:@"echo"] boolValue] : YES );

	JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:attributeMsg sender:[[self connection] localUser] andTranscript:self];
	[cmessage setAction:action];

	[self sendMessage:cmessage];
	if( localEcho ) [self echoSentMessageToDisplay:cmessage];

	[cmessage release];
}

- (void) addEventMessageScriptCommand:(NSScriptCommand *) command {
	NSString *message = [[command evaluatedArguments] objectForKey:@"message"];
	NSString *name = [[command evaluatedArguments] objectForKey:@"name"];
	id attributes = [[command evaluatedArguments] objectForKey:@"attributes"];

	if( ! [name length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Event name can't be blank."];
		return;
	}

	if( ! [message length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Event message can't be blank."];
		return;
	}

	[self addEventMessageToDisplay:message withName:name andAttributes:( [attributes isKindOfClass:[NSDictionary class]] ? attributes : nil ) entityEncodeAttributes:NO];
}

- (unsigned long) scriptTypedEncoding {
	switch( _encoding ) {
		default:
		case NSUTF8StringEncoding: return 'utF8';
		case NSASCIIStringEncoding: return 'ascI';
		case NSNonLossyASCIIStringEncoding: return 'nlAs';
		case NSISOLatin1StringEncoding: return 'isL1';
		case NSISOLatin2StringEncoding: return 'isL2';
		case (NSStringEncoding) 0x80000203: return 'isL3';
		case (NSStringEncoding) 0x80000204: return 'isL4';
		case (NSStringEncoding) 0x80000205: return 'isL5';
		case (NSStringEncoding) 0x8000020F: return 'isL9';
		case NSWindowsCP1250StringEncoding: return 'cp50';
		case NSWindowsCP1251StringEncoding: return 'cp51';
		case NSWindowsCP1252StringEncoding: return 'cp52';

		case NSMacOSRomanStringEncoding: return 'mcRo';
		case (NSStringEncoding) 0x8000001D: return 'mcEu';
		case (NSStringEncoding) 0x80000007: return 'mcCy';
		case (NSStringEncoding) 0x80000001: return 'mcJp';
		case (NSStringEncoding) 0x80000019: return 'mcSc';
		case (NSStringEncoding) 0x80000002: return 'mcTc';
		case (NSStringEncoding) 0x80000003: return 'mcKr';

		case (NSStringEncoding) 0x80000A02: return 'ko8R';

		case (NSStringEncoding) 0x80000421: return 'wnSc';
		case (NSStringEncoding) 0x80000423: return 'wnTc';
		case (NSStringEncoding) 0x80000422: return 'wnKr';

		case NSJapaneseEUCStringEncoding: return 'jpUC';
		case (NSStringEncoding) 0x80000A01: return 'sJiS';
		case NSShiftJISStringEncoding: return 'sJiS';

		case (NSStringEncoding) 0x80000940: return 'krUC';

		case (NSStringEncoding) 0x80000930: return 'scUC';
		case (NSStringEncoding) 0x80000931: return 'tcUC';
		case (NSStringEncoding) 0x80000632: return 'gb30';
		case (NSStringEncoding) 0x80000631: return 'gbKK';
		case (NSStringEncoding) 0x80000A03: return 'biG5';
		case (NSStringEncoding) 0x80000A06: return 'bG5H';
	}
}

- (void) setScriptTypedEncoding:(unsigned long) enc {
	NSStringEncoding encoding = NSUTF8StringEncoding;

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

	[self setPreference:[NSNumber numberWithInt:encoding] forKey:@"encoding"];
	[self changeEncoding:nil];
}
@end

#pragma mark -

@implementation MVChatScriptPlugin (MVChatScriptPluginChatSupport)
- (void) processIncomingMessage:(JVMutableChatMessage *) message {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"----", [NSNumber numberWithBool:[message isAction]], @"piM1", [message sender], @"piM2", [message transcript], @"piM3", nil];
	[self callScriptHandler:'piMX' withArguments:args forSelector:_cmd];
}

- (void) processOutgoingMessage:(JVMutableChatMessage *) message {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"----", [NSNumber numberWithBool:[message isAction]], @"poM1", [message transcript], @"poM2", nil];
	[self callScriptHandler:'poMX' withArguments:args forSelector:_cmd];
}

/*- (void) userNamed:(NSString *) nickname isNowKnownAs:(NSString *) newNickname inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:nickname, @"----", newNickname, @"uNc1", view, @"uNc2", nil];
	[self callScriptHandler:'uNcX' withArguments:args forSelector:_cmd];
}*/
@end
