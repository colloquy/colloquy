#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <AddressBook/AddressBook.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatScriptPlugin.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <ChatCore/NSColorAdditions.h>

#import <libxml/xinclude.h>
#import <libxml/debugXML.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import <AGRegex/AGRegex.h>

#import "JVChatController.h"
#import "JVChatTranscriptPrivates.h"
#import "JVNotificationController.h"
#import "MVConnectionsController.h"
#import "JVDirectChat.h"
#import "MVBuddyListController.h"
#import "JVBuddy.h"
#import "MVTextView.h"
#import "MVMenuButton.h"
#import "NSURLAdditions.h"
#import "JVMarkedScroller.h"

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
	(NSStringEncoding) -1,
	(NSStringEncoding) 0x80000940,		// EUC
	(NSStringEncoding) 0x80000003,		// Mac
	(NSStringEncoding) 0x80000422,		// Windows
	/* End */ 0 };

extern char *MVChatXHTMLToIRC( const char * const string );
extern char *MVChatIRCToXHTML( const char * const string );

static NSString *JVToolbarTextEncodingItemIdentifier = @"JVToolbarTextEncodingItem";

NSComparisonResult sortBundlesByName( id style1, id style2, void *context );

#pragma mark -

@interface JVDirectChat (JVDirectChatPrivate)
- (void) addEventMessageToLogAndDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes;
- (void) addMessageToLogAndDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action;
- (void) processQueue;
- (void) displayQueue;
- (void) writeToLog:(void *) root withDoc:(void *) doc initializing:(BOOL) init continuation:(BOOL) cont;
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
- (void) _makeHyperlinksInString:(NSMutableString *) string;
- (void) _breakLongLinesInString:(NSMutableString *) string;
- (void) _performEmoticonSubstitutionOnString:(NSMutableString *) string;
- (char *) _classificationForNickname:(NSString *) nickname;
- (void) _saveSelfIcon;
- (void) _saveBuddyIcon:(JVBuddy *) buddy;
@end

#pragma mark -

@implementation JVDirectChat
- (id) init {
	if( ( self = [super init] ) ) {
		send = nil;
		_messageId = 0;
		_target = nil;
		_buddy = nil;
		_connection = nil;
		_firstMessage = YES;
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		_requiresFullMessage = NO;
		_cantSendMessages = NO;
		_isActive = NO;
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

- (id) initWithTarget:(NSString *) target forConnection:(MVChatConnection *) connection {
	if( ( self = [self init] ) ) {
		NSString *source = nil;
		_target = [target copy];
		_connection = [connection retain];
		_buddy = [[[MVBuddyListController sharedBuddyList] buddyForNickname:_target onServer:[_connection server]] retain];
		source = [NSString stringWithFormat:@"%@/%@", [[[self connection] url] absoluteString], _target];
		xmlSetProp( xmlDocGetRootElement( _xmlLog ), "source", [source UTF8String] );

		// Set up log directories
		NSString *logs = [[NSString stringWithFormat:@"~/Documents/%@ Transcripts", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];
		logs = [logs stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%@)", _target, [_connection server]]];
		if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs attributes:nil];
		logs = [logs stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.colloquyTranscript", [[NSDate date] description]]];

		[fileManager createFileAtPath:logs contents:[NSData data] attributes:nil];
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, [NSNumber numberWithUnsignedLong:'coTr'], NSFileHFSTypeCode, [NSNumber numberWithUnsignedLong:'coRC'], NSFileHFSCreatorCode, nil] atPath:logs];

		_logFile = [[NSFileHandle fileHandleForUpdatingAtPath:logs] retain];

		// Write the <log> element to the logfile
		[self writeToLog:xmlDocGetRootElement( _xmlLog ) withDoc:_xmlLog initializing:YES continuation:NO];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:connection];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didDisconnect: ) name:MVChatConnectionDidDisconnectNotification object:connection];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _awayStatusChanged: ) name:MVChatConnectionSelfAwayStatusNotification object:connection];

		_settings = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:[[self identifier] stringByAppendingString:@" Settings"]] mutableCopy];
		if( ! _settings ) _settings = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}

- (void) awakeFromNib {
	NSBundle *style = nil;
	NSString *variant = nil;
	NSBundle *emoticon = nil;

	if( [self preferenceForKey:@"style"] ) {
		style = [NSBundle bundleWithIdentifier:[self preferenceForKey:@"style"]];
		variant = [self preferenceForKey:@"style variant"];
		if( ! style ) {
			[self setPreference:nil forKey:@"style"];
			[self setPreference:nil forKey:@"style variant"];
		}
	}

	if( [self preferenceForKey:@"emoticon"] && [(NSString *)[self preferenceForKey:@"emoticon"] length] ) {
		emoticon = [NSBundle bundleWithIdentifier:[self preferenceForKey:@"emoticon"]];
		if( ! emoticon ) [self setPreference:nil forKey:@"emoticon"];
	}

	if( style ) [self setChatStyle:style withVariant:variant];
	[self setChatEmoticons:emoticon];

	[self changeEncoding:nil];

	[super awakeFromNib];

	if( [self isMemberOfClass:[JVDirectChat class]] ) {
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], _target]];

		[_filePath autorelease];
		_filePath = [[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Recent Acquaintances/%@ (%@).inetloc", _target, [[self connection] server]] stringByExpandingTildeInPath] retain];

		[url writeToInternetLocationFile:_filePath];
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:_filePath];

		if( ! [[NSFileManager defaultManager] fileExistsAtPath:_filePath] ) {
			[_filePath autorelease];
			_filePath = nil;
		}
	}

	[send setHorizontallyResizable:YES];
	[send setVerticallyResizable:YES];
	[send setAutoresizingMask:NSViewWidthSizable];
	[send setSelectable:YES];
	[send setEditable:YES];
	[send setRichText:YES];
	[send setImportsGraphics:NO];
	[send setUsesFontPanel:YES];
	[send setUsesRuler:NO];
	[send setDelegate:self];
	[send setContinuousSpellCheckingEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatSpellChecking"]];
	[send reset:nil];

	[self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
}

- (void) dealloc {
	extern NSArray *JVAutoActionVerbs;
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_target release];
	[_buddy release];
	[_connection release];
	[_sendHistory release];
	[_waitingAlertNames release];
	[_settings release];
	[_encodingMenu release];
	[_spillEncodingMenu release];
	[_messageQueue release];
	// TODO: Read in the logfile and write it back out again after adding the 'ended' attribute to the log node.
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
	_buddy = nil;
	_sendHistory = nil;
	_connection = nil;
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

- (MVChatConnection *) connection {
	return [[_connection retain] autorelease];
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
	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [_buddy preferredName];
	return [[_target retain] autorelease];
}

- (NSString *) windowTitle {
	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [NSString stringWithFormat:@"%@ (%@)", [_buddy preferredName], [[self connection] server]];
	return [NSString stringWithFormat:@"%@ (%@)", _target, [[self connection] server]];
}

- (NSString *) information {
	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname && ! [_target isEqualToString:[_buddy preferredName]] )
		return [NSString stringWithFormat:@"%@ (%@)", _target, [[self connection] server]];
	return [[self connection] server];
}

