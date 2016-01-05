#import "JVDirectChatPanel.h"

#import "JVBuddy.h"
#import "JVChatController.h"
#import "JVChatEvent.h"
#import "JVChatMessage.h"
#import "JVChatRoomMember.h"
#import "JVChatRoomPanel.h"
#import "JVChatTranscript.h"
#import "JVChatUserInspector.h"
#import "JVEmoticonSet.h"
#import "JVMarkedScroller.h"
#import "JVNotificationController.h"
#import "JVSpeechController.h"
#import "JVSplitView.h"
#import "JVStyle.h"
#import "JVStyleView.h"
#import "JVTabbedChatWindowController.h"
#import "KAIgnoreRule.h"
#import "MVBuddyListController.h"
#import "MVChatUserAdditions.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVMenuButton.h"
#import "MVTextView.h"
#import "MVApplicationController.h"
#import "NSAttributedStringMoreAdditions.h"
#import "NSBundleAdditions.h"
#import "NSDateAdditions.h"
#import "NSRegularExpressionAdditions.h"

static NSSet *actionVerbs = nil;

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
	/* Baltic */
	(NSStringEncoding) -1,
	(NSStringEncoding) 0x8000020D,		// ISO Latin 7
	(NSStringEncoding) 0x80000507,		// Windows
	/* Central European */
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

NSString *JVToolbarTextEncodingItemIdentifier = @"JVToolbarTextEncodingItem";
NSString *JVToolbarClearScrollbackItemIdentifier = @"JVToolbarClearScrollbackItem";
NSString *JVToolbarSendFileItemIdentifier = @"JVToolbarSendFileItem";
NSString *JVToolbarMarkItemIdentifier = @"JVToolbarMarkItem";

NSString *JVChatMessageWasProcessedNotification = @"JVChatMessageWasProcessedNotification";
NSString *JVChatEventMessageWasProcessedNotification = @"JVChatEventMessageWasProcessedNotification";

@interface JVDirectChatPanel (JVDirectChatPrivate) <ABImageClient, MVTextViewDelegate>
@property (readonly, copy) NSString *_selfCompositeName;
@property (readonly, copy) NSString *_selfStoredNickname;
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
- (void) _didSwitchStyles:(NSNotification *) notification;
- (void) _openAppearancePreferences:(id) sender;
@end

#pragma mark -

@interface JVStyleView (JVStyleViewPrivate)
@property (readonly) NSUInteger _visibleMessageCount;
- (NSUInteger) _locationOfElementAtIndex:(NSUInteger) index;
@end

#pragma mark -

@implementation JVDirectChatPanel
- (instancetype) init {
	if( ( self = [super init] ) ) {
		send = nil;
		_target = nil;
		_firstMessage = YES;
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		[(MVApplicationController *)[NSApp delegate] updateDockTile];
		_cantSendMessages = NO;
		_isActive = NO;
		_forceSplitViewPosition = YES;
		_historyIndex = 0;
		_sendHeight = 25.;

		_encoding = NSASCIIStringEncoding;
		_encodingMenu = nil;
		_spillEncodingMenu = nil;

		_sendHistory = [NSMutableArray arrayWithCapacity:30];
		[_sendHistory insertObject:[[NSAttributedString alloc] initWithString:@""] atIndex:0];

		_waitingAlerts = [NSMutableArray arrayWithCapacity:5];
		_waitingAlertNames = [NSMutableDictionary dictionaryWithCapacity:5];
	}

	return self;
}

- (instancetype) initWithTarget:(id) target {
	if( ( self = [self init] ) ) {
		_target = target;

		if( [self connection] ) {
			if( ( [self isMemberOfClass:[JVDirectChatPanel class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogPrivateChats"] ) ||
				( [self isMemberOfClass:[JVChatRoomPanel class]] && [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogChatRooms"] ) ) {

				[self checkTranscriptDirectoryState];
			}

			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];

			if( ! [target isKindOfClass:[MVDirectChatConnection class]] ) {
				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:[self connection]];
				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didDisconnect: ) name:MVChatConnectionDidDisconnectNotification object:[self connection]];
				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _awayStatusChanged: ) name:MVChatConnectionSelfAwayStatusChangedNotification object:[self connection]];
				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _errorOccurred: ) name:MVChatConnectionErrorNotification object:[self connection]];
			}

			if( [target isKindOfClass:[MVChatUser class]] ) {
				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:_target];
				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userStatusChanged:) name:MVChatUserStatusChangedNotification object:_target];

				_watchRule = [[MVChatUserWatchRule alloc] init];
				[_watchRule setNickname:[target nickname]];

				[[self connection] addChatUserWatchRule:_watchRule];
			}
		}

		_settings = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:[[self identifier] stringByAppendingString:@" Settings"]]];
	}

	return self;
}

- (void) awakeFromNib {
	JVStyle *style = nil;
	NSString *variant = nil;
	JVEmoticonSet *emoticon = nil;

	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] ) {
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVDirectChatConnectionDidConnectNotification object:[self target]];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVDirectChatConnectionDidDisconnectNotification object:[self target]];
	} else {
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidConnectNotification object:[self connection]];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatConnectionDidDisconnectNotification object:[self connection]];
	}

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

	[display setBodyTemplate:@"directChat"];

	[self changeEncoding:nil];

	[send setSelectable:YES];
	[send setEditable:YES];
	[send setRichText:YES];
	[send setImportsGraphics:NO];
	[send setUsesFontPanel:YES];
	[send setUsesFindPanel:NO];
	[send setAllowsUndo:YES];
	[send setUsesRuler:NO];
	[send setDelegate:self];
	[send reset:nil];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		[(JVSplitView *)[[[send superview] superview] superview] setDividerStyle:NSSplitViewDividerStylePaneSplitter];
}

- (void) dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if( _watchRule ) [[self connection] removeChatUserWatchRule:_watchRule];

	for( id alert in _waitingAlerts )
		NSReleaseAlertPanel( alert );
}

#pragma mark -

- (id) target {
	return _target;
}

- (MVChatUser *) user {
	if( [[self target] isKindOfClass:[MVChatUser class]] )
		return [self target];
	if( [[self target] isKindOfClass:[MVChatRoom class]] )
		return [(MVChatRoom *)[self target] localMemberUser];
	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] )
		return [(MVDirectChatConnection *)[self target] user];
	return nil;
}

- (NSURL *) url {
	NSString *server = [[[self connection] url] absoluteString];
	return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", server, [[[self user] nickname] stringByEncodingIllegalURLCharacters]]];
}

- (MVChatConnection *) connection {
	if( [[self target] respondsToSelector:@selector( connection )] )
		return (MVChatConnection *)[[self target] connection];
	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] )
		return [[(MVDirectChatConnection *)[self target] user] connection];
	return nil;
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVDirectChat" owner:self topLevelObjects:NULL];
	return contents;
}

- (NSResponder *) firstResponder {
	return send;
}

#pragma mark -

- (BOOL) isEnabled {
	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] )
		return ( [(MVDirectChatConnection *)[self target] status] == MVDirectChatConnectionConnectedStatus );
	MVChatUserStatus status = [(MVChatUser *)[self target] status];
	return ([[self connection] isConnected] && (status == MVChatUserAvailableStatus || status == MVChatUserAwayStatus));
}

- (NSString *) title {
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [_buddy preferredName]; */
	return [[self user] displayName];
}

- (NSString *) windowTitle {
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [NSString stringWithFormat:@"%@ (%@)", [_buddy preferredName], [[self user] serverAddress]]; */

	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] ) {
		NSString *host = [(MVDirectChatConnection *)[self target] connectedHost];
		if( ! [host length] ) host = [[self user] address];
		if( [host length] ) return [NSString stringWithFormat:@"%@ (%@)", [self title], host];
		return [self title];
	}

	return [NSString stringWithFormat:@"%@ (%@)", [self title], [[self user] serverAddress]];
}

- (NSString *) information {
/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname && ! [[self target] isEqualToString:[_buddy preferredName]] )
		return [NSString stringWithFormat:@"%@ (%@)", [self target], [[self user] serverAddress]]; */
	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] ) {
		if( [(MVDirectChatConnection *)[self target] status] == MVDirectChatConnectionWaitingStatus )
			return NSLocalizedString( @"waiting for connection", "waiting for connection information" );
		if( [(MVDirectChatConnection *)[self target] status] == MVDirectChatConnectionDisconnectedStatus )
			return NSLocalizedString( @"disconnected", "disconnected information" );

		NSString *host = [(MVDirectChatConnection *)[self target] connectedHost];
		if( ! [host length] ) host = [[self user] address];
		return host;
	}

	return [[self user] serverAddress];
}

