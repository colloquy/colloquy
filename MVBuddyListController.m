#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import "MVBuddyListController.h"
#import "MVChatConnection.h"
#import "MVImageTextCell.h"

static MVBuddyListController *sharedInstance = nil;

@class ABUIController;
@class ABRoundedTextField;
@class ABSplitView;
@class ABTableView;
@class ABScrollView;

@interface ABPeoplePickerController : NSObject {
	@public
    NSView *_peoplePicker;
    ABUIController *_uiController;
    NSWindow *_window;
    ABSplitView *_mainSplit;
    NSTextField *_label;
    ABRoundedTextField *_searchField;
}
- (id) initWithWindow:(NSWindow *) window;
- (id) init;
- (void) awakeFromNib;
- (NSView *) peoplePickerView;
- (NSArray *) selectedGroups;
- (NSArray *) selectedRecords;
- (NSArray *) stringsFromSelectionExpanding:(BOOL) expand;
- (void) addColumnFilter:(NSDictionary *) filter forColumnTitle:(NSString *) title;
- (void) removeAllColumnFilters;
- (void) removeColumnFilter:(NSDictionary *) filter;
- (void) selectColumnTitle:(NSString *) title;
- (void) setAllowSubrowSelection:(BOOL) allow;
- (void) setAllowGroupSelection:(BOOL) allow;
- (NSArray *) displayedColumns;
- (void) editInAddressBook:(id) sender;
- (void) setGroupDoubleClickTarget:(id) target andAction:(SEL) action;
- (void) setPeopleDoubleClickTarget:(id) target andAction:(SEL) action;
@end

#pragma mark -

@interface ABPerson (ABPersonPrivate)
- (NSString *) compositeName;
@end

#pragma mark -

@interface MVBuddyListController (MVBuddyListControllerPrivate)
- (void) _saveBuddyList;
- (void) _loadBuddyList;
@end

#pragma mark -

@implementation MVBuddyListController
+ (MVBuddyListController *) sharedBuddyList {
	extern MVBuddyListController *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _registerBuddies: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _disconnected: ) name:MVChatConnectionDidDisconnectNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _nicknameChange: ) name:MVChatConnectionUserNicknameChangedNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOnline: ) name:MVChatConnectionBuddyIsOnlineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOffline: ) name:MVChatConnectionBuddyIsOfflineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAway: ) name:MVChatConnectionBuddyIsAwayNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyUnaway: ) name:MVChatConnectionBuddyIsUnawayNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyIdle: ) name:MVChatConnectionBuddyIsIdleNotification object:nil];

		[ABPerson addPropertiesAndTypes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kABMultiStringProperty] forKey:@"ColloquyIRC"]];

		_me = [[[ABAddressBook sharedAddressBook] me] retain];
		_onlineBuddies = [[NSMutableDictionary dictionary] retain];
		_buddiesStatus = [[NSMutableDictionary dictionary] retain];
		_connections = [[NSMutableArray array] retain];

		[self _loadBuddyList];
	}
	return self;
}