- (NSString *) toolTip {
	NSString *messageCount = @"";
	if( [self newMessagesWaiting] == 0 ) messageCount = NSLocalizedString( @"no messages waiting", "no messages waiting room tooltip" );
	else if( [self newMessagesWaiting] == 1 ) messageCount = NSLocalizedString( @"1 message waiting", "one message waiting room tooltip" );
	else messageCount = [NSString stringWithFormat:NSLocalizedString( @"%d messages waiting", "messages waiting room tooltip" ), [self newMessagesWaiting]];
	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [NSString stringWithFormat:@"%@\n%@ (%@)\n%@", [_buddy preferredName], _target, [[self connection] server], messageCount];
	return [NSString stringWithFormat:@"%@ (%@)\n%@", _target, [[self connection] server], messageCount];
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:NULL keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add to Favorites", "add to favorites contextual menu") action:@selector( addToFavorites: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFileToSelectedUser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Leave Chat", "leave chat contextual menu item title" ) action:@selector( leaveChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
	[item setRepresentedObject:self];
	[item setTarget:[JVChatController defaultManager]];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"messageUser"];
}

- (NSImage *) statusImage {
	if( _isActive && [[[self view] window] isKeyWindow] ) {
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		return nil;
	}

	return ( [_waitingAlerts count] ? [NSImage imageNamed:@"viewAlert"] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"newHighlightMessage"] : [NSImage imageNamed:@"newMessage"] ) : nil ) );
}

#pragma mark -

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Direct Chat %@ (%@)", _target, [[self connection] server]];
}

#pragma mark -

- (void) didUnselect {
	_newMessageCount = 0;
	_newHighlightMessageCount = 0;
	_isActive = NO;
	[super didUnselect];
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
	[[self connection] sendFile:path toUser:_target];
}

#pragma mark -

- (void) savePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	if( returnCode == NSOKButton ) xmlSetProp( xmlDocGetRootElement( _xmlLog ), "ended", [[[NSDate date] description] UTF8String] );
	[(id) super savePanelDidEnd:sheet returnCode:returnCode contextInfo:contextInfo];
	if( returnCode == NSOKButton ) xmlUnsetProp( xmlDocGetRootElement( _xmlLog ), "ended" );
}

#pragma mark -

- (void) setTarget:(NSString *) target {
	NSString *oldNick = _target;

	[_target autorelease];
	_target = [target copy];

	[_windowController reloadListItem:self andChildren:YES];

	[_settings autorelease];
	_settings = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:[[self identifier] stringByAppendingString:@" Settings"]] mutableCopy];
	if( ! _settings ) _settings = [[NSMutableDictionary dictionary] retain];

	NSString *source = [NSString stringWithFormat:@"%@/%@", [[[self connection] url] absoluteString], _target];
	xmlSetProp( xmlDocGetRootElement( _xmlLog ), "source", [source UTF8String] );

	[_buddy autorelease];
	_buddy = [[[MVBuddyListController sharedBuddyList] buddyForNickname:_target onServer:[[self connection] server]] retain];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSString * ), @encode( NSString * ), @encode( JVDirectChat * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( userNamed:isNowKnownAs:inView: )];
	[invocation setArgument:&oldNick atIndex:2];
	[invocation setArgument:&target atIndex:3];
	[invocation setArgument:&self atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
}

- (JVBuddy *) buddy {
	return [[_buddy retain] autorelease];
}

#pragma mark -

- (void) unavailable {
	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"Message undeliverable", "title of the user offline message sheet" ), NSLocalizedString( @"This user is now offline or you have messaged an invalid user. Any messages sent will not be received by the other user.", "error description for messaging a user that went offline or invalid" ), @"OK", nil, nil ) withName:@"unavailable"];
}

- (IBAction) addToFavorites:(id) sender {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], _target]];
	NSString *path = [[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Favorites/%@ (%@).inetloc", _target, [[self connection] server]] stringByExpandingTildeInPath] retain];

	[url writeToInternetLocationFile:path];
	[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSFileExtensionHidden, nil] atPath:path];

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
	NSBundle *style = [NSBundle bundleWithIdentifier:[sender representedObject]];
	NSString *variant = nil;
	if( style ) {
		[self setPreference:[style bundleIdentifier] forKey:@"style"];
		[self setPreference:nil forKey:@"style variant"];
	} else {
		style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatDefaultStyle"]];
		[self setPreference:nil forKey:@"style"];
		[self setPreference:nil forKey:@"style variant"];
		if( ! style ) {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
			style = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
		}
		variant = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [style bundleIdentifier]]];
	}

	if( ! [self _usingSpecificEmoticons] ) {
		NSBundle *emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [style bundleIdentifier]]]];
		[self setChatEmoticons:emoticon performRefresh:NO];		
	}

	[self setChatStyle:style withVariant:variant];
}