- (NSString *) toolTip {
	NSString *messageCount = @"";
	if( [self newMessagesWaiting] == 0 ) messageCount = NSLocalizedString( @"no messages waiting", "no messages waiting room tooltip" );
	else if( [self newMessagesWaiting] == 1 ) messageCount = NSLocalizedString( @"1 message waiting", "one message waiting room tooltip" );
	else messageCount = [NSString stringWithFormat:NSLocalizedString( @"%d messages waiting", "messages waiting room tooltip" ), [self newMessagesWaiting]];

/*	if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [NSString stringWithFormat:@"%@\n%@ (%@)\n%@", [_buddy preferredName], [self target], [[self user] serverAddress], messageCount]; */

	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] ) {
		NSString *info = nil;
		if( [(MVDirectChatConnection *)[self target] status] == MVDirectChatConnectionWaitingStatus )
			info = NSLocalizedString( @"waiting for connection", "waiting for connection tooltip" );
		else if( [(MVDirectChatConnection *)[self target] status] == MVDirectChatConnectionDisconnectedStatus )
			info = NSLocalizedString( @"disconnected", "disconnected tooltip" );
		else {
			info = [(MVDirectChatConnection *)[self target] connectedHost];
			if( ! [info length] ) info = [[self user] address];
		}

		if( [info length] ) return [NSString stringWithFormat:@"%@ (%@)\n%@", [self title], info, messageCount];
		return [NSString stringWithFormat:@"%@\n%@", [self title], messageCount];
	}

	return [NSString stringWithFormat:@"%@ (%@)\n%@", [self title], [[self user] serverAddress], messageCount];
}

#pragma mark -

- (NSMenu *) menu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

	NSArray *standardItems = [[self user] standardMenuItems];
	for( item in standardItems )
		if( [item action] != @selector( startDirectChat: ) )
			[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ignore Notifications", "lists whether or not notifications are enabled for this conversation") action:@selector( toggleNotifications: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	if( [[[self windowController] allChatViewControllers] count] > 1 ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""];
		[item setRepresentedObject:self];
		[item setTarget:[JVChatController defaultController]];
		[menu addItem:item];
	}

	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Disconnect", "disconnect contextual menu item title" ) action:@selector( disconnect ) keyEquivalent:@""];
		[item setTarget:[self target]];
		[menu addItem:item];
	}

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""];
	[item setTarget:self];
	[menu addItem:item];

	return menu;
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( toggleNotifications: ) ) {
		if( [[self preferenceForKey:@"muted"] boolValue] )
			[menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
	}

	return YES;
}

- (NSImage *) icon {
	BOOL smallIcons = [[[self windowController] preferenceForKey:@"small drawer icons"] boolValue];
	if( smallIcons || [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
		return [NSImage imageNamed:@"privateChatTab"];
	return [NSImage imageNamed:@"directChatIcon"];
}

- (NSImage *) statusImage {
	if( _isActive && [[[self view] window] isKeyWindow] ) {
		_newMessageCount = 0;
		_newHighlightMessageCount = 0;
		[(MVApplicationController *)[NSApp delegate] updateDockTile];
		return nil;
	}

	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
		return ( [_waitingAlerts count] ? [NSImage imageNamed:NSImageNameCaution] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"privateChatTabNewMessage"] : [NSImage imageNamed:@"privateChatTabNewMessage"] ) : nil ) );

	return ( [_waitingAlerts count] ? [NSImage imageNamed:@"viewAlert"] : nil );
}

#pragma mark -

- (NSString *) identifier {
	if( [[self target] isKindOfClass:[MVDirectChatConnection class]] )
		return [NSString stringWithFormat:@"Direct Chat %@", [self user]];
	return [NSString stringWithFormat:@"Direct Chat %@ (%@)", [self user], [[self user] serverAddress]];
}

#pragma mark -

- (void) didUnselect {
	_newMessageCount = 0;
	_newHighlightMessageCount = 0;
	[(MVApplicationController *)[NSApp delegate] updateDockTile];
	_isActive = NO;
	[super didUnselect];
}

- (void) willSelect {
	_newMessageCount = 0;
	_newHighlightMessageCount = 0;
	[(MVApplicationController *)[NSApp delegate] updateDockTile];
}

- (void) didSelect {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] ) {
		[(JVSplitView *)[[[send superview] superview] superview] setPositionUsingName:@"JVChatSplitViewPosition"];
	} else [self textDidChange:nil];

	_newMessageCount = 0;
	_newHighlightMessageCount = 0;
	[(MVApplicationController *)[NSApp delegate] updateDockTile];
	_isActive = YES;

	[super didSelect];

	[_windowController reloadListItem:self andChildren:NO];
	[[[self view] window] makeFirstResponder:send];

	if( [_waitingAlerts count] )
		[[NSApplication sharedApplication] beginSheet:_waitingAlerts[0] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

#pragma mark -
#pragma mark Drag & Drop Support

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return YES;
}

- (void) handleDraggedFile:(NSString *) path {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	[[MVFileTransferController defaultController] addFileTransfer:[[self user] sendFile:path passively:passive]];
}

#pragma mark -
#pragma mark GUI Actions

- (IBAction) getInfo:(id) sender {
	[[JVInspectorController inspectorOfObject:self] show:sender];
}

#pragma mark -

