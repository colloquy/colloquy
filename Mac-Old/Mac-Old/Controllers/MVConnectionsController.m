#import "CQKeychain.h"
#import "MVApplicationController.h"
#import "MVConnectionsController.h"
#import "JVConnectionInspector.h"
#import "JVNotificationController.h"
#import "JVAnalyticsController.h"
#import "JVChatController.h"
#import "JVChatRoomBrowser.h"
#import "JVChatRoomPanel.h"
#import "MVKeyChain.h"
//#import "JVChatRoomPanel.h"
//#import "JVDirectChatPanel.h"
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>

#import <SecurityInterface/SFCertificateTrustPanel.h>

static MVConnectionsController *sharedInstance = nil;

static NSString *const connectionInvalidSSLCertAction = nil;

static NSString *MVToolbarConnectToggleItemIdentifier = @"MVToolbarConnectToggleItem";
static NSString *MVToolbarEditItemIdentifier = @"MVToolbarEditItem";
static NSString *MVToolbarInspectorItemIdentifier = @"MVToolbarInspectorItem";
static NSString *MVToolbarDeleteItemIdentifier = @"MVToolbarDeleteItem";
static NSString *MVToolbarConsoleItemIdentifier = @"MVToolbarConsoleItem";
static NSString *MVToolbarJoinRoomItemIdentifier = @"MVToolbarJoinRoomItem";
static NSString *MVToolbarQueryUserItemIdentifier = @"MVToolbarQueryUserItem";

static NSString *MVConnectionPboardType = @"Colloquy Chat Connection v1.0 pasteboard type";

static NSMenu *favoritesMenu = nil;

@interface MVConnectionsController (Private) <NSMenuDelegate>
- (void) _loadInterfaceIfNeeded;
- (void) _registerNotificationsForConnection:(MVChatConnection *) connection;
- (void) _deregisterNotificationsForConnection:(MVChatConnection *) connection;
- (void) _refresh:(NSNotification *) notification;
- (void) _applicationQuitting:(NSNotification *) notification;
- (void) _errorOccurred:(NSNotification *) notification;
- (void) _saveBookmarkList;
- (void) _loadBookmarkList;
- (void) _validateToolbar;
- (void) _requestPassword:(NSNotification *) notification;
- (void) _requestCertificatePassword:(NSNotification *) notification;
- (void) _requestPublicKeyVerification:(NSNotification *) notification;
- (void) _autoJoinRoomsForConnection:(MVChatConnection *) connection;
- (void) _didIdentify:(NSNotification *) notification;
- (void) _connect:(id) sender;
- (void) _willConnect:(NSNotification *) notification;
- (void) _didConnect:(NSNotification *) notification;
- (void) _didDisconnect:(NSNotification *) notification;
- (void) _gotConnectionError:(NSNotification *) notification;
- (NSString *) _idleMessageString;
- (void) _machineDidBecomeIdle:(NSNotification *) notification;
- (void) _machineDidStopIdling:(NSNotification *) notification;
- (void) _disconnect:(id) sender;
- (void) _delete:(id) sender;
- (void) _messageUser:(id) sender;
- (void) _openConsole:(id) sender;
+ (void) _openFavoritesFolder:(id) sender;
+ (void) _connectToFavorite:(id) sender;
@end

#pragma mark -

@interface NSAlert (LeopardOnly)
- (void) setAccessoryView:(NSView *) view;
@end

#pragma mark -

@implementation MVConnectionsController
+ (MVConnectionsController *) defaultController {
	if( ! sharedInstance ) {
		sharedInstance = [self alloc];
		sharedInstance = [sharedInstance initWithWindowNibName:@"MVConnections"];
	}

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshFavoritesMenu) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshFavoritesMenu) name:MVChatRoomPartedNotification object:nil];

	return sharedInstance;
}

+ (NSMenu *) favoritesMenu {
	[self refreshFavoritesMenu];
	return favoritesMenu;
}

+ (void) refreshFavoritesMenu {
	if( ! favoritesMenu )
		favoritesMenu = [[NSMenu alloc] initWithTitle:@""];
	else [favoritesMenu removeAllItems];

	NSString *path = [@"~/Library/Application Support/Colloquy/Favorites/Favorites.plist" stringByExpandingTildeInPath];
	NSArray *favorites = [NSArray arrayWithContentsOfFile:path];

	NSMenuItem *menuItem = nil;
	if( ! [favorites count] ) {
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Favorites", "no favorites menu title" ) action:NULL keyEquivalent:@""];
		[favoritesMenu addItem:menuItem];
	}

	NSImage *icon = [[NSImage imageNamed:@"room"] copy];
	[icon setSize:NSMakeSize( 16., 16. )];

	for( NSDictionary *item in favorites ) {
		NSString *scheme = [item objectForKey:@"scheme"];
		NSString *server = [item objectForKey:@"server"];
		NSString *target = [item objectForKey:@"target"];

		menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", target, server] action:@selector( _connectToFavorite: ) keyEquivalent:@""];
		[menuItem setImage:icon];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@", [item objectForKey:@"scheme"], [item objectForKey:@"server"], [item objectForKey:@"target"]]]];

		for (MVChatConnection *connection in [[MVConnectionsController defaultController] connections]) {
			if (!(connection.isConnected || connection.status == MVChatConnectionConnectingStatus))
				continue;

			if (![connection.urlScheme isEqualToString:scheme])
				continue;

			if (![connection.server isEqualToString:server])
				continue;

			for (MVChatRoom *room in connection.joinedChatRooms) {
				if (![room.name isEqualToString:target])
					continue;

				menuItem.state = NSOnState;

				break;
			}

			if (menuItem.state == NSOnState)
				break;
		}

		[favoritesMenu addItem:menuItem];
	}

	[favoritesMenu addItem:[NSMenuItem separatorItem]];

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add to Favorites", "add to favorites contextual menu") action:@selector( toggleFavorites: ) keyEquivalent:@""];
	[menuItem setEnabled:NO];
	[menuItem setTag:10];
	[favoritesMenu addItem:menuItem];
}

+ (void) _refreshFavoritesMenu {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshFavoritesMenu) object:nil];

	[self performSelector:@selector(refreshFavoritesMenu) withObject:nil afterDelay:.0];
}

#pragma mark -

- (MVChatConnectionType) newTypeToConnectionType {
	MVChatConnectionType type = MVChatConnectionUnsupportedType;

	switch( [[newType selectedItem] tag] ) {
	case 0:
		type = MVChatConnectionICBType;
		break;
	case 1:
		type = MVChatConnectionIRCType;
		break;
	case 2:
		type = MVChatConnectionSILCType;
		break;
	case 3:
		type = MVChatConnectionXMPPType;
		break;
	default:
		NSAssert1( NO, @"Unsupported connection type %ld", [[newType selectedItem] tag] );
	}

	return type;
}

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_bookmarks = nil;
		_passConnection = nil;

		_connectionToErrorToAlertMap = [NSMapTable strongToStrongObjectsMapTable];
		_joinRooms = [[NSMutableArray alloc] init];
		_publicKeyRequestQueue = [[NSMutableSet alloc] init];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationQuitting: ) name:NSApplicationWillTerminateNotification object:nil];

		[self _loadBookmarkList];

		// this can likely be removed when 3.0 starts, if we even keep MVConnectionsController around (zach)
		// agreed. and once we do, we should document it in a list of "retired user defaults keys". (alex)
		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVFavoritesMigrated"] ) {
			NSString *path = [@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath];

			NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
			for ( NSString *item in directoryContents ) {
				if ( ![[item pathExtension] isEqualToString:@"inetloc"] ) {
					continue;
				}

				// This code previously migrated favorites from being resource fork based (.inetloc files) to the newer
				// plist (shipped 4 versions with it from 2012 to at least 2015), now it just deletes the old files.

				[[NSFileManager defaultManager] removeItemAtPath:item error:nil];
			}

			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVFavoritesMigrated"];
		}
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_peerTrustFeedbackNotification:) name:MVChatConnectionNeedTLSPeerTrustFeedbackNotification object:nil];
	}

	return self;
}

- (void) dealloc {
	[self _saveBookmarkList];

	[connections setDelegate:nil];
	[connections setDataSource:nil];

	[newJoinRooms setDelegate:nil];
	[newJoinRooms setDataSource:nil];

	[userSelectionTable setDelegate:nil];
	[userSelectionTable setDataSource:nil];

	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	_bookmarks = nil;
	_joinRooms = nil;
	_passConnection = nil;
	_publicKeyRequestQueue = nil;
}

- (void) windowDidLoad {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Connections"];
	NSTableColumn *theColumn = nil;

	[newNickname setObjectValue:NSUserName()];
	[newUsername setObjectValue:NSUserName()];
	[newRealName setObjectValue:NSFullUserName()];

	[(NSPanel *)[self window] setFloatingPanel:NO];
	[[self window] setHidesOnDeactivate:NO];
	[[self window] setResizeIncrements:NSMakeSize( 1, [connections rowHeight] + [connections intercellSpacing].height - 1. )];

	[connections setAccessibilityLabel:NSLocalizedString(@"Connections", "VoiceOver label for connections table")];

	theColumn = [connections tableColumnWithIdentifier:@"auto"];
	[[theColumn headerCell] setImage:[NSImage imageNamed:@"autoHeaderTemplate"]];

	theColumn = [connections tableColumnWithIdentifier:@"status"];
	[[theColumn headerCell] setImage:[NSImage imageNamed:@"statusHeaderTemplate"]];

	[connections registerForDraggedTypes:[NSArray arrayWithObjects:MVConnectionPboardType,NSURLPboardType,@"CorePasteboardFlavorType 0x75726C20",nil]];
	[connections setTarget:self];
	[connections setDoubleAction:@selector( _connect: )];

	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	[menu setDelegate:self];
	[connections setMenu:menu];

	[userSelectionTable setTarget:self];
	[userSelectionTable setDoubleAction:@selector( userSelectionSelected: )];

	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];

	NSWindowCollectionBehavior windowCollectionBehavior = (NSWindowCollectionBehaviorDefault | NSWindowCollectionBehaviorParticipatesInCycle | NSWindowCollectionBehaviorTransient);
	if( floor( NSAppKitVersionNumber ) >= NSAppKitVersionNumber10_7 )
		windowCollectionBehavior |= NSWindowCollectionBehaviorFullScreenAuxiliary;

	[[self window] setCollectionBehavior:windowCollectionBehavior];

	[showDetails setBezelStyle:NSRoundedDisclosureBezelStyle];
	[showDetails setButtonType:NSOnOffButton];

	[self setWindowFrameAutosaveName:@"Connections"];
	[self _validateToolbar];

	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	numberFormatter.numberStyle = NSNumberFormatterNoStyle;
	[newPort setFormatter:numberFormatter];
}

