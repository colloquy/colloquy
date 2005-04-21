#import <ChatCore/MVChatConnection.h>
#import <ChatCore/NSAttributedStringAdditions.h>

#import "JVChatRoomBrowser.h"
#import "JVChatController.h"
#import "JVChatConsolePanel.h"
#import "MVConnectionsController.h"
#import "MVTableView.h"

@interface NSDisclosureButtonCell
+ (id) alloc;
- (id) initWithCell:(NSCell *) cell;
@end

#pragma mark -

@interface JVChatRoomBrowser (JVChatRoomBrowserPrivate)
- (void) _needToRefreshResults:(id) sender;
- (void) _refreshResults:(id) sender;
- (void) _resortResults;
- (void) _connectionChange:(NSNotification *) notification;
- (void) _startFetch;
- (void) _stopFetch;
@end

#pragma mark -

@implementation JVChatRoomBrowser
- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"JVChatRoomBrowser"] ) ) {
		_connection = nil;
		_roomResults = nil;
		_roomOrder = nil;
		_currentFilter = nil;
		_sortColumn = @"room";
		_ascending = YES;
		_collapsed = YES;
		_needsRefresh = YES;

		_refreshTimer = [[NSTimer scheduledTimerWithTimeInterval:( 2. ) target:self selector:@selector( _refreshResults: ) userInfo:nil repeats:YES] retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _connectionChange: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _connectionChange: ) name:MVChatConnectionDidDisconnectNotification object:nil];
	}
	return self;
}

- (id) initWithConnection:(MVChatConnection *) connection {
	if( ( self = [self initWithWindowNibName:nil] ) ) {
		[self setConnection:connection];
	}
	return self;
}

+ (id) chatRoomBrowserForConnection:(MVChatConnection *) connection {
	return [[self alloc] initWithConnection:connection];
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[_refreshTimer invalidate];
	[super release];
}

- (void) dealloc {
	[roomField setDelegate:nil];
	[roomField setDataSource:nil];

	[roomsTable setDelegate:nil];
	[roomsTable setDataSource:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_refreshTimer release];
	[_connection release];
	[_currentFilter release];
	[_roomResults release];
	[_roomOrder release];
	[_sortColumn release];

	_refreshTimer = nil;
	_connection = nil;
	_currentFilter = nil;
	_roomResults = nil;
	_roomOrder = nil;
	_sortColumn = nil;

	[super dealloc];
}

- (void) windowDidLoad {
	NSTableColumn *theColumn = nil;

	theColumn = [roomsTable tableColumnWithIdentifier:@"members"];
	[[theColumn headerCell] setImage:[NSImage imageNamed:@"personHeader"]];

	[self tableView:roomsTable didClickTableColumn:[roomsTable tableColumnWithIdentifier:_sortColumn]];

	[roomsTable setDoubleAction:@selector( joinRoom: )];

	[showBroswer setCell:[[[NSDisclosureButtonCell alloc] initWithCell:[showBroswer cell]] autorelease]];

	if( NSAppKitVersionNumber >= 700. ) {
		[searchField setCell:[[[NSClassFromString( @"NSSearchFieldCell" ) alloc] initTextCell:@""] autorelease]];
		[searchField setBezelStyle:NSTextFieldRoundedBezel];
		[searchField setBezeled:YES];
		[searchField setEditable:YES];
		[searchField setEditable:YES];
		[[searchField cell] performSelector:@selector( setPlaceholderString: ) withObject:@"Filter Rooms"];
	}

	[searchField setAction:@selector( filterResults: )];
	[searchField setTarget:self];

	_collapsed = NO;
	[showBroswer setState:NSOffState];
	[self toggleRoomBrowser:showBroswer];

	[self _connectionChange:nil];

	_needsRefresh = YES;
	[self _refreshResults:nil];

	if( [connectionPopup indexOfSelectedItem] != -1 )
		[[self window] makeFirstResponder:roomField];
}

#pragma mark -