- (void) showAlert:(NSPanel *) alert withName:(NSString *) name {
	if( _isActive && ! [[_windowController window] attachedSheet] ) {
		if( alert ) [[NSApplication sharedApplication] beginSheet:alert modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
	} else {
		if( name && _waitingAlertNames[name] ) {
			NSPanel *sheet = _waitingAlertNames[name];

			if( alert ) {
				_waitingAlerts[[_waitingAlerts indexOfObjectIdenticalTo:_waitingAlertNames[name]]] = alert;
				_waitingAlertNames[name] = alert;
			} else {
				[_waitingAlerts removeObjectAtIndex:[_waitingAlerts indexOfObjectIdenticalTo:_waitingAlertNames[name]]];
				[_waitingAlertNames removeObjectForKey:name];
			}

			NSReleaseAlertPanel( sheet );
		} else {
			if( name && alert ) _waitingAlertNames[name] = alert;
			if( alert ) [_waitingAlerts addObject:alert];
		}
	}

	[_windowController reloadListItem:self andChildren:NO];
}

#pragma mark -
#pragma mark Prefences/User Defaults

- (void) userDefaultsChanged:(NSNotification *) notification {
	[self checkTranscriptDirectoryState];
}

- (void) setPreference:(id) value forKey:(NSString *) key {
	NSParameterAssert( key != nil );
	NSParameterAssert( [key length] );

	if( value ) _settings[key] = value;
	else [_settings removeObjectForKey:key];

	if( [_settings count] ) [[NSUserDefaults standardUserDefaults] setObject:_settings forKey:[[self identifier] stringByAppendingString:@" Settings"]];
	else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[[self identifier] stringByAppendingString:@" Settings"]];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (id) preferenceForKey:(NSString *) key {
	NSParameterAssert( key != nil );
	NSParameterAssert( [key length] );
	return _settings[key];
}

- (void) checkTranscriptDirectoryState {
	BOOL loggingEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogChatRooms"] || [[NSUserDefaults standardUserDefaults] boolForKey:@"JVLogPrivateChats"];
	NSString *logs = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];
	if( loggingEnabled ) {
		NSFileManager *fileManager = [NSFileManager defaultManager];

		if ( ! [fileManager fileExistsAtPath:logs])
			[fileManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];

		NSInteger org = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptFolderOrganization"];
		if( org == 1 ) {
			logs = [logs stringByAppendingPathComponent:[[self user] serverAddress]];
			if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];
		} else if( org == 2 ) {
			logs = [logs stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%@)", [self target], [[self user] serverAddress]]];
			if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];
		} else if( org == 3 ) {
			logs = [logs stringByAppendingPathComponent:[[self user] serverAddress]];
			if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];

			logs = [logs stringByAppendingPathComponent:[self title]];
			if( ! [fileManager fileExistsAtPath:logs] ) [fileManager createDirectoryAtPath:logs withIntermediateDirectories:YES attributes:nil error:nil];
		}

		NSString *logName = nil;
		NSString *dateString = [NSDate formattedShortDateStringForDate:[NSDate date]];

		NSInteger session = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptSessionHandling"];
		if( ! session ) {
			BOOL nameFound = NO;
			NSUInteger i = 1;

			if( org ) logName = [NSString stringWithFormat:@"%@.colloquyTranscript", [self target]];
			else logName = [NSString stringWithFormat:@"%@ (%@).colloquyTranscript", [self target], [[self user] serverAddress]];
			nameFound = ! [fileManager fileExistsAtPath:[logs stringByAppendingPathComponent:logName]];

			while( ! nameFound ) {
				if( org ) logName = [NSString stringWithFormat:@"%@ %ld.colloquyTranscript", [self target], i++];
				else logName = [NSString stringWithFormat:@"%@ (%@) %ld.colloquyTranscript", [self target], [[self user] serverAddress], i++];
				nameFound = ! [fileManager fileExistsAtPath:[logs stringByAppendingPathComponent:logName]];
			}
		} else if( session == 1 ) {
			if( org ) logName = [NSString stringWithFormat:@"%@.colloquyTranscript", [self target]];
			else logName = [NSString stringWithFormat:@"%@ (%@).colloquyTranscript", [self target], [[self user] serverAddress]];
		} else if( session == 2 ) {
			if( org ) logName = [NSMutableString stringWithFormat:@"%@ %@.colloquyTranscript", [self target], dateString];
			else logName = [NSMutableString stringWithFormat:@"%@ (%@) %@.colloquyTranscript", [self target], [[self user] serverAddress], dateString];
			[(NSMutableString *)logName replaceOccurrencesOfString:@"/" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [logName length] )];
			[(NSMutableString *)logName replaceOccurrencesOfString:@":" withString:@"-" options:NSLiteralSearch range:NSMakeRange( 0, [logName length] )];
		}

		logs = [logs stringByAppendingPathComponent:logName];

		if( [fileManager fileExistsAtPath:logs] )
			[[self transcript] startNewSession];

		[[self transcript] setFilePath:logs];
		NSURL *connURL = [[self connection] url];
		NSString *targetName = nil;

		if( [_target respondsToSelector:@selector( name )] )
			targetName = [(MVChatRoom *)_target name];
		else if( [_target respondsToSelector:@selector( nickname )] )
			targetName = [(MVChatUser *)_target nickname];
		else targetName = [_target description];

		NSURL *source = [[NSURL alloc] initWithScheme:[connURL scheme] host:[connURL host] path:[[connURL path] stringByAppendingString:[NSString stringWithFormat:@"/%@", targetName]]];
		[[self transcript] setSource:source];
		[[self transcript] setAutomaticallyWritesChangesToFile:YES];
		[[self transcript] setElementLimit:0]; // start with zero limit
	}
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
	JVStyle *style = [sender representedObject][@"style"];
	NSString *variant = [sender representedObject][@"variant"];

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
	if( ! [[self connection] supportedStringEncodings] ) return;

	NSMenuItem *menuItem = nil;
	NSUInteger i = 0, count = 0;
	BOOL new = NO;
	if( ! [sender tag] ) {
		_encoding = (NSStringEncoding) [[self preferenceForKey:@"encoding"] intValue];
		if( ! _encoding ) _encoding = [[self connection] encoding];
	} else _encoding = (NSStringEncoding) [sender tag];

	if( ! _encodingMenu ) {
		_encodingMenu = [[NSMenu alloc] initWithTitle:@""];
		menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		[menuItem setImage:[NSImage imageNamed:@"encoding"]];
		[_encodingMenu addItem:menuItem];
		new = YES;
	}

	const NSStringEncoding *supportedEncodings = [[self connection] supportedStringEncodings];

	for( i = 0; supportedEncodings[i]; i++ ) {
		/* if( supportedEncodings[i] == (NSStringEncoding) -1 ) {
			if( new ) [_encodingMenu addItem:[NSMenuItem separatorItem]];
			continue;
		} */
		if( new ) menuItem = [[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:supportedEncodings[i]] action:@selector( changeEncoding: ) keyEquivalent:@""];
		else menuItem = (NSMenuItem *)[_encodingMenu itemAtIndex:i + 1];
		if( _encoding == supportedEncodings[i] ) {
			[menuItem setState:NSOnState];
		} else [menuItem setState:NSOffState];
		if( new ) {
			[menuItem setTag:supportedEncodings[i]];
			[_encodingMenu addItem:menuItem];
		}
	}

	if( ! _spillEncodingMenu ) _spillEncodingMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding menu toolbar item" )];
	count = [_spillEncodingMenu numberOfItems];
	for( i = 0; i < count; i++ ) [_spillEncodingMenu removeItemAtIndex:0];
	count = [_encodingMenu numberOfItems];
	for( i = 1; i < count; i++ ) [_spillEncodingMenu addItem:[(NSMenuItem *)[_encodingMenu itemAtIndex:i] copy]];

	if( _encoding != [[self connection] encoding] ) {
		[self setPreference:@(_encoding) forKey:@"encoding"];
	} else [self setPreference:nil forKey:@"encoding"];
}

#pragma mark -
#pragma mark Messages & Events

- (void) _performEmoticonSubstitutionOnStringIfNecessary:(NSMutableAttributedString *) string {
	if ([self emoticons] == [JVEmoticonSet textOnlyEmoticonSet])
		return;

	[[self emoticons] performEmoticonSubstitution:string];
}