- (void) dealloc {
	extern MVBuddyListController *sharedInstance;
	[self _saveBuddyList];

	[window close];
	window = nil;

	[_me autorelease];
	[_onlineBuddies autorelease];
	[_buddiesStatus autorelease];
	[_connections autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_me = nil;
	_onlineBuddies = nil;
	_buddiesStatus = nil;
	_connections = nil;

	if( self == sharedInstance ) sharedInstance = nil;
	[super dealloc];
}

- (void) awakeFromNib {
	NSTableColumn *theColumn = nil;
	id prototypeCell = nil;

	[buddies setVerticalMotionCanBeginDrag:NO];
	[buddies setDoubleAction:NULL];

	[myName setObjectValue:[_me compositeName]];
	if( [_me imageData] ) [myIcon setImage:[[[NSImage alloc] initWithData:[_me imageData]] autorelease]];
	else [myIcon setImage:[NSImage imageNamed:@"largePerson"]];

	[self setStatus:nil sendToServers:NO];

	theColumn = [buddies tableColumnWithIdentifier:@"buddy"];
	prototypeCell = [MVImageTextCell new];
	[prototypeCell setFont:[NSFont systemFontOfSize:11.]];
	[theColumn setDataCell:prototypeCell];

/*	{
		ABPeoplePickerController *picker = [[ABPeoplePickerController alloc] initWithWindow:pickerWindow];

		[picker setAllowSubrowSelection:NO];
		[picker setAllowGroupSelection:NO];
		[picker addColumnFilter:[NSDictionary dictionaryWithObject:@"" forKey:@"Email"] forColumnTitle:@"Email"];

		[[picker peoplePickerView] setFrame:[pickerView frame]];
		[[pickerWindow contentView] replaceSubview:pickerView with:[picker peoplePickerView]];

		[pickerWindow makeKeyAndOrderFront:nil];
	}*/
}

#pragma mark -

- (IBAction) showBuddyList:(id) sender {
	static BOOL loaded = NO;
	if( ! loaded ) loaded = [NSBundle loadNibNamed:@"MVBuddyList" owner:self];
	NSLog( @"showBuddyList %d", loaded );
	[window makeKeyAndOrderFront:nil];
}

#pragma mark -

- (void) setStatus:(NSString *) status sendToServers:(BOOL) send {
	if( send ) {
		NSEnumerator *enumerator = [_connections objectEnumerator];
		MVChatConnection *connection = nil;
		[_statusMessage autorelease];
		_statusMessage = [status copy];

		while( ( connection = [enumerator nextObject] ) )
			[connection setAwayStatusWithMessage:_statusMessage];
	}

	if( [_statusMessage length] ) status = _statusMessage;

	if( ! [status length] ) {
		if( ! [_connections count] ) {
			[myStatus setEditable:NO];
			[self setStatus:NSLocalizedString( @"Offline", buddy list offline status message ) sendToServers:NO];
			[_statusMessage autorelease];
			_statusMessage = nil;
		} else {
			[myStatus setEditable:YES];
			[self setStatus:[NSString stringWithFormat:NSLocalizedString( @"Available (%d %@)", buddy list available status message with the number of servers entered at runtime ), [_connections count], ( [_connections count] == 1 ? NSLocalizedString( @"server", singular server label ) : NSLocalizedString( @"servers", plural server label ) )] sendToServers:NO];
		}
	} else {
		NSDictionary *attribs = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor darkGrayColor], NSForegroundColorAttributeName, nil];
		NSMutableAttributedString *statusAttr = [[[NSMutableAttributedString alloc] initWithString:status attributes:attribs] autorelease];

		[myStatus setObjectValue:statusAttr];
	}
}

- (void) editStatus:(id) sender {
	if( ! [myStatus isEditable] ) return;
	[editStatusButton setFrame:NSZeroRect];
	[myStatus setObjectValue:_statusMessage];
	[window makeFirstResponder:myStatus];
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerDelegate)
- (void) controlTextDidEndEditing:(NSNotification *) notification {
	[editStatusButton setFrame:[myStatus frame]];
	[self setStatus:[myStatus stringValue] sendToServers:YES];
}

