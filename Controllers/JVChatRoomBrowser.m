#import "JVChatRoomBrowser.h"
#import "JVChatController.h"
#import "JVChatConsolePanel.h"
#import "MVConnectionsController.h"
#import "MVTableView.h"
#import "NSImageAdditions.h"

@interface JVChatRoomBrowser (Private)
- (void) _needToRefreshResults:(id) sender;
- (void) _refreshResults:(id) sender;
- (void) _resortResults;
- (void) _connectionChange:(NSNotification *) notification;
- (void) _startFetch;
- (void) _stopFetch;

- (void) tableView:(NSTableView *) view didClickTableColumn:(NSTableColumn *) column;
@end

#pragma mark -

@implementation JVChatRoomBrowser
- (instancetype) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_self = self;
		_sortColumn = @"room";
		_ascending = YES;
		_collapsed = YES;

		[self _userDefaultsChanged:nil];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _connectionChange: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _connectionChange: ) name:MVChatConnectionDidDisconnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _userDefaultsChanged: ) name:NSUserDefaultsDidChangeNotification object:nil];
	}
	return self;
}

- (instancetype) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self initWithWindowNibName:@"JVChatRoomBrowser"] ) ) {
		[self setConnection:connection];
	}
	return self;
}

+ (instancetype) chatRoomBrowserForConnection:(MVChatConnection *) connection {
	return [[self alloc] initWithConnection:connection];
}

- (void) dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _refreshResults: ) object:nil];

	[roomField setDelegate:nil];
	[roomField setDataSource:nil];

	[roomsTable setDelegate:nil];
	[roomsTable setDataSource:nil];

	[[NSNotificationCenter chatCenter] removeObserver:self];
}

- (void) windowDidLoad {
	NSTableColumn *theColumn = nil;

	[roomsTable accessibilitySetOverrideValue:NSLocalizedString(@"Chat rooms", "VoiceOver title for chat rooms table") forAttribute:NSAccessibilityDescriptionAttribute];

	theColumn = [roomsTable tableColumnWithIdentifier:@"members"];
	NSImage *headerImage = [NSImage imageFromPDF:@"person"];
	headerImage.size = NSMakeSize(10., 10.);
	[[theColumn headerCell] setImage:headerImage];
	[[theColumn headerCell] accessibilitySetOverrideValue:NSLocalizedString(@"Participants", "VoiceOver title for number of connected users in chat room browser table") forAttribute:NSAccessibilityDescriptionAttribute];

	[self tableView:roomsTable didClickTableColumn:[roomsTable tableColumnWithIdentifier:_sortColumn]];

	[roomsTable setDoubleAction:@selector( joinRoom: )];

	[showBrowser setBezelStyle:NSRoundedDisclosureBezelStyle];
	[showBrowser setButtonType:NSOnOffButton];
	[[showBrowser cell] accessibilitySetOverrideValue:NSLocalizedString(@"Show chat rooms", "VoiceOver title for disclosure checkbox for chat rooms table in Join room dialog") forAttribute:NSAccessibilityDescriptionAttribute];

	[searchField setAction:@selector( filterResults: )];
	[searchField setTarget:self];

	_collapsed = NO;
	[showBrowser setState:NSOffState];
	[self toggleRoomBrowser:showBrowser];

	[self _connectionChange:nil];

	[self _refreshResults:nil];

	[[self window] recalculateKeyViewLoop];

	NSWindowCollectionBehavior windowCollectionBehavior = NSWindowCollectionBehaviorDefault | NSWindowCollectionBehaviorParticipatesInCycle;
	if( floor( NSAppKitVersionNumber ) >= NSAppKitVersionNumber10_7 )
		windowCollectionBehavior |= NSWindowCollectionBehaviorFullScreenAuxiliary;

	[[self window] setCollectionBehavior:windowCollectionBehavior];

	if( [connectionPopup indexOfSelectedItem] != -1 )
		[[self window] makeFirstResponder:roomField];
}

#pragma mark -

- (void) close {
	[[self window] orderOut:nil];
	[[NSApplication sharedApplication] endSheet:[self window]];

	if( _connection ) [self _stopFetch];

	[super close];

	[self performSelector:@selector( _nilOutSelf ) withObject:nil afterDelay:0.];
}

- (void) _nilOutSelf {
	_self = nil;
}

#pragma mark -

- (IBAction) showWindow:(id) sender {
	[[self window] center];
	[[self window] makeKeyAndOrderFront:sender];
}

- (IBAction) close:(id) sender {
	[self close];
}