- (void) addEventMessageToDisplay:(NSString *) message withName:(NSString *) name andAttributes:(NSDictionary *) attributes {
	if( ! _nibLoaded ) [self view];

	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] );

	// The message needs to be able to convert to UTF8, otherwise we can't display it.
	if( ! [message UTF8String] )
		return;

	JVMutableChatEvent *event = [JVMutableChatEvent chatEventWithName:name andMessage:message];
	[event setAttributes:attributes];

	[display setScrollbackLimit:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatScrollbackLimit"]];
	if( [[self transcript] automaticallyWritesChangesToFile] )
		[[self transcript] setElementLimit:( [display scrollbackLimit] * 2 )];

	JVChatEvent *newEvent = [[self transcript] appendEvent:event];
	[display appendChatTranscriptElement:newEvent];

	[[NSNotificationCenter chatCenter] postNotificationName:JVChatEventMessageWasProcessedNotification object:self userInfo:@{@"event": newEvent}];

	if( ! [[[_windowController window] representedFilename] length] )
		[self _refreshWindowFileProxy];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type
{
	[self addMessageToDisplay:message fromUser:user withAttributes:@{@"action": @(action)} withIdentifier:identifier andType:type];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(JVChatMessageType) type {
	if( ! _nibLoaded ) [self view];

	NSParameterAssert( message != nil );
	NSParameterAssert( user != nil );

	NSFont *baseFont = [[NSFontManager sharedFontManager] fontWithFamily:[[display preferences] standardFontFamily] traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:[[display preferences] defaultFontSize]];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(_encoding), @"StringEncoding", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]), @"IgnoreFontColors", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]), @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSTextStorage *messageString = [NSTextStorage attributedStringWithChatFormat:message options:options];

	if( ! messageString ) {
		options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);
		messageString = [[NSTextStorage alloc] initWithAttributedString:[NSMutableAttributedString attributedStringWithChatFormat:message options:options]];

		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:baseFont, NSFontAttributeName, nil];
		NSMutableAttributedString *error = [[NSMutableAttributedString alloc] initWithString:[@" " stringByAppendingString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" )] attributes:attributes];
		[error addAttribute:@"CSSClasses" value:[NSSet setWithObjects:@"error", @"encoding", nil] range:NSMakeRange( 1, ( [error length] - 1 ) )];
		[messageString appendAttributedString:error];
	}

	// The message needs to be able to convert to UTF8, otherwise we can't display it.
	if( ! [messageString length] || ! [[messageString string] UTF8String] ) {
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:baseFont, NSFontAttributeName, [NSSet setWithObjects:@"error", @"encoding", nil], @"CSSClasses", nil];
		messageString = [[NSTextStorage alloc] initWithString:NSLocalizedString( @"incompatible encoding", "encoding of the message different than your current encoding" ) attributes:attributes];
	}

	JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:messageString sender:user];
	if (msgAttributes[@"time"]) [cmessage setDate:msgAttributes[@"time"]];
	[cmessage setMessageIdentifier:identifier];
	[cmessage setAttributes:msgAttributes];
	[cmessage setAction:[msgAttributes[@"action"] boolValue]];
	[cmessage setType:type];

	if ( !cmessage )
		return;

	messageString = [cmessage body]; // just incase

	if( !messageString) {
		return;
	}

	[self _setCurrentMessage:cmessage];

	if( ! [user isLocalUser] )
		[cmessage setIgnoreStatus:[[JVChatController defaultController] shouldIgnoreUser:user withMessage:messageString inView:self]];

	if( ! [user isLocalUser] && [cmessage ignoreStatus] == JVNotIgnored )
		_newMessageCount++;

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] ) {
		[messageString makeLinkAttributesAutomatically];
		[self _hyperlinkRoomNames:messageString];
	}

	[self _performEmoticonSubstitutionOnStringIfNecessary:messageString];

	if( ! [user isLocalUser] ) {
		NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
		NSMutableArray *names = [[[NSUserDefaults standardUserDefaults] stringArrayForKey:@"MVChatHighlightNames"] mutableCopy];
		if( [self connection] )
			[names addObject:[[self connection] nickname]];

		NSRegularExpression *regex = nil;

		for( __strong NSString *name in names ) {
			if( ! [name length] ) continue;

			if( [name hasPrefix:@"/"] && [name hasSuffix:@"/"] && [name length] > 1 ) {
				regex = [NSRegularExpression cachedRegularExpressionWithPattern:[name substringWithRange:NSMakeRange( 1, [name length] - 2 )] options:NSRegularExpressionCaseInsensitive error:nil];
			} else {
				name = [name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
				NSString *pattern = [NSString stringWithFormat:@"(?<=^|\\s|[^\\w])%@(?=$|\\s|[^\\w])", [name stringByEscapingCharactersInSet:escapeSet]];
				regex = [NSRegularExpression cachedRegularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
			}

			NSArray *matches = [regex matchesInString:[messageString string] options:0 range:NSMakeRange( 0, [messageString string].length ) ];
			for( NSTextCheckingResult *match in matches ) {
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

	if( [cmessage isHighlighted] && [cmessage ignoreStatus] == JVNotIgnored ) {
		_newHighlightMessageCount++;
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		context[@"title"] = [NSString stringWithFormat:NSLocalizedString( @"%@ Mentioned a Highlight Word", "mention bubble title" ), [user displayName]];
		context[@"description"] = [messageString string];
		context[@"image"] = [NSImage imageNamed:@"activityNewImportant"];
		context[@"target"] = self;
		context[@"action"] = NSStringFromSelector( @selector( activate: ) );
		[self performNotification:@"JVChatMentioned" withContextInfo:context];
	}

	if( [cmessage ignoreStatus] != JVNotIgnored ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		context[@"title"] = ( ( [cmessage ignoreStatus] == JVUserIgnored ) ? NSLocalizedString( @"User Ignored", "user ignored bubble title" ) : NSLocalizedString( @"Message Ignored", "message ignored bubble title" ) );
		if( [self isMemberOfClass:[JVChatRoomPanel class]] ) context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@'s message was ignored in %@.", "chat room user ignored bubble text" ), user, [self title]];
		else context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@'s message was ignored.", "direct chat user ignored bubble text" ), user];
		context[@"image"] = [NSImage imageNamed:@"activity"];
		[self performNotification:( ( [cmessage ignoreStatus] == JVUserIgnored ) ? @"JVUserIgnored" : @"JVMessageIgnored" ) withContextInfo:context];
	}

	[display setScrollbackLimit:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatScrollbackLimit"]];
	if( [[self transcript] automaticallyWritesChangesToFile] )
		[[self transcript] setElementLimit:( [display scrollbackLimit] * 2 )];

	JVChatMessage *newMessage = [[self transcript] appendMessage:cmessage];
	if( [display appendChatMessage:newMessage] ) {
		if( [cmessage isHighlighted] ) [display markScrollbarForMessage:newMessage];
		[self quickSearchMatchMessage:newMessage];
		_firstMessage = NO; // not the first message anymore
	} else if( [cmessage ignoreStatus] == JVNotIgnored ) {
		// the style decided to excluded this message, decrease the new message counts
		if( [cmessage isHighlighted] ) _newHighlightMessageCount--;
		_newMessageCount--;
	}

	if( [cmessage ignoreStatus] == JVNotIgnored ) {
		NSString *voiceIdentifier = [[[MVBuddyListController sharedBuddyList] buddyForUser:user] speechVoice];
		if( [voiceIdentifier length] ) {
			NSString *text = [cmessage bodyAsPlainText];
			if( [cmessage isAction] ) text = [NSString stringWithFormat:@"%@ %@", [[cmessage sender] displayName], text];
			[[JVSpeechController sharedSpeechController] startSpeakingString:text usingVoice:voiceIdentifier];
		}
	}

	[[NSNotificationCenter chatCenter] postNotificationName:JVChatMessageWasProcessedNotification object:self userInfo:@{@"message": newMessage}];

	[self _setCurrentMessage:nil];

	[_windowController reloadListItem:self andChildren:NO];

	if( ! [[[_windowController window] representedFilename] length] )
		[self _refreshWindowFileProxy];

	[(MVApplicationController *)[NSApp delegate] updateDockTile];
}

- (void) processIncomingMessage:(JVMutableChatMessage *) message {
	if( [[message sender] respondsToSelector:@selector( isLocalUser )] && ! [[message sender] isLocalUser] ) {
		if( [message ignoreStatus] == JVNotIgnored && _firstMessage ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			context[@"title"] = NSLocalizedString( @"New Private Message", "first message bubble title" );
			context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@ wrote you a private message.", "first message bubble text" ), [self title]];
			context[@"image"] = [NSImage imageNamed:@"directChatIcon"];
			context[@"coalesceKey"] = [[self windowTitle] stringByAppendingString:@"JVChatPrivateMessage"];
			context[@"target"] = self;
			context[@"action"] = NSStringFromSelector( @selector( activate: ) );
			context[@"subtitle"] = [NSString stringWithFormat:@"%@: %@", self.target, [message bodyAsPlainText]];
			[self performNotification:@"JVChatFirstMessage" withContextInfo:context];
		} else if( [message ignoreStatus] == JVNotIgnored ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			context[@"title"] = NSLocalizedString( @"Private Message", "new message bubble title" );
			if( [self newMessagesWaiting] == 1 ) context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"You have 1 message waiting from %@.", "new single message bubble text" ), [self title]];
			context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"You have %d messages waiting from %@.", "new messages bubble text" ), [self newMessagesWaiting], [self title]];
			context[@"image"] = [NSImage imageNamed:@"directChatIcon"];
			context[@"coalesceKey"] = [[self windowTitle] stringByAppendingString:@"JVChatPrivateMessage"];
			context[@"target"] = self;
			context[@"action"] = NSStringFromSelector( @selector( activate: ) );
			context[@"subtitle"] = [NSString stringWithFormat:@"%@: %@", self.target, [message bodyAsPlainText]];
			[self performNotification:@"JVChatAdditionalMessages" withContextInfo:context];
		}
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processIncomingMessage:inView: )];
	MVAddUnsafeUnretainedAddress(message, 2);
	MVAddUnsafeUnretainedAddress(self, 3);

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

	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:@([self encoding]), @"StringEncoding", cformat, @"FormatType", nil];
	NSData *msgData = [[message body] chatFormatWithOptions:options]; // we could save this back to the message object before sending
	[self addMessageToDisplay:msgData fromUser:[message sender] withAttributes:[message attributes] withIdentifier:[message messageIdentifier] andType:[message type]];
}

- (NSUInteger) newMessagesWaiting {
	return _newMessageCount;
}

- (NSUInteger) newHighlightMessagesWaiting {
	return _newHighlightMessageCount;
}

- (JVMutableChatMessage *) currentMessage {
	return _currentMessage;
}

#pragma mark -
#pragma mark History manipulation