#pragma mark -

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem {
	if( [menuItem action] == @selector( cut: ) ) {
		
	} else if( [menuItem action] == @selector( copy: ) ) {
		
	} else if( [menuItem action] == @selector( clear: ) ) {
		
	}
	return YES;
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_onlineBuddies count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	NSArray *buds = [_onlineBuddies allValues];
	if( [[[buds objectAtIndex:row] objectAtIndex:0] isKindOfClass:[ABPerson class]] ) {
		ABPerson *buddy = [[buds objectAtIndex:row] objectAtIndex:0];
		return [buddy compositeName];
	} else {
		NSURL *url = [NSURL URLWithString:[[buds objectAtIndex:row] lastObject]];
		return [url user];
	}
	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	BOOL away = NO, idle = NO, multiple = NO;
	NSString *key = [[_onlineBuddies allKeysForObject:[[_onlineBuddies allValues] objectAtIndex:row]] lastObject];
	NSEnumerator *enumerator = [[_onlineBuddies objectForKey:key] objectEnumerator];
	NSString *mask = nil;
	unsigned int count = 0;

	[enumerator nextObject]; // Skip the first record
	while( ( mask = [enumerator nextObject] ) && ! multiple ) {
		if( [[[_buddiesStatus objectForKey:mask] objectForKey:@"idle"] unsignedIntValue] > [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatIdleLimit"] unsignedIntValue] ) {
			if( ! idle && count ) multiple = YES;
			idle = YES;
		} else {
			if( idle && count ) multiple = YES;
			idle = NO;
		}
		if( [[[_buddiesStatus objectForKey:mask] objectForKey:@"away"] boolValue] ) {
			if( ! away && count ) multiple = YES;
			away = YES;
		} else {
			if( away && count ) multiple = YES;
			away = NO;
		}
		count++;
	}

	if( ! away && ! idle && ! multiple ) [cell setImage:[NSImage imageNamed:@"person"]];
	else if( away && ! multiple ) [cell setImage:[NSImage imageNamed:@"person-away"]];
	else if( idle && ! multiple ) [cell setImage:[NSImage imageNamed:@"person-idle"]];
	else if( multiple ) [cell setImage:[NSImage imageNamed:@"person-half"]];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerPrivate)
- (void) _buddyOnline:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [_buddyList objectEnumerator];
	NSEnumerator *kenumerator = [_buddyList keyEnumerator];
	NSString *server = [connection server];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSArray *info = nil;
	NSString *mask = nil, *identifier = nil;
	NSURL *url = nil;
	BOOL found = NO;

	if( ! benumerator ) return;
	if( ! kenumerator ) return;
	if( ! who ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) && ( identifier = [kenumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] && [who isEqualToString:[url user]] ) {
				ABSearchElement *search = [ABPerson searchElementForProperty:@"ColloquyIRC" label:nil key:nil value:mask comparison:kABEqual];
				ABPerson *buddy = [[[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:search] lastObject];
				NSMutableArray *list = [_onlineBuddies objectForKey:identifier];
				if( ! list ) {
					list = [NSMutableArray array];
					[_onlineBuddies setObject:list forKey:identifier];
				}
				if( buddy && ! [list count] ) [list addObject:buddy];
				else if( ! buddy && ! [list count] ) [list addObject:[NSNull null]];
				else if( buddy && [list count] ) [list replaceObjectAtIndex:0 withObject:buddy];
				if( ! [list containsObject:mask] ) [list addObject:mask];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _buddyOffline:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSDictionary *online = [[_onlineBuddies copy] autorelease];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [online objectEnumerator];
	NSEnumerator *kenumerator = [online keyEnumerator];
	NSString *server = [connection server];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSArray *info = nil;
	NSString *mask = nil, *identifier = nil;
	NSURL *url = nil;
	BOOL found = NO;

	if( ! benumerator ) return;
	if( ! kenumerator ) return;
	if( ! who ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) && ( identifier = [kenumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		[nenumerator nextObject]; // Skip the first record
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] && [who isEqualToString:[url user]] ) {
				NSMutableArray *list = [_onlineBuddies objectForKey:identifier];
				[list removeObject:mask];
				if( [list count] == 1 ) [_onlineBuddies removeObjectForKey:identifier];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _buddyIdle:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [_onlineBuddies objectEnumerator];
	NSString *server = [connection server];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSNumber *idle = [[notification userInfo] objectForKey:@"idle"];
	NSArray *info = nil;
	NSString *mask = nil;
	NSURL *url = nil;
	BOOL found = NO;

	if( ! benumerator ) return;
	if( ! who ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		[nenumerator nextObject]; // Skip the first record
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] && [who isEqualToString:[url user]] ) {
				NSMutableDictionary *list = [_buddiesStatus objectForKey:mask];
				if( ! list ) {
					list = [NSMutableDictionary dictionary];
					[_buddiesStatus setObject:list forKey:mask];
				}
				[list setObject:idle forKey:@"idle"];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _buddyAway:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [_onlineBuddies objectEnumerator];
	NSString *server = [connection server];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSArray *info = nil;
	NSString *mask = nil;
	NSURL *url = nil;
	BOOL found = NO;

	if( ! benumerator ) return;
	if( ! who ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		[nenumerator nextObject]; // Skip the first record
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] && [who isEqualToString:[url user]] ) {
				NSMutableDictionary *list = [_buddiesStatus objectForKey:mask];
				if( ! list ) {
					list = [NSMutableDictionary dictionary];
					[_buddiesStatus setObject:list forKey:mask];
				}
				[list setObject:[NSNumber numberWithBool:YES] forKey:@"away"];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _buddyUnaway:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [_onlineBuddies objectEnumerator];
	NSString *server = [connection server];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSArray *info = nil;
	NSString *mask = nil;
	NSURL *url = nil;
	BOOL found = NO;

	if( ! benumerator ) return;
	if( ! who ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		[nenumerator nextObject]; // Skip the first record
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] && [who isEqualToString:[url user]] ) {
				NSMutableDictionary *list = [_buddiesStatus objectForKey:mask];
				if( ! list ) {
					list = [NSMutableDictionary dictionary];
					[_buddiesStatus setObject:list forKey:mask];
				}
				[list setObject:[NSNumber numberWithBool:NO] forKey:@"away"];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _registerBuddies:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [_buddyList objectEnumerator];
	NSString *server = [connection server];
	NSDictionary *info = nil;
	NSString *mask = nil;
	NSURL *url = nil;

	[_connections addObject:connection];
	[connection setAwayStatusWithMessage:_statusMessage];

	[self setStatus:nil sendToServers:NO];

	if( ! benumerator ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) ) {
		nenumerator = [info objectEnumerator];
		while( ( mask = [nenumerator nextObject] ) ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] ) {
				[connection addUserToNotificationList:[url user]];
			}
		}
	}
}

