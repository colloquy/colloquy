#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/NSMethodSignatureAdditions.h>
#import <ChatCore/NSURLAdditions.h>

#import "MVConnectionsController.h"
#import "JVConnectionInspector.h"
#import "MVApplicationController.h"
#import "MVChatPluginManager.h"
#import "JVChatController.h"
#import "JVChatRoomBrowser.h"
#import "MVKeyChain.h"
#import "JVChatRoom.h"
#import "JVDirectChat.h"

static MVConnectionsController *sharedInstance = nil;

static NSString *MVToolbarConnectToggleItemIdentifier   = @"MVToolbarConnectToggleItem";
static NSString *MVToolbarEditItemIdentifier			= @"MVToolbarEditItem";
static NSString *MVToolbarInspectorItemIdentifier		= @"MVToolbarInspectorItem";
static NSString *MVToolbarDeleteItemIdentifier			= @"MVToolbarDeleteItem";
static NSString *MVToolbarConsoleItemIdentifier			= @"MVToolbarConsoleItem";
static NSString *MVToolbarJoinRoomItemIdentifier		= @"MVToolbarJoinRoomItem";
static NSString *MVToolbarQueryUserItemIdentifier		= @"MVToolbarQueryUserItem";

static NSString *MVConnectionPboardType = @"Colloquy Chat Connection v1.0 pasteboard type";

static NSMenu *favoritesMenu = nil;

@interface MVConnectionsController (MVConnectionsControllerPrivate)
- (void) _connect:(id) sender;
- (void) _refresh:(NSNotification *) notification;
- (void) _loadInterfaceIfNeeded;
- (void) _saveBookmarkList;
- (void) _loadBookmarkList;
- (void) _validateToolbar;
- (void) _delete:(id) sender;
@end

#pragma mark -

@interface NSDisclosureButtonCell
+ (id) alloc;
- (id) initWithCell:(NSCell *) cell;
@end

#pragma mark -

@implementation MVConnectionsController
+ (MVConnectionsController *) defaultManager {
	extern MVConnectionsController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:nil] ) );
}

+ (NSMenu *) favoritesMenu {
	extern NSMenu *favoritesMenu;
	[self refreshFavoritesMenu];
	return favoritesMenu;
}

+ (void) refreshFavoritesMenu {
	extern NSMenu *favoritesMenu;
	if( ! favoritesMenu ) favoritesMenu = [[NSMenu alloc] initWithTitle:@""];

	NSMenuItem *menuItem = nil;
	NSEnumerator *enumerator = [[[[favoritesMenu itemArray] copy] autorelease] objectEnumerator];
	while( ( menuItem = [enumerator nextObject] ) )
		[favoritesMenu removeItem:menuItem];

	NSURL *url = nil;
	NSString *item = nil;
	NSMutableArray *rooms = [NSMutableArray array], *roomNames = [NSMutableArray array];
	NSMutableArray *users = [NSMutableArray array], *userNames = [NSMutableArray array];

	enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath]];
	while( ( item = [enumerator nextObject] ) ) {
		if( [[item pathExtension] isEqualToString:@"inetloc"] ) {
			url = [NSURL URLWithInternetLocationFile:[[NSString stringWithFormat:@"~/Library/Application Support/Colloquy/Favorites/%@", item] stringByExpandingTildeInPath]];
			if( [url isChatRoomURL] ) {
				[rooms addObject:url];
				[roomNames addObject:[item stringByDeletingPathExtension]];
			} else if( [url isDirectChatURL] ) {
				[users addObject:url];
				[userNames addObject:[item stringByDeletingPathExtension]];
			}
		}
	}

	if( ! [rooms count] && ! [users count] ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Favorites", "no favorites menu title" ) action:NULL keyEquivalent:@""] autorelease];
		[favoritesMenu addItem:menuItem];
	}

	NSEnumerator *nameEnumerator = [roomNames objectEnumerator];
	NSImage *icon = [[[NSImage imageNamed:@"room"] copy] autorelease];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize( 16., 16. )];
	enumerator = [rooms objectEnumerator];
	while( ( url = [enumerator nextObject] ) && ( item = [nameEnumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( _connectToFavorite: ) keyEquivalent:@""] autorelease];
		[menuItem setImage:icon];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:url];
		[favoritesMenu addItem:menuItem];
	}

	if( [users count] ) [favoritesMenu addItem:[NSMenuItem separatorItem]];

	enumerator = [users objectEnumerator];
	nameEnumerator = [userNames objectEnumerator];
	icon = [[[NSImage imageNamed:@"messageUser"] copy] autorelease];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize( 16., 16. )];
	while( ( url = [enumerator nextObject] ) && ( item = [nameEnumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:item action:@selector( _connectToFavorite: ) keyEquivalent:@""] autorelease];
		[menuItem setImage:icon];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:url];
		[favoritesMenu addItem:menuItem];
	}

	[favoritesMenu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Open Favorites folder...", "open favorites folder menu title" ) action:@selector( _openFavoritesFolder: ) keyEquivalent:@""] autorelease];
	[menuItem setTarget:self];
	[favoritesMenu addItem:menuItem];
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"MVConnections"] ) ) {
		_bookmarks = nil;
		_joinRooms = nil;
		_passConnection = nil;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationQuitting: ) name:NSApplicationWillTerminateNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionWillConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionDidNotConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionDidDisconnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionNicknameAcceptedNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _willConnect: ) name:MVChatConnectionWillConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _errorOccurred : ) name:MVChatConnectionErrorNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _requestPassword: ) name:MVChatConnectionNeedNicknamePasswordNotification object:nil];

		[self _loadBookmarkList];
	}
	return self;
}

- (void) dealloc {
	extern MVConnectionsController *sharedInstance;
	[self _saveBookmarkList];

	[connections setDelegate:nil];
	[connections setDataSource:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_bookmarks release];
	[_joinRooms release];
	[_passConnection release];

	_bookmarks = nil;
	_joinRooms = nil;
	_passConnection = nil;

	[super dealloc];
}

- (void) windowDidLoad {
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Connections"] autorelease];
	NSTableColumn *theColumn = nil;

	[newNickname setObjectValue:NSUserName()];
	[newUsername setObjectValue:NSUserName()];
	[newRealName setObjectValue:NSFullUserName()];

	[(NSPanel *)[self window] setFloatingPanel:NO];
	[[self window] setResizeIncrements:NSMakeSize( 1, [connections rowHeight] + [connections intercellSpacing].height - 1. )];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( windowWillClose: ) name:NSWindowWillCloseNotification object:[self window]];

	theColumn = [connections tableColumnWithIdentifier:@"auto"];
	[[theColumn headerCell] setImage:[NSImage imageNamed:@"autoHeader"]];

	theColumn = [connections tableColumnWithIdentifier:@"status"];
	[[theColumn headerCell] setImage:[NSImage imageNamed:@"statusHeader"]];

	[connections registerForDraggedTypes:[NSArray arrayWithObjects:MVConnectionPboardType,NSURLPboardType,@"CorePasteboardFlavorType 0x75726C20",nil]];

	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];

	[showDetails setCell:[[NSDisclosureButtonCell alloc] initWithCell:[showDetails cell]]];

	[self setWindowFrameAutosaveName:@"Connections"];
	[self _validateToolbar];
}