- (NSRect) windowWillUseStandardFrame:(NSWindow *) sender defaultFrame:(NSRect) defaultFrame {
	if( sender != [connections window] ) return defaultFrame;

	NSRect frame = [sender frame];
	NSScrollView *scrollView = [connections enclosingScrollView];
	CGFloat displayedHeight = [[scrollView contentView] bounds].size.height;
	CGFloat heightChange = [[scrollView documentView] bounds].size.height - displayedHeight;
	CGFloat heightExcess = 0.;

	if( heightChange >= 0 && heightChange <= 1 ) {
		// either the window is already optimal size, or it's too big
		CGFloat rowHeight = [connections rowHeight] + [connections intercellSpacing].height;
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
	[self newConnectionWithJoinRooms:nil];
}

- (void) newConnectionWithJoinRooms:(NSArray *) rooms {
	[self _loadInterfaceIfNeeded];
	if( [openConnection isVisible] ) return;

	if( rooms ) [_joinRooms setArray:rooms];
	else [_joinRooms removeAllObjects];

	[newJoinRooms reloadData];

	if( [showDetails state] != NSOffState ) {
		[showDetails setState:NSOffState];
		[self toggleNewConnectionDetails:showDetails];
	}

	[newServerPassword setObjectValue:@""];

	MVChatConnectionType type = [self newTypeToConnectionType];
	if( [[MVChatConnection defaultServerPortsForType:type] count] )
		[newPort setObjectValue:[[MVChatConnection defaultServerPortsForType:type] objectAtIndex:0]];

	[openConnection center];
	[openConnection makeKeyAndOrderFront:nil];
}

- (IBAction) changeNewConnectionProtocol:(id) sender {
	MVChatConnectionType type = [self newTypeToConnectionType];

	[newPort reloadData];
	if( [[MVChatConnection defaultServerPortsForType:type] count] )
		[newPort setObjectValue:[[MVChatConnection defaultServerPortsForType:type] objectAtIndex:0]];

	if( type == MVChatConnectionICBType ) {
		[sslConnection setEnabled:NO];
		[newProxy setEnabled:NO];
	} else if( type == MVChatConnectionIRCType ) {
		[sslConnection setEnabled:YES];
		[newProxy setEnabled:YES];
	} else if( type == MVChatConnectionSILCType ) {
		[sslConnection setEnabled:NO];
		[newProxy setEnabled:NO];
	} else if( type == MVChatConnectionXMPPType ) {
		[sslConnection setEnabled:YES];
		[newProxy setEnabled:NO];
	}
}

- (IBAction) toggleNewConnectionDetails:(id) sender {
	CGFloat offset = NSHeight( [detailsTabView frame] );
	NSRect windowFrame = [openConnection frame];
	NSRect newWindowFrame = NSMakeRect( NSMinX( windowFrame ), NSMinY( windowFrame ) + ( [sender state] ? offset * -1 : offset ), NSWidth( windowFrame ), ( [sender state] ? NSHeight( windowFrame ) + offset : NSHeight( windowFrame ) - offset ) );
	if( ! [sender state] ) [detailsTabView selectTabViewItemAtIndex:0];
	[openConnection setFrame:newWindowFrame display:YES animate:YES];
	if( [sender state] ) [detailsTabView selectTabViewItemAtIndex:1];
	[openConnection recalculateKeyViewLoop];
}

- (IBAction) addRoom:(id) sender {
	[_joinRooms addObject:@""];
	[newJoinRooms noteNumberOfRowsChanged];
	[newJoinRooms selectRowIndexes:[NSIndexSet indexSetWithIndex:( [_joinRooms count] - 1 )] byExtendingSelection:NO];
	[newJoinRooms editColumn:0 row:( [_joinRooms count] - 1 ) withEvent:nil select:NO];
}

- (IBAction) removeRoom:(id) sender {
	if( [newJoinRooms selectedRow] == -1 || [newJoinRooms editedRow] != -1 ) return;
	[_joinRooms removeObjectAtIndex:[newJoinRooms selectedRow]];
	[newJoinRooms noteNumberOfRowsChanged];
}

- (IBAction) openNetworkPreferences:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Network.prefPane"];
}

- (void) _peerTrustFeedbackNotification:(NSNotification *) notification {
	void (^completionHandler)(BOOL shouldTrustPeer) = notification.userInfo[@"completionHandler"];
	if ([connectionInvalidSSLCertAction isEqualToString:@"Deny"]) {
		completionHandler(NO);
		return;
	}

	if ([connectionInvalidSSLCertAction isEqualToString:@"Allow"]) {
		completionHandler(YES);
		return;
	}

	// Ask people what to do, if its ever been turned on
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MVAskOnInvalidCertificates"] || [[[CQKeychain standardKeychain] passwordForServer:@"MVAskOnInvalidCertificates" area:@"MVSecurePrefs"] boolValue]) {
		[[CQKeychain standardKeychain] setPassword:@"1" forServer:@"MVAskOnInvalidCertificates" area:@"MVSecurePrefs"];

		SFCertificateTrustPanel *panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
		panel.showsHelp = YES;

		[panel setDefaultButtonTitle:NSLocalizedString(@"Continue", @"Continue button")];
		[panel setAlternateButtonTitle:NSLocalizedString(@"Cancel", @"Cancel button")];

		SecTrustRef trust = (__bridge SecTrustRef)notification.userInfo[@"trust"];
		NSInteger shouldTrust = [panel runModalForTrust:trust showGroup:YES];

		completionHandler(shouldTrust == NSModalResponseOK);
	} else {
		completionHandler(YES);
	}
}