- (void) close {
	[[self window] orderOut:nil];
	[[NSApplication sharedApplication] endSheet:[self window]];

	if( _connection ) [self _stopFetch];

	[super close];

	[self performSelector:@selector( release ) withObject:nil afterDelay:0.];
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
	_needsRefresh = YES;
	[self _refreshResults:nil];
}

- (IBAction) changeConnection:(id) sender {
	[self setConnection:[[sender selectedItem] representedObject]];
	[[self window] makeFirstResponder:roomField];

	if( ! _collapsed && ! [_connection isConnected] ) {
		if( NSRunInformationalAlertPanel( NSLocalizedString( @"Connection is Disconnected", "connection is disconnected dialog title" ), NSLocalizedString( @"Would you like to connect and retrieve the server's chat room listing?", "would you like to connect to get room listing dialog message" ), NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
			[_connection connect];
		} else {
			[showBroswer setState:NSOffState];
			[self toggleRoomBrowser:showBroswer];
		}
	}
}

- (IBAction) hideRoomBrowser:(id) sender {
	if( _collapsed ) return;
	[showBroswer setState:NSOffState];
	[self toggleRoomBrowser:showBroswer];
}

- (IBAction) showRoomBrowser:(id) sender {
	if( ! _collapsed ) return;
	[showBroswer setState:NSOnState];
	[self toggleRoomBrowser:showBroswer];
}

- (IBAction) toggleRoomBrowser:(id) sender {
	NSRect windowFrame = [[self window] frame];

	if( ! [_connection isConnected] && [sender state] ) {
		if( NSRunInformationalAlertPanel( NSLocalizedString( @"Connection is Disconnected", "connection is disconnected dialog title" ), NSLocalizedString( @"Would you like to connect and retrieve the server's chat room listing?", "would you like to connect to get room listing dialog message" ), NSLocalizedString( @"Yes", "yes button" ), NSLocalizedString( @"No", "no button" ), nil ) == NSOKButton ) {
			[_connection connect];
		} else {
			[sender setState:NSOffState];
			return;
		}
	}

	static float origWidth = 0.;
	if( ! origWidth ) origWidth = NSWidth( windowFrame );

	static float origOffset = 0.;
	if( ! origOffset ) origOffset = NSHeight( [borwserArea frame] );

	float offset = NSHeight( [borwserArea frame] );
	if( ! offset ) offset = origOffset;

	float width = NSWidth( windowFrame );

	[searchArea selectTabViewItemAtIndex:2];

	if( ! [sender state] ) {
		[borwserArea selectTabViewItemAtIndex:0];
		[[self window] setShowsResizeIndicator:NO];
		width = origWidth;
		_collapsed = YES;
	} else width = 500.;

	NSRect newWindowFrame = NSMakeRect( ( NSMinX( windowFrame ) + ( ( NSWidth( windowFrame ) - width ) / 2. ) ), NSMinY( windowFrame ) + ( [sender state] ? offset * -1 : offset ), width, ( [sender state] ? NSHeight( windowFrame ) + offset : NSHeight( windowFrame ) - offset ) );
	[[self window] setFrame:newWindowFrame display:YES animate:YES];

	if( [sender state] ) {
		[roomsTable sizeLastColumnToFit];
		[borwserArea selectTabViewItemAtIndex:1];
		[searchArea selectTabViewItemAtIndex:1];
		[[self window] setShowsResizeIndicator:YES];
		_collapsed = NO;
		[self _startFetch];
	} else [searchArea selectTabViewItemAtIndex:0];

	_needsRefresh = YES;
	[self _refreshResults:nil];
}

#pragma mark -

- (void) setFilter:(NSString *) filter {
	[_currentFilter autorelease];
	_currentFilter = [filter copy];
	[searchField setStringValue:_currentFilter];
}

- (NSString *) filter {
	return [[_currentFilter retain] autorelease];
}

#pragma mark -

- (void) setConnection:(MVChatConnection *) connection {
	if( _connection ) {
		[self _stopFetch];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_connection];
	}

	[_connection autorelease];
	_connection = [connection retain];

	if( _connection && ! _collapsed )
		[self _startFetch];

	if( _connection ) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _needToRefreshResults: ) name:MVChatConnectionChatRoomlistUpdatedNotification object:_connection];

	[_roomResults autorelease];
	_roomResults = [[_connection chatRoomListResults] retain];

	[_roomOrder autorelease];
	_roomOrder = [[NSMutableArray array] retain];

	_needsRefresh = YES;
	[self _refreshResults:nil];

	[showBroswer setEnabled:( _connection ? YES : NO )];
	[roomField setEnabled:( _connection ? YES : NO )];
}