- (IBAction) joinRoom:(id) sender {
	[self close];

	if( ! [_connection isConnected] ) [_connection connect];
	[_connection joinChatRoomNamed:[roomField stringValue]];
}

- (IBAction) filterResults:(id) sender {
	[self setFilter:[searchField stringValue]];
	[self _refreshResults:nil];
}

- (IBAction) changeConnection:(id) sender {
	[self setConnection:[[sender selectedItem] representedObject]];
	[[self window] makeFirstResponder:roomField];

	if( ! _collapsed && ! [_connection isConnected] ) {
		if( NSRunInformationalAlertPanel( NSLocalizedString( @"Connection is Disconnected", "connection is disconnected dialog title" ), NSLocalizedString( @"Would you like to connect and retrieve the server's chat room listing?", "would you like to connect to get room listing dialog message" ), NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil, nil ) == NSOKButton ) {
			[_connection connect];
		} else {
			[showBrowser setState:NSOffState];
			[self toggleRoomBrowser:showBrowser];
		}
	}
}

- (IBAction) hideRoomBrowser:(id) sender {
	if( _collapsed ) return;
	[showBrowser setState:NSOffState];
	[self toggleRoomBrowser:showBrowser];
}

- (IBAction) showRoomBrowser:(id) sender {
	if( ! _collapsed ) return;
	[showBrowser setState:NSOnState];
	[self toggleRoomBrowser:showBrowser];
}

- (IBAction) toggleRoomBrowser:(id) sender {
	NSRect windowFrame = [[self window] frame];

	if( ! [_connection isConnected] && [sender state] ) {
		if( NSRunInformationalAlertPanel( NSLocalizedString( @"Connection is Disconnected", "connection is disconnected dialog title" ), NSLocalizedString( @"Would you like to connect and retrieve the server's chat room listing?", "would you like to connect to get room listing dialog message" ), NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil, nil ) == NSOKButton ) {
			[_connection connect];
		} else {
			[sender setState:NSOffState];
			return;
		}
	}

	static CGFloat origWidth = 0.;
	if( ! origWidth ) origWidth = NSWidth( windowFrame );

	static CGFloat origOffset = 0.;
	if( ! origOffset ) origOffset = NSHeight( [browserArea frame] );

	CGFloat offset = NSHeight( [browserArea frame] );
	if( ! offset ) offset = origOffset;

	CGFloat width = 500.;

	[searchArea selectTabViewItemAtIndex:2];

	if( ! [sender state] ) {
		[browserArea selectTabViewItemAtIndex:0];
		[[self window] setShowsResizeIndicator:NO];
		width = origWidth;
		_collapsed = YES;
	}

	NSRect newWindowFrame = NSMakeRect( ( NSMinX( windowFrame ) + ( ( NSWidth( windowFrame ) - width ) / 2. ) ), NSMinY( windowFrame ) + ( [sender state] ? offset * -1 : offset ), width, ( [sender state] ? NSHeight( windowFrame ) + offset : NSHeight( windowFrame ) - offset ) );
	[[self window] setFrame:newWindowFrame display:YES animate:YES];

	if( [sender state] ) {
		[roomsTable sizeLastColumnToFit];
		[browserArea selectTabViewItemAtIndex:1];
		[searchArea selectTabViewItemAtIndex:1];
		[[self window] setShowsResizeIndicator:YES];
		_collapsed = NO;
		[self _startFetch];
	} else [searchArea selectTabViewItemAtIndex:0];

	[self _refreshResults:nil];

	[[self window] recalculateKeyViewLoop];
}

#pragma mark -

- (void) setFilter:(NSString *) filter {
	_currentFilter = [filter copy];
	[searchField setStringValue:_currentFilter];
}

- (NSString *) filter {
	return _currentFilter;
}

#pragma mark -

- (void) setConnection:(MVChatConnection *) connection {
	if( _connection ) {
		[self _stopFetch];
		[[NSNotificationCenter chatCenter] removeObserver:self name:nil object:_connection];
	}

	_connection = connection;

	if( _connection && ! _collapsed )
		[self _startFetch];

	__weak __typeof__((self)) weakSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		if( strongSelf->_connection ) [[NSNotificationCenter chatCenter] addObserver:strongSelf selector:@selector( _needToRefreshResults: ) name:MVChatConnectionChatRoomListUpdatedNotification object:strongSelf->_connection];
	});

	_roomResults = [_connection chatRoomListResults];

	_roomOrder = [NSMutableArray array];

	[self _refreshResults:nil];

	[showBrowser setEnabled:( _connection ? YES : NO )];
	[roomField setEnabled:( _connection ? YES : NO )];
}

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (NSSize) windowWillResize:(NSWindow *) window toSize:(NSSize) proposedFrameSize {
	return ( _collapsed ? [window frame].size : proposedFrameSize );
}