- (NSRect) windowWillUseStandardFrame:(NSWindow *) sender defaultFrame:(NSRect) defaultFrame {
	if( sender != [connections window] ) return defaultFrame;

	NSRect frame = [sender frame];
	NSScrollView *scrollView = [connections enclosingScrollView];
	float displayedHeight = [[scrollView contentView] bounds].size.height;
	float heightChange = [[scrollView documentView] bounds].size.height - displayedHeight;
	float heightExcess = 0.;

	if( heightChange >= 0 && heightChange <= 1 ) {
		// either the window is already optimal size, or it's too big
		float rowHeight = [connections rowHeight] + [connections intercellSpacing].height;
		heightChange = (rowHeight * [connections numberOfRows]) - displayedHeight;
	}

	frame.size.height += heightChange;

	if( ( heightExcess = [sender minSize].height - frame.size.height) > 1 || ( heightExcess = [sender maxSize].height - frame.size.height) < 1 ) {
		heightChange += heightExcess;
		frame.size.height += heightExcess;
	}

	frame.origin.y -= heightChange;

	return frame;
}

- (void) windowWillClose:(NSNotification *) notification {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVShowConnectionsWindowOnLaunch"];
}

#pragma mark -

- (id <JVInspection>) objectToInspect {
	if( [connections selectedRow] == -1 ) return nil;
	return [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"];
}

- (IBAction) getInfo:(id) sender {
	if( [connections selectedRow] == -1 ) return;
	MVChatConnection *conection = [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"];
	[[JVInspectorController inspectorOfObject:conection] show:sender];
}

#pragma mark -

- (IBAction) showConnectionManager:(id) sender {
	[[self window] makeKeyAndOrderFront:nil];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVShowConnectionsWindowOnLaunch"];
}

- (IBAction) hideConnectionManager:(id) sender {
	[[self window] orderOut:nil];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"JVShowConnectionsWindowOnLaunch"];
}

#pragma mark -

- (IBAction) newConnection:(id) sender {
	[self _loadInterfaceIfNeeded];
	if( [openConnection isVisible] ) return;
	[_joinRooms autorelease];
	_joinRooms = [[NSMutableArray array] retain];
	if( [showDetails state] != NSOffState ) {
		[showDetails setState:NSOffState];
		[self toggleNewConnectionDetails:showDetails];
	}
	[newServerPassword setObjectValue:@""];
	[openConnection center];
	[openConnection makeKeyAndOrderFront:nil];
}

- (IBAction) toggleNewConnectionDetails:(id) sender {
	float offset = NSHeight( [detailsTabView frame] );
	NSRect windowFrame = [openConnection frame];
	NSRect newWindowFrame = NSMakeRect( NSMinX( windowFrame ), NSMinY( windowFrame ) + ( [sender state] ? offset * -1 : offset ), NSWidth( windowFrame ), ( [sender state] ? NSHeight( windowFrame ) + offset : NSHeight( windowFrame ) - offset ) );
	if( ! [sender state] ) [detailsTabView selectTabViewItemAtIndex:0];
	[openConnection setFrame:newWindowFrame display:YES animate:YES];
	if( [sender state] ) [detailsTabView selectTabViewItemAtIndex:1];
}

- (IBAction) addRoom:(id) sender {
	[_joinRooms addObject:@""];
	[newJoinRooms noteNumberOfRowsChanged];
	[newJoinRooms selectRow:([_joinRooms count] - 1) byExtendingSelection:NO];
	[newJoinRooms editColumn:0 row:([_joinRooms count] - 1) withEvent:nil select:NO];
}

- (IBAction) removeRoom:(id) sender {
	if( [newJoinRooms selectedRow] == -1 || [newJoinRooms editedRow] != -1 ) return;
	[_joinRooms removeObjectAtIndex:[newJoinRooms selectedRow]];
	[newJoinRooms noteNumberOfRowsChanged];
}

- (IBAction) openNetworkPreferences:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Network.prefPane"];
}