- (MVChatConnection *) connection {
	return [[_connection retain] autorelease];
}

#pragma mark -

- (NSSize) windowWillResize:(NSWindow *) window toSize:(NSSize) proposedFrameSize {
	return ( _collapsed ? [window frame].size : proposedFrameSize );
}

- (BOOL) windowShouldZoom:(NSWindow *) window toFrame:(NSRect) newFrame {
	return ( _collapsed ? NO : YES );
}

#pragma mark -

- (int) numberOfItemsInComboBox:(NSComboBox *) comboBox {
	return [_roomOrder count];
}

- (id) comboBox:(NSComboBox *) comboBox objectValueForItemAtIndex:(int) index {
	return [_roomOrder objectAtIndex:index];
}

- (unsigned int) comboBox:(NSComboBox *) comboBox indexOfItemWithStringValue:(NSString *) string {
	return [_roomOrder indexOfObject:string];
}

- (NSString *) comboBox:(NSComboBox *) comboBox completedString:(NSString *) substring {
	NSEnumerator *enumerator = [_roomOrder objectEnumerator];
	NSString *room = nil;
	while( ( room = [enumerator nextObject] ) )
		if( [room hasPrefix:substring] ) return room;
	return nil;
}

- (void) comboBoxSelectionDidChange:(NSNotification *) notification {
	[acceptButton setEnabled:( [roomField indexOfSelectedItem] != -1 || [[roomField stringValue] length] )];

	if( ! _collapsed && roomsTable != [[roomsTable window] firstResponder] ) {
		int index = [roomField indexOfSelectedItem];
		if( index != -1 ) {
			[roomsTable selectRow:index byExtendingSelection:NO];
			[roomsTable scrollRowToVisible:index];
		} else [roomsTable deselectAll:nil];
	}
}

- (void) controlTextDidChange:(NSNotification *) notification {
	[acceptButton setEnabled:( [[roomField stringValue] length] )];

	if( ! _collapsed && roomsTable != [[roomsTable window] firstResponder] ) {
		int index = [roomField indexOfSelectedItem];
		if( index != -1 ) {
			[roomsTable selectRow:index byExtendingSelection:NO];
			[roomsTable scrollRowToVisible:index];
		} else [roomsTable deselectAll:nil];
	}
}