- (IBAction) connectNewConnection:(id) sender {
	if( ! [[newNickname stringValue] length] ) {
		[[self window] makeFirstResponder:newNickname];
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Nickname is blank", "chat invalid nickname dialog title" );
		alert.informativeText = NSLocalizedString( @"The nickname is invalid because it was left blank.", "chat nickname blank dialog message" );
		alert.alertStyle = NSAlertStyleCritical;
		[alert runModal];
		
		return;
	}

	if( ! [[newAddress stringValue] length] ) {
		[[self window] makeFirstResponder:newAddress];
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Chat Server is blank", "chat invalid nickname dialog title" );
		alert.informativeText = NSLocalizedString( @"The chat server is invalid because it was left blank.", "chat server blank dialog message" );
		alert.alertStyle = NSAlertStyleCritical;
		[alert runModal];
		
		return;
	}

	if( [newPort intValue] < 0 ) {
		[[self window] makeFirstResponder:newPort];
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Chat Server Port is invalid", "chat invalid nickname dialog title" );
		alert.informativeText = NSLocalizedString( @"The chat server port you specified is invalid because it can't be negative or greater than 65535.", "chat server port invalid dialog message" );
		alert.alertStyle = NSAlertStyleCritical;
		[alert runModal];
		
		return;
	}

	if( ! [[newUsername stringValue] length] ) {
		if( [showDetails state] != NSOnState ) {
			[showDetails setState:NSOnState];
			[self toggleNewConnectionDetails:showDetails];
		}
		[[self window] makeFirstResponder:newUsername];
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Username is blank", "chat blank username dialog title" );
		alert.informativeText = NSLocalizedString( @"The username is invalid because it was left blank.", "chat username blank dialog message" );
		alert.alertStyle = NSAlertStyleCritical;
		[alert runModal];
		
		return;
	}

	NSMutableCharacterSet *allowedCharacters = (NSMutableCharacterSet *)[NSMutableCharacterSet alphanumericCharacterSet];
	[allowedCharacters addCharactersInString:@"`_-|^{}[]@./"];

	NSCharacterSet *illegalCharacters = [allowedCharacters invertedSet];

	if( [[newUsername stringValue] rangeOfCharacterFromSet:illegalCharacters].location != NSNotFound ) {
		if( [showDetails state] != NSOnState ) {
			[showDetails setState:NSOnState];
			[self toggleNewConnectionDetails:showDetails];
		}
		[[self window] makeFirstResponder:newUsername];
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Username invalid", "chat invalid username dialog title" );
		alert.informativeText = NSLocalizedString( @"The username you specified is invalid because it contains spaces or other non-alphanumeric characters.", "chat username blank dialog message" );
		alert.alertStyle = NSAlertStyleCritical;
		[alert runModal];
		
		return;
	}

	for( NSDictionary *info in _bookmarks ) {
		MVChatConnection *connection = [info objectForKey:@"connection"];

		if( [[connection server] isEqualToString:[newAddress stringValue]] && [connection serverPort] == [newPort intValue] &&
			[[connection nickname] isEqualToString:[newNickname stringValue]] &&
			[[connection username] isEqualToString:[newUsername stringValue]] &&
			[[connection password] isEqualToString:[newServerPassword stringValue]] ) {
			if( [connection isConnected] ) {
				
				NSAlert *alert = [[NSAlert alloc] init];
				alert.messageText = NSLocalizedString( @"Already connected", "already connected dialog title" );
				alert.informativeText = NSLocalizedString( @"The chat server with the nickname you specified is already connected to from this computer. Use another nickname if you desire multiple connections.", "chat already connected message" );
				alert.alertStyle = NSAlertStyleCritical;
				[alert runModal];
				
				[openConnection makeFirstResponder:newNickname];
			} else {
				[connections selectRowIndexes:[NSIndexSet indexSetWithIndex:[_bookmarks indexOfObject:info]] byExtendingSelection:NO];
				[self _connect:nil];
				[[self window] makeKeyAndOrderFront:nil];
				[openConnection orderOut:nil];
			}

			return;
		}
	}

	[openConnection orderOut:nil];

	MVChatConnectionType type = [self newTypeToConnectionType];

	MVChatConnection *connection = [[MVChatConnection alloc] initWithType:type];
	[connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];
	[connection setOutgoingChatFormat:[[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatFormat"] unsignedIntValue]];
	[connection setProxyType:(OSType)[[newProxy selectedItem] tag]];
	[connection setSecure:[sslConnection state]];
	[connection setPassword:[newServerPassword stringValue]];
	[connection setUsername:[newUsername stringValue]];
	[connection setRealName:[newRealName stringValue]];
	if( [_joinRooms count] ) [connection joinChatRoomsNamed:_joinRooms];

	if( [[newNickname stringValue] length] ) [connection setNickname:[newNickname stringValue]];
	if( [[newAddress stringValue] length] ) [connection setServer:[newAddress stringValue]];
	if( [newPort intValue] ) [connection setServerPort:[newPort intValue]];

	[self addConnection:connection keepBookmark:(BOOL)[newRemember state]];
	[self setJoinRooms:_joinRooms forConnection:connection];

	[connection connect];

	[[self window] makeKeyAndOrderFront:nil];
}

#pragma mark -

- (IBAction) messageUser:(id) sender {
	[self.window endSheet:messageUser];

	if( [connections selectedRow] == -1 ) return;

	if( [sender tag] ) {
		NSSet *users = [[[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"] chatUsersWithNickname:[userToMessage stringValue]];
		MVChatUser *user;

		if( [users count] == 0 ) return;
		else if( [users count] == 1 ) user = [users anyObject];
		else {
			[self _validateToolbar];

			_userSelectionPossibleUsers = [users allObjects];
			[userSelectionDescription setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Multiple users with the name '%@' have been found.", "multiple user same nickname, user selection description"), [userToMessage stringValue]]];

			[userSelectionTable reloadData];
			[userSelectionTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

			[self.window beginSheet:userSelectionPanel completionHandler:nil];

			return;
		}

		[[JVChatController defaultController] chatViewControllerForUser:user ifExists:NO];
	}
}

- (IBAction) joinRoom:(id) sender {
	if( ! [_bookmarks count] ) return;
	NSArray *connectedConnections = [self connectedConnections];
	JVChatRoomBrowser *browser = [JVChatRoomBrowser chatRoomBrowserForConnection:( [connections selectedRow] == -1 ? ( [connectedConnections count] ? [connectedConnections objectAtIndex:0] : nil ) : [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"] )];
	[self.window beginSheet:browser.window completionHandler:nil];
}

#pragma mark -

- (IBAction) sendPassword:(id) sender {
	[nicknameAuth orderOut:nil];

	if( [sender tag] ) {
		[_passConnection setNicknamePassword:[authPassword stringValue]];
		if( [authKeychain state] == NSOnState ) {
			[[CQKeychain standardKeychain] setPassword:[authPassword stringValue] forServer:_passConnection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", _passConnection.preferredNickname] displayValue:_passConnection.server];
		}
	}

	_passConnection = nil;
}

- (IBAction) sendCertificatePassword:(id) sender {
	[certificateAuth orderOut:nil];

	MVChatConnection *ourConnection = _certificateConnection;
	_certificateConnection = nil;

	if( [sender tag] ) {
		[ourConnection authenticateCertificateWithPassword:[certificatePassphrase stringValue]];

		if( [certificateKeychain state] == NSOnState ) {
			[[CQKeychain standardKeychain] setPassword:[certificatePassphrase stringValue] forServer:ourConnection.uniqueIdentifier area:@"Colloquy" displayValue:ourConnection.server];
		}
	}
}

- (IBAction) verifiedPublicKey:(id) sender {
	NSDictionary *dict = _publicKeyDictionary;

	_publicKeyDictionary = nil;

	MVChatConnection *connection = [dict objectForKey:@"connection"];

	BOOL accepted = NO;

	if( [sender tag] )
		accepted = YES;

	BOOL alwaysAccept = NO;

	if( [publicKeyAlwaysAccept state] == NSOnState )
		alwaysAccept = YES;

	[connection publicKeyVerified:dict andAccepted:accepted andAlwaysAccept:alwaysAccept];

	[publicKeyVerification orderOut:nil];

	if( [_publicKeyRequestQueue count] ) {
		NSNotification *note = [_publicKeyRequestQueue anyObject];

		if( note ) {
			[_publicKeyRequestQueue removeObject:note];
			[[NSNotificationCenter chatCenter] postNotification:note];
		}
	}
}

#pragma mark -
#pragma mark User Selection

- (IBAction) userSelectionSelected:(id) sender {
	[self.window endSheet:userSelectionPanel];

	NSInteger row = [userSelectionTable selectedRow];

	if( [sender tag] || row == -1 ) {
		_userSelectionPossibleUsers = nil;
		return;
	}

	[[JVChatController defaultController] chatViewControllerForUser:[_userSelectionPossibleUsers objectAtIndex:row] ifExists:NO];
	[userSelectionPanel orderOut:nil];

	_userSelectionPossibleUsers = nil;
}

#pragma mark -

- (NSArray *) connections {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];

	for( id info in _bookmarks ) {
		MVChatConnection *connection = [info objectForKey:@"connection"];
		if( connection ) [ret addObject:connection];
	}

	return ret;
}

- (NSArray *) connectedConnections {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];

	for( id info in _bookmarks ) {
		MVChatConnection *connection = [info objectForKey:@"connection"];
		if( [connection isConnected] )
			[ret addObject:connection];
	}

	return ret;
}

- (MVChatConnection *) connectionForServerAddress:(NSString *) address {
	NSArray *result = [self connectionsForServerAddress:address];
	if( [result count] )
		return [result objectAtIndex:0];
	return nil;
}

- (NSArray *) connectionsForServerAddress:(NSString *) address {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_bookmarks count]];

	address = [address stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@". \t\n"]];

	for( id info in _bookmarks ) {
		MVChatConnection *connection = [info objectForKey:@"connection"];
		NSString *server = [connection server];
		NSRange range = [server rangeOfString:address options:( NSCaseInsensitiveSearch | NSLiteralSearch | NSBackwardsSearch | NSAnchoredSearch ) range:NSMakeRange( 0, [server length] )];
		if( range.location != NSNotFound && ( range.location == 0 || [server characterAtIndex:( range.location - 1 )] == '.' ) )
			[ret addObject:connection];
	}

	return ret;
}

- (BOOL) managesConnection:(MVChatConnection *) connection {
	for( NSDictionary *info in _bookmarks )
		if( [[info objectForKey:@"connection"] isEqual:connection] )
			return YES;

	return NO;
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

	if( keep && [[connection password] length] ) {
		[[CQKeychain standardKeychain] setPassword:[connection password] forServer:connection.uniqueIdentifier area:@"Server" displayValue:connection.server];
	}

	[_bookmarks addObject:info];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];

	[self _registerNotificationsForConnection:connection];
}

- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSDate date] forKey:@"created"];
	[info setObject:connection forKey:@"connection"];

	[_bookmarks insertObject:info atIndex:index];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];

	[self _registerNotificationsForConnection:connection];
}

- (void) removeConnection:(MVChatConnection *) connection {
	unsigned index = 0;

	for( NSDictionary *info in _bookmarks ) {
		if( [[info objectForKey:@"connection"] isEqual:connection] )
			break;
		index++;
	}

	[self removeConnectionAtIndex:index];
}

- (void) removeConnectionAtIndex:(NSUInteger) index {
	MVChatConnection *connection = [[_bookmarks objectAtIndex:index] objectForKey:@"connection"];
    if( ! connection ) return;

	NSString *quitMessage = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"];
	if ( [quitMessage length] ) {
		NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:quitMessage];
		[connection disconnectWithReason:quitMessageString];
	} else
		[connection disconnect];

	[self _deregisterNotificationsForConnection:connection];

	[[CQKeychain standardKeychain] removePasswordForServer:connection.uniqueIdentifier area:@"Server"];
	[[CQKeychain standardKeychain] removePasswordForServer:connection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", connection.preferredNickname]];

	[_bookmarks removeObjectAtIndex:index];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];
}

- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection {
	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSDate date] forKey:@"created"];
	[info setObject:connection forKey:@"connection"];

	MVChatConnection *oldConnection = [[_bookmarks objectAtIndex:index] objectForKey:@"connection"];

	NSString *quitMessage = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"];
	if ( [quitMessage length] ) {
		NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:quitMessage];
		[oldConnection disconnectWithReason:quitMessageString];
	} else
		[oldConnection disconnect];

	[self _deregisterNotificationsForConnection:oldConnection];

	[[CQKeychain standardKeychain] removePasswordForServer:connection.uniqueIdentifier area:@"Server"];
	[[CQKeychain standardKeychain] removePasswordForServer:connection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", connection.preferredNickname]];

	[self _registerNotificationsForConnection:connection];

	[_bookmarks replaceObjectAtIndex:index withObject:info];
	[self _saveBookmarkList];

	[connections noteNumberOfRowsChanged];
}

#pragma mark -