- (IBAction) changeChatStyleVariant:(id) sender {
	NSString *variant = [[sender representedObject] objectForKey:@"variant"];
	NSString *style = [[sender representedObject] objectForKey:@"style"];

	[self setPreference:style forKey:@"style"];
	[self setPreference:variant forKey:@"style variant"];

	if( ! [style isEqual:_chatStyle] ) {
		if( ! [self _usingSpecificEmoticons] ) {
			NSBundle *emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", style]]];
			[self setChatEmoticons:emoticon performRefresh:NO];
		}

		[self setChatStyle:[NSBundle bundleWithIdentifier:style] withVariant:variant];
	} else {
		[self setChatStyleVariant:variant];
	}
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
		emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle bundleIdentifier]]]];
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
		if( ! _encoding ) _encoding = (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
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

	if( _encoding != (NSStringEncoding) [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"] ) {
		[self setPreference:[NSNumber numberWithInt:_encoding] forKey:@"encoding"];
	} else [self setPreference:nil forKey:@"encoding"];
}

#pragma mark -
#pragma mark Messages & Events

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes {
	if( [_logLock tryLock] ) {
		[self displayQueue];
		[self addEventMessageToLogAndDisplay:message withName:name andAttributes:attributes];
		[_logLock unlock];
	} else { // Queue the message
		NSDictionary *queueEntry = [NSDictionary dictionaryWithObjectsAndKeys:@"event", @"type", message, @"message", name, @"name", attributes, @"attributes", nil];
		[_messageQueue addObject:queueEntry];
		if( [_messageQueue count] == 1 ) // We just added to an empty queue, so we need to attempt to process it soon
			[self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
	}
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action {
	if( [_logLock tryLock] ) {
		[self displayQueue];
		[self addMessageToLogAndDisplay:message fromUser:user asAction:action];
		[_logLock unlock];
	} else { // Queue the message
		NSDictionary *queueEntry = [NSDictionary dictionaryWithObjectsAndKeys:@"message", @"type", message, @"message", user, @"user", [NSNumber numberWithBool:action], @"action", nil];
		[_messageQueue addObject:queueEntry];
		if( [_messageQueue count] == 1 ) // We just added to an empty queue, so we need to attempt to process it soon
			[self performSelector:@selector( processQueue ) withObject:nil afterDelay:0.25];
	}
}

- (void) processMessage:(NSMutableString *) message asAction:(BOOL) action fromUser:(NSString *) user {
	if( ! [user isEqualToString:[[self connection] nickname]] ) {
		if( _firstMessage ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"New Private Message", "first message bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ wrote you a private message.", "first message bubble text" ), [self title]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"messageUser"] forKey:@"image"];
			[context setObject:_target forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[context setObject:_target forKey:@"performedInRoom"];
			[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatPrivateMessage"] forKey:@"coalesceKey"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatFirstMessage" withContextInfo:context];
		} else {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"Private Message", "new message bubble title" ) forKey:@"title"];
			if( [self newMessagesWaiting] == 1 ) [context setObject:[NSString stringWithFormat:NSLocalizedString( @"You have 1 message waiting from %@.", "new single message bubble text" ), [self title]] forKey:@"description"];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You have %d messages waiting from %@.", "new messages bubble text" ), [self newMessagesWaiting], [self title]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"messageUser"] forKey:@"image"];
			[context setObject:_target forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[context setObject:_target forKey:@"performedInRoom"];
			[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatPrivateMessage"] forKey:@"coalesceKey"];
			[[JVNotificationController defaultManager] performNotification:@"JVChatAdditionalMessages" withContextInfo:context];
		}
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( NSMutableString * ), @encode( BOOL ), @encode( JVDirectChat * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processMessage:asAction:inChat: )];
	[invocation setArgument:&message atIndex:2];
	[invocation setArgument:&action atIndex:3];
	[invocation setArgument:&self atIndex:4];

	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (void) echoSentMessageToDisplay:(NSAttributedString *) message asAction:(BOOL) action {
	NSMutableAttributedString *encodedMsg = [[message mutableCopy] autorelease];

	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreColors"]], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatIgnoreFormatting"]], @"NSHTMLIgnoreFontTraits", nil];
	NSMutableData *msgData = [[[encodedMsg HTMLWithOptions:options usingEncoding:_encoding allowLossyConversion:YES] mutableCopy] autorelease];
	[msgData appendBytes:"\0" length:1];

	char *msg = MVChatXHTMLToIRC( (const char * const) [msgData bytes] );
	msg = MVChatIRCToXHTML( msg );

	[self addMessageToDisplay:[NSData dataWithBytes:msg length:strlen( msg )] fromUser:[[self connection] nickname] asAction:action];
}

- (unsigned int) newMessagesWaiting {
	return _newMessageCount;
}

- (unsigned int) newHighlightMessagesWaiting {
	return _newHighlightMessageCount;
}

#pragma mark -
#pragma mark Input Handling

- (IBAction) send:(id) sender {
	NSMutableAttributedString *subMsg = nil;
	BOOL action = NO;
	NSRange range;

	if( ! [[self connection] isConnected] || ( _cantSendMessages && ! [[[send textStorage] string] hasPrefix:@"/"] ) ) return;

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
			if( [[subMsg string] hasPrefix:@"/"] ) {
				BOOL handled = NO;
				NSScanner *scanner = [NSScanner scannerWithString:[subMsg string]];
				NSString *command = nil;
				NSAttributedString *arguments = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [[subMsg string] length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [subMsg attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], range.location - [scanner scanLocation] )];

				if( ! ( handled = [self processUserCommand:command withArguments:arguments] ) )
					[[self connection] sendRawMessage:[command stringByAppendingFormat:@" %@", [arguments string]]];
			} else {
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

				[self sendAttributedMessage:subMsg asAction:action];
				if( [[subMsg string] length] )
					[self echoSentMessageToDisplay:subMsg asAction:action];
			}
		}
		if( range.length ) range.location++;
		[[send textStorage] deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}

	[send reset:nil];
	[display stringByEvaluatingJavaScriptFromString:@"scrollToBottom();"];
}

- (void) sendAttributedMessage:(NSMutableAttributedString *) message asAction:(BOOL) action {
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"NSHTMLIgnoreFontSizes", [NSNumber numberWithBool:NO], @"NSHTMLIgnoreFontColors", [NSNumber numberWithBool:NO], @"NSHTMLIgnoreFontTraits", nil];
	NSData *msgData = [message HTMLWithOptions:options usingEncoding:_encoding allowLossyConversion:YES];
	NSString *messageString = [[[NSString alloc] initWithData:msgData encoding:_encoding] autorelease];

	[message setAttributedString:[[[NSAttributedString alloc] initWithString:messageString] autorelease]];

	NSSet *plugins = [[MVChatPluginManager defaultManager] pluginsThatRespondToSelector:@selector( processMessage:asAction:toChat: )];
	NSEnumerator *enumerator = [plugins objectEnumerator];
	id item = nil;

	while( ( item = [enumerator nextObject] ) )
		if( [item isKindOfClass:[MVChatScriptPlugin class]] )
			[item processMessage:message asAction:action toChat:self];

	[message setAttributedString:[NSAttributedString attributedStringWithHTMLFragment:[message string] baseURL:nil]];

	enumerator = [plugins objectEnumerator];
	while( ( item = [enumerator nextObject] ) )
		if( ! [item isKindOfClass:[MVChatScriptPlugin class]] )
			[item processMessage:message asAction:action toChat:self];

	if( [[message string] length] )
		[[self connection] sendMessage:message withEncoding:_encoding toUser:[self target] asAction:action];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( JVDirectChat * ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processUserCommand:withArguments:toChat: )];
	[invocation setArgument:&command atIndex:2];
	[invocation setArgument:&arguments atIndex:3];
	[invocation setArgument:&self atIndex:4];

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
	[(JVMarkedScroller *)[[[[[display mainFrame] frameView] documentView] enclosingScrollView] verticalScroller] removeAllMarks];
}

#pragma mark -
#pragma mark TextView Support

- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event {
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

- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event {
	BOOL ret = NO;
	
	if( ( [event modifierFlags] & NSAlternateKeyMask ) != 0 ) {
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

	// exclude device-dependent flags and fn key (necessary for pg up/pg dn/home/end on portables)
	if( [event modifierFlags] & ~( NSFunctionKeyMask | NSNumericPadKeyMask | 0xffff ) ) return NO;

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

- (BOOL) textView:(NSTextView *) textView tabKeyPressed:(NSEvent *) event {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVUsePantherTextCompleteOnTab"] ) {
		[textView complete:nil];
		return YES;
	}

	NSArray *tabArr = [[send string] componentsSeparatedByString:@" "];
	unsigned len = [(NSString *)[tabArr lastObject] length];
	if( ! len ) return YES;
	if( len <= [_target length] && [[tabArr lastObject] caseInsensitiveCompare:[_target substringToIndex:len]] == NSOrderedSame ) {
		[[send textStorage] replaceCharactersInRange:NSMakeRange([[send textStorage] length] - len, len) withString:_target];
		if( ! [[send string] rangeOfString:@" "].length ) [send replaceCharactersInRange:NSMakeRange([[send textStorage] length], 0) withString:@": "];
		else [send replaceCharactersInRange:NSMakeRange([[send textStorage] length], 0) withString:@" "];
	}
	return YES;
}

- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event {
	[send reset:nil];
	return YES;	
}

- (NSArray *) textView:(NSTextView *) textView completions:(NSArray *) words forPartialWordRange:(NSRange) charRange indexOfSelectedItem:(int *) index {
	NSString *search = [[[send textStorage] string] substringWithRange:charRange];
	NSMutableArray *ret = [NSMutableArray array];
	if( [search length] <= [_target length] && [search caseInsensitiveCompare:[_target substringToIndex:[search length]]] == NSOrderedSame )
		[ret addObject:_target];
	if( [self isMemberOfClass:[JVDirectChat class]] ) [ret addObjectsFromArray:words];
	return ret;
}

- (void) textDidChange:(NSNotification *) notification {
	_historyIndex = 0;
}

#pragma mark -
#pragma mark SplitView Support

- (BOOL) splitView:(NSSplitView *) sender canCollapseSubview:(NSView *) subview {
	return NO;
}

- (float) splitView:(NSSplitView *) splitView constrainSplitPosition:(float) proposedPosition ofSubviewAt:(int) index {
//	float position = ( NSHeight( [splitView frame] ) - proposedPosition - [splitView dividerThickness] );
//	int lines = (int) floorf( position / 15. );
//	NSLog( @"%.2f %.2f / 15. = %.2f (%d)", proposedPosition, position, position / 15., lines );
//	return ( roundf( proposedPosition / 15. ) * 15. ) + [splitView dividerThickness] + 2.;
	return proposedPosition;
}

- (void) splitViewDidResizeSubviews:(NSNotification *) notification {
	// Cache the height of the send box so we can keep it constant during window resizes.
	NSRect sendFrame = [[[send superview] superview] frame];
	_sendHeight = sendFrame.size.height;

	if( _scrollerIsAtBottom ) {
		NSScrollView *scrollView = [[[[display subviews] objectAtIndex:0] subviews] objectAtIndex:0];
		[scrollView scrollClipView:[scrollView contentView] toPoint:[[scrollView contentView] constrainScrollPoint:NSMakePoint(0, [[scrollView documentView] bounds].size.height)]];
		[scrollView reflectScrolledClipView:[scrollView contentView]];
	}
}

- (void)splitViewWillResizeSubviews:(NSNotification *) aNotification {
	// The scrollbars are two subviews down from the JVWebView (deep in the WebKit bowls).
	NSScrollView *scrollView = [[[[display subviews] objectAtIndex:0] subviews] objectAtIndex:0];
	if( [[scrollView verticalScroller] floatValue] == 1. ) _scrollerIsAtBottom = YES;
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
	webFrame.size.height = newFrame.size.height - dividerThickness - _sendHeight;
	webFrame.size.width = newFrame.size.width;
	webFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = _sendHeight;
	sendFrame.size.width = newFrame.size.width;
	sendFrame.origin.y = webFrame.size.height + dividerThickness;

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
	} else return [super toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:willBeInserted];
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarDefaultItemIdentifiers:toolbar]];
	[list addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	return list;
}

- (BOOL) validateToolbarItem:(NSToolbarItem *) toolbarItem {
	return [super validateToolbarItem:toolbarItem];
}
@end

#pragma mark -

@implementation JVDirectChat (JVDirectChatPrivate)
- (void) addEventMessageToLogAndDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes {
	NSEnumerator *enumerator = nil, *kenumerator = nil;
	NSString *key = nil, *value = nil;
	NSMutableString *messageString = nil;
	xmlDocPtr doc = NULL, msgDoc = NULL;
	xmlNodePtr root = NULL, child = NULL;
	const char *msgStr = NULL;

	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] );

	doc = xmlNewDoc( "1.0" );
	root = xmlNewNode( NULL, "event" );
	xmlSetProp( root, "name", [name UTF8String] );
	xmlSetProp( root, "occurred", [[[NSDate date] description] UTF8String] );
	xmlDocSetRootElement( doc, root );

	if( message ) {
		msgStr = [[NSString stringWithFormat:@"<message>%@</message>", message] UTF8String];
		if( msgStr ) {
			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}
	}

	kenumerator = [attributes keyEnumerator];
	enumerator = [attributes objectEnumerator];
	while( ( key = [kenumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
		msgStr = nil;

		if( [value isMemberOfClass:[NSNull class]] ) {
			msgStr = [[NSString stringWithFormat:@"<%@ />", key] UTF8String];			
		} else {
			value = [value stringByEncodingXMLSpecialCharactersAsEntities];
			msgStr = [[NSString stringWithFormat:@"<%@>%@</%@>", key, value, key] UTF8String];
		}

		if( msgStr ) {
			msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );
			child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
			xmlAddChild( root, child );
			xmlFreeDoc( msgDoc );
		}
	}

	if( [[_styleParams objectForKey:@"subsequent"] isEqualToString:@"'yes'"] ) {
		[_styleParams removeObjectForKey:@"subsequent"];
		if( _params ) [[self class] _freeXsltParamArray:_params];
		_params = [[self class] _xsltParamArrayWithDictionary:_styleParams];
	}

	xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( root, _xmlLog, 1 ) );
	[self writeToLog:root withDoc:doc initializing:NO continuation:NO];

	messageString = [[[self _applyStyleOnXMLDocument:doc] mutableCopy] autorelease];
	if( [messageString length] ) {
		[messageString escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[messageString replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [messageString length] )];
		[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"appendMessage( \"%@\" );", messageString]];
	}

	xmlFreeDoc( doc );

	_requiresFullMessage = YES;
}