- (void) addMessageToHistory:(NSAttributedString *) message {
	if( ! [message length] ) return;
	if( [_sendHistory count] )
		_sendHistory[0] = [[NSAttributedString alloc] initWithString:@""];
	[_sendHistory insertObject:[message copy] atIndex:1];
	if( [_sendHistory count] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatMaximumHistory"] unsignedIntValue] )
		[_sendHistory removeObjectAtIndex:[_sendHistory count] - 1];	
}

#pragma mark -
#pragma mark Notifications Handling

/**
 * This method should be used to handle all notification processing. It will check to see if
 * notifications have been muted for the given chat room, and if they have, it will not pass
 * the notification request on to the JVNotificationController.
 */
- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context {
	if( ![[self preferenceForKey:@"muted"] boolValue] )
		[[JVNotificationController defaultController] performNotification:identifier withContextInfo:context];
}

/**
 * Toggles notifications (this is for private, direct user-user chats)
 */
- (IBAction) toggleNotifications:(id) sender {
	if( [[self preferenceForKey:@"muted"] isEqual:@YES] )
		[self setPreference:@NO forKey:@"muted"];
	else [self setPreference:@YES forKey:@"muted"];
}

#pragma mark -
#pragma mark Input Handling

- (IBAction) send:(id) sender {
	NSTextStorage *subMsg = nil;
	__block BOOL action = NO;
	NSRange range;

	// allow commands to be passed to plugins if we arn't connected, allow commands to pass to plugins and server if we are just out of the room
	if( ( _cantSendMessages || ! [self isEnabled] ) && ( ! [[[send textStorage] string] hasPrefix:@"/"] || [[[send textStorage] string] hasPrefix:@"//"] ) ) {
		if( [[self target] isKindOfClass:[MVChatUser class]] && [[self user] status] == MVChatUserOfflineStatus ) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString( @"User \"%@\" is not online", "user not online alert dialog title" ), [[self user] displayName]]];
			[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString( @"The user \"%@\" is not online and is unavailable until they reconnect.", "user not online alert dialog message" ), [[self user] displayName]]];
			[alert setAlertStyle:NSInformationalAlertStyle];
			[alert runModal];
		}
		return;
	}

	// ask if the user really wants to send a message with lots of newlines.
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVWarnOnLargeMessages"] ) {
		NSUInteger newlineCount = 0;
		NSUInteger messageLimit = 5;

		NSArray *lines = [[[send textStorage] string] componentsSeparatedByString:@"\n"];

		for( NSString *line in lines )
			if( [line length] ) newlineCount++;

		if ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVWarnOnLargeMessageLimit"] unsignedIntValue] > 1 )
			messageLimit = [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVWarnOnLargeMessageLimit"] unsignedIntValue];

		if ( newlineCount > messageLimit ) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:NSLocalizedString( @"Multiple lines detected", "multiple lines detected alert dialog title")];
			[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString( @"You are about to send a message with %d lines. Are you sure you want to do this?", "about to send a %d line message alert dialog message" ), newlineCount]];
			[alert addButtonWithTitle:NSLocalizedString( @"Send", "Send alert dialog button title" )];
			[alert addButtonWithTitle:NSLocalizedString( @"Cancel", "Cancel alert dialog button title" )];
			[alert setAlertStyle:NSWarningAlertStyle];

			if ( [alert runModal] == NSAlertSecondButtonReturn ) return;
		}
	}

	_historyIndex = 0;
	if( ! [[send string] length] ) return;
	[self addMessageToHistory:[send textStorage]];

	if( [sender isKindOfClass:[NSNumber class]] && [sender boolValue] ) action = YES;

	[[[send textStorage] mutableString] replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange( 0, [[send string] length] )];
	NSTextStorage *storage = [[send textStorage] mutableCopy];

	while( [[storage string] length] ) {
		range = [[storage string] rangeOfString:@"\n"];
		if( ! range.length ) range.location = [[storage string] length];
		subMsg = [[storage attributedSubstringFromRange:NSMakeRange( 0, range.location )] mutableCopy];

		if( ( [subMsg length] >= 1 && range.length ) || ( [subMsg length] && ! range.length ) ) {
			if( [[subMsg string] hasPrefix:@"/"] && ! [[subMsg string] hasPrefix:@"//"] ) {
				NSScanner *scanner = [NSScanner scannerWithString:[subMsg string]];
				NSString *command = nil;
				NSAttributedString *arguments = nil;

				[scanner scanString:@"/" intoString:nil];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&command];
				if( [[subMsg string] length] >= [scanner scanLocation] + 1 )
					[scanner setScanLocation:[scanner scanLocation] + 1];

				arguments = [subMsg attributedSubstringFromRange:NSMakeRange( [scanner scanLocation], range.location - [scanner scanLocation] )];

				if( ![self processUserCommand:command withArguments:arguments] && [[self connection] isConnected] )
					[[self connection] sendCommand:command withArguments:arguments];
			} else {
				if( [[subMsg string] hasPrefix:@"//"] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendDoubleSlashes"] ) [subMsg deleteCharactersInRange:NSMakeRange( 0, 1 )];
				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatNaturalActions"] && ! action ) {
					if( ! actionVerbs ) {
						NSArray *verbs = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"verbs" ofType:@"plist"]];
						actionVerbs = [[NSSet allocWithZone:nil] initWithArray:verbs];
					}

					NSScanner *scanner = [[NSScanner alloc] initWithString:[subMsg string]];
					[scanner setCharactersToBeSkipped:nil];

					NSString *word = nil;
					[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&word];

					if ([actionVerbs containsObject:word])
						action = YES;
				}

				if( [subMsg length] ) {
					MVChatUser* localUser = ( [[self target] isKindOfClass:[MVChatRoom class]] ? [[self target] localMemberUser] : [[self connection] localUser] );
					JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:subMsg sender:localUser];
					[cmessage setAction:action];

					[self sendMessage:cmessage];
					[self echoSentMessageToDisplay:cmessage]; // echo after the plugins process the message
				}
			}
		}

		if( range.length ) range.location++;
		[storage deleteCharactersInRange:NSMakeRange( 0, range.location )];
	}

	NSDictionary *typingAttributes = [send typingAttributes];

	[send reset:nil];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputRetainsFormatting"] )
		[send setTypingAttributes:typingAttributes];

	[self textDidChange:nil];
	[display scrollToBottom];
}

- (void) sendMessage:(JVMutableChatMessage *) message {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), @encode( JVMutableChatMessage * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	[invocation setSelector:@selector( processOutgoingMessage:inView: )];
	MVAddUnsafeUnretainedAddress(message, 2);
	MVAddUnsafeUnretainedAddress(self, 3);

	[self _setCurrentMessage:message];
	[[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
	[self _setCurrentMessage:nil];

	if( [[message body] length] )
		[[self target] sendMessage:[message body] withEncoding:_encoding withAttributes:[message attributes]];
}

- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( MVChatConnection * ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

	MVChatConnection *connection = [self connection];

	[invocation setSelector:@selector( processUserCommand:withArguments:toConnection:inView: )];
	MVAddUnsafeUnretainedAddress(command, 2);
	MVAddUnsafeUnretainedAddress(arguments, 3);
	MVAddUnsafeUnretainedAddress(connection, 4);
	MVAddUnsafeUnretainedAddress(self, 5);

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

- (IBAction) markDisplay:(id) sender {
	[display mark];
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
		[self send:@YES];
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
	} else if( ([event modifierFlags] & NSControlKeyMask) != 0 ) {
		[self send:@YES];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatSendOnReturn"] ) {
		[self send:nil];
		ret = YES;
	} else if( [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatActionOnReturn"] ) {
		[self send:@YES];
		ret = YES;
	}

	return ret;
}

- (BOOL) upArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		_sendHistory[0] = [[send textStorage] copy];

	_historyIndex++;

	if( _historyIndex >= (NSInteger) [_sendHistory count] ) {
		if( [_sendHistory count] >= 1 )
			_historyIndex = [_sendHistory count] - 1;
		else _historyIndex = 0;
		return YES;
	}

	[send reset:nil];
	[[send textStorage] insertAttributedString:_sendHistory[_historyIndex] atIndex:0];

	return YES;
}

- (BOOL) downArrowKeyPressed {
	if( ! _historyIndex && [_sendHistory count] )
		_sendHistory[0] = [[send textStorage] copy];

	if( [[send string] length] ) _historyIndex--;

	if( _historyIndex < 0 ) {
		[send reset:nil];
		_historyIndex = -1;
		return YES;
	} else if( ! [_sendHistory count] ) {
		_historyIndex = 0;
		return YES;
	}

	[send reset:nil];
	[[send textStorage] insertAttributedString:_sendHistory[_historyIndex] atIndex:0];

	return YES;
}

- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event {
	unichar chr = 0;

	if( [[event charactersIgnoringModifiers] length] ) {
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];
	} else return NO;

	// exclude device-dependent flags, caps-lock and fn key (necessary for pg up/pg dn/home/end on portables)
	if( [event modifierFlags] & ~( NSFunctionKeyMask | NSNumericPadKeyMask | NSAlphaShiftKeyMask | NSAlternateKeyMask | 0xffff ) ) return NO;

	BOOL usesOnlyArrows = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendHistoryUsesOnlyArrows"];

	if( chr == NSUpArrowFunctionKey && ( usesOnlyArrows || [event modifierFlags] & NSAlternateKeyMask ) ) {
		return [self upArrowKeyPressed];
	} else if( chr == NSDownArrowFunctionKey && ( usesOnlyArrows || [event modifierFlags] & NSAlternateKeyMask ) ) {
		return [self downArrowKeyPressed];
	} else if( chr == NSPageUpFunctionKey || chr == NSPageDownFunctionKey || chr == NSHomeFunctionKey || chr == NSBeginFunctionKey || chr == NSEndFunctionKey ) {
		[[[[display mainFrame] findFrameNamed:@"content"] frameView] keyDown:event];
		return YES;
	}

	return NO;
}

- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputRetainsFormatting"] || ! [[send string] length] )
		[send reset:nil];
	else [send setString:@""];
	return YES;
}