- (IBAction) conenctNewConnection:(id) sender {
	MVChatConnection *connection = nil;

	if( ! [[newNickname stringValue] length] ) {
		[[self window] makeFirstResponder:newNickname];
		NSRunCriticalAlertPanel( NSLocalizedString( @"Nickname is blank", "chat invalid nickname dialog title" ), NSLocalizedString( @"The nickname is invalid because it was left blank.", "chat nickname blank dialog message" ), nil, nil, nil );
		return;
	}

	if( ! [[newAddress stringValue] length] ) {
		[[self window] makeFirstResponder:newAddress];
		NSRunCriticalAlertPanel( NSLocalizedString( @"Chat Server is blank", "chat invalid nickname dialog title" ), NSLocalizedString( @"The chat server is invalid because it was left blank.", "chat server blank dialog message" ), nil, nil, nil );
		return;
	}

	if( [newPort intValue] < 0 || [newPort intValue] > 65535 ) {
		[[self window] makeFirstResponder:newPort];
		NSRunCriticalAlertPanel( NSLocalizedString( @"Chat Server Port is invalid", "chat invalid nickname dialog title" ), NSLocalizedString( @"The chat server port you specified is invalid because it can't be negative or greater than 65535.", "chat server port invalid dialog message" ), nil, nil, nil );
		return;
	}

	if( ! [[newUsername stringValue] length] ) {
		if( [showDetails state] != NSOnState ) {
			[showDetails setState:NSOnState];
			[self toggleNewConnectionDetails:showDetails];
		}
		[[self window] makeFirstResponder:newUsername];
		NSRunCriticalAlertPanel( NSLocalizedString( @"Username is blank", "chat blank username dialog title" ), NSLocalizedString( @"The username is invalid because it was left blank.", "chat username blank dialog message" ), nil, nil, nil );
		return;
	}

	if( [[newUsername stringValue] rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location != NSNotFound ) {
		if( [showDetails state] != NSOnState ) {
			[showDetails setState:NSOnState];
			[self toggleNewConnectionDetails:showDetails];
		}
		[[self window] makeFirstResponder:newUsername];
		NSRunCriticalAlertPanel( NSLocalizedString( @"Username invalid", "chat invalid username dialog title" ), NSLocalizedString( @"The username you specified is invalid because it contains spaces or other non-alphanumeric characters.", "chat username blank dialog message" ), nil, nil, nil );
		return;
	}

	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id data = nil;

	while( ( data = [enumerator nextObject] ) ) {
		if( [[(MVChatConnection *)[data objectForKey:@"connection"] server] isEqualToString:[newAddress stringValue]] &&
			[[(MVChatConnection *)[data objectForKey:@"connection"] nickname] isEqualToString:[newNickname stringValue]] ) {
			if( [(MVChatConnection *)[data objectForKey:@"connection"] isConnected] ) {
				NSRunCriticalAlertPanel( NSLocalizedString( @"Already connected", "already connected dialog title" ), NSLocalizedString( @"The chat server with the nickname you specified is already connected to from this computer. Use another nickname if you desire multiple connections.", "chat already connected message" ), nil, nil, nil );
				[openConnection makeFirstResponder:newNickname];
			} else {
				[connections selectRow:[_bookmarks indexOfObject:data] byExtendingSelection:NO];
				[self _connect:nil];
				[[self window] makeKeyAndOrderFront:nil];
				[openConnection orderOut:nil];
			}
			return;
		}
	}

	[openConnection orderOut:nil];

	connection = [[[MVChatConnection alloc] init] autorelease];
	[connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];
	[connection setProxyType:[[newProxy selectedItem] tag]];
	[connection setSecure:[sslConnection state]];
	[connection setPassword:[newServerPassword stringValue]];
	[connection setUsername:[newUsername stringValue]];
	[connection setRealName:[newRealName stringValue]];
	[connection joinChatRooms:_joinRooms];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"] )
		[[JVChatController defaultManager] chatConsoleForConnection:connection ifExists:NO];

	[connection connectToServer:[newAddress stringValue] onPort:[newPort intValue] asUser:[newNickname stringValue]];

	[self addConnection:connection keepBookmark:(BOOL)[newRemember state]];
	[self setJoinRooms:_joinRooms forConnection:connection];

	[[self window] makeKeyAndOrderFront:nil];
}

#pragma mark -

- (IBAction) messageUser:(id) sender {
	[messageUser orderOut:nil];
	[[NSApplication sharedApplication] endSheet:messageUser];

	if( [connections selectedRow] == -1 ) return;

	if( [sender tag] ) {
		[[JVChatController defaultManager] chatViewControllerForUser:[userToMessage stringValue] withConnection:[[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"] ifExists:NO];
	}
}

- (IBAction) joinRoom:(id) sender {
	if( ! [_bookmarks count] ) return;
	JVChatRoomBrowser *browser = [JVChatRoomBrowser chatRoomBrowserForConnection:( [connections selectedRow] == -1 ? nil : [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"] )];
	[[NSApplication sharedApplication] beginSheet:[browser window] modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

#pragma mark -

- (IBAction) sendPassword:(id) sender {
	[nicknameAuth orderOut:nil];

	if( [sender tag] ) {
		[_passConnection setNicknamePassword:[authPassword stringValue]];

		if( [authKeychain state] == NSOnState ) {
			[[MVKeyChain defaultKeyChain] setInternetPassword:[authPassword stringValue] forServer:[_passConnection server] securityDomain:[_passConnection server] account:[_passConnection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
		}
	}

	[_passConnection autorelease];
	_passConnection = nil;
}

#pragma mark -

- (NSArray *) connections {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) )
		[ret addObject:[info objectForKey:@"connection"]];

	return [[ret retain] autorelease];
}

- (NSArray *) connectedConnections {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) )
		if( [[info objectForKey:@"connection"] isConnected] )
			[ret addObject:[info objectForKey:@"connection"]];

	return [[ret retain] autorelease];
}

- (MVChatConnection *) connectionForServerAddress:(NSString *) address {
	MVChatConnection *ret = nil;
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [[(MVChatConnection *)[info objectForKey:@"connection"] server] caseInsensitiveCompare:address] == NSOrderedSame ) {
			ret = [info objectForKey:@"connection"];
			if( [ret isConnected] ) return ret;
		}
	}

	return ret;
}

- (NSArray *) connectionsForServerAddress:(NSString *) address {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) )
		if( [[(MVChatConnection *)[info objectForKey:@"connection"] server] caseInsensitiveCompare:address] == NSOrderedSame )
			[ret addObject:[info objectForKey:@"connection"]];

	return [[ret retain] autorelease];
}

#pragma mark -

- (void) addConnection:(MVChatConnection *) connection {
	[self addConnection:connection keepBookmark:YES];
}

- (void) addConnection:(MVChatConnection *) connection keepBookmark:(BOOL) keep {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSDate date] forKey:@"created"];
	[info setObject:connection forKey:@"connection"];
	if( ! keep ) [info setObject:[NSNumber numberWithBool:YES] forKey:@"temporary"];

	[_bookmarks addObject:info];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];
}

- (void) insertConnection:(MVChatConnection *) connection atIndex:(unsigned) index {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSDate date] forKey:@"created"];
	[info setObject:connection forKey:@"connection"];

	[_bookmarks insertObject:info atIndex:index];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];
}

- (void) removeConnectionAtIndex:(unsigned) index {
	MVChatConnection *connection = [[_bookmarks objectAtIndex:index] objectForKey:@"connection"];
    [connection disconnect];

	[[MVKeyChain defaultKeyChain] setInternetPassword:nil forServer:[connection server] securityDomain:[connection server] account:[connection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
	[[MVKeyChain defaultKeyChain] setInternetPassword:nil forServer:[connection server] securityDomain:[connection server] account:nil path:nil port:[connection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];

	[_bookmarks removeObjectAtIndex:index];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];
}

- (void) replaceConnectionAtIndex:(unsigned) index withConnection:(MVChatConnection *) connection {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSDate date] forKey:@"created"];
	[info setObject:connection forKey:@"connection"];

	MVChatConnection *oldConnection = [[_bookmarks objectAtIndex:index] objectForKey:@"connection"];
    [oldConnection disconnect];

	[[MVKeyChain defaultKeyChain] setInternetPassword:nil forServer:[oldConnection server] securityDomain:[oldConnection server] account:[oldConnection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
	[[MVKeyChain defaultKeyChain] setInternetPassword:nil forServer:[oldConnection server] securityDomain:[oldConnection server] account:nil path:nil port:[oldConnection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];

	[_bookmarks replaceObjectAtIndex:index withObject:info];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];
}

#pragma mark -

- (void) handleURL:(NSURL *) url andConnectIfPossible:(BOOL) connect {
	if( [url isChatURL] ) {
		MVChatConnection *connection = nil;
		NSEnumerator *enumerator = [_bookmarks objectEnumerator];
		id data = nil;
		BOOL isRoom = YES;
		BOOL handled = NO;
		NSString *target = nil;

		if( [url fragment] ) {
			if( [[url fragment] length] > 0 ) {
				target = [url fragment];
				isRoom = YES;
			}
		} else if( [url path] && [[url path] length] >= 2 ) {
			target = [[url path] substringFromIndex:1];
			if( [[[url path] substringFromIndex:1] hasPrefix:@"&"] || [[[url path] substringFromIndex:1] hasPrefix:@"+"] || [[[url path] substringFromIndex:1] hasPrefix:@"!"] ) {
				isRoom = YES;
			} else {
				isRoom = NO;
			}
		}

		while( ( data = [enumerator nextObject] ) ) {
			connection = [data objectForKey:@"connection"];
			if( [[connection server] isEqualToString:[url host]] && ( ! [url user] || [[connection nickname] isEqualToString:[url user]] ) && ( ! [connection serverPort] || ! [[url port] unsignedShortValue] || [connection serverPort] == [[url port] unsignedShortValue] ) ) {
				if( ! [connection isConnected] && connect ) {
					if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"] )
						[[JVChatController defaultManager] chatConsoleForConnection:connection ifExists:NO];
					[connection connect];
				}
				if( target && isRoom ) [connection joinChatRoom:target];
				else if( target && ! isRoom ) [[JVChatController defaultManager] chatViewControllerForUser:target withConnection:connection ifExists:NO];
				else [[self window] orderFront:nil];
				[connections selectRow:[_bookmarks indexOfObject:data] byExtendingSelection:NO];
				handled = YES;
				break;
			}
		}

		if( ! handled && ! [url user] ) {
			[newAddress setObjectValue:[url host]];
			if( [url port] ) [newPort setObjectValue:[url port]];
			[self newConnection:nil];
			handled = YES;
		} else if( ! handled && [url user] ) {
			connection = [[[MVChatConnection alloc] initWithURL:url] autorelease];
			[connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];

			if( connect ) {
				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"] )
					[[JVChatController defaultManager] chatConsoleForConnection:connection ifExists:NO];
				[connection connect];
			}

			[self addConnection:connection keepBookmark:NO];

			[[self window] orderFront:nil];

			if( target && ! isRoom ) [[JVChatController defaultManager] chatViewControllerForUser:target withConnection:connection ifExists:NO];
		}
	}
}

#pragma mark -

- (void) setAutoConnect:(BOOL) autoConnect forConnection:(MVChatConnection *) connection {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSMutableDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( autoConnect ) [info setObject:[NSNumber numberWithBool:NO] forKey:@"temporary"];
			[info setObject:[NSNumber numberWithBool:autoConnect] forKey:@"automatic"];
			break;
		}
	}
}