- (void) handleURL:(NSURL *) url andConnectIfPossible:(BOOL) connect {
	if( [MVChatConnection supportsURLScheme:[url scheme]] ) {
		NSString *target = nil;
		BOOL handled = NO;

		if( [url fragment] ) {
			if( [[url fragment] length] > 0 ) target = [@"#" stringByAppendingString:[[url fragment] stringByDecodingIllegalURLCharacters]];
		} else if( [url path] && [[url path] length] > 1 ) {
			target = [[[url path] substringFromIndex:1] stringByDecodingIllegalURLCharacters];
		}

		for( NSDictionary *info in _bookmarks ) {
			MVChatConnection *connection = [info objectForKey:@"connection"];

			if( [[connection server] isEqualToString:[url host]] &&
				( ! [[url user] length] || [[connection nickname] isEqualToString:[url user]] ) &&
				( ! [[url port] unsignedShortValue] || [connection serverPort] == [[url port] unsignedShortValue] ) ) {

				if( target ) [connection joinChatRoomNamed:target];
				else [[self window] orderFront:nil];

				if( ! [connection isConnected] && connect )
					[connection connect];

				[connections selectRowIndexes:[NSIndexSet indexSetWithIndex:[_bookmarks indexOfObject:info]] byExtendingSelection:NO];

				handled = YES;
				break;
			}
		}

		if( ! handled && ! [[url user] length] ) {
			[newAddress setObjectValue:[url host]];

			NSInteger index = [newType indexOfItemWithTag:( [[url scheme] isEqualToString:@"silc"] ? 2 : 1 )];
			[newType selectItemAtIndex:index];

			[self newConnectionWithJoinRooms:( target ? [NSArray arrayWithObject:target] : nil )];

			if( [url port] ) [newPort setObjectValue:[url port]];
		} else if( ! handled && [[url user] length] ) {
			MVChatConnection *connection = [[MVChatConnection alloc] initWithURL:url];
			[connection setEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"]];
			[connection setOutgoingChatFormat:[[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatFormat"] unsignedIntValue]];

			[self addConnection:connection keepBookmark:NO];

			if( connect ) {
				if( target ) [connection joinChatRoomNamed:target];
				[connection connect];
			}

			[[self window] orderFront:nil];
		}
	}
}

#pragma mark -

- (void) setAutoConnect:(BOOL) autoConnect forConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( autoConnect ) [info setObject:[NSNumber numberWithBool:NO] forKey:@"temporary"];
			[info setObject:[NSNumber numberWithBool:autoConnect] forKey:@"automatic"];
			[self _saveBookmarkList];
			break;
		}
	}
}

- (BOOL) autoConnectForConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			return [[info objectForKey:@"automatic"] boolValue];
		}
	}

	return NO;
}

#pragma mark -

- (void) setShowConsoleOnConnect:(BOOL) autoConsole forConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			[info setObject:[NSNumber numberWithBool:autoConsole] forKey:@"showConsole"];
			[self _saveBookmarkList];
			break;
		}
	}
}

- (BOOL) showConsoleOnConnectForConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			return [[info objectForKey:@"showConsole"] boolValue];
		}
	}

	return NO;
}


#pragma mark -

- (void) setJoinRooms:(NSArray *) rooms forConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( [rooms count] ) [info setObject:[rooms mutableCopy] forKey:@"rooms"];
			else [info removeObjectForKey:@"rooms"];
			[self _saveBookmarkList];
			break;
		}
	}
}

- (NSMutableArray *) joinRoomsForConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			NSMutableArray *ret = [info objectForKey:@"rooms"];
			if( ! ret ) {
				ret = [NSMutableArray array];
				[info setObject:ret forKey:@"rooms"];
			}
			return ret;
		}
	}

	return nil;
}

#pragma mark -

- (void) setConnectCommands:(NSString *) commands forConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( commands ) [info setObject:[commands mutableCopy] forKey:@"commands"];
			else [info removeObjectForKey:@"commands"];
			[self _saveBookmarkList];
			break;
		}
	}
}

- (NSString *) connectCommandsForConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			return [info objectForKey:@"commands"];
		}
	}

	return nil;
}

#pragma mark -

- (void) setIgnoreRules:(NSArray *) ignores forConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			if( [ignores count] ) {
				NSMutableArray *copy = (id)ignores;
				if( ! [ignores isKindOfClass:[NSMutableArray class]] )
					copy = [ignores mutableCopy];
				[info setObject:copy forKey:@"ignores"];
			} else [info removeObjectForKey:@"ignores"];
			[self _saveBookmarkList];
			break;
		}
	}
}

- (NSMutableArray *) ignoreRulesForConnection:(MVChatConnection *) connection {
	for( NSMutableDictionary *info in _bookmarks ) {
		if( [info objectForKey:@"connection"] == connection ) {
			NSMutableArray *ret = [info objectForKey:@"ignores"];
			if( ! ret ) {
				ret = [NSMutableArray array];
				[info setObject:ret forKey:@"ignores"];
			}
			return ret;
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

- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	if( view == connections ) return [_bookmarks count];
	else if( view == newJoinRooms ) return [_joinRooms count];
	else if( view == userSelectionTable ) return [_userSelectionPossibleUsers count];
	return 0;
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == connections ) {
		if( [[column identifier] isEqualToString:@"auto"] ) {
			return [[_bookmarks objectAtIndex:row] objectForKey:@"automatic"];
		} else if( [[column identifier] isEqualToString:@"address"] ) {
			return [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] server];
		} else if( [[column identifier] isEqualToString:@"port"] ) {
			return [NSNumber numberWithUnsignedShort:[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] serverPort]];
		} else if( [[column identifier] isEqualToString:@"nickname"] ) {
			return [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] nickname];
		}
	} else if( view == newJoinRooms ) {
		return [_joinRooms objectAtIndex:row];
	} else if( view == userSelectionTable ) {
		MVChatUser *user = [_userSelectionPossibleUsers objectAtIndex:row];

		if( [[column identifier] isEqualToString:@"hostname"] ) {
			return [user address];
		} else if( [[column identifier] isEqualToString:@"fingerprint"] ) {
			return [user fingerprint];
		}
	}

	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == connections ) {
		if( [[column identifier] isEqual:@"status"] ) {
			NSString *imageName = nil;
			NSString *title = nil;
			if( [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] isConnected] ) {
				imageName = @"connectedTemplate";
				title = NSLocalizedString(@"Connected", "VoiceOver title for connected image");
			} else if( [(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] status] == MVChatConnectionConnectingStatus ) {
				imageName = @"connectingTemplate";
				title = NSLocalizedString(@"Connecting", "VoiceOver title for connecting image");
			} else {
				title = NSLocalizedString(@"Not connected", "VoiceOver title for not connected image");
			}
			if( imageName )
				[cell setImage:[NSImage imageNamed:imageName]];
			[cell setAccessibilityValueDescription:title];
		}
	}
}

- (void)menuNeedsUpdate:(NSMenu*)menu {
	if (menu == [connections menu]) {
		NSInteger clickedRow = [connections clickedRow];
		MVChatConnection *connection = nil;
		if (clickedRow != -1) {
			connection = [[_bookmarks objectAtIndex:clickedRow] objectForKey:@"connection"];
		}
		NSArray<NSMenuItem *> *menuItems = [self menuItemsForConnection:connection];
		if (@available(macOS 10.14, *)) {
			[menu setItemArray:menuItems];
		} else {
			[menu removeAllItems];
			for (NSMenuItem *item in menuItems) {
				[menu addItem:item];
			}
		}
	}
}