- (NSArray *) textView:(NSTextView *) textView stringCompletionsForPrefix:(NSString *) prefix {
	NSMutableArray *possibleCompletion = [NSMutableArray array];

	if( [[self title] rangeOfString:prefix options:( NSCaseInsensitiveSearch | NSAnchoredSearch )].location == 0 )
		[possibleCompletion addObject:[self title]];
	if( [[[self connection] nickname] rangeOfString:prefix options:( NSCaseInsensitiveSearch | NSAnchoredSearch )].location == 0 )
		[possibleCompletion addObject:[[self connection] nickname]];

	static NSArray *commands;
	if (!commands) commands = @[@"/me ", @"/msg ", @"/nick ", @"/away ", @"/say ", @"/raw ", @"/quote ", @"/join ", @"/quit ", @"/disconnect ", @"/query ", @"/umode ", @"/google ", @"/part "];

	for( NSString *name in commands )
		if ([name hasCaseInsensitivePrefix:prefix])
			[possibleCompletion addObject:name];

	for ( MVChatRoom* room in self.connection.knownChatRooms )
	{
		if ( [room.uniqueIdentifier hasCaseInsensitivePrefix:prefix] )
			[possibleCompletion addObject:room.uniqueIdentifier];
		if ( [room.displayName hasCaseInsensitivePrefix:prefix] )
			[possibleCompletion addObject:room.displayName];
	}

	return possibleCompletion;
}

- (NSArray *) textView:(NSTextView *) textView completions:(NSArray *) words forPartialWordRange:(NSRange) charRange indexOfSelectedItem:(NSInteger *) index {
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	NSString *search = [[[send textStorage] string] substringWithRange:charRange];
	NSMutableArray *ret = [NSMutableArray array];
	NSString *suffix = ( ! ( [event modifierFlags] & NSAlternateKeyMask ) ? ( charRange.location == 0 ? @": " : @" " ) : @"" );
	NSString *comparison = [[[self user] nickname] substringToIndex:[search length]];

	if( [search length] <= [[self title] length] && comparison && [search caseInsensitiveCompare:comparison] == NSOrderedSame )
		[ret addObject:[[self title] stringByAppendingString:suffix]];
	comparison = [[[self connection] nickname] substringToIndex:[search length]];
	if( [search length] <= [[[self connection] nickname] length] && comparison && [search caseInsensitiveCompare:comparison] == NSOrderedSame )
		[ret addObject:[[[self connection] nickname] stringByAppendingString:suffix]];

	unichar chr = 0;
	if( [[event charactersIgnoringModifiers] length] )
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];

	if( chr != NSTabCharacter ) [ret addObjectsFromArray:words];
	return ret;
}

- (void) textDidChange:(NSNotification *) notification {
	_historyIndex = 0;

	if( ! [[send string] length] && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputRetainsFormatting"] )
		[send reset:nil];

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
	float newContentHeight =  MIN( maxContentHeight, MAX( 22., contentSize.height + 8. ) );

	if( newContentHeight == NSHeight( sendFrame ) ) return;

	NSRect webFrame = [display frame];

	// Set size of the web view to the maximum size possible
	webFrame.size.height = NSHeight( splitViewFrame ) - dividerThickness - newContentHeight;
	webFrame.origin = NSMakePoint( 0., 0. );

	// Keep the send box the same size
	sendFrame.size.height = newContentHeight;
	sendFrame.origin.y = NSHeight( webFrame ) + dividerThickness;

	_scrollerIsAtBottom = [display scrolledNearBottom];

	// Commit the changes
	[[[send superview] superview] setFrame:sendFrame];
	[display setFrame:webFrame];

	[splitView adjustSubviews];

	if( _scrollerIsAtBottom ) [display scrollToBottom];
}

#pragma mark -
#pragma mark SplitView Support

- (CGFloat) splitView:(NSSplitView *) splitView constrainSplitPosition:(CGFloat) proposedPosition ofSubviewAt:(NSInteger) index {
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		return ( NSHeight( [[splitView subviews][index] frame] ) ); // prevents manual resize
	return proposedPosition;
}

- (void) splitViewDidResizeSubviews:(NSNotification *) notification {
	// Cache the height of the send box so we can keep it constant during window resizes.
	NSRect sendFrame = [[[send superview] superview] frame];
	_sendHeight = sendFrame.size.height;

	if( _scrollerIsAtBottom ) [display scrollToBottom];

	if( ! _forceSplitViewPosition && ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputAutoResizes"] )
		[(JVSplitView *)[notification object] savePositionUsingName:@"JVChatSplitViewPosition"];

	_forceSplitViewPosition = NO;
}

- (void) splitViewWillResizeSubviews:(NSNotification *) notification {
	_scrollerIsAtBottom = [display scrolledNearBottom];
}

- (void) splitView:(NSSplitView *) sender resizeSubviewsWithOldSize:(NSSize) oldSize {
	float dividerThickness = [sender dividerThickness];
	NSRect newFrame = [sender frame];

	// Keep the size of the send box constant during window resizes

	// We need to resize the scroll view frames of the webview and the textview.
	// The scroll views are two superviews up: NSTextView(WebView) -> NSClipView -> NSScrollView
	NSRect sendFrame = [[[send superview] superview] frame];
	NSRect webFrame = [display frame];

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
	sendFrame = [send frame];
	sendFrame.size.width = newFrame.size.width;
	[send setFrame:sendFrame];

	[display setFrame:webFrame];
}

#pragma mark -
#pragma mark Toolbar Support

- (NSString *) toolbarIdentifier {
	return @"Direct Chat";
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	if( [identifier isEqual:JVToolbarTextEncodingItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Encoding", "encoding menu toolbar item" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Text Encoding", "encoding menu toolbar customize palette name" )];

		[toolbarItem setTarget:nil];
		[toolbarItem setAction:NULL];

		NSPopUpButton *button = [[NSPopUpButton alloc] initWithFrame:NSMakeRect( 0., 0., 53., 20. ) pullsDown:YES];
		[button setMenu:_encodingMenu];

		[toolbarItem setToolTip:NSLocalizedString( @"Text Encoding Options", "encoding menu toolbar item tooltip" )];
		[toolbarItem setMinSize:NSMakeSize( 60., 24. )];
		[toolbarItem setMaxSize:NSMakeSize( 60., 32. )];

		[toolbarItem setView:button];

		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding menu toolbar item" ) action:NULL keyEquivalent:@""];
		[menuItem setImage:[NSImage imageNamed:@"encoding"]];
		[menuItem setSubmenu:_spillEncodingMenu];

		[toolbarItem setMenuFormRepresentation:menuItem];

		return toolbarItem;
	} else if( [identifier isEqual:JVToolbarClearScrollbackItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Clear", "clear display toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Clear Display", "clear display toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Clear Display", "clear display tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"clear"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( clearDisplay: )];

		return toolbarItem;
	} else if( [identifier isEqual:JVToolbarMarkItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Mark", "mark display toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Mark Display", "mark display toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Mark Display", "mark display tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"markDisplay"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( markDisplay: )];

		return toolbarItem;
	} else if( [identifier isEqual:JVToolbarSendFileItemIdentifier] ) {
		NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

		[toolbarItem setLabel:NSLocalizedString( @"Send File", "send file toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Send File", "send file toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Send File", "send file toolbar tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"fileSend"]];

		[toolbarItem setTarget:[self user]];
		[toolbarItem setAction:@selector( sendFile: )];

		return toolbarItem;
	}

	return [super toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:willBeInserted];
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarDefaultItemIdentifiers:toolbar]];
	if( [self isMemberOfClass:[JVDirectChatPanel class]] ) {
		[list addObject:JVToolbarSendFileItemIdentifier];
		[list addObject:JVToolbarTextEncodingItemIdentifier];
		[list addObject:NSToolbarFlexibleSpaceItemIdentifier];
		[list addObject:JVToolbarMarkItemIdentifier];
		[list addObject:JVToolbarClearScrollbackItemIdentifier];
		[list addObject:NSToolbarSeparatorItemIdentifier];
		[list addObject:JVToolbarQuickSearchItemIdentifier];
	}
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
	if( [self isMemberOfClass:[JVDirectChatPanel class]] ) [list addObject:JVToolbarSendFileItemIdentifier];
	[list addObject:JVToolbarTextEncodingItemIdentifier];
	[list addObject:JVToolbarClearScrollbackItemIdentifier];
	[list addObject:JVToolbarMarkItemIdentifier];
	return list;
}

#pragma mark-
#pragma mark WebKit Support

- (NSArray *) webView:(WebView *) sender contextMenuItemsForElement:(NSDictionary *) element defaultMenuItems:(NSArray *) defaultMenuItems {
	NSMutableArray *ret = [NSMutableArray array];

	BOOL found = NO;

	for( NSMenuItem *item in defaultMenuItems ) {
		switch( [item tag] ) {
			case WebMenuItemTagCopy:
			case WebMenuItemTagDownloadLinkToDisk:
			case WebMenuItemTagDownloadImageToDisk:
				found = YES;
				break;
		}
	}

	if( ! found && ! [element[WebElementIsSelectedKey] boolValue] ) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Clear Display", "clear display contextual menu" ) action:NULL keyEquivalent:@""];
		[item setTarget:self];
		[item setAction:@selector( clearDisplay: )];
		[ret addObject:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Encoding", "encoding contextual menu" ) action:NULL keyEquivalent:@""];
		[item setSubmenu:_spillEncodingMenu];
		[ret addObject:item];
	}

	[ret addObjectsFromArray:[super webView:sender contextMenuItemsForElement:element defaultMenuItems:defaultMenuItems]];

	return ret;
}

#pragma mark -

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
	return _encodingMenu;
}