- (void) _disconnected:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSDictionary *online = [[_onlineBuddies copy] autorelease];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [online objectEnumerator];
	NSEnumerator *kenumerator = [online keyEnumerator];
	NSString *server = [connection server];
	NSArray *info = nil;
	NSString *mask = nil, *identifier = nil;
	NSURL *url = nil;
	BOOL found = NO;

	[_connections removeObject:connection];

	if( ! [_connections count] ) {
		[_statusMessage autorelease];
		_statusMessage = nil;
	}

	[self setStatus:nil sendToServers:NO];

	if( ! benumerator ) return;
	if( ! kenumerator ) return;
	if( ! server ) return;

	while( ( info = [benumerator nextObject] ) && ( identifier = [kenumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		[nenumerator nextObject]; // Skip the first record
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] ) {
				NSMutableArray *list = [_onlineBuddies objectForKey:identifier];
				[list removeObject:mask];
				if( [list count] == 1 ) [_onlineBuddies removeObjectForKey:identifier];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _nicknameChange:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSDictionary *online = [[_onlineBuddies copy] autorelease];
	NSEnumerator *nenumerator = nil;
	NSEnumerator *benumerator = [online objectEnumerator];
	NSEnumerator *kenumerator = [online keyEnumerator];
	NSString *server = [connection server];
	NSString *who = [[notification userInfo] objectForKey:@"oldNickname"];
	NSString *new = [[notification userInfo] objectForKey:@"newNickname"];
	NSArray *info = nil;
	NSString *mask = nil, *identifier = nil;
	NSURL *url = nil;
	BOOL found = NO;

	if( ! benumerator ) return;
	if( ! kenumerator ) return;
	if( ! server ) return;
	if( ! who ) return;
	if( ! new ) return;

	while( ( info = [benumerator nextObject] ) && ( identifier = [kenumerator nextObject] ) && ! found ) {
		nenumerator = [info objectEnumerator];
		[nenumerator nextObject]; // Skip the first record
		while( ( mask = [nenumerator nextObject] ) && ! found ) {
			url = [NSURL URLWithString:mask];
			if( [server isEqualToString:[url host]] && [who isEqualToString:[url user]] ) {
				NSMutableArray *list = [_onlineBuddies objectForKey:identifier];
				[list addObject:[NSString stringWithFormat:@"irc://%@@%@", new, server]];
				[list removeObject:mask];
				found = YES;
				break;
			}
		}
	}

	[buddies reloadData];
}

- (void) _saveBuddyList {
	[[NSUserDefaults standardUserDefaults] setObject:_buddyList forKey:@"MVChatBuddies"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) _loadBuddyList {
	[_buddyList autorelease];
	_buddyList = [[[NSUserDefaults standardUserDefaults] objectForKey:@"MVChatBuddies"] mutableCopy];
}
@end