- (BOOL) autoConnectForConnection:(MVChatConnection *) connection {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSMutableDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"connection"] == connection ) {
			return [[info objectForKey:@"automatic"] boolValue];
		}
	}

	return NO;
}

#pragma mark -

- (void) setJoinRooms:(NSArray *) rooms forConnection:(MVChatConnection *) connection {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSMutableDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( rooms ) [info setObject:[[rooms mutableCopy] autorelease] forKey:@"rooms"];
			else [info removeObjectForKey:@"rooms"];
			break;
		}
	}
}

- (NSArray *) joinRoomsForConnection:(MVChatConnection *) connection {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSMutableDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"connection"] == connection ) {
			return [info objectForKey:@"rooms"];
		}
	}

	return nil;
}

#pragma mark -

- (void) setConnectCommands:(NSString *) commands forConnection:(MVChatConnection *) connection {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSMutableDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( commands ) [info setObject:[[commands mutableCopy] autorelease] forKey:@"commands"];
			else [info removeObjectForKey:@"commands"];
			break;
		}
	}
}

- (NSString *) connectCommandsForConnection:(MVChatConnection *) connection {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSMutableDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"connection"] == connection ) {
			return [info objectForKey:@"commands"];
		}
	}

	return nil;
}

#pragma mark -

- (IBAction) cut:(id) sender {
	MVChatConnection *connection = nil;

	if( [connections selectedRow] == -1 ) return;
	connection = [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"];

	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil] owner:self];

	[[connection url] writeToPasteboard:[NSPasteboard generalPasteboard]];
	[[NSPasteboard generalPasteboard] setString:[[connection url] description] forType:NSStringPboardType];

	[self _delete:sender];
}

- (IBAction) copy:(id) sender {
	MVChatConnection *connection = nil;

	if( [connections selectedRow] == -1 ) return;
	connection = [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"];

	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil] owner:self];

	[[connection url] writeToPasteboard:[NSPasteboard generalPasteboard]];
	[[NSPasteboard generalPasteboard] setString:[[connection url] description] forType:NSStringPboardType];
}

- (IBAction) paste:(id) sender {
	NSURL *url = [NSURL URLFromPasteboard:[NSPasteboard generalPasteboard]];
	if( ! url ) url = [NSURL URLWithString:[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType]];
	[self handleURL:url andConnectIfPossible:NO];
}

- (IBAction) clear:(id) sender {
	[self _delete:sender];
}
@end

#pragma mark -

@implementation MVConnectionsController (MVConnectionsControllerDelegate)
- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( cut: ) ) {
		if( [connections selectedRow] == -1 ) return NO;
	} else if( [menuItem action] == @selector( copy: ) ) {
		if( [connections selectedRow] == -1 ) return NO;
	} else if( [menuItem action] == @selector( clear: ) ) {
		if( [connections selectedRow] == -1 ) return NO;
	} else if( [menuItem action] == @selector( joinRoom: ) ) {
		if( ! [_bookmarks count] ) return NO;
		else return YES;
	} else if( [menuItem action] == @selector( getInfo: ) ) {
		if( [connections selectedRow] == -1 ) return NO;
		else return YES;
	}
	return YES;
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	if( view == connections ) return [_bookmarks count];
	else if( view == newJoinRooms ) return [_joinRooms count];
	return 0;
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == connections ) {
		if( [[column identifier] isEqualToString:@"auto"] ) {
			return [[_bookmarks objectAtIndex:row] objectForKey:@"automatic"];
		} else if( [[column identifier] isEqualToString:@"address"] ) {
			return [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] server];
		} else if( [[column identifier] isEqualToString:@"port"] ) {
			return [NSNumber numberWithUnsignedInt:[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] serverPort]];
		} else if( [[column identifier] isEqualToString:@"nickname"] ) {
			return [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] nickname];
		}
	} else if( view == newJoinRooms ) {
		return [_joinRooms objectAtIndex:row];	
	}

	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == connections ) {
		if( [[column identifier] isEqual:@"status"] ) {
			if( [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] isConnected] ) {
				if( [view editedRow] != row && ( [view selectedRow] != row || ! [[view window] isKeyWindow] || ( [view selectedRow] == row && [[view window] firstResponder] != view ) ) ) [cell setImage:[NSImage imageNamed:@"connected"]];
				else [cell setImage:[NSImage imageNamed:@"connectedSelected"]];
			} else if( [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] status] == MVChatConnectionConnectingStatus ) {
				if( [view editedRow] != row && ( [view selectedRow] != row || ! [[view window] isKeyWindow] || ( [view selectedRow] == row && [[view window] firstResponder] != view ) ) ) [cell setImage:[NSImage imageNamed:@"connecting"]];
				else [cell setImage:[NSImage imageNamed:@"connectingSelected"]];
			} else {
				[cell setImage:nil];
			}
		}
	}
}