- (void) _hyperlinkRoomNames:(NSMutableAttributedString *) message {
	if( ! message || ! [message string] ) return;
	if( [[self connection] type] != MVChatConnectionIRCType ) return;

	// catch IRC rooms like "#room" but not HTML colors like "#ab12ef" nor HTML entities like "&#135;" or "&amp;"
	NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"\\B(?<!&)#(?![\\da-fA-F]{6}\\b|\\d{1,3}\\b)[\\w-_.+&#]{2,}\\b" options:NSRegularExpressionCaseInsensitive error:nil];
	NSArray *matches = [regex matchesInString:[message string] options:0 range:NSMakeRange( 0, [message string].length )];

	for( NSTextCheckingResult *match in matches ) {
		NSRange foundRange = [match range];
		NSString *text = [[message string] substringWithRange:foundRange];
		id currentLink = [message attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		if( ! currentLink ) [message addAttribute:NSLinkAttributeName value:[NSString stringWithFormat:@"%@://%@/%@", [[self connection] urlScheme], [[self connection] server], text] range:foundRange];
	}
}

- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message {
	return [self _convertRawMessage:message withBaseFont:nil];
}

- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont {
	if( ! message || ! [message length] ) return nil;

	if( ! baseFont ) baseFont = [[NSFontManager sharedFontManager] fontWithFamily:[[display preferences] standardFontFamily] traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:[[display preferences] defaultFontSize]];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:@(_encoding), @"StringEncoding", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]), @"IgnoreFontColors", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]), @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSMutableAttributedString *messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];

	if( ! messageString ) {
		options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);
		messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];
	}

	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] ) {
		[messageString makeLinkAttributesAutomatically];
		[self _hyperlinkRoomNames:messageString];
	}

	[self _performEmoticonSubstitutionOnStringIfNecessary:messageString];

	return messageString;
}

- (void) _alertSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	[[NSApplication sharedApplication] endSheet:sheet];
	[sheet orderOut:nil];

	[_waitingAlerts removeObjectIdenticalTo:sheet];

	id key = nil;
	for( key in _waitingAlertNames ) {
		id value = _waitingAlertNames[key];
		if( value == sheet ) break;
	}

	if( key ) [_waitingAlertNames removeObjectForKey:key];

	NSReleaseAlertPanel( sheet );

	if( [_waitingAlerts count] )
		[[NSApplication sharedApplication] beginSheet:_waitingAlerts[0] modalForWindow:[_windowController window] modalDelegate:self didEndSelector:@selector( _alertSheetDidEnd:returnCode:contextInfo: ) contextInfo:NULL];
}

- (void) _didConnect:(NSNotification *) notification {
	[self addEventMessageToDisplay:NSLocalizedString( @"You reconnected to the server.", "reconnected to server status message" ) withName:@"reconnected" andAttributes:nil];
	if( [self isMemberOfClass:[JVDirectChatPanel class]] )
		_cantSendMessages = NO;
}

- (void) _didDisconnect:(NSNotification *) notification {
	[self addEventMessageToDisplay:NSLocalizedString( @"You left the chat by being disconnected from the server.", "disconnect from the server status message" ) withName:@"disconnected" andAttributes:nil];
	_cantSendMessages = YES;
}

- (void) _errorOccurred:(NSNotification *) notification {
	NSError *error = [notification userInfo][@"error"];
	if( [error code] == MVChatConnectionNoSuchUserError ) {
		MVChatUser *user = [error userInfo][@"user"];
		if( [user isEqualTo:[self user]] )
			[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ is not online. Any messages sent will not be received.", "user not online" ), [[[self user] displayName] stringByEncodingXMLSpecialCharactersAsEntities]] withName:@"offline" andAttributes:nil];
	}
}

- (void) _awayStatusChanged:(NSNotification *) notification {
	if( [[self connection] awayStatusMessage] ) {
		NSMutableAttributedString *messageString = [[[self connection] awayStatusMessage] mutableCopy];

		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"MVChatDisableLinkHighlighting"] )
			[messageString makeLinkAttributesAutomatically];

		[self _performEmoticonSubstitutionOnStringIfNecessary:messageString];

		NSDictionary *options = @{@"IgnoreFonts": @YES, @"IgnoreFontSizes": @YES};
		NSString *msgString = [messageString HTMLFormatWithOptions:options];

		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"You have set yourself away with \"%@\".", "self away status set message" ), msgString] withName:@"awaySet" andAttributes:[NSDictionary dictionaryWithObjectsAndKeys:messageString, @"away-message", nil]];

		NSUInteger messageCount = [display _visibleMessageCount];
		NSUInteger loc = [display _locationOfElementAtIndex:( messageCount - 1 )];
		if( loc != NSNotFound ) [[display verticalMarkedScroller] startShadedAreaAt:loc];
	} else {
		[self addEventMessageToDisplay:NSLocalizedString( @"You have returned from away.", "self away status removed message" ) withName:@"awayRemoved" andAttributes:nil];

		NSUInteger messageCount = [display _visibleMessageCount];
		NSUInteger loc = [display _locationOfElementAtIndex:( messageCount - 1 )];
		if( loc != NSNotFound ) [[display verticalMarkedScroller] stopShadedAreaAt:loc];
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
		enumerator = [[[menu itemArray] copy] objectEnumerator];
		if( ! [menu indexOfItemWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )] )
			[enumerator nextObject];
		while( ( menuItem = [enumerator nextObject] ) )
			if( ! [menuItem tag] && ! [menuItem isSeparatorItem] )
				[menu removeItem:menuItem];
	}

	NSUInteger count = 0;
	if( ! [menu indexOfItemWithTitle:NSLocalizedString( @"Emoticons", "choose emoticons toolbar item label" )] )
		count++;

	NSArray *menuItems = [[self emoticons] emoticonMenuItems];
	for( menuItem in menuItems ) {
		[menuItem setAction:@selector( _insertEmoticon: )];
		[menuItem setTarget:self];
		[menu insertItem:menuItem atIndex:count++];
	}

	if( ! [menuItems count] ) {
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Selectable Emoticons", "no selectable emoticons menu item title" ) action:NULL keyEquivalent:@""];
		[menuItem setEnabled:NO];
		[menu insertItem:menuItem atIndex:count];
	}

	if( new ) {
		JVEmoticonSet *emoticon = nil;

		[menu addItem:[NSMenuItem separatorItem]];

		subMenu = [[NSMenu alloc] initWithTitle:@""];
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Preferences", "preferences menu item title" ) action:NULL keyEquivalent:@""];
		[menuItem setSubmenu:subMenu];
		[menuItem setTag:20];
		[menu addItem:menuItem];

		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Style Default", "default style emoticons menu item title" ) action:@selector( changeEmoticons: ) keyEquivalent:@""];
		[menuItem setTarget:self];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[NSMenuItem alloc] initWithTitle:[[JVEmoticonSet textOnlyEmoticonSet] displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[JVEmoticonSet textOnlyEmoticonSet]];
		[subMenu addItem:menuItem];

		[subMenu addItem:[NSMenuItem separatorItem]];

		enumerator = [[[[JVEmoticonSet emoticonSets] allObjects] sortedArrayUsingSelector:@selector( compare: )] objectEnumerator];
		while( ( emoticon = [enumerator nextObject] ) ) {
			if( ! [[emoticon displayName] length] ) continue;
			menuItem = [[NSMenuItem alloc] initWithTitle:[emoticon displayName] action:@selector( changeEmoticons: ) keyEquivalent:@""];
			[menuItem setTarget:self];
			[menuItem setRepresentedObject:emoticon];
			[subMenu addItem:menuItem];
		}

		[subMenu addItem:[NSMenuItem separatorItem]];

		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Appearance Preferences...", "appearance preferences menu item title" ) action:@selector( _openAppearancePreferences: ) keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setTag:10];
		[subMenu addItem:menuItem];
	}

	[self _changeEmoticonsMenuSelection];
}