- (NSArray<NSMenuItem *> *) menuItemsForConnection:(nullable MVChatConnection *)connection {
	if (!connection) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"New Connection", "new connection contextual menu item title" ) action:@selector( newConnection: ) keyEquivalent:@""];
		[item setTarget:self];
		return @[item];
	} else {
		BOOL connected = [connection isConnected];
		NSMutableArray *menuItems = [NSMutableArray array];
		NSMenuItem *item = nil;

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""];
		[item setTarget:self];
		[menuItems addObject:item];

		if( connected ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Disconnect", "disconnect from server title" ) action:@selector( _disconnect: ) keyEquivalent:@""];
			[item setTarget:self];
			[menuItems addObject:item];
		} else {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Connect", "connect to server title" ) action:@selector( _connect: ) keyEquivalent:@""];
			[item setTarget:self];
			[menuItems addObject:item];
		}

		[menuItems addObject:[NSMenuItem separatorItem]];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Join Room...", "join room contextual menu item title" ) action:@selector( joinRoom: ) keyEquivalent:@""];
		[item setTarget:self];
		if( ! [_bookmarks count] ) [item setAction:NULL];
		[menuItems addObject:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Message User...", "message user contextual menu item title" ) action:@selector( _messageUser: ) keyEquivalent:@""];
		[item setTarget:self];
		if( ! connected ) [item setAction:NULL];
		[menuItems addObject:item];

		[menuItems addObject:[NSMenuItem separatorItem]];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"New Connection", "new connection contextual menu item title" ) action:@selector( newConnection: ) keyEquivalent:@""];
		[item setTarget:self];
		[menuItems addObject:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Delete", "delete item title" ) action:@selector( _delete: ) keyEquivalent:@""];
		[item setTarget:self];
		[menuItems addObject:item];

		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		id contextView = nil;

		[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
		MVAddUnsafeUnretainedAddress(connection, 2);
		MVAddUnsafeUnretainedAddress(contextView, 3);

		NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
		if( [results count] ) {
			if( [menuItems count ] && ! [[menuItems lastObject] isSeparatorItem] )
				[menuItems addObject:[NSMenuItem separatorItem]];

			for( NSArray *items in results ) {
				if( ![items conformsToProtocol:@protocol(NSFastEnumeration)] ) continue;
				for( item in items ) {
					if( [item isKindOfClass:[NSMenuItem class]] ) [menuItems addObject:item];
				}
			}
		}

		if( [[menuItems lastObject] isSeparatorItem] ) {
			[menuItems removeLastObject];
		}

		return menuItems;
	}
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == connections ) {
		if( [[column identifier] isEqual:@"auto"] ) {
			[[_bookmarks objectAtIndex:row] setObject:object forKey:@"automatic"];
			if( [object boolValue] )
				[[_bookmarks objectAtIndex:row] setObject:[NSNumber numberWithBool:NO] forKey:@"temporary"];
		} else if( [[column identifier] isEqual:@"nickname"] ) {
			[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] setPreferredNickname:object];
		} else if( [[column identifier] isEqual:@"address"] ) {
			[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] setServer:object];
		} else if( [[column identifier] isEqual:@"port"] ) {
			[(MVChatConnection *)[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] setServerPort:( [object unsignedIntValue] % 65536 )];
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


- (BOOL) tableView:(NSTableView *) tableView writeRowsWithIndexes:(NSIndexSet *) rowIndexes toPasteboard:(NSPasteboard *) board {
	if( tableView == connections ) {
		NSInteger row = rowIndexes.lastIndex;
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

		plist = @[ @[ connection.url.absoluteString ], @[ connection.url.host ] ];
		data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
		string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		[board setPropertyList:plist forType:@"WebURLsWithTitlesPboardType"];
		[board setString:string forType:@"WebURLsWithTitlesPboardType"];
		[board setData:data forType:@"WebURLsWithTitlesPboardType"];
	}

	return YES;
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(NSInteger) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( view == connections ) {
		NSString *string = nil;
		NSInteger index = -1;

		if( operation == NSTableViewDropOn && row != -1 ) return NSDragOperationNone;

		string = [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:MVConnectionPboardType]];
		NSData *pboardData = [[info draggingPasteboard] dataForType:MVConnectionPboardType];
		[pboardData getBytes:&index length:[pboardData length]];
		if( string && row >= 0 && row != index && ( row - 1 ) != index ) return NSDragOperationEvery;
		else if( string && row == -1 ) return NSDragOperationNone;

		if( row == -1 ) {
			if( [MVChatConnection supportsURLScheme:[[NSURL URLFromPasteboard:[info draggingPasteboard]] scheme]] )
				return NSDragOperationEvery;

			string = [[info draggingPasteboard] stringForType:NSStringPboardType];
			if( string && [MVChatConnection supportsURLScheme:[[NSURL URLWithString:string] scheme]] )
				return NSDragOperationEvery;

			string = [[info draggingPasteboard] stringForType:@"CorePasteboardFlavorType 0x75726C20"];
			if( string && [MVChatConnection supportsURLScheme:[[NSURL URLWithString:string] scheme]] )
				return NSDragOperationEvery;

			string = [[[[info draggingPasteboard] propertyListForType:@"WebURLsWithTitlesPboardType"] objectAtIndex:0] objectAtIndex:0];
			if( string && [MVChatConnection supportsURLScheme:[[NSURL URLWithString:string] scheme]] )
				return NSDragOperationEvery;
		}
	}

	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) view acceptDrop:(id <NSDraggingInfo>) info row:(NSInteger) row dropOperation:(NSTableViewDropOperation) operation {
	if( view == connections ) {
		if( [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:MVConnectionPboardType]] ) {
			NSInteger index = -1;
			NSData *pboardData = [[info draggingPasteboard] dataForType:MVConnectionPboardType];
			[pboardData getBytes:&index length:[pboardData length]];
			if( row > index ) row--;

			id item = [_bookmarks objectAtIndex:index];
			[_bookmarks removeObjectAtIndex:index];
			[_bookmarks insertObject:item atIndex:row];

			[self _refresh:nil];
			return YES;
		} else {
			NSString *string = nil;
			NSURL *url = [NSURL URLFromPasteboard:[info draggingPasteboard]];

			if( ! url || ! [MVChatConnection supportsURLScheme:[url scheme]] ) {
				string = [[info draggingPasteboard] stringForType:@"CorePasteboardFlavorType 0x75726C20"];
				if( string ) url = [NSURL URLWithString:string];
			}

			if( ! url || ! [MVChatConnection supportsURLScheme:[url scheme]] ) {
				string = [[[[info draggingPasteboard] propertyListForType:@"WebURLsWithTitlesPboardType"] objectAtIndex:0] objectAtIndex:0];
				if( string ) url = [NSURL URLWithString:string];
			}

			if( ! url || ! [MVChatConnection supportsURLScheme:[url scheme]] ) {
				string = [[info draggingPasteboard] stringForType:NSStringPboardType];
				if( string ) url = [NSURL URLWithString:string];
			}

			if( [MVChatConnection supportsURLScheme:[url scheme]] ) {
				[self handleURL:url andConnectIfPossible:NO];
				return YES;
			}
		}
	}

	return NO;
}

#pragma mark -

- (NSInteger) numberOfItemsInComboBox:(NSComboBox *) comboBox {
	if( comboBox == newAddress ) {
		return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] count];
	} else if( comboBox == newPort ) {
		MVChatConnectionType type = [self newTypeToConnectionType];
		return [[MVChatConnection defaultServerPortsForType:type] count];
	}

	return 0;
}

- (id) comboBox:(NSComboBox *) comboBox objectValueForItemAtIndex:(NSInteger) index {
	if( comboBox == newAddress ) {
		return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] objectAtIndex:index];
	} else if( comboBox == newPort ) {
		MVChatConnectionType type = [self newTypeToConnectionType];
		return [[MVChatConnection defaultServerPortsForType:type] objectAtIndex:index];
	}

	return nil;
}

- (NSUInteger) comboBox:(NSComboBox *) comboBox indexOfItemWithStringValue:(NSString *) string {
	if( comboBox == newAddress ) {
		return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] indexOfObject:string];
	}

	return NSNotFound;
}

- (NSString *) comboBox:(NSComboBox *) comboBox completedString:(NSString *) substring {
	if( comboBox == newAddress ) {
		for( NSString *server in [[NSUserDefaults standardUserDefaults] arrayForKey:@"JVChatServers"] )
			if( [server hasPrefix:substring] ) return server;
	}

	return nil;
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];

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
		[toolbarItem setImage:[NSImage imageNamed:NSImageNameInfo]];

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

		[toolbarItem setToolTip:NSLocalizedString( @"Delete Connection", "delete connection button tooltip" )];
		NSImage *deleteImage = [NSImage imageNamed:@"delete"];
		[toolbarItem setImage:deleteImage];
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

@implementation MVConnectionsController (Private)
- (void) _loadInterfaceIfNeeded {
	if( ! [self isWindowLoaded] ) [self window];
}

- (void) _registerNotificationsForConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionWillConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionDidConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionDidNotConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionDidDisconnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refresh: ) name:MVChatConnectionNicknameAcceptedNotification object:connection];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _willConnect: ) name:MVChatConnectionWillConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didDisconnect: ) name:MVChatConnectionDidDisconnectNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _errorOccurred : ) name:MVChatConnectionErrorNotification object:connection];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _requestPassword: ) name:MVChatConnectionNeedNicknamePasswordNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _requestCertificatePassword: ) name:MVChatConnectionNeedCertificatePasswordNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _requestPublicKeyVerification: ) name:MVChatConnectionNeedPublicKeyVerificationNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _didIdentify: ) name:MVChatConnectionDidIdentifyWithServicesNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _machineDidBecomeIdle: ) name:JVMachineBecameIdleNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _machineDidStopIdling: ) name:JVMachineStoppedIdlingNotification object:connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotConnectionError: ) name:MVChatConnectionGotErrorNotification object:connection];
}

- (void) _deregisterNotificationsForConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionWillConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionDidConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionDidNotConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionDidDisconnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:connection];

	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionWillConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionDidConnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionDidDisconnectNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionErrorNotification object:connection];

	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNeedNicknamePasswordNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNeedCertificatePasswordNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionNeedPublicKeyVerificationNotification object:connection];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionDidIdentifyWithServicesNotification object:connection];
}

- (void) _refresh:(NSNotification *) notification {
	[self _validateToolbar];
	[connections reloadData];
}

- (void) _applicationQuitting:(NSNotification *) notification {
	[self _saveBookmarkList];

	NSArray *bookmarkedConnections = [_bookmarks valueForKey:@"connection"];

	NSString *quitMessage = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"];
	if ( [quitMessage length] ) {
		NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:quitMessage];
		[bookmarkedConnections makeObjectsPerformSelector:@selector(disconnectWithReason:) withObject:quitMessageString];
	} else
		[bookmarkedConnections makeObjectsPerformSelector:@selector(disconnect)];
}