- (NSMenu *) tableView:(NSTableView *) view menuForTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == connections ) {
		NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
		NSMenuItem *item = nil;
		BOOL connected = [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] isConnected];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		if( connected ) {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Disconnect", "disconnect from server title" ) action:@selector( _disconnect: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		} else {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Connect", "connect to server title" ) action:@selector( _connect: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}

		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Join Room...", "join room contextual menu item title" ) action:@selector( joinRoom: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		if( ! [_bookmarks count] ) [item setAction:NULL];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Message User...", "message user contextual menu item title" ) action:@selector( _messageUser: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		if( ! connected ) [item setAction:NULL];
		[menu addItem:item];

		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Delete", "delete item title" ) action:@selector( _delete: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		return [[menu retain] autorelease];
	}

	return nil;
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == connections ) {
		MVChatConnection *connection = nil;
		if( [[column identifier] isEqual:@"auto"] ) {
			[[_bookmarks objectAtIndex:row] setObject:object forKey:@"automatic"];
			if( [object boolValue] )
				[[_bookmarks objectAtIndex:row] setObject:[NSNumber numberWithBool:NO] forKey:@"temporary"];
		} else if( [[column identifier] isEqual:@"nickname"] ) {
			[connection setNicknamePassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:object path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
			[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] setNickname:object];
		} else if( [[column identifier] isEqual:@"address"] ) {
			[connection setPassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:object securityDomain:object account:nil path:nil port:[connection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
			[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] setServer:object];
		} else if( [[column identifier] isEqual:@"port"] ) {
			[connection setPassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:nil path:nil port:[object unsignedShortValue] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
			[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] setServerPort:[object unsignedShortValue]];
		}
		[self _saveBookmarkList];
	} else if( view == newJoinRooms ) {
		[_joinRooms replaceObjectAtIndex:row withObject:object];		
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	if( [notification object] == connections ) {
		[[JVInspectorController sharedInspector] inspectObject:[self objectToInspect]];
		[self _validateToolbar];
	} else if( [notification object] == newJoinRooms ) {
		[newRemoveRoom setTransparent:( [newJoinRooms selectedRow] == -1 )];
		[newRemoveRoom highlight:NO];
	}
}

- (BOOL) tableView:(NSTableView *) view writeRows:(NSArray *) rows toPasteboard:(NSPasteboard *) board {
	if( view == connections ) {
		int row = [[rows lastObject] intValue];
		NSDictionary *info = nil;
		MVChatConnection *connection = nil;
		NSString *string = nil;
		NSData *data = nil;
		id plist = nil;

		if( row == -1 ) return NO;
		
		info = [_bookmarks objectAtIndex:row];
		connection = [info objectForKey:@"connection"];
		data = [NSData dataWithBytes:&row length:sizeof( &row )];

		[board declareTypes:[NSArray arrayWithObjects:MVConnectionPboardType, NSURLPboardType, NSStringPboardType, @"CorePasteboardFlavorType 0x75726C20", @"CorePasteboardFlavorType 0x75726C6E", @"WebURLsWithTitlesPboardType", nil] owner:self];

		[board setData:data forType:MVConnectionPboardType];

		[[connection url] writeToPasteboard:board];

		string = [[connection url] absoluteString];
		data = [string dataUsingEncoding:NSASCIIStringEncoding];
		[board setString:string forType:NSStringPboardType];
		[board setData:data forType:NSStringPboardType];

		string = [[connection url] absoluteString];
		data = [string dataUsingEncoding:NSASCIIStringEncoding];
		[board setString:string forType:@"CorePasteboardFlavorType 0x75726C20"];
		[board setData:data forType:@"CorePasteboardFlavorType 0x75726C20"];

		string = [[connection url] host];
		data = [string dataUsingEncoding:NSASCIIStringEncoding];
		[board setString:string forType:@"CorePasteboardFlavorType 0x75726C6E"];
		[board setData:data forType:@"CorePasteboardFlavorType 0x75726C6E"];

		plist = [NSArray arrayWithObjects:[NSArray arrayWithObject:[[connection url] absoluteString]], [NSArray arrayWithObject:[[connection url] host]], nil];
		data = [NSPropertyListSerialization dataFromPropertyList:plist format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
		string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		[board setPropertyList:plist forType:@"WebURLsWithTitlesPboardType"];
		[board setString:string forType:@"WebURLsWithTitlesPboardType"];
		[board setData:data forType:@"WebURLsWithTitlesPboardType"];
	}

	return YES;
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(int) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( view == connections ) {
		NSString *string = nil;
		int index = -1;

		if( operation == NSTableViewDropOn && row != -1 ) return NSDragOperationNone;

		string = [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:MVConnectionPboardType]];
		[[[info draggingPasteboard] dataForType:MVConnectionPboardType] getBytes:&index];
		if( string && row >= 0 && row != index && ( row - 1 ) != index ) return NSDragOperationEvery;
		else if( string && row == -1 ) return NSDragOperationNone;

		if( row == -1 ) {
			if( [[NSURL URLFromPasteboard:[info draggingPasteboard]] isChatURL] ) return NSDragOperationEvery;

			string = [[info draggingPasteboard] stringForType:NSStringPboardType];
			if( string && [[NSURL URLWithString:string] isChatURL] ) return NSDragOperationEvery;

			string = [[info draggingPasteboard] stringForType:@"CorePasteboardFlavorType 0x75726C20"];
			if( string && [[NSURL URLWithString:string] isChatURL] ) return NSDragOperationEvery;

			string = [[[[info draggingPasteboard] propertyListForType:@"WebURLsWithTitlesPboardType"] objectAtIndex:0] objectAtIndex:0];
			if( string && [[NSURL URLWithString:string] isChatURL] ) return NSDragOperationEvery;
		}
	}

	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) view acceptDrop:(id <NSDraggingInfo>) info row:(int) row dropOperation:(NSTableViewDropOperation) operation {
	if( view == connections ) {
		if( [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:MVConnectionPboardType]] ) {
			int index = -1;
			id item = nil;
			[[[info draggingPasteboard] dataForType:MVConnectionPboardType] getBytes:&index];
			if( row > index ) row--;
			item = [[[_bookmarks objectAtIndex:index] retain] autorelease];
			[_bookmarks removeObjectAtIndex:index];
			[_bookmarks insertObject:item atIndex:row];
			[self _refresh:nil];
			return YES;
		} else {
			NSString *string = nil;
			NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];

			if( ! [url isChatURL] ) {
				string = [[info draggingPasteboard] stringForType:@"CorePasteboardFlavorType 0x75726C20"];
				if( string ) url = [NSURL URLWithString:string];
			}

			if( ! [url isChatURL] ) {
				string = [[[[info draggingPasteboard] propertyListForType:@"WebURLsWithTitlesPboardType"] objectAtIndex:0] objectAtIndex:0];
				if( string ) url = [NSURL URLWithString:string];
			}

			if( ! [url isChatURL] ) {
				string = [[info draggingPasteboard] stringForType:NSStringPboardType];
				if( string ) url = [NSURL URLWithString:string];
			}

			if( [url isChatURL] ) {
				[self handleURL:url andConnectIfPossible:NO];
				return YES;
			}
		}
	}

	return NO;
}

#pragma mark -

- (int) numberOfItemsInComboBox:(NSComboBox *) comboBox {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] count];
}

- (id) comboBox:(NSComboBox *) comboBox objectValueForItemAtIndex:(int) index {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] objectAtIndex:index];
}

- (unsigned int) comboBox:(NSComboBox *) comboBox indexOfItemWithStringValue:(NSString *) string {
	return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] indexOfObject:string];
}