- (BOOL) windowShouldZoom:(NSWindow *) window toFrame:(NSRect) newFrame {
	return ( _collapsed ? NO : YES );
}

#pragma mark -

- (NSInteger) numberOfItemsInComboBox:(NSComboBox *) comboBox {
	return [_roomOrder count];
}

- (id) comboBox:(NSComboBox *) comboBox objectValueForItemAtIndex:(NSInteger) index {
	return _roomOrder[index];
}

- (NSUInteger) comboBox:(NSComboBox *) comboBox indexOfItemWithStringValue:(NSString *) string {
	return [_roomOrder indexOfObject:string];
}

- (NSString *) comboBox:(NSComboBox *) comboBox completedString:(NSString *) substring {
	for( NSString *room in _roomOrder )
		if( [room hasPrefix:substring] ) return room;
	return nil;
}

- (void) comboBoxSelectionDidChange:(NSNotification *) notification {
	[acceptButton setEnabled:( [roomField indexOfSelectedItem] != -1 || [[roomField stringValue] length] )];

	if( ! _collapsed && roomsTable != [[roomsTable window] firstResponder] ) {
		NSInteger index = [roomField indexOfSelectedItem];
		if( index != -1 ) {
			[roomsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
			[roomsTable scrollRowToVisible:index];
		} else [roomsTable deselectAll:nil];
	}
}

- (void) controlTextDidChange:(NSNotification *) notification {
	[acceptButton setEnabled:( [[roomField stringValue] length] )];

	if( ! _collapsed && roomsTable != [[roomsTable window] firstResponder] ) {
		NSInteger index = [roomField indexOfSelectedItem];
		if( index != -1 ) {
			[roomsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
			[roomsTable scrollRowToVisible:index];
		} else [roomsTable deselectAll:nil];
	}
}

- (void) controlTextDidEndEditing:(NSNotification *) notification {
	if( ! _collapsed && roomsTable != [[roomsTable window] firstResponder] ) {
		NSInteger index = [roomField indexOfSelectedItem];
		if( index != -1 ) {
			[roomsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
			[roomsTable scrollRowToVisible:index];
		} else [roomsTable deselectAll:nil];
	}
}

- (void) _userDefaultsChanged:(NSNotification *) notification {
	_ignoreFontColors = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"];
	_ignoreFontTraits = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"];
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	return [_roomOrder count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( [column.identifier isEqualToString:@"room"] ) {
		return _roomOrder[row];
	} else if( [column.identifier isEqualToString:@"topic"] ) {
		NSMutableDictionary *info = _roomResults[_roomOrder[row]];
		NSAttributedString *t = info[@"topicAttributed"];

		if( ! t ) {
			NSData *topic = info[@"topic"];
			NSMutableDictionary *options = [@{
				@"StringEncoding": @(_connection.encoding),
				@"IgnoreFontColors": @(_ignoreFontColors),
				@"IgnoreFontTraits": @(_ignoreFontTraits),
				@"BaseFont": [NSFont systemFontOfSize:11.]
			} mutableCopy];

			if( ! ( t = [NSAttributedString attributedStringWithChatFormat:topic options:options] ) ) {
				options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);

				t = [NSAttributedString attributedStringWithChatFormat:topic options:options];
			}

			if( t ) info[@"topicAttributed"] = t;
		}

		return t;
	} else if( [column.identifier isEqualToString:@"members"] ) {
		return _roomResults[_roomOrder[row]][@"users"];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view didClickTableColumn:(NSTableColumn *) column {
	if( [[column identifier] isEqualToString:@"topic"] ) return;

	[[view window] makeFirstResponder:view];

	BOOL ascending = [[view indicatorImageInTableColumn:column] isEqual:[NSImage imageNamed:@"NSDescendingSortIndicator"]];

	[view setIndicatorImage:nil inTableColumn:[view highlightedTableColumn]];

	if( ascending ) [view setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:column];
	else [view setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:column];

	[view setHighlightedTableColumn:column];

	_ascending = ! ascending;

	_sortColumn = [[column identifier] copy];

	NSInteger index = [roomsTable selectedRow];
	NSString *selectedRoom = ( index != -1 && [_roomOrder count] ? [_roomOrder[index] copy] : nil );
	[roomsTable deselectAll:nil];

	[self _resortResults];

	if( selectedRoom ) index = [_roomOrder indexOfObject:selectedRoom];
	else index = NSNotFound;


	if( index != NSNotFound ) {
		[roomsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[roomsTable scrollRowToVisible:index];
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	if( [notification object] != [[[notification object] window] firstResponder] ) return;

	if( [roomsTable selectedRow] == -1 ) {
		[roomField setObjectValue:@""];
		[acceptButton setEnabled:( [[roomField stringValue] length] )];
	} else {
		[roomField setObjectValue:_roomOrder[[roomsTable selectedRow]]];
		[acceptButton setEnabled:( [[roomField stringValue] length] )];
	}
}
@end

#pragma mark -

static NSComparisonResult sortByRoomNameAscending( NSString *room1, NSString *room2, void *context ) {
	return [room1 caseInsensitiveCompare:room2];
}

static NSComparisonResult sortByRoomNameDescending( NSString *room1, NSString *room2, void *context ) {
	return [room2 caseInsensitiveCompare:room1];
}

static NSComparisonResult sortByNumberOfMembersAscending( NSString *room1, NSString *room2, void *context ) {
	NSDictionary *info = (__bridge NSDictionary *)(context);
	NSComparisonResult res = [(NSNumber *)(info[room1])[@"users"] compare:(info[room2])[@"users"]];
	if( res != NSOrderedSame ) return res;
	return [room1 caseInsensitiveCompare:room2];
}

static NSComparisonResult sortByNumberOfMembersDescending( NSString *room1, NSString *room2, void *context ) {
	NSDictionary *info = (__bridge NSDictionary *)(context);
	NSComparisonResult res = [(NSNumber *)(info[room2])[@"users"] compare:(info[room1])[@"users"]];
	if( res != NSOrderedSame ) return res;
	return [room1 caseInsensitiveCompare:room2];
}

#pragma mark -

@implementation JVChatRoomBrowser (JVChatRoomBrowserPrivate)
- (void) _connectionChange:(NSNotification *) notification {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

	for( MVChatConnection *connection in [[MVConnectionsController defaultController] connections] ) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", [connection server], [connection nickname]] action:NULL keyEquivalent:@""];

		NSImage *icon = nil;
		if( [connection isConnected] ) icon = [NSImage imageNamed:@"connected"];
		else icon = [[NSImage alloc] initWithSize:NSMakeSize( 9., 16. )];
		[item setImage:icon];

		[item setRepresentedObject:connection];
		if( connection == _connection ) [item setState:NSOnState];
		[menu addItem:item];
	}

	[connectionPopup setMenu:menu];

	if( [[notification name] isEqualToString:MVChatConnectionDidConnectNotification] && [notification object] == _connection ) {
		if( ! _collapsed ) [self _startFetch];
	} else if( [[notification name] isEqualToString:MVChatConnectionDidDisconnectNotification] && [notification object] == _connection ) {
		[self setConnection:nil];
	}

	if( ! _connection && [menu numberOfItems] ) [connectionPopup selectItemAtIndex:-1];

	[connectionPopup setEnabled:( ! ( ! _connection && ! [menu numberOfItems] ) )];
	[showBrowser setEnabled:( _connection ? YES : NO )];
	[roomField setEnabled:( _connection ? YES : NO )];

	if( [connectionPopup indexOfSelectedItem] == -1 || ! [menu numberOfItems] ) {
		[roomField setObjectValue:@""];
		[acceptButton setEnabled:NO];
		if( ! _collapsed ) {
			[showBrowser setState:NSOffState];
			[self toggleRoomBrowser:showBrowser];
		}
	}
}

- (void) _needToRefreshResults:(id) sender {
	if( ! [_roomOrder count] ) { // first refresh, do immediately
		[self _refreshResults:nil];
		return;
	}

	if( _needsRefresh ) return; // already queued to refresh
	_needsRefresh = YES;

	[self performSelector:@selector( _refreshResults: ) withObject:nil afterDelay:1.];
}

- (void) _refreshResults:(id) sender {
	NSInteger index = roomsTable.selectedRow;
	NSString *selectedRoom = ( index != -1 && _roomOrder.count ? [_roomOrder[index] copy] : nil );
	NSMutableDictionary *options = nil;

	if( _collapsed || ! _currentFilter.length ) {
		_roomOrder.array = _roomResults.allKeys;
		goto refresh;
	}

	[_roomOrder removeAllObjects]; // this is far more efficient than doing a containsObject: and a removeObject: during the while

	options = [@{
		@"StringEncoding": @(_connection.encoding),
		@"IgnoreFontColors": @(_ignoreFontColors),
		@"IgnoreFontTraits": @(_ignoreFontTraits),
		@"BaseFont": [NSFont systemFontOfSize:11.]
	} mutableCopy];

	for( NSString *room in _roomResults ) {
		NSMutableDictionary *info = _roomResults[room];

		if( [room rangeOfString:_currentFilter options:NSCaseInsensitiveSearch].location != NSNotFound ) {
			[_roomOrder addObject:room];
			continue;
		}

		NSAttributedString *t = info[@"topicAttributed"];

		if( ! t ) {
			NSData *topic = info[@"topic"];
			options[@"StringEncoding"] = @(_connection.encoding);

			if( ! ( t = [NSAttributedString attributedStringWithChatFormat:topic options:options] ) ) {
				options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);
				t = [NSAttributedString attributedStringWithChatFormat:topic options:options];
			}

			if( t ) info[@"topicAttributed"] = t;
		}

		if( t && [t.string rangeOfString:_currentFilter options:NSCaseInsensitiveSearch].location != NSNotFound )
			[_roomOrder addObject:room];
	}

refresh:
	if( _connection && _connection.isConnected && _roomResults.count ) {
		indexResults.objectValue = [NSString stringWithFormat:NSLocalizedString( @"%d rooms indexed.", "number of rooms listed on the server" ), _roomResults.count];
		if( ! _currentFilter.length ) {
			indexAndFindResults.objectValue = indexResults.stringValue;
		} else {
			indexAndFindResults.objectValue = [NSString stringWithFormat:NSLocalizedString( @"%d of %d rooms found.", "number of rooms found with a filter from the server listing" ), _roomOrder.count, _roomResults.count];
		}
	} else {
		indexResults.objectValue = @"";
		indexAndFindResults.objectValue = @"";
	}

	[roomsTable deselectAll:nil];

	[self _resortResults];

	if( selectedRoom ) index = [_roomOrder indexOfObject:selectedRoom];
	else index = NSNotFound;


	if( index != NSNotFound ) {
		[roomsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[roomsTable scrollRowToVisible:index];
	}

	_needsRefresh = NO;
}

- (void) _resortResults {
	if( _collapsed || ( [_sortColumn isEqualToString:@"room"] && _ascending ) ) [_roomOrder sortUsingFunction:sortByRoomNameAscending context:NULL];
	else if( [_sortColumn isEqualToString:@"room"] && ! _ascending ) [_roomOrder sortUsingFunction:sortByRoomNameDescending context:NULL];
	else if( [_sortColumn isEqualToString:@"members"] && _ascending ) [_roomOrder sortUsingFunction:sortByNumberOfMembersAscending context:(__bridge void *)(_roomResults)];
	else if( [_sortColumn isEqualToString:@"members"] && ! _ascending ) [_roomOrder sortUsingFunction:sortByNumberOfMembersDescending context:(__bridge void *)(_roomResults)];

	if( ! _collapsed ) [roomsTable noteNumberOfRowsChanged];
	[roomField noteNumberOfItemsChanged];
}

- (void) _startFetch {
	JVChatConsolePanel *console = [[JVChatController defaultController] chatConsoleForConnection:_connection ifExists:YES];
	[console pause];
	[_connection fetchChatRoomList];
}

- (void) _stopFetch {
	[_connection stopFetchingChatRoomList];
	JVChatConsolePanel *console = [[JVChatController defaultController] chatConsoleForConnection:_connection ifExists:YES];
	[console resume];
}
@end

#pragma mark -

@interface JVOpenRoomBrowserScriptCommand : NSScriptCommand {}
@end

#pragma mark -

@implementation JVOpenRoomBrowserScriptCommand
- (id) performDefaultImplementation {
	NSDictionary *args = [self evaluatedArguments];
	id connection = args[@"connection"];
	id filter = args[@"filter"];
	id expanded = args[@"expanded"];
	BOOL realExpanded = NO;

	if( [expanded isKindOfClass:[NSNumber class]] )
		realExpanded = [expanded boolValue];

	JVChatRoomBrowser *browser = [JVChatRoomBrowser chatRoomBrowserForConnection:connection];
	[browser showWindow:nil];
	if( filter ) [browser setFilter:[filter description]];
	if( realExpanded ) {
		[browser _startFetch];
		[browser showRoomBrowser:nil];
	}

	return nil;
}
@end
