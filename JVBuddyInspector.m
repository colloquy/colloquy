#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>

#import "MVConnectionsController.h"
#import "JVBuddyInspector.h"

@implementation JVBuddy (JVBuddyInspection)
- (id <JVInspector>) inspector {
	return [[[JVBuddyInspector alloc] initWithBuddy:self] autorelease];
}
@end

#pragma mark -

@implementation JVBuddyInspector
- (id) initWithBuddy:(JVBuddy *) buddy {
	if( ( self = [self init] ) ) {
		_buddy = [buddy retain];
	}
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_buddy release];
	_buddy = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVBuddyInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 250., 300. );
}

- (NSString *) title {
	return [_buddy compositeName];
}

- (NSString *) type {
	return NSLocalizedString( @"Buddy", "buddy inspector type" );
}

- (void) willLoad {
	NSMutableSet *addresses = [NSMutableSet set];
	NSEnumerator *enumerator = [[[MVConnectionsController defaultManager] connections] objectEnumerator];
	MVChatConnection *connection = nil;
	NSString *address = nil;

	while( ( connection = [enumerator nextObject] ) )
		[addresses addObject:[connection server]];

	enumerator = [addresses objectEnumerator];
	while( ( address = [enumerator nextObject] ) )
		[servers addItemWithTitle:address];

	[picture setImage:[_buddy picture]];
	[firstName setObjectValue:[_buddy firstName]];
	[lastName setObjectValue:[_buddy lastName]];
	[nickname setObjectValue:[_buddy givenNickname]];
	[email setObjectValue:[_buddy primaryEmail]];

	[self changeServer:servers];
}

#pragma mark -

- (IBAction) changeServer:(id) sender {
	if( [[sender selectedItem] tag] ) {
		[_activeNicknames autorelease];
		_activeNicknames = [[[_buddy nicknames] allObjects] mutableCopy];
		[[nicknames tableColumnWithIdentifier:@"nickname"] setEditable:NO];
		[addNickname setEnabled:NO];
	} else {
		[_activeNicknames autorelease];
		_activeNicknames = [[NSMutableArray array] retain];

		NSEnumerator *enumerator = [[_buddy nicknames] objectEnumerator];
		NSURL *url = nil;

		while( ( url = [enumerator nextObject] ) )
			if( [[servers titleOfSelectedItem] caseInsensitiveCompare:[url host]] == NSOrderedSame )
				[_activeNicknames addObject:url];

		[[nicknames tableColumnWithIdentifier:@"nickname"] setEditable:YES];
		[addNickname setEnabled:YES];
	}

	[nicknames deselectAll:nil];
	[nicknames reloadData];
}

#pragma mark -

- (IBAction) addNickname:(id) sender {
	[_activeNicknames addObject:[NSNull null]];
	[nicknames noteNumberOfRowsChanged];
	[nicknames selectRow:([_activeNicknames count] - 1) byExtendingSelection:NO];
	[nicknames editColumn:0 row:([_activeNicknames count] - 1) withEvent:nil select:NO];
}

- (IBAction) removeNickname:(id) sender {
	if( [nicknames selectedRow] == -1 || [nicknames editedRow] != -1 ) return;
	[_buddy removeNickname:[_activeNicknames objectAtIndex:[nicknames selectedRow]]];
	[_activeNicknames removeObjectAtIndex:[nicknames selectedRow]];
	[nicknames noteNumberOfRowsChanged];
}

#pragma mark -

- (IBAction) editCard:(id) sender {
	[_buddy editInAddressBook];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_activeNicknames count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[_activeNicknames objectAtIndex:row] isMemberOfClass:[NSNull class]] ) return @"";
	if( [[servers selectedItem] tag] )
		return [NSString stringWithFormat:@"%@ (%@)", [[_activeNicknames objectAtIndex:row] user], [[_activeNicknames objectAtIndex:row] host]];
	return [[_activeNicknames objectAtIndex:row] user];
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
}

- (void) tableView:(NSTableView *) view setObjectValue:(id) object forTableColumn:(NSTableColumn *) column row:(int) row {
	if( ! [(NSString *)object length] ) {
		[_activeNicknames removeObjectAtIndex:row];
		[nicknames noteNumberOfRowsChanged];
		return;
	}

	NSString *server = [servers titleOfSelectedItem];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( object ), MVURLEncodeString( server )]];

	if( [[_activeNicknames objectAtIndex:row] isMemberOfClass:[NSNull class]] ) {
		[_buddy addNickname:url];
		[_activeNicknames replaceObjectAtIndex:row withObject:url];
	} else {
		[_buddy replaceNickname:[_activeNicknames objectAtIndex:row] withNickname:url];
		[_activeNicknames replaceObjectAtIndex:row withObject:url];
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	[removeNickname setTransparent:( [nicknames selectedRow] == -1 )];
	[removeNickname highlight:NO];
}
@end