- (void) _errorOccurred:(NSNotification *) notification {
	NSString *errorTitle = nil;

	NSError *error = notification.userInfo[@"error"];
	switch ( error.code ) {
		case MVChatConnectionCantSendToRoomError:
			errorTitle = NSLocalizedString( @"Can't Send to Room", "cannot send to room error title" );
			break;
		case MVChatConnectionCantChangeNickError:
			errorTitle = NSLocalizedString( @"Can't Change Nick", "cannot change nickname error title" );
			break;
		case MVChatConnectionServicesDownError:
			errorTitle = NSLocalizedString( @"Services Down", "services down error title" );
			break;
		case MVChatConnectionCantChangeUsedNickError:
			errorTitle = NSLocalizedString( @"Service will change nickname", "service will change nickname error title" );
			break;
		case MVChatConnectionRoomIsFullError:
			errorTitle = NSLocalizedString( @"Room is Full", "room is full error title" );
			break;
		case MVChatConnectionInviteOnlyRoomError:
			errorTitle = NSLocalizedString( @"Invite Only Room", "invite only room error title" );
			break;
		case MVChatConnectionBannedFromRoomError:
			errorTitle = NSLocalizedString( @"Banned from Room", "banned from room error title" );
			break;
		case MVChatConnectionRoomPasswordIncorrectError:
			errorTitle = NSLocalizedString( @"Room Password Incorrect", "room password incorrect error title" );
			break;
		case MVChatConnectionIdentifyToJoinRoomError:
			errorTitle = NSLocalizedString( @"Identify to Join Room", "identify to join room error title" );
			break;
		default:
			errorTitle = NSLocalizedString( @"An Error Occured", "unknown error title" );
			break;
	}

	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	[context setObject:errorTitle forKey:@"title"];
	[context setObject:[[[notification userInfo] objectForKey:@"error"] localizedDescription] forKey:@"description"];
	[[JVNotificationController defaultController] performNotification:@"JVChatError" withContextInfo:context];

	NSMapTable *errorToAlertMappingsForConnection = [_connectionToErrorToAlertMap objectForKey:notification.object];
	if (!errorToAlertMappingsForConnection) {
		errorToAlertMappingsForConnection = [NSMapTable strongToStrongObjectsMapTable];
		[_connectionToErrorToAlertMap setObject:errorToAlertMappingsForConnection forKey:notification.object];
	}

	NSAlert *chatErrorAlert = [errorToAlertMappingsForConnection objectForKey:@(error.code)];
	if (chatErrorAlert) return;

	chatErrorAlert = [[NSAlert alloc] init];

	[errorToAlertMappingsForConnection setObject:chatErrorAlert forKey:@(error.code)];

	[chatErrorAlert setMessageText:errorTitle];
	if( error.userInfo[@"errorLiteralReason"] )
		[chatErrorAlert setInformativeText:[NSString stringWithFormat:NSLocalizedString( @"%@\n\nServer Details:\n%@", "error alert informative text with literal reason"), [[[notification userInfo] objectForKey:@"error"] localizedDescription], [[[[notification userInfo] objectForKey:@"error"] userInfo] objectForKey:@"errorLiteralReason"]]];
	else [chatErrorAlert setInformativeText:[[[notification userInfo] objectForKey:@"error"] localizedDescription]];

	[chatErrorAlert setAlertStyle:NSInformationalAlertStyle];

	if ( error.code == MVChatConnectionServicesDownError ) {
		// ask the user if we want to continue auto joining rooms without identification (== no hostmask cloaking) now that we know services are down
		// add "Continue Auto Join Sequence without identification?" to InformativeText
		[chatErrorAlert addButtonWithTitle:NSLocalizedString( @"Join", "join button" )];
		[chatErrorAlert addButtonWithTitle:NSLocalizedString( @"Cancel", "cancel button" )];
		if ( [chatErrorAlert runModal] == NSAlertFirstButtonReturn ) {
			[self _didIdentify:[NSNotification notificationWithName:@"continueConnectWithoutIdentification" object:[notification object]]];
		}
	} else if ( error.code == MVChatConnectionRoomPasswordIncorrectError && floor( NSAppKitVersionNumber ) > NSAppKitVersionNumber10_4) {
		// in case of incorrect password we can simplytry again with the correct one. leopard only for now, because NSAlert's setAccessoryView is 10.5+ only, 10.4 would need a new NIB for this feature:
		[chatErrorAlert addButtonWithTitle:NSLocalizedString( @"Join", "join button" )];
		[chatErrorAlert addButtonWithTitle:NSLocalizedString( @"Cancel", "cancel button" )];
		NSTextField *roomKeyAccessory = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0,0,220,22)];
		[[roomKeyAccessory cell] setPlaceholderString:NSLocalizedString( @"Room Key", "room key secure text field placeholder" )];
		[chatErrorAlert setAccessoryView:roomKeyAccessory];
		// the roomKeyAccessory should be in the tab chain and probably also the initial first responder, this code is not ready yet though
		// [chatErrorAlert layout];
		// [[chatErrorAlert window] setInitialFirstResponder:roomKeyAccessory];
		if ( [chatErrorAlert runModal] == NSAlertFirstButtonReturn ) {
			[[notification object] joinChatRoomNamed:[[[[notification userInfo] objectForKey:@"error"] userInfo] objectForKey:@"room"] withPassphrase:[roomKeyAccessory stringValue]];
		}
	} else {
		[chatErrorAlert runModal];
	}

	[errorToAlertMappingsForConnection removeObjectForKey:@(error.code)];

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
					if( NSRunCriticalAlertPanel( NSLocalizedString( @"You have been disconnected", "title of the you have been disconnected error" ), NSLocalizedString( @"The server may have shutdown for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", "connection dropped" ), NSLocalizedString( @"Reconnect", "reconnect to server button" ), NSLocalizedString( @"Cancel", "cancel button" ), nil ) == NSModalResponseOK )
						[connection connect];
				} else {
					if( NSRunCriticalAlertPanel( NSLocalizedString( @"Could not connect", "title of the could not connect error" ), NSLocalizedString( @"The server may be down for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", "connection dropped" ), NSLocalizedString( @"Retry", "retry connecting to server" ), NSLocalizedString( @"Cancel" "cancel buttun" ), nil ) == NSModalResponseOK )
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
				if( NSRunCriticalAlertPanel( NSLocalizedString( @"Could not connect to Chat server", "chat invalid password dialog title" ), NSLocalizedString( @"The server is disconnected or refusing connections from your computer. Make sure you are connected to the internet and have access to the server.", "chat invalid password dialog message" ), NSLocalizedString( @"Retry", "retry connecting to server" ), NSLocalizedString( @"Cancel", "cancel button" ), nil ) == NSModalResponseOK )
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
					[(JVChatRoomPanel *)[[JVChatController defaultController] chatViewControllerForRoom:target withConnection:connection ifExists:YES] unavailable];
				} else if( target ) {
					[(JVDirectChatPanel *)[[JVChatController defaultController] chatViewControllerForUser:target withConnection:connection ifExists:YES] unavailable];
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
	if( ! _bookmarks ) return; // _loadBookmarkList hasn't fired yet, we have nothing to save

	NSUInteger roomCount = 0;
	NSMutableArray *saveList = [NSMutableArray arrayWithCapacity:[_bookmarks count]];

	for( id info in _bookmarks ) {
		if( ! [[info objectForKey:@"temporary"] boolValue] ) {
			MVChatConnection *connection = [info objectForKey:@"connection"];
			if( ! connection ) continue;

			NSMutableDictionary *data = [NSMutableDictionary dictionary];
			[data setObject:[NSNumber numberWithBool:[[info objectForKey:@"automatic"] boolValue]] forKey:@"automatic"];
			[data setObject:[NSNumber numberWithBool:[[info objectForKey:@"showConsole"] boolValue]] forKey:@"showConsole"];
			[data setObject:[NSNumber numberWithBool:[connection isSecure]] forKey:@"secure"];
			[data setObject:[NSNumber numberWithBool:connection.requestsSASL] forKey:@"requestsSASL"];
			[data setObject:[NSNumber numberWithBool:connection.roomsWaitForIdentification] forKey:@"roomsWaitForIdentification"];
			[data setObject:[NSNumber numberWithLong:[connection proxyType]] forKey:@"proxy"];
			[data setObject:[NSNumber numberWithLong:[connection encoding]] forKey:@"encoding"];
			[data setObject:[connection uniqueIdentifier] forKey:@"uniqueIdentifier"];
			[data setObject:[connection server] forKey:@"server"];
			[data setObject:[NSNumber numberWithUnsignedShort:[connection serverPort]] forKey:@"port"];
			if( [connection preferredNickname] )
				[data setObject:[connection preferredNickname] forKey:@"nickname"];
			if( [[connection alternateNicknames] count] )
				[data setObject:[connection alternateNicknames] forKey:@"alternateNicknames"];
			if( [(NSArray *)[info objectForKey:@"rooms"] count] ) [data setObject:[info objectForKey:@"rooms"] forKey:@"rooms"];
			if( [info objectForKey:@"commands"] ) [data setObject:[info objectForKey:@"commands"] forKey:@"commands"];
			[data setObject:[info objectForKey:@"created"] forKey:@"created"];
			if( [connection realName] )
				[data setObject:[connection realName] forKey:@"realName"];
			if( [connection username] )
				[data setObject:[connection username] forKey:@"username"];
			[data setObject:[connection urlScheme] forKey:@"type"];

			if( [[connection persistentInformation] count] )
				[data setObject:[connection persistentInformation] forKey:@"persistentInformation"];

			NSMutableArray *permIgnores = [NSMutableArray array];

			for( KAIgnoreRule *rule in [info objectForKey:@"ignores"] ) {
				if( [rule isPermanent] ) {
					NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:rule];
					if( archive ) [permIgnores addObject:archive];
				}
			}

			if( [permIgnores count] ) [data setObject:permIgnores forKey:@"ignores"];

			roomCount += [[connection knownChatRooms] count];

			[saveList addObject:data];
		}
	}

	[[NSUserDefaults standardUserDefaults] setObject:saveList forKey:@"MVChatBookmarks"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	JVAnalyticsController *analyticsController = [JVAnalyticsController defaultController];
	if (analyticsController) {
		[analyticsController setObject:[NSNumber numberWithUnsignedLong:roomCount] forKey:@"total-rooms"];
		[analyticsController setObject:[NSNumber numberWithUnsignedLong:[saveList count]] forKey:@"total-connections"];
	}

	[self _validateToolbar];
}