- (void) addMessageToLogAndDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action {
	// DO *NOT* call this method without first acquiring _logLock!
	BOOL continuation = NO;
	BOOL highlight = NO;
	xmlDocPtr doc = NULL, msgDoc = NULL;
	xmlNodePtr root = NULL, child = NULL, parent = NULL;
	const char *msgStr = NULL;
	NSMutableData *mutableMsg = [[message mutableCopy] autorelease];
	NSMutableString *messageString = nil;

	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	if( ! [user isEqualToString:[[self connection] nickname]] )
		_newMessageCount++;

	messageString = [[[NSMutableString alloc] initWithData:mutableMsg encoding:_encoding] autorelease];
	if( ! messageString ) {
		messageString = [NSMutableString stringWithCString:[mutableMsg bytes] length:[mutableMsg length]];
		[messageString appendFormat:@" <span class=\"error incompatible\">%@</span>", NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" )];
	}

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"] ) {
		AGRegex *regex = [AGRegex regexWithPattern:@"</*font.*?>" options:AGRegexCaseInsensitive];
		[messageString setString:[regex replaceWithString:@"" inString:messageString]];
	}

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"] ) {
		AGRegex *regex = [AGRegex regexWithPattern:@"</*[b|i|u]>" options:AGRegexCaseInsensitive];
		[messageString setString:[regex replaceWithString:@"" inString:messageString]];
	}

	if( ! [user isEqualToString:[[self connection] nickname]] ) {
		NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
		NSMutableArray *names = [[[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"MVChatHighlightNames"] mutableCopy] autorelease];
		[names addObject:[[self connection] nickname]];

		NSEnumerator *enumerator = [names objectEnumerator];
		AGRegex *regex = nil;
		NSString *name = nil;

		while( ( name = [enumerator nextObject] ) ) {
			if( [name hasPrefix:@"/"] && [name hasSuffix:@"/"] ) {
				regex = [AGRegex regexWithPattern:[name substringWithRange:NSMakeRange( 1, [name length] - 2 )] options:AGRegexCaseInsensitive];
			} else {
				NSString *pattern = [NSString stringWithFormat:@"(?:\\W|^)(%@)(?:\\W|$)", [name stringByEscapingCharactersInSet:escapeSet]];
				regex = [AGRegex regexWithPattern:pattern options:AGRegexCaseInsensitive];
			}

			NSRange searchRange = NSMakeRange( 0, [messageString length] );
			NSRange backSearchRange = NSMakeRange( 0, [messageString length] );
			AGRegexMatch *match = [regex findInString:messageString range:searchRange];

			while( match ) {
				NSRange foundRange = ( [match count] > 1 ? [match rangeAtIndex:1] : [match rangeAtIndex:0] );
				backSearchRange.length = foundRange.location - backSearchRange.location;

				// Search to see if we're in a tag
				NSRange leftRange = [messageString rangeOfString:@"<" options:( NSBackwardsSearch | NSLiteralSearch ) range:backSearchRange];
				NSRange rightRange = [messageString rangeOfString:@">" options:( NSBackwardsSearch | NSLiteralSearch ) range:backSearchRange];

				if( leftRange.location == NSNotFound || ( rightRange.location != NSNotFound && rightRange.location > leftRange.location ) ) {
					[messageString replaceCharactersInRange:foundRange withString:[NSString stringWithFormat:@"<span class=\"highlight\">%@</span>", ( [match count] > 1 ? [match groupAtIndex:1] : [match groupAtIndex:0] )]];
					searchRange.location = NSMaxRange( foundRange ) + 31;
					searchRange.length = [messageString length] - searchRange.location;
					backSearchRange.location = searchRange.location;
					highlight = YES;
				} else {
					searchRange.location = NSMaxRange( foundRange );
					searchRange.length = [messageString length] - searchRange.location;
				}

				match = [regex findInString:messageString range:searchRange];
			}
		}
	}

	if( highlight ) {
		_newHighlightMessageCount++;
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"You Were Mentioned", "mentioned bubble title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"One of your highlight words was mentioned in %@.", "mentioned bubble text" ), [self title]] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activityNewImportant"] forKey:@"image"];
		[context setObject:_target forKey:@"performedOn"];
		[context setObject:user forKey:@"performedBy"];
		[context setObject:_target forKey:@"performedInRoom"];
		[context setObject:[[self windowTitle] stringByAppendingString:@" JVChatMentioned"] forKey:@"coalesceKey"];
		[[JVNotificationController defaultManager] performNotification:@"JVChatMentioned" withContextInfo:context];
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
		[self _makeHyperlinksInString:messageString];

	[self _performEmoticonSubstitutionOnString:messageString];

	[self processMessage:messageString asAction:action fromUser:user];

	if( ! [messageString length] ) {
		_newMessageCount--;
		return;
	}

	_firstMessage = NO;

	doc = xmlNewDoc( "1.0" );

	xmlXPathObjectPtr result = NULL;

	xmlXPathContextPtr ctx = xmlXPathNewContext( _xmlLog );
	if( ! ctx ) return;
	result = xmlXPathEval( [[NSString stringWithFormat:@"/log/*[name() = 'envelope' and position() = last() and (sender = '%@' or sender/@nickname = '%@')]", user, user] UTF8String], ctx );

	if( ! _requiresFullMessage && result && result -> nodesetval -> nodeNr ) {
		continuation = YES;
		if( ! [[_styleParams objectForKey:@"subsequent"] isEqualToString:@"'yes'"] ) {
			[_styleParams setObject:@"'yes'" forKey:@"subsequent"];
			if( _params ) [[self class] _freeXsltParamArray:_params];
			_params = [[self class] _xsltParamArrayWithDictionary:_styleParams];
		}

		parent = result -> nodesetval -> nodeTab[0];
		root = xmlDocCopyNode( parent, doc, 1 );
		xmlDocSetRootElement( doc, root );
	} else {
		continuation = NO;
		if( [[_styleParams objectForKey:@"subsequent"] isEqualToString:@"'yes'"] ) {
			[_styleParams removeObjectForKey:@"subsequent"];
			if( _params ) [[self class] _freeXsltParamArray:_params];
			_params = [[self class] _xsltParamArrayWithDictionary:_styleParams];
		}

		root = xmlNewNode( NULL, "envelope" );
		xmlSetProp( root, "id", [[NSString stringWithFormat:@"%d", _messageId++] UTF8String] );
		xmlDocSetRootElement( doc, root );

		if( [user isEqualToString:_target] && _buddy ) {
			NSString *theirName = user;
			if( [_buddy preferredNameWillReturn] != JVBuddyActiveNickname ) theirName = [_buddy preferredName];
			child = xmlNewTextChild( root, NULL, "sender", [theirName UTF8String] );
			if( ! [theirName isEqualToString:user] )
				xmlSetProp( child, "nickname", [user UTF8String] );
			xmlSetProp( child, "card", [[_buddy uniqueIdentifier] UTF8String] );
			[self _saveBuddyIcon:_buddy];
		} else if( [user isEqualToString:[[self connection] nickname]] ) {
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
		}
		 
		xmlSetProp( child, "classification", [self _classificationForNickname:user] );		
	}

	xmlXPathFreeObject( result );
	xmlXPathFreeContext( ctx );

	msgStr = [[NSString stringWithFormat:@"<message>%@</message>", messageString] UTF8String];

	msgDoc = xmlParseMemory( msgStr, strlen( msgStr ) );

	child = xmlDocCopyNode( xmlDocGetRootElement( msgDoc ), doc, 1 );
	xmlSetProp( child, "received", [[[NSDate date] description] UTF8String] );
	if( action ) xmlSetProp( child, "action", "yes" );
	if( highlight ) xmlSetProp( child, "highlight", "yes" );
	xmlAddChild( root, child );

    [self writeToLog:root withDoc:doc initializing:NO continuation:continuation];

	xmlFreeDoc( msgDoc );

	if( parent ) xmlAddChild( parent, xmlDocCopyNode( child, _xmlLog, 1 ) );
	else xmlAddChild( xmlDocGetRootElement( _xmlLog ), xmlDocCopyNode( root, _xmlLog, 1 ) );

	messageString = [[[self _applyStyleOnXMLDocument:doc] mutableCopy] autorelease];
	if( [messageString length] ) {
		[messageString escapeCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\\\"'"]];
		[messageString replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange( 0, [messageString length] )];
		if( parent ) [display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"appendConsecutiveMessage( \"%@\" );", messageString]];
		else [display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"appendMessage( \"%@\" );", messageString]];

		if( highlight ) {
			unsigned int loc = [[display stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"locationOfMessage( \"%d\" );", ( _messageId - 1 )]] intValue];
			if( loc ) [(JVMarkedScroller *)[[[[[display mainFrame] frameView] documentView] enclosingScrollView] verticalScroller] addMarkAt:loc];
		}
	}

	xmlFreeDoc( doc );

	_requiresFullMessage = NO;

	[_windowController reloadListItem:self andChildren:NO];
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
			[self addMessageToLogAndDisplay:[msg objectForKey:@"message"] fromUser:[msg objectForKey:@"user"] asAction:[[msg objectForKey:@"action"] boolValue]];
		} else if( [[msg objectForKey:@"type"] isEqualToString:@"event"] ) {
			if( [[msg objectForKey:@"message"] isEqual:[NSNull null]] ) {
				[self addEventMessageToLogAndDisplay:nil withName:[msg objectForKey:@"name"] andAttributes:[msg objectForKey:@"attributes"]];
			} else {
				[self addEventMessageToLogAndDisplay:[msg objectForKey:@"message"] withName:[msg objectForKey:@"name"] andAttributes:[msg objectForKey:@"attributes"]];
			}
		}
	}
}