- (NSString *) comboBox:(NSComboBox *) comboBox completedString:(NSString *) substring {
	NSEnumerator *enumerator = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] objectEnumerator];
	NSString *server = nil;
	while( ( server = [enumerator nextObject] ) )
		if( [server hasPrefix:substring] ) return server;
	return nil;
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdent] autorelease];

	if( [itemIdent isEqualToString:MVToolbarConnectToggleItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Connect", "connect to server title" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Connect", "connect to server title" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Connect to server", "connect button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"connect"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else if( [itemIdent isEqualToString:MVToolbarEditItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Info", "short toolbar connection info button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Connection Info", "name for connection info button in customize palette" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Show connection info", "connection info button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"info"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else if( [itemIdent isEqualToString:MVToolbarInspectorItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Inspector", "short toolbar inspector button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Inspector", "inspector toolbar button in customize palette" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Show inspector", "connection info button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"inspector"]];

		[toolbarItem setTarget:[JVInspectorController class]];
		[toolbarItem setAction:@selector( showInspector: )];
	} else if( [itemIdent isEqualToString:MVToolbarDeleteItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Delete", "delete item title" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Delete Connection", "name for delete connection button in customize palette" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Delete connection", "delete connection button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"delete"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else if( [itemIdent isEqualToString:MVToolbarConsoleItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Console", "short toolbar server console button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Server Console", "name for server console button in customize palette" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Open the server console", "server console button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"console"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else if( [itemIdent isEqualToString:MVToolbarJoinRoomItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Join Room", "short toolbar join chat room button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Join Chat Room", "name for join chat room button in customize palette" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Join a chat room", "join chat room button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"joinRoom"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( joinRoom: )];
	} else if( [itemIdent isEqualToString:MVToolbarQueryUserItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Message User", "toolbar message user button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Message User", "toolbar message user button name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Message a user", "message user button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"messageUser"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else toolbarItem = nil;

	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:MVToolbarConnectToggleItemIdentifier, NSToolbarSeparatorItemIdentifier,
		MVToolbarJoinRoomItemIdentifier, MVToolbarQueryUserItemIdentifier, MVToolbarConsoleItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, MVToolbarEditItemIdentifier, MVToolbarDeleteItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, MVToolbarConnectToggleItemIdentifier,
		MVToolbarEditItemIdentifier, MVToolbarInspectorItemIdentifier, MVToolbarDeleteItemIdentifier, MVToolbarConsoleItemIdentifier,
		MVToolbarJoinRoomItemIdentifier, MVToolbarQueryUserItemIdentifier, nil];
}
@end

#pragma mark -

@implementation MVConnectionsController (MVConnectionsControllerPrivate)
- (void) _loadInterfaceIfNeeded {
	if( ! [self isWindowLoaded] ) [self window];
}

- (void) _refresh:(NSNotification *) notification {
	[self _validateToolbar];
	if( [[notification name] isEqualToString:MVChatConnectionNicknameAcceptedNotification] ) {
		MVChatConnection *connection = [notification object];
		[connection setNicknamePassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:[connection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
	}
	[connections reloadData];
	[connections noteNumberOfRowsChanged];
}

- (void) _applicationQuitting:(NSNotification *) notification {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	MVChatConnection *connection = nil;
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		connection = [info objectForKey:@"connection"];
		[connection sendRawMessage:@"QUIT"];
	}
}

- (void) _errorOccurred:(NSNotification *) notification {
/*	MVChatConnection *connection = [notification object];
	MVChatError error = (MVChatError) [[[notification userInfo] objectForKey:@"error"] intValue];
	NSLog( @"error: %@ (%d)", [MVChatConnection descriptionForError:error], error );
	if( [[[notification userInfo] objectForKey:@"disconnected"] boolValue] ) {
		switch( error ) {
			case MVChatUserDisconnectError:
				break;
			case MVChatDisconnectError:
			case MVChatPacketError:
			case MVChatPacketSizeError:
				if( ! [connection isConnected] ) {
					if( NSRunCriticalAlertPanel( NSLocalizedString( @"You have been disconnected", "title of the you have been disconnected error" ), NSLocalizedString( @"The server may have shutdown for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", "connection dropped" ), NSLocalizedString( @"Reconnect", "reconnect to server button" ), @"Cancel", nil ) == NSOKButton )
						[connection connect];
				} else {
					if( NSRunCriticalAlertPanel( NSLocalizedString( @"Could not connect", "title of the could not connect error" ), NSLocalizedString( @"The server may be down for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", "connection dropped" ), NSLocalizedString( @"Retry", "retry connecting to server" ), @"Cancel", nil ) == NSOKButton )
						[connection connect];
				}
				break;
			default:
				NSRunCriticalAlertPanel( NSLocalizedString( @"You have been disconnected", "title of the you have been disconnected error" ), [NSString stringWithFormat:NSLocalizedString( @"The connection was terminated between your computer and the server. %s.", "unknown disconnection error dialog message" ), [MVChatConnection descriptionForError:error]], nil, nil, nil );
				break;
		}
	} else if( [[[notification userInfo] objectForKey:@"whileConnecting"] boolValue] ) {
		switch( error ) {
			case MVChatSocketError:
			case MVChatDNSError:
				if( NSRunCriticalAlertPanel( NSLocalizedString( @"Could not connect to Chat server", "chat invalid password dialog title" ), NSLocalizedString( @"The server is disconnected or refusing connections from your computer. Make sure you are conencted to the internet and have access to the server.", "chat invalid password dialog message" ), NSLocalizedString( @"Retry", "retry connecting to server" ), @"Cancel", nil ) == NSOKButton )
					[connection connect];
				break;
			case MVChatBadUserPasswordError:
				NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat password is invalid", "chat invalid password dialog title" ), NSLocalizedString( @"The password you specified is invalid or a connection could not be made without a proper password. Make sure you have access to the server.", "chat invalid password dialog message" ), nil, nil, nil );
				break;
			case MVChatBadTargetError:
				NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat nickname could not be used", "chat invalid nickname dialog title" ), [NSString stringWithFormat:NSLocalizedString( @"The nickname you specified is in use or invalid on this server. A connection could not be made with '%@' as your nickname.", "chat invalid nicknames dialog message" ), [connection nickname]], nil, nil, nil );
				break;
			default:
				NSRunCriticalAlertPanel( NSLocalizedString( @"An error occured while connecting", "chat connecting error dialog title" ), [NSString stringWithFormat:NSLocalizedString( @"The connection could not be made. %s.", "unknown connection error dialog message" ), [NSString stringWithFormat:NSLocalizedString( @"The connection was terminated between your computer and the server. %s.", "unknown disconnection error dialog message" ), [MVChatConnection descriptionForError:error]]], nil, nil, nil );
				break;
		}
	} else {
		NSString *target = [[notification userInfo] objectForKey:@"target"];
		if( [target isMemberOfClass:[NSNull class]] ) target = nil;
		switch( error ) {
			case MVChatBadTargetError:
				if( [target hasPrefix:@"#"] || [target hasPrefix:@"&"] || [target hasPrefix:@"+"] || [target hasPrefix:@"!"] ) {
					[(JVChatRoom *)[[JVChatController defaultManager] chatViewControllerForRoom:target withConnection:connection ifExists:YES] unavailable];
				} else if( target ) {
					[(JVDirectChat *)[[JVChatController defaultManager] chatViewControllerForUser:target withConnection:connection ifExists:YES] unavailable];
				} else {
					NSRunCriticalAlertPanel( NSLocalizedString( @"Your Chat nickname could not be used", "chat invalid nickname dialog title" ), NSLocalizedString( @"The nickname you specified is in use or invalid on this server.", "chat invalid nickname dialog message" ), nil, nil, nil );
				}
				break;
			default:
				NSRunCriticalAlertPanel( NSLocalizedString( @"An error occured", "unknown error dialog title" ), [NSString stringWithFormat:NSLocalizedString( @"An error occured when dealing with %@. %@", "unknown error dialog message" ), ( target ? target : NSLocalizedString( @"server", "singular server label" ) ), [MVChatConnection descriptionForError:error]], nil, nil, nil );
				break;
		}
	}*/
}

- (void) _saveBookmarkList {
	NSMutableArray *saveList = [NSMutableArray arrayWithCapacity:[_bookmarks count]];
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( ! [[info objectForKey:@"temporary"] boolValue] ) {
			NSMutableDictionary *data = [NSMutableDictionary dictionary];
			[data setObject:[NSNumber numberWithBool:[[info objectForKey:@"automatic"] boolValue]] forKey:@"automatic"];
			[data setObject:[NSNumber numberWithBool:[(MVChatConnection *)[info objectForKey:@"connection"] isSecure]] forKey:@"secure"];
			[data setObject:[NSNumber numberWithInt:(int)[(MVChatConnection *)[info objectForKey:@"connection"] proxyType]] forKey:@"proxy"];
			[data setObject:[NSNumber numberWithLong:(long)[(MVChatConnection *)[info objectForKey:@"connection"] encoding]] forKey:@"encoding"];
			[data setObject:[(MVChatConnection *)[info objectForKey:@"connection"] server] forKey:@"server"];
			[data setObject:[NSNumber numberWithUnsignedShort:[(MVChatConnection *)[info objectForKey:@"connection"] serverPort]] forKey:@"port"];
			[data setObject:[(MVChatConnection *)[info objectForKey:@"connection"] preferredNickname] forKey:@"nickname"];
			if( [(MVChatConnection *)[info objectForKey:@"connection"] alternateNicknames] )
				[data setObject:[(MVChatConnection *)[info objectForKey:@"connection"] alternateNicknames] forKey:@"alternateNicknames"];
			if( [info objectForKey:@"rooms"] ) [data setObject:[info objectForKey:@"rooms"] forKey:@"rooms"];
			if( [info objectForKey:@"commands"] ) [data setObject:[info objectForKey:@"commands"] forKey:@"commands"];
			[data setObject:[info objectForKey:@"created"] forKey:@"created"];
			[data setObject:[(MVChatConnection *)[info objectForKey:@"connection"] realName] forKey:@"realName"];
			[data setObject:[(MVChatConnection *)[info objectForKey:@"connection"] username] forKey:@"username"];
			[saveList addObject:data];
		}
	}

	[[NSUserDefaults standardUserDefaults] setObject:saveList forKey:@"MVChatBookmarks"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	[self _validateToolbar];
}

- (void) _loadBookmarkList {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatBookmarks"]];
	NSEnumerator *enumerator = [list objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		MVChatConnection *connection = nil;

		if( [info objectForKey:@"url"] ) {
			connection = [[[MVChatConnection alloc] initWithURL:[NSURL URLWithString:[info objectForKey:@"url"]]] autorelease];
		} else {
			connection = [[[MVChatConnection alloc] initWithServer:[info objectForKey:@"server"] port:[[info objectForKey:@"port"] unsignedShortValue] user:[info objectForKey:@"nickname"]] autorelease];
		}

		[connection setProxyType:(MVChatConnectionProxy)[[info objectForKey:@"proxy"] unsignedIntValue]];

		if( [[info objectForKey:@"encoding"] longValue] ) [connection setEncoding:[[info objectForKey:@"encoding"] longValue]];
		else [connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];

		if( [info objectForKey:@"realName"] ) [connection setRealName:[info objectForKey:@"realName"]];
		if( [info objectForKey:@"nickname"] ) [connection setNickname:[info objectForKey:@"nickname"]];
		if( [info objectForKey:@"username"] ) [connection setUsername:[info objectForKey:@"username"]];
		if( [info objectForKey:@"alternateNicknames"] )
			[connection setAlternateNicknames:[info objectForKey:@"alternateNicknames"]];

		[connection setSecure:[[info objectForKey:@"secure"] boolValue]];

		if( [[info objectForKey:@"automatic"] boolValue] ) {
			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"] )
				[[JVChatController defaultManager] chatConsoleForConnection:connection ifExists:NO];

			[connection setPassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:nil path:nil port:[connection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
			[connection setNicknamePassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:[connection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];

			[connection connect];
		}

		[info setObject:connection forKey:@"connection"];
	}

	[_bookmarks autorelease];
	_bookmarks = [list retain];

	[connections noteNumberOfRowsChanged];

	if( ! [_bookmarks count] ) [self newConnection:nil];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowConnectionsWindowOnLaunch"] )
		[[self window] orderFront:nil];

	[self _validateToolbar];
}

- (void) _validateToolbar {
	NSEnumerator *enumerator = [[[[self window] toolbar] visibleItems] objectEnumerator];
	id item = nil;
	BOOL noneSelected = YES;
	MVChatConnectionStatus status = MVChatConnectionDisconnectedStatus;

	if( [connections selectedRow] != -1 ) noneSelected = NO;
	if( ! noneSelected ) status = [(MVChatConnection *)[[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"] status];
	while( ( item = [enumerator nextObject] ) ) {
		if( [[item itemIdentifier] isEqualToString:MVToolbarConnectToggleItemIdentifier] ) {
			if( noneSelected ) {
				[item setLabel:NSLocalizedString( @"New", "new connection title" )];
				[item setToolTip:NSLocalizedString( @"New Connection", "new connection tooltip" )];
				[item setAction:@selector( newConnection: )];
				[item setImage:[NSImage imageNamed:@"connect"]];
			} else if( status == MVChatConnectionDisconnectedStatus || status == MVChatConnectionServerDisconnectedStatus || status == MVChatConnectionSuspendedStatus ) {
				[item setLabel:NSLocalizedString( @"Connect", "connect to server title" )];
				[item setToolTip:NSLocalizedString( @"Connect to Server", "connect button tooltip" )];
				[item setAction:@selector( _connect: )];
				[item setImage:[NSImage imageNamed:@"connect"]];
			} else if( status == MVChatConnectionConnectedStatus || status == MVChatConnectionConnectingStatus ) {
				[item setLabel:NSLocalizedString( @"Disconnect", "disconnect from server title" )];
				[item setToolTip:NSLocalizedString( @"Disconnect from Server", "disconnect button tooltip" )];
				[item setAction:@selector( _disconnect: )];
				[item setImage:[NSImage imageNamed:@"disconnect"]];
			}
		} else if( [[item itemIdentifier] isEqualToString:MVToolbarJoinRoomItemIdentifier] ) {
			if( [_bookmarks count] ) [item setAction:@selector( joinRoom: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqualToString:MVToolbarQueryUserItemIdentifier] ) {
			if( status == MVChatConnectionConnectedStatus ) [item setAction:@selector( _messageUser: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqualToString:MVToolbarConsoleItemIdentifier] ) {
			if( noneSelected ) [item setAction:NULL];
			else [item setAction:@selector( _openConsole: )];
		} else if( [[item itemIdentifier] isEqualToString:MVToolbarEditItemIdentifier] ) {
			if( noneSelected ) [item setAction:NULL];
			else [item setAction:@selector( getInfo: )];
		} else if( [[item itemIdentifier] isEqualToString:MVToolbarDeleteItemIdentifier] ) {
			if( noneSelected ) [item setAction:NULL];
			else [item setAction:@selector( _delete: )];
		} else if( [[item itemIdentifier] isEqualToString:MVToolbarConsoleItemIdentifier] ) {
			if( noneSelected ) [item setAction:NULL];
			else [item setAction:NULL];
		}
	}
}

- (void) _requestPassword:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];

	NSString *pass = [[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:[connection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
	if( [pass length] ) {
		[connection setNicknamePassword:pass];
		return;
	}

	if( [nicknameAuth isVisible] ) {
		// Do somthing better here, like queue requests until the current one is sent
		return;
	}

	[authAddress setObjectValue:[connection server]];
	[authNickname setObjectValue:[connection nickname]];
	[authPassword setObjectValue:@""];
	[authKeychain setState:NSOffState];

	[_passConnection autorelease];
	_passConnection = [connection retain];

	[nicknameAuth center];
	[nicknameAuth orderFront:nil];
}

- (IBAction) _connect:(id) sender {
	if( [connections selectedRow] == -1 ) return;
	MVChatConnection *connection = [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"];
	[connection setPassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:nil path:nil port:[connection serverPort] protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
	[connection setNicknamePassword:[[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:[connection nickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault]];
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"] )
		[[JVChatController defaultManager] chatConsoleForConnection:connection ifExists:NO];
	[connection connect];
}

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = nil;
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"connection"] isEqual:[notification object]] ) {
			connection = [notification object];
			break;
		}
	}

	if( ! connection ) return;

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatOpenConsoleOnConnect"] )
		[[JVChatController defaultManager] chatConsoleForConnection:connection ifExists:NO];
}

- (void) _didConnect:(NSNotification *) notification {
	MVChatConnection *connection = nil;
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"connection"] isEqual:[notification object]] ) {
			connection = [notification object];
			break;
		}
	}

	if( ! connection ) return;

	[connection joinChatRooms:[info objectForKey:@"rooms"]];

	NSEnumerator *commands = [[[info objectForKey:@"commands"] componentsSeparatedByString:@"\n"] objectEnumerator];
	NSMutableString *command = nil;

	while( ( command = [commands nextObject] ) ) {
		command = [[command mutableCopy] autorelease];
		[command replaceOccurrencesOfString:@"%@" withString:[connection nickname] options:NSLiteralSearch range:NSMakeRange( 0, [command length] )];

		if( [command hasPrefix:@"/"] ) {
			command = (NSMutableString *)[command substringFromIndex:1];

			NSString *arguments = nil;
			NSRange range = [command rangeOfString:@" "];
			if( range.location != NSNotFound ) {
				if( ( range.location + 1 ) < [command length] )
					arguments = [command substringFromIndex:( range.location + 1 )];
				command = (NSMutableString *)[command substringToIndex:range.location];
			}

			NSAttributedString *args = [[[NSAttributedString alloc] initWithString:arguments] autorelease];

			NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( MVChatConnection * ), nil];
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

			[invocation setSelector:@selector( processUserCommand:withArguments:toConnection: )];
			[invocation setArgument:&command atIndex:2];
			[invocation setArgument:&args atIndex:3];
			[invocation setArgument:&connection atIndex:4];

			NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
			if( ! [[results lastObject] boolValue] )
				[connection sendRawMessage:[command stringByAppendingFormat:@" %@", arguments]];
		} else if( [command length] ) {
			[connection sendRawMessage:command];
		}
	}
}

- (IBAction) _disconnect:(id) sender {
	unsigned int row = [connections selectedRow];
	if( row == -1 ) return;
	[[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] disconnect];
}

- (void) _delete:(id) sender {
	unsigned int row = [connections selectedRow];
	if( row == -1 ) return;
	[connections deselectAll:nil];
	[self removeConnectionAtIndex:row];
}

- (IBAction) _messageUser:(id) sender {
	if( [connections selectedRow] == -1 ) return;
	[[NSApplication sharedApplication] beginSheet:messageUser modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) _openConsole:(id) sender {
	unsigned int row = [connections selectedRow];
	if( row == -1 ) return;
	[[JVChatController defaultManager] chatConsoleForConnection:[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] ifExists:NO];
}

+ (IBAction) _openFavoritesFolder:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath]];
}

+ (IBAction) _connectToFavorite:(id) sender {
	if( ! [sender representedObject] ) return;
	[[MVConnectionsController defaultManager] handleURL:[sender representedObject] andConnectIfPossible:YES];
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[MVConnectionsController class]];
	NSScriptObjectSpecifier *container = [[MVConnectionsController defaultManager] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"connectionsArray" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation MVConnectionsController (MVConnectionsControllerScripting)
- (NSArray *) connectionsArray {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	id info = nil;

	while( ( info = [enumerator nextObject] ) )
		[ret addObject:[info objectForKey:@"connection"]];

	return [[ret retain] autorelease];
}

- (MVChatConnection *) valueInConnectionsArrayAtIndex:(unsigned) index {
	return [[_bookmarks objectAtIndex:index] objectForKey:@"connection"];
}

- (MVChatConnection *) valueInConnectionsArrayWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [_bookmarks objectEnumerator];
	MVChatConnection *connection = nil;
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		connection = [info objectForKey:@"connection"];
		if( [[connection uniqueIdentifier] isEqual:identifier] )
			return connection;
	}

	return nil;
}

- (void) addInConnectionsArray:(MVChatConnection *) connection {
	[self addConnection:connection];
}

- (void) insertInConnectionsArray:(MVChatConnection *) connection {
	[self addConnection:connection];
}

- (void) insertInConnectionsArray:(MVChatConnection *) connection atIndex:(unsigned) index {
	[self insertConnection:connection atIndex:index];
}

- (void) removeFromConnectionsArrayAtIndex:(unsigned) index {
	[self removeConnectionAtIndex:index];
}

- (void) replaceInConnectionsArray:(MVChatConnection *) connection atIndex:(unsigned) index {
	[self replaceConnectionAtIndex:index withConnection:connection];
}

- (MVChatConnection *) handleURLScriptCommand:(NSScriptCommand *) command {
	NSURL *url = [NSURL URLWithString:[[command evaluatedArguments] objectForKey:@"url"]];
	if( ! url ) return nil;

	MVChatConnection *connection = [[[MVChatConnection alloc] initWithURL:url] autorelease];
	[connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];

	if( ! connection ) return nil;

	[self addConnection:connection];
	return connection;
}
@end