- (void) _loadBookmarkList {
	NSArray *list = [[NSUserDefaults standardUserDefaults] arrayForKey:@"MVChatBookmarks"];

	[self _deregisterNotificationsForConnection:nil]; // deregister all connections

	_bookmarks = [[NSMutableArray alloc] init];

	for( __strong NSMutableDictionary *info in list ) {
		info = [NSMutableDictionary dictionaryWithDictionary:info];

		MVChatConnection *connection = nil;

		MVChatConnectionType type;
		if( ! [(NSString *)[info objectForKey:@"type"] length] )
		    type = MVChatConnectionIRCType;
		else {
			if( [info[@"type"] isEqualToString:@"icb"] ) type = MVChatConnectionICBType;
			else if( [info[@"type"] isEqualToString:@"irc"] ) type = MVChatConnectionIRCType;
		    else if( [info[@"type"] isEqualToString:@"silc"] ) type = MVChatConnectionSILCType;
		    else if( [info[@"type"] isEqualToString:@"xmpp"] ) type = MVChatConnectionXMPPType;
			else type = MVChatConnectionIRCType;
		}

		if( info[@"url"] ) {
			connection = [[MVChatConnection alloc] initWithURL:[NSURL URLWithString:info[@"url"]]];
		} else {
			connection = [[MVChatConnection alloc] initWithServer:info[@"server"] type:type port:[info[@"port"] unsignedShortValue] user:info[@"nickname"]];
		}

		if( ! connection ) continue;

		if (info[@"uniqueIdentifier"]) connection.uniqueIdentifier = info[@"uniqueIdentifier"];

		connection.persistentInformation = info[@"persistentInformation"];
		connection.proxyType = [info[@"proxy"] unsignedIntValue];

		if( [info[@"encoding"] longValue] ) connection.encoding = [info[@"encoding"] longValue];
		else connection.encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];

		connection.outgoingChatFormat = [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatFormat"] unsignedIntValue];

		if( info[@"realName"] ) connection.realName = info[@"realName"];
		if( info[@"nickname"] ) connection.preferredNickname = info[@"nickname"];
		if( info[@"username"] ) connection.username = info[@"username"];
		if( info[@"alternateNicknames"] )
			connection.alternateNicknames = info[@"alternateNicknames"];

		NSMutableArray *permIgnores = [NSMutableArray array];
		for( NSData *rule in [info objectForKey:@"ignores"] ) {
			NSData *archive = [NSKeyedUnarchiver unarchiveObjectWithData:rule];
			if( archive ) [permIgnores addObject:archive];
		}

		info[@"ignores"] = permIgnores;

		connection.secure = [info[@"secure"] boolValue];
		connection.requestsSASL = [[info objectForKey:@"requestsSASL"] boolValue];
		connection.roomsWaitForIdentification = [info[@"roomsWaitForIdentification"] boolValue];
		info[@"connection"] = connection;

		[_bookmarks addObject:info];

		[self _registerNotificationsForConnection:connection];

		NSString *password = [[CQKeychain standardKeychain] passwordForServer:connection.uniqueIdentifier area:@"Server"];;
		if (!password) {
			password = [[MVKeyChain defaultKeyChain] internetPasswordForServer:connection.server securityDomain:connection.server account:nil path:nil port:connection.serverPort protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];

			if (password.length) {
				[[MVKeyChain defaultKeyChain] removeInternetPasswordForServer:connection.server securityDomain:connection.server account:nil path:nil port:connection.serverPort protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
				[[CQKeychain standardKeychain] setPassword:password forServer:connection.uniqueIdentifier area:@"Server" displayValue:connection.server];
			}
		}
		connection.password = password;

		NSString *nicknamePassword = [[CQKeychain standardKeychain] passwordForServer:connection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", connection.preferredNickname]];
		if (!nicknamePassword) {
			nicknamePassword = [[MVKeyChain defaultKeyChain] internetPasswordForServer:[connection server] securityDomain:[connection server] account:[connection preferredNickname] path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];

			if (nicknamePassword.length) {
				[[MVKeyChain defaultKeyChain] removeInternetPasswordForServer:connection.server securityDomain:connection.server account:connection.preferredNickname path:nil port:0 protocol:MVKeyChainProtocolIRC authenticationType:MVKeyChainAuthenticationTypeDefault];
				[[CQKeychain standardKeychain] setPassword:nicknamePassword forServer:connection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", connection.preferredNickname] displayValue:connection.server];
			}
		}
		connection.nicknamePassword = nicknamePassword;

		if( [info[@"automatic"] boolValue] && ! ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) )
			[connection connect];
	}

	[connections noteNumberOfRowsChanged];

	if( ! [_bookmarks count] ) [self newConnection:nil];

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowConnectionsWindowOnLaunch"] )
		[[self window] orderFront:nil];

	[self _validateToolbar];
}

- (void) _validateToolbar {
	BOOL noneSelected = YES;
	MVChatConnectionStatus status = MVChatConnectionDisconnectedStatus;

	if( [connections selectedRow] != -1 ) noneSelected = NO;
	if( ! noneSelected ) status = [(MVChatConnection *)[[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"] status];

	for( NSToolbarItem *item in [[[self window] toolbar] visibleItems] ) {
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

	if( [nicknameAuth isVisible] ) {
		// Do somthing better here, like queue requests until the current one is sent
		return;
	}

	[authAddress setObjectValue:[connection server]];
	[authNickname setObjectValue:[connection nickname]];
	[authPassword setObjectValue:@""];
	[authKeychain setState:NSOffState];

	_passConnection = connection;

	[nicknameAuth center];
	[nicknameAuth setLevel:NSModalPanelWindowLevel]; 
	[nicknameAuth orderFront:nil];
}

- (void) _requestCertificatePassword:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];

	NSString *pass = [[MVKeyChain defaultKeyChain] genericPasswordForService:[connection certificateServiceName] account:@"Colloquy"];
	if( pass.length ) {
		[[CQKeychain standardKeychain] setPassword:pass forServer:[connection certificateServiceName] area:@"Colloquy"];
		[[MVKeyChain defaultKeyChain] removeGenericPasswordForService:[connection certificateServiceName] account:@"Colloquy"];
	}

	if( [pass length] ) {
		// if authenticateCertificateWithPassword returns NO, its the wrong password.
		if( [connection authenticateCertificateWithPassword:pass] ) return;
	}

	if( [certificateAuth isVisible] ) {
		// Do somthing better here, like queue requests until the current one is sent
		return;
	}

	[certificateDescription setObjectValue:[NSString stringWithFormat:NSLocalizedString( @"Your certificate is locked with a passphrase. In order to connect to %@, you need to unlock your certificate.", "certificate unlock request, server name inserted" ), [connection server]]];
	[certificatePassphrase setObjectValue:@""];
	[certificateKeychain setState:NSOffState];

	_certificateConnection = connection;

	[certificateAuth center];
	[certificateAuth orderFront:nil];
}

- (void) _requestPublicKeyVerification:(NSNotification *) notification {
	NSDictionary *dict = [notification userInfo];

	if( [publicKeyVerification isVisible] ) {
		[_publicKeyRequestQueue addObject:notification];
		return;
	}

	switch( [[dict objectForKey:@"publicKeyType"] unsignedIntValue] ) {
		case MVChatConnectionClientPublicKeyType:
			[publicKeyNameDescription setObjectValue:NSLocalizedString( @"User name:", "verification target name" )];
			[publicKeyDescription setObjectValue:NSLocalizedString( @"Please verify the users public key.", "message of verification for public key" )];
			break;
		case MVChatConnectionServerPublicKeyType:
			[publicKeyNameDescription setObjectValue:NSLocalizedString( @"Server name:", "verification target name" )];
			[publicKeyDescription setObjectValue:NSLocalizedString( @"Please verify the servers public key.", "message of verification for public key" )];
			break;
	}

	[publicKeyName setObjectValue:[dict objectForKey:@"name"]];
	[publicKeyFingerprint setObjectValue:[dict objectForKey:@"fingerprint"]];
	[publicKeyBabbleprint setObjectValue:[dict objectForKey:@"babbleprint"]];
	[publicKeyAlwaysAccept setState:NSOffState];

	_publicKeyDictionary = dict;

	[publicKeyVerification center];
	[publicKeyVerification orderFront:nil];
}

- (void) _autoJoinRoomsForConnection:(MVChatConnection *) connection {
	NSMutableArray *roomIdentifiers = [[self joinRoomsForConnection:connection] mutableCopy];

	for( JVChatRoomPanel *chatRoomController in [[JVChatController defaultController] chatViewControllersWithConnection:connection] ) {
		if( ![chatRoomController isMemberOfClass:NSClassFromString(@"JVChatRoomPanel")] )
			continue;

		MVChatRoom *openRoom = (MVChatRoom *)[chatRoomController target];
		NSString *openRoomIdentifier = [openRoom uniqueIdentifier];
		if( !( [openRoom modes] & MVChatRoomInviteOnlyMode ) ) {
			if( ( [openRoom modes] & MVChatRoomPassphraseToJoinMode ) ) {
				[roomIdentifiers removeObject:openRoomIdentifier];
				NSString *openRoomIdentifierWithPassphrase = [[openRoomIdentifier stringByAppendingString:@" "] stringByAppendingString:[openRoom attributeForMode:MVChatRoomPassphraseToJoinMode]];
				if ( ![roomIdentifiers containsObject:openRoomIdentifierWithPassphrase] )
					[roomIdentifiers addObject:openRoomIdentifierWithPassphrase];
			} else if( ![roomIdentifiers containsObject:openRoomIdentifier] )
				[roomIdentifiers addObject:openRoomIdentifier];
		}
	}

	if( [roomIdentifiers count] && ! ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) )
		[connection joinChatRoomsNamed:roomIdentifiers];
}

- (void) _didIdentify:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];

	if ( [[notification name] isEqualToString:MVChatConnectionDidIdentifyWithServicesNotification] ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"You Have Been Identified", "identified bubble title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"%@ has identified you as %@ on %@.", "identified bubble message, server message and server name" ), [[notification userInfo] objectForKey:@"user"], [[notification userInfo] objectForKey:@"target"], [connection server]] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"Keychain"] forKey:@"image"];
		[[JVNotificationController defaultController] performNotification:@"JVNickNameIdentifiedWithServer" withContextInfo:context];
	}

	NSString *strcommands = [self connectCommandsForConnection:connection];

	if( ! ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ) ) {
		for( __strong NSMutableString *command in [strcommands componentsSeparatedByString:@"\n"] ) {
			command = [command mutableCopy];
			[command replaceOccurrencesOfString:@"%@" withString:[connection nickname] options:NSLiteralSearch range:NSMakeRange( 0, [command length] )];

			if( [command hasPrefix:@"\\"] ) {
				command = (NSMutableString *)[command substringFromIndex:1];

				NSString *arguments = @"";
				NSRange range = [command rangeOfString:@" "];
				if( range.location != NSNotFound ) {
					if( ( range.location + 1 ) < [command length] )
						arguments = [command substringFromIndex:( range.location + 1 )];
					command = (NSMutableString *)[command substringToIndex:range.location];
				}

				NSAttributedString *args = [[NSAttributedString alloc] initWithString:arguments];
				id view = nil;

				NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( MVChatConnection * ), @encode( id ), nil];
				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

				[invocation setSelector:@selector( processUserCommand:withArguments:toConnection:inView: )];
				MVAddUnsafeUnretainedAddress(command, 2);
				MVAddUnsafeUnretainedAddress(args, 3);
				MVAddUnsafeUnretainedAddress(connection, 4);
				MVAddUnsafeUnretainedAddress(view, 5);

				NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
				if( ! [[results lastObject] boolValue] )
					[connection sendCommand:command withArguments:args];
			}
		}
	}

	if( [[connection nicknamePassword] length] && [connection roomsWaitForIdentification] )
		[self _autoJoinRoomsForConnection:connection];
}