- (void) writeToLog:(void *) root withDoc:(void *) doc initializing:(BOOL) init continuation:(BOOL) cont {
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

- (void) _makeHyperlinksInString:(NSMutableString *) string {
	unsigned i = 0, c = 0;
	NSMutableArray *parts = nil;
	NSMutableString *part = nil;
	NSScanner *urlScanner = nil;
	NSCharacterSet *legalSchemeSet = nil;
	NSCharacterSet *legalAddressSet = nil;
	NSCharacterSet *ircChannels = [NSCharacterSet characterSetWithCharactersInString:@"#&"];
	NSCharacterSet *seperaters = [NSCharacterSet characterSetWithCharactersInString:@"<> \t\n\r&"];
	NSString *link = nil, *urlHandle = nil;
	NSMutableString *mutableLink = nil;
	BOOL inTag = NO;
	NSRange range, srange;

	srange = NSMakeRange( 0, [string length] );
	range = [string rangeOfCharacterFromSet:seperaters options:NSLiteralSearch range:srange];
	while( range.location != NSNotFound ) {
		if( [string characterAtIndex:range.location] == '<' ) {
			[string insertString:@"\033" atIndex:range.location];
			inTag = ! inTag;
		} else if( [string characterAtIndex:range.location] == '>' ) {
			[string insertString:@"\033" atIndex:range.location + 1];
			inTag = ! inTag;
		} else if( [string characterAtIndex:range.location] == ' ' && ! inTag ) {
			[string insertString:@"\033" atIndex:range.location + 1];
		} else if( [string characterAtIndex:range.location] == '&' && ! inTag &&
				   ([string length] < range.location + 5 ||
					![[string substringWithRange:NSMakeRange(range.location, 5)]
						isEqualToString:@"&amp;"]) ) {
			[string insertString:@"\033" atIndex:range.location];
		}
		if( range.location >= [string length] ) break;
		srange = NSMakeRange( range.location + 2, [string length] - range.location - 2 );
		range = [string rangeOfCharacterFromSet:seperaters options:NSLiteralSearch range:srange];
	}

	parts = [[[string componentsSeparatedByString:@"\033"] mutableCopy] autorelease];

	for( i = 0, c = [parts count]; i < c; i++ ) {
		part = [[[parts objectAtIndex:i] mutableCopy] autorelease];

		if( ! [part length] || ( [part length] >= 1 && [part characterAtIndex:0] == '<' ) )
			continue;

		// catch well-formed urls like "http://www.apple.com" or "irc://irc.javelin.cc"
		legalSchemeSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-"];
		legalAddressSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890:;#.,\\/?!&%$-+=_~@*'"];
		urlScanner = [NSScanner scannerWithString:part];
		srange = [part rangeOfString:@"://"];
		range = [part rangeOfCharacterFromSet:[legalSchemeSet invertedSet] options:( NSLiteralSearch | NSBackwardsSearch ) range:NSMakeRange( 0, ( srange.location != NSNotFound ? srange.location : 0 ) )];
		if( range.location != NSNotFound ) [urlScanner setScanLocation:range.location];
		[urlScanner scanUpToCharactersFromSet:legalSchemeSet intoString:NULL];
		if( [urlScanner scanUpToString:@"://" intoString:&urlHandle] && [urlScanner scanCharactersFromSet:legalAddressSet intoString:&link] ) {
			if( [link characterAtIndex:([link length] - 1)] == '.' || [link characterAtIndex:([link length] - 1)] == '?' || [link characterAtIndex:([link length] - 1)] == '!' || [link characterAtIndex:([link length] - 1)] == ',' )
				link = [link substringToIndex:( [link length] - 1 )];
			if( [link length] >= 4 )
				link = [urlHandle stringByAppendingString:link];
			if( [link length] >= 7 ) {
				mutableLink = [[link mutableCopy] autorelease];
				[mutableLink replaceOccurrencesOfString:@"/" withString:@"/&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"+" withString:@"+&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"%" withString:@"&#8203;%" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"&" withString:@"&#8203;&" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[part replaceOccurrencesOfString:link withString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", link, mutableLink] options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}

		// catch www urls like "www.apple.com"
		urlScanner = [NSScanner scannerWithString:part];
		[urlScanner scanUpToString:@"www." intoString:NULL];
		if( [urlScanner scanCharactersFromSet:legalAddressSet intoString:&link] ) {
			if( [link characterAtIndex:([link length] - 1)] == '.' || [link characterAtIndex:([link length] - 1)] == '?' || [link characterAtIndex:([link length] - 1)] == '!' || [link characterAtIndex:([link length] - 1)] == ',' )
				 link = [link substringToIndex:( [link length] - 1 )];
			if( [link length] >= 8 ) {
				mutableLink = [[link mutableCopy] autorelease];
				[mutableLink replaceOccurrencesOfString:@"/" withString:@"/&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"+" withString:@"+&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"%" withString:@"&#8203;%" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"&" withString:@"&#8203;&" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[part replaceOccurrencesOfString:link withString:[NSString stringWithFormat:@"<a href=\"http://%@\">%@</a>", link, mutableLink] options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}

		// catch well-formed email addresses like "timothy@hatcher.name" or "timothy@javelin.cc"
		legalSchemeSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890._-+"];
		legalAddressSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890@.-_"];
		urlScanner = [NSScanner scannerWithString:part];
		srange = [part rangeOfString:@"@"];
		range = [part rangeOfCharacterFromSet:[legalSchemeSet invertedSet] options:( NSLiteralSearch | NSBackwardsSearch ) range:NSMakeRange( 0, ( srange.location != NSNotFound ? srange.location : 0 ) )];
		if( range.location != NSNotFound ) [urlScanner setScanLocation:range.location];
		[urlScanner scanUpToCharactersFromSet:legalSchemeSet intoString:NULL];
		if( [urlScanner scanUpToString:@"@" intoString:&urlHandle] && [urlScanner scanCharactersFromSet:legalAddressSet intoString:&link] ) {
			if( [link characterAtIndex:([link length] - 1)] == '.' )
				link = [link substringToIndex:( [link length] - 1 )];
			NSRange hasPeriod = [link rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
			if( [urlHandle length] && [link length] && hasPeriod.location < ([link length] - 1) && hasPeriod.location != NSNotFound ) {
				link = [urlHandle stringByAppendingString:link];
				[part replaceOccurrencesOfString:link withString:[NSString stringWithFormat:@"<a href=\"mailto:%@\">%@</a>", link, link] options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}

		[part replaceOccurrencesOfString:@"~" withString:@"~tilde;" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
		[part replaceOccurrencesOfString:@"&" withString:@"~amp;" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
		[part replaceOccurrencesOfString:@"~amp;amp;" withString:@"&" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];

		// catch well-formed IRC channel names like "#php" or "&admins"
		legalAddressSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890:;.,?!%^$@#&*~`\\|+/-_"];
		urlScanner = [NSScanner scannerWithString:part];
		if( ( ( [urlScanner scanUpToCharactersFromSet:ircChannels intoString:NULL] && [urlScanner scanLocation] < [part length] && ! [[NSCharacterSet alphanumericCharacterSet] characterIsMember:[part characterAtIndex:( [urlScanner scanLocation] - 1 )]] ) || [part rangeOfCharacterFromSet:ircChannels].location == 0 ) && [urlScanner scanCharactersFromSet:legalAddressSet intoString:&urlHandle] ) {
			if( [urlHandle length] >= 2 && [urlHandle rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet] options:NSLiteralSearch range:NSMakeRange( 1, [urlHandle length] - 1 )].location != NSNotFound && ! ( [urlHandle length] >= 7 && [NSColor colorWithHTMLAttributeValue:urlHandle] ) ) {
				if( [urlHandle characterAtIndex:([urlHandle length] - 1)] == '.' || [urlHandle characterAtIndex:([urlHandle length] - 1)] == '?' || [urlHandle characterAtIndex:([urlHandle length] - 1)] == '!' || [urlHandle characterAtIndex:([urlHandle length] - 1)] == ',' )
					urlHandle = [urlHandle substringToIndex:( [urlHandle length] - 1 )];
				link = [NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], urlHandle];
				mutableLink = [NSMutableString stringWithFormat:@"<a href=\"%@\">%@</a>", link, urlHandle];
				[mutableLink replaceOccurrencesOfString:@"&" withString:@"~amp;amp;" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				[part replaceOccurrencesOfString:urlHandle withString:mutableLink options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];

				[part replaceOccurrencesOfString:@"&" withString:@"~amp;amp;" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				[part replaceOccurrencesOfString:@"~amp;" withString:@"&" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				[part replaceOccurrencesOfString:@"~tilde;" withString:@"~" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}

		[part replaceOccurrencesOfString:@"&" withString:@"~amp;amp;" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
		[part replaceOccurrencesOfString:@"~amp;" withString:@"&" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
		[part replaceOccurrencesOfString:@"~tilde;" withString:@"~" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];

	finish:
		[parts replaceObjectAtIndex:i withObject:part];
	}

	[string setString:[parts componentsJoinedByString:@""]];
}

- (void) _breakLongLinesInString:(NSMutableString *) string { // Not good on strings that have prior HTML or HTML entities
	NSScanner *scanner = [NSScanner scannerWithString:string];
	NSCharacterSet *stopSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	unsigned int lastLoc = 0;

	while( ! [scanner isAtEnd] ) {
		lastLoc = [scanner scanLocation];
		[scanner scanUpToCharactersFromSet:stopSet intoString:nil];
		if( ( [scanner scanLocation] - lastLoc ) > 34 ) { // Who says "supercalifragilisticexpialidocious" anyway?
			unsigned int times = (unsigned int) ( ( [scanner scanLocation] - lastLoc ) / 34 );
			while( times > 0 ) {
				[string insertString:@"&#8203;" atIndex:( lastLoc + ( times * 34 ) )];
				times--;
			}
		}
	}
}

- (void) _performEmoticonSubstitutionOnString:(NSMutableString *) string {
	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	NSEnumerator *keyEnumerator = [_emoticonMappings keyEnumerator];
	NSEnumerator *objEnumerator = [_emoticonMappings objectEnumerator];
	NSEnumerator *srcEnumerator = nil;
	NSString *result = string;
	NSString *str = nil;
	NSString *key = nil;
	NSArray *obj = nil;

	while( ( key = [keyEnumerator nextObject] ) && ( obj = [objEnumerator nextObject] ) ) {
		srcEnumerator = [obj objectEnumerator];
		while( ( str = [srcEnumerator nextObject] ) ) {
			NSMutableString *search = [str mutableCopy];
			[search encodeXMLSpecialCharactersAsEntities];
			[search escapeCharactersInSet:escapeSet];

			AGRegex *regex = [AGRegex regexWithPattern:[NSString stringWithFormat:@"(\\s|^)(%@)", search]]; // Not ideal but this allows consecutive (same) emoticons that share a common space
			if( [regex findInString:result] ) {
				NSString *replacement = [NSString stringWithFormat:@"$1<span class=\"emoticon %@\"><samp>$2</samp></span>", key];
				result = [regex replaceWithString:replacement inString:result];
			}

			[search release];
		}
	}

	[string setString:result];
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
//	[self showAlert:nil withName:@"disconnected"]; // cancel the disconnected alert
	_cantSendMessages = NO;
}

- (void) _didDisconnect:(NSNotification *) notification {
//	[self showAlert:NSGetInformationalAlertPanel( NSLocalizedString( @"You're now offline", "title of the you're offline message sheet" ), NSLocalizedString( @"You are no longer connected to the server where you were chatting. No messages can be sent at this time. Reconnecting might be in progress.", "chat window error description for loosing connection" ), @"OK", nil, nil ) withName:@"disconnected"];
	[self addEventMessageToDisplay:NSLocalizedString( @"You left the chat by being disconnected from the server.", "disconenct from the server status message" ) withName:@"disconnected" andAttributes:nil];
	_cantSendMessages = YES;
}

- (void) _awayStatusChanged:(NSNotification *) notification {
	if( [[[notification userInfo] objectForKey:@"away"] boolValue] ) {
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You have set yourself away with \"%@\".", "self away status set message" ), [[_connection awayStatusMessage] string]] withName:@"awaySet" andAttributes:nil];
	} else {
		[self addEventMessageToDisplay:NSLocalizedString( @"You have returned from away.", "self away status removed message" ) withName:@"awayRemoved" andAttributes:nil];
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

		emoticon = [NSBundle bundleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [_chatStyle bundleIdentifier]]]];
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Text Only", "text only emoticons menu item title" ) action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:@""];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		enumerator = [[[JVChatEmoticonBundles allObjects] sortedArrayUsingFunction:sortBundlesByName context:self] objectEnumerator];
		while( ( emoticon = [enumerator nextObject] ) ) {
			menuItem = [[[NSMenuItem alloc] initWithTitle:[[self class] _nameForBundle:emoticon] action:@selector( changeChatEmoticons: ) keyEquivalent:@""] autorelease];
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
		[[NSFontManager sharedFontManager] fontWithFamily:[preferences standardFontFamily] traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size: [preferences defaultFontSize]];
	} else baseFont = [NSFont userFontOfSize:0.];
	[send setBaseFont:baseFont];
}

- (BOOL) _usingSpecificStyle {
	return ( [NSBundle bundleWithIdentifier:[self preferenceForKey:@"style"]] ? YES : NO );
}

- (BOOL) _usingSpecificEmoticons {
	return ( [self preferenceForKey:@"emoticon"] ? YES : NO );
}

- (char *) _classificationForNickname:(NSString *) nickname {
	return "normal";
}

- (void) _saveSelfIcon {
	ABPerson *_person = [[ABAddressBook sharedAddressBook] me];
	NSImage *icon = [[[NSImage alloc] initWithData:[_person imageData]] autorelease];
	NSData *imageData = [icon TIFFRepresentation];
	if( ! [imageData length] ) {
		[[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [_person uniqueId]] handler:nil];
		return;
	}
	if( [[NSFileManager defaultManager] isReadableFileAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [_person uniqueId]]] )
		return;
	[imageData writeToFile:[NSString stringWithFormat:@"/tmp/%@.tif", [_person uniqueId]] atomically:NO];
}

- (void) _saveBuddyIcon:(JVBuddy *) buddy {
	NSData *imageData = [[buddy picture] TIFFRepresentation];
	if( ! [imageData length] ) {
		[[NSFileManager defaultManager] removeFileAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]] handler:nil];
		return;
	}
	if( [[NSFileManager defaultManager] isReadableFileAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]]] )
		return;
	[imageData writeToFile:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]] atomically:NO];
}
@end


#pragma mark -

@implementation JVDirectChat (JVDirectChatScripting)
- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSString *message = [[command evaluatedArguments] objectForKey:@"message"];

	if( ! [message length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Message can't be blank"];
		return;
	}

	NSMutableAttributedString *attributeMsg = [NSMutableAttributedString attributedStringWithHTMLFragment:message baseURL:nil];
	BOOL action = [[[command evaluatedArguments] objectForKey:@"action"] boolValue];
	BOOL localEcho = ( [[command evaluatedArguments] objectForKey:@"echo"] ? [[[command evaluatedArguments] objectForKey:@"echo"] boolValue] : YES );

	[self sendAttributedMessage:attributeMsg asAction:action];
	if( localEcho ) [self echoSentMessageToDisplay:attributeMsg asAction:action];
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

	[self addEventMessageToDisplay:message withName:name andAttributes:( [attributes isKindOfClass:[NSDictionary class]] ? attributes : nil )];
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
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toChat:(JVDirectChat *) chat {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:command, @"----", [arguments string], @"pcC1", chat, @"pcC2", nil];
	id result = [self callScriptHandler:'pcCX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	return ( [result isKindOfClass:[NSNumber class]] ? [result boolValue] : NO );
}

- (void) processMessage:(NSMutableString *) message asAction:(BOOL) action inChat:(JVDirectChat *) chat {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:message, @"----", [NSNumber numberWithBool:action], @"piM1", [chat target], @"piM2", chat, @"piM3", nil];
	id result = [self callScriptHandler:'piMX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	else if( [result isKindOfClass:[NSString class]] ) [message setString:result];
}

- (void) processMessage:(NSMutableAttributedString *) message asAction:(BOOL) action toChat:(JVDirectChat *) chat {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:[message string], @"----", [NSNumber numberWithBool:action], @"poM1", chat, @"poM2", nil];
	id result = [self callScriptHandler:'poMX' withArguments:args];
	if( ! result ) [self doesNotRespondToSelector:_cmd];
	else if( [result isKindOfClass:[NSString class]] )
		[message setAttributedString:[[[NSAttributedString alloc] initWithString:result] autorelease]];
}

- (void) userNamed:(NSString *) nickname isNowKnownAs:(NSString *) newNickname inView:(id <JVChatViewController>) view {
	NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:nickname, @"----", newNickname, @"uNc1", view, @"uNc2", nil];
	if( ! [self callScriptHandler:'uNcX' withArguments:args] )
		[self doesNotRespondToSelector:_cmd];
}

@end