- (void) controlTextDidEndEditing:(NSNotification *) notification {
	if( ! _collapsed && roomsTable != [[roomsTable window] firstResponder] ) {
		int index = [roomField indexOfSelectedItem];
		if( index != -1 ) {
			[roomsTable selectRow:index byExtendingSelection:NO];
			[roomsTable scrollRowToVisible:index];
		} else [roomsTable deselectAll:nil];
	}
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_roomOrder count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqualToString:@"room"] ) {
		return [_roomOrder objectAtIndex:row];
	} else if( [[column identifier] isEqualToString:@"topic"] ) {
		NSMutableDictionary *info = [_roomResults objectForKey:[_roomOrder objectAtIndex:row]];
		NSAttributedString *t = [info objectForKey:@"topicAttributed"];

		if( ! t ) {
			NSData *topic = [info objectForKey:@"topic"];
			NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[_connection encoding]], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", [NSFont systemFontOfSize:11.], @"BaseFont", nil];
			if( ! ( t = [NSAttributedString attributedStringWithChatFormat:topic options:options] ) ) {
				[options setObject:[NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]] forKey:@"StringEncoding"];
				t = [NSAttributedString attributedStringWithChatFormat:topic options:options];
			}

			if( t ) [info setObject:t forKey:@"topicAttributed"];
		}

		return t;
	} else if( [[column identifier] isEqualToString:@"members"] ) {
		NSString *room = [_roomOrder objectAtIndex:row];
		return [[_roomResults objectForKey:room] objectForKey:@"users"];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view didClickTableColumn:(NSTableColumn *) column {
	if( [[column identifier] isEqualToString:@"topic"] ) return;

	[[view window] makeFirstResponder:view];

	BOOL ascending = [[view indicatorImageInTableColumn:column] isEqual:[MVTableView ascendingSortIndicator]];

	[view setIndicatorImage:nil inTableColumn:[view highlightedTableColumn]];

	if( ascending ) [view setIndicatorImage:[MVTableView descendingSortIndicator] inTableColumn:column];
	else [view setIndicatorImage:[MVTableView ascendingSortIndicator] inTableColumn:column];

	[view setHighlightedTableColumn:column];

	_ascending = ! ascending;

	[_sortColumn autorelease];
	_sortColumn = [[column identifier] copy];

	unsigned int index = [roomsTable selectedRow];
	NSString *selectedRoom = ( index != -1 && [_roomOrder count] ? [[[_roomOrder objectAtIndex:index] copy] autorelease] : nil );
	[roomsTable deselectAll:nil];

	[self _resortResults];

	if( selectedRoom ) index = [_roomOrder indexOfObject:selectedRoom];
	else index = NSNotFound;

	if( index != NSNotFound ) {
		[roomsTable selectRow:index byExtendingSelection:NO];
		[roomsTable scrollRowToVisible:index];
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	if( [notification object] != [[[notification object] window] firstResponder] ) return;

	if( [roomsTable selectedRow] == -1 ) {
		[roomField setObjectValue:@""];
		[acceptButton setEnabled:( [[roomField stringValue] length] )];
	} else {
		[roomField setObjectValue:[_roomOrder objectAtIndex:[roomsTable selectedRow]]];
		[acceptButton setEnabled:( [[roomField stringValue] length] )];
	}
}
@end

#pragma mark -

NSComparisonResult sortByRoomNameAscending( NSString *room1, NSString *room2, void *context ) {
	return [room1 caseInsensitiveCompare:room2];
}

NSComparisonResult sortByRoomNameDescending( NSString *room1, NSString *room2, void *context ) {
	return [room2 caseInsensitiveCompare:room1];
}

NSComparisonResult sortByNumberOfMembersAscending( NSString *room1, NSString *room2, void *context ) {
	NSDictionary *info = context;
	NSComparisonResult res = [(NSNumber *)[[info objectForKey:room1] objectForKey:@"users"] compare:[[info objectForKey:room2] objectForKey:@"users"]];
	if( res != NSOrderedSame ) return res;
	return [room1 caseInsensitiveCompare:room2];
}

NSComparisonResult sortByNumberOfMembersDescending( NSString *room1, NSString *room2, void *context ) {
	NSDictionary *info = context;
	NSComparisonResult res = [(NSNumber *)[[info objectForKey:room2] objectForKey:@"users"] compare:[[info objectForKey:room1] objectForKey:@"users"]];
	if( res != NSOrderedSame ) return res;
	return [room1 caseInsensitiveCompare:room2];
}

#pragma mark -

@implementation JVChatRoomBrowser (JVChatRoomBrowserPrivate)
- (void) _connectionChange:(NSNotification *) notification {
	NSEnumerator *enumerator = [[[MVConnectionsController defaultManager] connections] objectEnumerator];
	MVChatConnection *connection = nil;
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	while( ( connection = [enumerator nextObject] ) ) {
		item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", [connection server], [connection nickname]] action:NULL keyEquivalent:@""] autorelease];

		NSImage *icon = nil;
		if( [connection isConnected] ) icon = [NSImage imageNamed:@"connected"];
		else icon = [[[NSImage alloc] initWithSize:NSMakeSize( 9., 16. )] autorelease];
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
	[showBroswer setEnabled:( _connection ? YES : NO )];
	[roomField setEnabled:( _connection ? YES : NO )];

	if( [connectionPopup indexOfSelectedItem] == -1 || ! [menu numberOfItems] ) {
		[roomField setObjectValue:@""];
		[acceptButton setEnabled:NO];
		if( ! _collapsed ) {
			[showBroswer setState:NSOffState];
			[self toggleRoomBrowser:showBroswer];
		}
	}
}

- (void) _needToRefreshResults:(id) sender {
	_needsRefresh = YES;
}

- (void) _refreshResults:(id) sender {
	if( ! _needsRefresh ) return;
	_needsRefresh = NO;

	unsigned int index = [roomsTable selectedRow];
	NSString *selectedRoom = ( index != -1 && [_roomOrder count] ? [[[_roomOrder objectAtIndex:index] copy] autorelease] : nil );

	if( _collapsed || ! [_currentFilter length] ) {
		[_roomOrder setArray:[_roomResults allKeys]];
		goto refresh;
	}

	NSEnumerator *enumerator = [_roomResults keyEnumerator];
	NSEnumerator *venumerator = [_roomResults objectEnumerator];
	NSString *room = nil;
	NSDictionary *info = nil;

	[_roomOrder removeAllObjects]; // this is far more efficient than doing a containsObject: and a removeObject: during the while

	while( ( room = [enumerator nextObject] ) && ( info = [venumerator nextObject] ) ) {
		if( [room rangeOfString:_currentFilter options:NSCaseInsensitiveSearch].location != NSNotFound || [[[info objectForKey:@"topicAttributed"] string] rangeOfString:_currentFilter options:NSCaseInsensitiveSearch].location != NSNotFound ) {
			[_roomOrder addObject:room];
		}
	}

refresh:
	if( _connection && [_connection isConnected] && [_roomResults count] ) {
		[indexResults setObjectValue:[NSString stringWithFormat:NSLocalizedString( @"%d rooms indexed.", "number of rooms listed on the server" ), [_roomResults count]]];
		if( ! [_currentFilter length] ) {
			[indexAndFindResults setObjectValue:[indexResults stringValue]];
		} else {
			[indexAndFindResults setObjectValue:[NSString stringWithFormat:NSLocalizedString( @"%d of %d rooms found.", "number of rooms found with a filter from the server listing" ), [_roomOrder count], [_roomResults count]]];
		}
	} else {
		[indexResults setObjectValue:@""];
		[indexAndFindResults setObjectValue:@""];
	}

	[roomsTable deselectAll:nil];

	[self _resortResults];

	if( selectedRoom ) index = [_roomOrder indexOfObject:selectedRoom];
	else index = NSNotFound;

	if( index != NSNotFound ) {
		[roomsTable selectRow:index byExtendingSelection:NO];
		[roomsTable scrollRowToVisible:index];
	}
}

- (void) _resortResults {
	if( _collapsed || ( [_sortColumn isEqualToString:@"room"] && _ascending ) ) [_roomOrder sortUsingFunction:sortByRoomNameAscending context:NULL];
	else if( [_sortColumn isEqualToString:@"room"] && ! _ascending ) [_roomOrder sortUsingFunction:sortByRoomNameDescending context:NULL];
	else if( [_sortColumn isEqualToString:@"members"] && _ascending ) [_roomOrder sortUsingFunction:sortByNumberOfMembersAscending context:_roomResults];
	else if( [_sortColumn isEqualToString:@"members"] && ! _ascending ) [_roomOrder sortUsingFunction:sortByNumberOfMembersDescending context:_roomResults];

	if( ! _collapsed ) [roomsTable noteNumberOfRowsChanged];
	[roomField noteNumberOfItemsChanged];
}

- (void) _startFetch {
	JVChatConsolePanel *console = [[JVChatController defaultManager] chatConsoleForConnection:_connection ifExists:YES];
	[console pause];
	[_connection fetchChatRoomList];
}

- (void) _stopFetch {
	[_connection stopFetchingChatRoomList];
	JVChatConsolePanel *console = [[JVChatController defaultManager] chatConsoleForConnection:_connection ifExists:YES];
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
	id connection = [args objectForKey:@"connection"];
	id filter = [args objectForKey:@"filter"];
	id expanded = [args objectForKey:@"expanded"];
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