- (void) _connect:(id) sender {
	if( [connections selectedRow] == -1 ) return;
	MVChatConnection *connection = [[_bookmarks objectAtIndex:[connections selectedRow]] objectForKey:@"connection"];

	connection.password = [[CQKeychain standardKeychain] passwordForServer:connection.uniqueIdentifier area:@"Server"];
	connection.nicknamePassword = [[CQKeychain standardKeychain] passwordForServer:connection.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", connection.preferredNickname]];
	[connection connect];
}

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];

	if( [self showConsoleOnConnectForConnection:connection] )
		[[JVChatController defaultController] chatConsoleForConnection:connection ifExists:NO];

	NSString *strcommands = [self connectCommandsForConnection:connection];

	if( ! ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ) ) {
		for( __strong NSMutableString *command in [strcommands componentsSeparatedByString:@"\n"] ) {
			command = [command mutableCopy];
			[command replaceOccurrencesOfString:@"%@" withString:[connection nickname] options:NSLiteralSearch range:NSMakeRange( 0, [command length] )];

			if( [command hasPrefix:@"/"] ) {
				command = (NSMutableString *)[command substringFromIndex:1];

				NSString *arguments = @"";
				NSRange range = [command rangeOfString:@" "];
				if( range.location != NSNotFound ) {
					if( ( range.location + 1 ) < [command length] )
						arguments = [command substringFromIndex:( range.location + 1 )];
					command = (NSMutableString *)[command substringToIndex:range.location];
				}

				NSAttributedString *args = [[NSAttributedString alloc] initWithString:arguments];
				id view = nil;

				NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( BOOL ), @encode( NSString * ), @encode( NSAttributedString * ), @encode( MVChatConnection * ), @encode( id ), nil];
				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

				[invocation setSelector:@selector( processUserCommand:withArguments:toConnection:inView: )];
				MVAddUnsafeUnretainedAddress(command, 2);
				MVAddUnsafeUnretainedAddress(args, 3);
				MVAddUnsafeUnretainedAddress(connection, 4);
				MVAddUnsafeUnretainedAddress(view, 5);

				NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:YES];
				if( ! [[results lastObject] boolValue] )
					[connection sendCommand:command withArguments:args];
			} else if( [command length] && ! [command hasPrefix:@"\\"] ) {
				[connection sendCommand:command withArguments:nil];
			}
		}
	}

	if( ![[connection nicknamePassword] length] || ( [[connection nicknamePassword] length] && ![connection roomsWaitForIdentification] ) )
		[self _autoJoinRoomsForConnection:connection];
}

- (void) _didConnect:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	[context setObject:NSLocalizedString( @"Connected", "connected bubble title" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You're now connected to %@ as %@.", "you are now connected bubble text" ), [connection server], [connection nickname]] forKey:@"description"];
	[context setObject:[NSImage imageNamed:@"connect"] forKey:@"image"];
	[[JVNotificationController defaultController] performNotification:@"JVChatConnected" withContextInfo:context];

	[[NSProcessInfo processInfo] disableSuddenTermination];
	[[NSProcessInfo processInfo] disableAutomaticTermination:@"chat connection opened."];
}

- (void) _didDisconnect:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	if( [connection status] == MVChatConnectionServerDisconnectedStatus ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"Disconnected", "disconnected bubble title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You're were disconnected from %@.", "you were disconnected bubble text" ), [connection server]] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"disconnect"] forKey:@"image"];
		[[JVNotificationController defaultController] performNotification:@"JVChatDisconnected" withContextInfo:context];
	}

	[[NSProcessInfo processInfo] enableSuddenTermination];
	[[NSProcessInfo processInfo] enableAutomaticTermination:@"chat connection closed"];
}

- (void) _gotConnectionError:(NSNotification *) notification {
//	MVChatConnection *connection = notification.object;
//
//	NSAlert *alert = [[NSAlert alloc] init];
//	alert.messageText = connection.server;
//	alert.informativeText = [notification.userInfo objectForKey:@"message"];
//	[alert addButtonWithTitle:NSLocalizedString(@"Okay", @"Okay button title")];
//
//	[alert runModal];
}

- (NSString *) _idleMessageString {
	NSString *awayString = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVIdleMessage"];
	return [awayString length] ? awayString : NSLocalizedString(@"Currently away from the computer", @"Currently away from the computer idle message");
}

- (void) _machineDidBecomeIdle:(NSNotification *) notification {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoAwayOnIdle"])
		return;

	MVChatConnection *connection = [notification object];
	if ( [connection status] != MVChatConnectionConnectedStatus)
		return;

	if ([[connection awayStatusMessage] length])
		return;

	MVChatString *awayMessage = [[MVChatString alloc] initWithString:[self _idleMessageString]];
	[connection setAwayStatusMessage:awayMessage];
}


 - (void) _machineDidStopIdling:(NSNotification *) notification {
	 if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoAwayOnIdle"])
		 return;

	 MVChatConnection *connection = [notification object];
	 if ( [connection status] != MVChatConnectionConnectedStatus)
		 return;

	 NSString *awayMessageString = [[connection awayStatusMessage] string];

	 // If we set the connection idle automatically, we should unset away when we're no longer idle. Otherwise, leave it alone
	 if ([awayMessageString isEqualToString:[self _idleMessageString]])
		 [connection setAwayStatusMessage:nil];
}

- (void) _disconnect:(id) sender {
	NSInteger row = [connections selectedRow];
	if( row == -1 ) return;
	
	MVChatConnection *selectedBookmarkedConnection = [[_bookmarks objectAtIndex:row] objectForKey:@"connection"];

	NSString *quitMessage = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"];
	if ( [quitMessage length] ) {
		NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:quitMessage];
		[selectedBookmarkedConnection disconnectWithReason:quitMessageString];
	} else
		[selectedBookmarkedConnection disconnect];
}

- (void) _delete:(id) sender {
	NSInteger row = [connections selectedRow];
	if( row == -1 ) return;

	MVChatConnection *connection = [[_bookmarks objectAtIndex:row] objectForKey:@"connection"];
	
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString( @"Are you sure you want to delete?", "delete confirm dialog title" );
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"Are you sure you want to delete the connection for %@? Any associated Keychain passwords will also be deleted.", "confirm the delete of a connection" ), [connection server]];
	alert.alertStyle = NSAlertStyleCritical;
	[alert addButtonWithTitle:NSLocalizedString( @"Cancel", "cancel button" )];
	[alert addButtonWithTitle:NSLocalizedString( @"OK", "OK button" )];
	[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
		if( returnCode != NSAlertSecondButtonReturn) return;
		
		[connections deselectAll:nil];
		[self removeConnectionAtIndex:row];
	}];
}

- (void) _messageUser:(id) sender {
	if( [connections selectedRow] == -1 ) return;
	[self.window beginSheet:messageUser completionHandler:nil];
}

- (void) _openConsole:(id) sender {
	NSInteger row = [connections selectedRow];
	if( row == -1 ) return;
	[[JVChatController defaultController] chatConsoleForConnection:[[_bookmarks objectAtIndex:row] objectForKey:@"connection"] ifExists:NO];
}

+ (void) _openFavoritesFolder:(id) sender {
	[[NSWorkspace sharedWorkspace] openFile:[@"~/Library/Application Support/Colloquy/Favorites" stringByExpandingTildeInPath]];
}

+ (void) _connectToFavorite:(id) sender {
	if( ! [sender representedObject] ) return;
	[[MVConnectionsController defaultController] handleURL:[sender representedObject] andConnectIfPossible:YES];
}
@end

#pragma mark -

@implementation MVChatConnection (MVChatConnectionObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatConnections" uniqueID:[self scriptUniqueIdentifier]];
}
@end

#pragma mark -

@implementation NSApplication (MVConnectionsControllerScripting)
- (void) newConnection:(NSScriptCommand *) command {
	[[MVConnectionsController defaultController] newConnection:nil];
}

#pragma mark -

- (NSArray *) chatConnections {
	return [[MVConnectionsController defaultController] connections];
}

- (MVChatConnection *) valueInChatConnectionsAtIndex:(NSUInteger) index {
	return [[self chatConnections] objectAtIndex:index];
}

- (MVChatConnection *) valueInChatConnectionsWithUniqueID:(id) identifier {
	for( MVChatConnection *connection in [self chatConnections] )
		if( [[connection scriptUniqueIdentifier] isEqual:identifier] )
			return connection;

	return nil;
}

- (void) addInChatConnections:(MVChatConnection *) connection {
	[[MVConnectionsController defaultController] addConnection:connection];
}

- (void) insertInChatConnections:(MVChatConnection *) connection {
	[[MVConnectionsController defaultController] addConnection:connection];
}

- (void) insertInChatConnections:(MVChatConnection *) connection atIndex:(NSUInteger) index {
	[[MVConnectionsController defaultController] insertConnection:connection atIndex:index];
}

- (void) removeFromChatConnectionsAtIndex:(NSUInteger) index {
	[[MVConnectionsController defaultController] removeConnectionAtIndex:index];
}

- (void) replaceInChatConnections:(MVChatConnection *) connection atIndex:(NSUInteger) index {
	[[MVConnectionsController defaultController] replaceConnectionAtIndex:index withConnection:connection];
}
@end