- (IBAction) _insertEmoticon:(id) sender {
	if( [[send string] length] )
		[send replaceCharactersInRange:NSMakeRange( [[send string] length], 0 ) withString:@" "];
	[send replaceCharactersInRange:NSMakeRange( [[send string] length], 0 ) withString:[NSString stringWithFormat:@"%@ ", [sender representedObject]]];
}

- (BOOL) _usingSpecificStyle {
	return ( [self preferenceForKey:@"style"] ? YES : NO );
}

- (BOOL) _usingSpecificEmoticons {
	return ( [self preferenceForKey:@"emoticon"] ? YES : NO );
}

- (void) _didSwitchStyles:(NSNotification *) notification {
	[super _didSwitchStyles:notification];

	NSFont *baseFont = nil;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatInputUsesStyleFont"] ) {
		WebPreferences *preferences = [display preferences];
		// in some versions of WebKit (v125.9 at least), this is a font name, not a font family, try both
		NSString *fontFamily = [preferences standardFontFamily];
		NSInteger fontSize = [preferences defaultFontSize];
		baseFont = [NSFont fontWithName:fontFamily size:fontSize];
		if( ! baseFont ) baseFont = [[NSFontManager sharedFontManager] fontWithFamily:fontFamily traits:( NSUnboldFontMask | NSUnitalicFontMask ) weight:5 size:fontSize];
	}

	[send setBaseFont:baseFont];
}

- (void) consumeImageData:(NSData *) data forTag:(NSInteger) tag {
	_personImageData = data;
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
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [me uniqueId]] error:nil];
	} else {
		NSImage *icon = [[NSImage alloc] initWithData:_personImageData];
		NSData *imageData = [icon TIFFRepresentation];
		[imageData writeToFile:[NSString stringWithFormat:@"/tmp/%@.tif", [me uniqueId]] atomically:NO];

		_personImageData = nil;
	}
}

- (void) _saveBuddyIcon:(JVBuddy *) buddy {
	NSData *imageData = [[buddy picture] TIFFRepresentation];
	if( ! [imageData length] ) {
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]] error:nil];
		return;
	}

	[imageData writeToFile:[NSString stringWithFormat:@"/tmp/%@.tif", [buddy uniqueIdentifier]] atomically:NO];
}

- (void) _refreshIcon:(NSNotification *) notification {
	[_windowController reloadListItem:self andChildren:NO];
}

- (void) _setCurrentMessage:(JVMutableChatMessage *) message {
	[_currentMessage setObjectSpecifier:nil];
	_currentMessage = message;

	id classDescription = [NSClassDescription classDescriptionForClass:[self class]];
	id msgSpecifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:[self objectSpecifier] key:@"currentMessage"];
	[_currentMessage setObjectSpecifier:msgSpecifier];
}

- (void) _userNicknameDidChange:(NSNotification *) notification {
	if( ! _watchRule ) return;

	[[self connection] removeChatUserWatchRule:_watchRule];

	[_watchRule setNickname:[_target nickname]];

	[[self connection] addChatUserWatchRule:_watchRule];
}

- (void) _userStatusChanged:(NSNotification *) notification {
	if ([(MVChatUser *)_target status] == MVChatUserOfflineStatus)
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"%@ disconnected from the server.", "User disconnected event message" ), [[[self user] displayName] stringByEncodingXMLSpecialCharactersAsEntities]] withName:@"userDisconnected" andAttributes:nil];
	else if ([(MVChatUser *)_target status] == MVChatUserAwayStatus)
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> is marked as away.", "User marked as away event message" ), [[[self user] displayName] stringByEncodingXMLSpecialCharactersAsEntities]] withName:@"userAway" andAttributes:nil];
	else if ([(MVChatUser *)_target status] == MVChatUserAvailableStatus)
		[self addEventMessageToDisplay:[NSString stringWithFormat:NSLocalizedString( @"<span class=\"member\">%@</span> is now available.", "User available event message" ), [[[self user] displayName] stringByEncodingXMLSpecialCharactersAsEntities]] withName:@"userAvailable" andAttributes:nil];
}
@end

#pragma mark -

@implementation NSApplication (NSApplicationActivePanelScripting)
- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	// if there is a subject or target parameter, perform the default implementation
	if( [command subjectSpecifier] || [command evaluatedArguments][@"target"] ) {
		[command performDefaultImplementation];
		return;
	}

	// if nothing responds to this command make it perform on the active panel of the front window
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	id container = [[NSIndexSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:nil key:@"orderedWindows" index:0];
	if( ! container ) return;

	classDescription = [NSClassDescription classDescriptionForClass:[NSWindow class]];
	id specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"activeChatViewController"];
	if( ! specifier ) return;

	[command setSubjectSpecifier:specifier];
	[command performDefaultImplementation];
}

- (id) addEventMessageScriptCommand:(NSScriptCommand *) command {
	// if there is a subject, perform the default implementation
	if( [command subjectSpecifier] ) {
		[command performDefaultImplementation];
		return nil;
	}

	// if nothing responds to this command make it perform on the active panel of the front window
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	id container = [[NSIndexSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:nil key:@"orderedWindows" index:0];
	if( ! container ) return nil;

	classDescription = [NSClassDescription classDescriptionForClass:[NSWindow class]];
	id specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"activeChatViewController"];
	if( ! specifier ) return nil;

	[command setSubjectSpecifier:specifier];
	[command performDefaultImplementation];
	return nil;
}
@end

#pragma mark -

@implementation JVDirectChatPanel (JVDirectChatScripting)
- (void) sendMessageScriptCommand:(NSScriptCommand *) command {
	NSDictionary *args = [command evaluatedArguments];
	id message = [command evaluatedDirectParameter];
	id action = args[@"action"];
	id localEcho = args[@"echo"];

	if( args[@"message"] ) // support the old command that had a message parameter instead
		message = args[@"message"];

	if( ! message ) {
		[command setScriptErrorNumber:-1715]; // errAEParamMissed
		[command setScriptErrorString:@"The message was missing."];
		return;
	}

	if( ! [message isKindOfClass:[NSString class]] ) {
		message = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:message toClass:[NSString class]];
		if( ! [message isKindOfClass:[NSString class]] ) {
			[command setScriptErrorNumber:-1700]; // errAECoercionFail
			[command setScriptErrorString:@"The message was not a string value and coercion failed."];
			return;
		}
	}

	if( ! [(NSString *)message length] ) {
		[command setScriptErrorNumber:-1715]; // errAEParamMissed
		[command setScriptErrorString:@"The message can't be blank."];
		return;
	}

	if( action && ! [action isKindOfClass:[NSNumber class]] ) {
		action = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:action toClass:[NSNumber class]];
		if( ! [action isKindOfClass:[NSNumber class]] ) {
			[command setScriptErrorNumber:-1700]; // errAECoercionFail
			[command setScriptErrorString:@"The action tense parameter was not a boolean value and coercion failed."];
			return;
		}
	}

	if( localEcho && ! [localEcho isKindOfClass:[NSNumber class]] ) {
		localEcho = [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:localEcho toClass:[NSNumber class]];
		if( ! [localEcho isKindOfClass:[NSNumber class]] ) {
			[command setScriptErrorNumber:-1700]; // errAECoercionFail
			[command setScriptErrorString:@"The local echo parameter was not a boolean value and coercion failed."];
			return;
		}
	}

	NSAttributedString *realMessage = [NSAttributedString attributedStringWithHTMLFragment:message];
	BOOL realAction = ( action ? [action boolValue] : NO );
	BOOL realLocalEcho = ( localEcho ? [localEcho boolValue] : YES );

	JVMutableChatMessage *cmessage = [[JVMutableChatMessage alloc] initWithText:realMessage sender:[[self connection] localUser]];
	[cmessage setAction:realAction];

	[self sendMessage:cmessage];
	if( realLocalEcho ) [self echoSentMessageToDisplay:cmessage];

	return;
}

#pragma mark -

- (unsigned long) scriptTypedEncoding {
	return [NSString scriptTypedEncodingFromStringEncoding:[self encoding]];
}

- (void) setScriptTypedEncoding:(unsigned long) encoding {
	[self setPreference:@(encoding) forKey:@"encoding"];
	[self changeEncoding:self];
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
	id name = args[@"name"];
	id attributes = args[@"attributes"];

	if( [message isKindOfClass:[JVDirectChatPanel class]] ) {
		// this is from an old compiled script, flip the parameters
		target = message;
		message = args[@"message"];
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

	if( ! name ) name = NSLocalizedString( @"unknown", "unknown name for script event" );
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
	else targets = @[target];

	for( target in targets ) {
		if( ! [target isKindOfClass:[JVDirectChatPanel class]] ) continue;
		[target addEventMessageToDisplay:message withName:name andAttributes:attributes];
	}

	return nil;
}
@end
