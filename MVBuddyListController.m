#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>

#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "JVDetailCell.h"

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
+ (ABPerson *) personFromDictionary:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;
- (NSString *) compositeName;
- (NSString *) alternateName;
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
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:nil] ) );
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"MVBuddyList"] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _registerBuddies: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _disconnected: ) name:MVChatConnectionDidDisconnectNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _nicknameChange: ) name:MVChatConnectionUserNicknameChangedNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOnline: ) name:MVChatConnectionBuddyIsOnlineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOffline: ) name:MVChatConnectionBuddyIsOfflineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAwayStatusChange: ) name:MVChatConnectionBuddyIsAwayNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAwayStatusChange: ) name:MVChatConnectionBuddyIsUnawayNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyIdleUpdate: ) name:MVChatConnectionBuddyIsIdleNotification object:nil];

		_onlineBuddies = [[NSMutableSet set] retain];
		_buddyInfo = [[NSMutableDictionary dictionary] retain];
		_buddyList = [[NSMutableSet set] retain];
		_picker = nil;

		[self _loadBuddyList];
	}
	return self;
}

- (void) dealloc {
	extern MVBuddyListController *sharedInstance;
	[self _saveBuddyList];

	[_onlineBuddies autorelease];
	[_buddyInfo autorelease];
	[_buddyList autorelease];
	[_picker autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_onlineBuddies = nil;
	_buddyInfo = nil;
	_buddyList = nil;
	_picker = nil;

	if( self == sharedInstance ) sharedInstance = nil;
	[super dealloc];
}

- (void) windowDidLoad {
	NSTableColumn *theColumn = nil;
	id prototypeCell = nil;

	[(NSPanel *)[self window] setFloatingPanel:NO];

	[buddies setVerticalMotionCanBeginDrag:NO];
	[buddies setTarget:self];
	[buddies setDoubleAction:@selector( messageSelectedBuddy: )];

	theColumn = [buddies tableColumnWithIdentifier:@"buddy"];
	prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont systemFontOfSize:11.]];
	[theColumn setDataCell:prototypeCell];

	_picker = [[[ABPeoplePickerController alloc] initWithWindow:pickerWindow] retain];

	[_picker setAllowSubrowSelection:NO];
	[_picker setAllowGroupSelection:NO];
	[_picker addColumnFilter:[NSDictionary dictionaryWithObject:@"" forKey:@"IRCNickname"] forColumnTitle:@"IRC Nickname"];
	[_picker setPeopleDoubleClickTarget:self andAction:@selector( confirmAddressBookEntrySelection: )];

	[[_picker peoplePickerView] setFrame:[pickerView frame]];
	[[pickerWindow contentView] replaceSubview:pickerView with:[_picker peoplePickerView]];
	[[_picker peoplePickerView] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

	NSTableView *table = [[[[[[[[(NSView *)_picker -> _mainSplit subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0];
	[table setAllowsMultipleSelection:NO];
	[table setAllowsEmptySelection:NO];

	table = [[[[[[[[(NSView *)_picker -> _mainSplit subviews] objectAtIndex:1] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0];
	[table setAllowsMultipleSelection:NO];
	[table setAllowsEmptySelection:NO];
}

#pragma mark -

- (IBAction) showBuddyList:(id) sender {
	[[self window] makeKeyAndOrderFront:nil];
}

#pragma mark -

- (IBAction) showBuddyPickerSheet:(id) sender {
	if( [[self window] attachedSheet] ) {
		[[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
		[[[self window] attachedSheet] orderOut:nil];
	}

	[_addPerson autorelease];
	_addPerson = nil;

	[[NSApplication sharedApplication] beginSheet:pickerWindow modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) cancelBuddySelection:(id) sender {
	if( [[self window] attachedSheet] ) {
		[[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
		[[[self window] attachedSheet] orderOut:nil];
	}
}

- (IBAction) confirmBuddySelection:(id) sender {
	if( [[self window] attachedSheet] ) {
		[[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
		[[[self window] attachedSheet] orderOut:nil];
	}

	ABPerson *person = [[_picker selectedRecords] lastObject];

	if( ! [[person valueForProperty:@"IRCNickname"] count] ) {
		[_addPerson autorelease];
		_addPerson = [[person uniqueId] copy];
		[self showNewPersonSheet:nil];
	} else {
		[_buddyList addObject:[[_picker selectedRecords] lastObject]];
		[self _saveBuddyList];
	}
}

#pragma mark -

- (IBAction) showNewPersonSheet:(id) sender {
	if( [[self window] attachedSheet] ) {
		[[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
		[[[self window] attachedSheet] orderOut:nil];
	}

	[nickname setObjectValue:@""];

	NSEnumerator *enumerator = [[[MVConnectionsController defaultManager] connections] objectEnumerator];
	MVChatConnection *connection = nil;
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	while( ( connection = [enumerator nextObject] ) ) {
		item = [[[NSMenuItem alloc] initWithTitle:[connection server] action:NULL keyEquivalent:@""] autorelease];
		[menu addItem:item];
	}

	[server setMenu:menu];

	ABPerson *person = nil;
	if( _addPerson ) person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:_addPerson];
	if( person ) {
		[firstName setObjectValue:[person valueForProperty:kABFirstNameProperty]];
		[lastName setObjectValue:[person valueForProperty:kABLastNameProperty]];
		ABMultiValue *value = [person valueForProperty:kABEmailProperty];
		[email setObjectValue:[value valueAtIndex:[value indexForIdentifier:[value primaryIdentifier]]]];
		[image setImage:[[[NSImage alloc] initWithData:[person imageData]] autorelease]];
	} else {
		[firstName setObjectValue:@""];
		[lastName setObjectValue:@""];
		[email setObjectValue:@""];
		[image setImage:nil];
	}

	[[NSApplication sharedApplication] beginSheet:newPersonWindow modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) cancelNewBuddy:(id) sender {
	if( [[self window] attachedSheet] ) {
		[[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
		[[[self window] attachedSheet] orderOut:nil];
	}

	[_addPerson autorelease];
	_addPerson = nil;
}

- (IBAction) confirmNewBuddy:(id) sender {
	if( [[self window] attachedSheet] ) {
		[[NSApplication sharedApplication] endSheet:[[self window] attachedSheet]];
		[[[self window] attachedSheet] orderOut:nil];
	}

	[ABPerson addPropertiesAndTypes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kABMultiStringProperty] forKey:@"IRCNickname"]];

	ABPerson *person = nil;
	if( _addPerson ) person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:_addPerson];
	if( ! person ) {
		NSMutableDictionary *info = [NSMutableDictionary dictionary];
		NSMutableDictionary *sub = nil;

		if( [(NSString *)[firstName objectValue] length] || [(NSString *)[lastName objectValue] length] || [(NSString *)[email objectValue] length] )
			[info setObject:[firstName objectValue] forKey:@"First"];
		else [info setObject:[nickname objectValue] forKey:@"First"];
		if( [(NSString *)[lastName objectValue] length] ) [info setObject:[lastName objectValue] forKey:@"Last"];

		if( [(NSString *)[email objectValue] length] ) {
			sub = [NSMutableDictionary dictionary];
			[sub setObject:[NSArray arrayWithObject:@"_$!<Other>!$_"] forKey:@"labels"];
			[sub setObject:[NSArray arrayWithObject:[email objectValue]] forKey:@"values"];
			[info setObject:sub forKey:@"Email"];
		}

		sub = [NSMutableDictionary dictionary];
		[sub setObject:[NSArray arrayWithObject:[server titleOfSelectedItem]] forKey:@"labels"];
		[sub setObject:[NSArray arrayWithObject:[nickname objectValue]] forKey:@"values"];
		[info setObject:sub forKey:@"IRCNickname"];

		[info setObject:[NSString stringWithFormat:NSLocalizedString( @"IRC Nickname: %@ (%@)", "new buddy card note" ), [nickname objectValue], [server titleOfSelectedItem]] forKey:@"Note"];

		person = [ABPerson personFromDictionary:info];

		[person setImageData:[[image image] TIFFRepresentation]];

		[[ABAddressBook sharedAddressBook] addRecord:person];
		[[ABAddressBook sharedAddressBook] save];
	} else {
		ABMutableMultiValue *value = [[[ABMutableMultiValue alloc] init] autorelease];
		[value addValue:[nickname objectValue] withLabel:[server titleOfSelectedItem]];
		[person setValue:value forProperty:@"IRCNickname"];

		if( [(NSString *)[firstName objectValue] length] || [(NSString *)[lastName objectValue] length] || [(NSString *)[email objectValue] length] )
			[person setValue:[firstName objectValue] forProperty:kABFirstNameProperty];
		else [person setValue:[nickname objectValue] forProperty:kABFirstNameProperty];
		[person setValue:[lastName objectValue] forProperty:kABLastNameProperty];
		ABMutableMultiValue *emailValue = [[[person valueForProperty:kABEmailProperty] mutableCopy] autorelease];
		if( emailValue ) {
			[emailValue replaceValueAtIndex:[emailValue indexForIdentifier:[emailValue primaryIdentifier]] withValue:[email objectValue]];
		} else {
			emailValue = [[[ABMutableMultiValue alloc] init] autorelease];
			[emailValue addValue:[email objectValue] withLabel:@"_$!<Other>!$_"];
		}
		[person setValue:emailValue forProperty:kABEmailProperty];

		[person setImageData:[[image image] TIFFRepresentation]];

		[[ABAddressBook sharedAddressBook] save];
	}

	if( person ) {
		[_buddyList addObject:person];
		[self _saveBuddyList];
	}

	[_addPerson autorelease];
	_addPerson = nil;
}

- (void) controlTextDidChange:(NSNotification *) notification {
	if( [(NSString *)[nickname objectValue] length] >= 1 ) [addButton setEnabled:YES];
	else [addButton setEnabled:NO];
}

#pragma mark -

- (IBAction) messageSelectedBuddy:(id) sender { // !![CHANGE]!!
	ABPerson *buddy = [[_onlineBuddies allObjects] objectAtIndex:[buddies selectedRow]];
	NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
	NSURL *url = [NSURL URLWithString:displayNick];
	[[JVChatController defaultManager] chatViewControllerForUser:[url user] withConnection:[[MVConnectionsController defaultManager] connectionForServerAddress:[url host]] ifExists:NO];
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerDelegate)
- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_onlineBuddies count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row { // !![CHANGE]!!
	if( row == -1 ) return nil;

	if( [[column identifier] isEqualToString:@"buddy"] ) {
		NSImage *ret = [[[NSImage imageNamed:@"largePerson"] copy] autorelease];

		if( [[[_onlineBuddies allObjects] objectAtIndex:row] imageData] )
			ret = [[[NSImage alloc] initWithData:[[[_onlineBuddies allObjects] objectAtIndex:row] imageData]] autorelease];
	
		[ret setScalesWhenResized:YES];
		[ret setSize:NSMakeSize( 32., 32. )];
		return ret;
	}

	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row { // !![CHANGE]!!
	if( row == -1 ) return;
	if( [[column identifier] isEqualToString:@"buddy"] ) {
		ABPerson *buddy = [[_onlineBuddies allObjects] objectAtIndex:row];
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"];
		NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
		NSURL *url = nil;

		if( ! [onlineNicks containsObject:displayNick] ) {
			displayNick = [[onlineNicks allObjects] objectAtIndex:0];
			[[_buddyInfo objectForKey:[buddy uniqueId]] setObject:displayNick forKey:@"displayNick"];
		}

		url = [NSURL URLWithString:displayNick];
		[cell setMainText:[buddy compositeName]];
		[cell setInformationText:[NSString stringWithFormat:@"%@ (%@)", [url user], [url host]]];
	} else if( [[column identifier] isEqualToString:@"switch"] ) {
		ABPerson *buddy = [[_onlineBuddies allObjects] objectAtIndex:row];
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"];
		if( [onlineNicks count] >= 2 ) {
			NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
			NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
			NSMenuItem *item = nil;
			NSEnumerator *nickEnumerator = [onlineNicks objectEnumerator];
			NSString *nick = nil;
			NSURL *url = nil;

			while( ( nick = [nickEnumerator nextObject] ) ) {
				url = [NSURL URLWithString:nick];
				item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", [url user], [url host]] action:NULL keyEquivalent:@""] autorelease];
				if( [nick isEqualToString:displayNick] ) [item setState:NSOnState];
				[menu addItem:item];
			}

			[cell setMenu:menu];
			[cell setArrowPosition:NSPopUpArrowAtCenter];
			[cell setEnabled:YES];
		} else {
			[cell setArrowPosition:NSPopUpNoArrow];
			[cell setEnabled:NO];
		}
	}
}

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) tableColumn row:(int) row { // !![CHANGE]!!
	if( row == -1 ) return;
	ABPerson *buddy = [[_onlineBuddies allObjects] objectAtIndex:row];
	NSArray *onlineNicks = [[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"] allObjects];
	[[_buddyInfo objectForKey:[buddy uniqueId]] setObject:[onlineNicks objectAtIndex:[object unsignedIntValue]] forKey:@"displayNick"];
	[buddies reloadData];
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerPrivate)
- (void) _buddyOnline:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	ABPerson *person = nil;
	ABMultiValue *value = nil;
	unsigned int i = 0, count = 0;
	BOOL found = NO;

	while( ( person = [enumerator nextObject] ) && ! found ) {
		value = [person valueForProperty:@"IRCNickname"];
		count = [value count];
		for( i = 0; i < count; i++ ) {
			if( [[value labelAtIndex:i] caseInsensitiveCompare:[connection server]] == NSOrderedSame && [[value valueAtIndex:i] caseInsensitiveCompare:who] == NSOrderedSame ) {
				[_onlineBuddies addObject:person];

				NSMutableSet *onlineNicks = nil;
				if( ! ( onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"] ) ) {
					onlineNicks = [NSMutableSet set];
					[[_buddyInfo objectForKey:[person uniqueId]] setObject:onlineNicks forKey:@"onlineNicks"];
				}

				NSMutableDictionary *nickInfo = nil;
				if( ! ( nickInfo = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] ) ) {
					NSMutableDictionary *info = [NSMutableDictionary dictionary];
					[[_buddyInfo objectForKey:[person uniqueId]] setObject:info forKey:@"nickInfo"];
				}

				[onlineNicks addObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
				[nickInfo setObject:[NSMutableDictionary dictionary] forKey:who];

				[buddies reloadData];

				found = YES;
				break;
			}
		}
	}
}

- (void) _buddyOffline:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSEnumerator *enumerator = [[[_onlineBuddies copy] autorelease] objectEnumerator];
	ABPerson *person = nil;

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		if( [onlineNicks containsObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]] ) {
			NSMutableDictionary *nickInfo = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"];
			[onlineNicks removeObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
			[nickInfo removeObjectForKey:who];
			if( ! [onlineNicks count] ) [_onlineBuddies removeObject:person];

			[buddies reloadData];

			break;
		}
	}
}

- (void) _buddyIdleUpdate:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSNumber *idle = [[notification userInfo] objectForKey:@"idle"];
	NSEnumerator *enumerator = [_onlineBuddies objectEnumerator];
	ABPerson *person = nil;

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		if( [onlineNicks containsObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]] ) {
			NSMutableDictionary *info = [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] objectForKey:who];
			[info setObject:idle forKey:@"idle"];

			[buddies reloadData];

			break;
		}
	}
}

- (void) _buddyAwayStatusChange:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSEnumerator *enumerator = [_onlineBuddies objectEnumerator];
	ABPerson *person = nil;
	BOOL away = ( [[notification name] isEqualToString:MVChatConnectionBuddyIsAwayNotification] ? YES : NO );

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		if( [onlineNicks containsObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]] ) {
			NSMutableDictionary *info = [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] objectForKey:who];
			[info setObject:[NSNumber numberWithBool:away] forKey:@"away"];

			[buddies reloadData];

			break;
		}
	}
}

- (void) _registerBuddies:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	ABPerson *person = nil;
	ABMultiValue *value = nil;
	unsigned int i = 0, count = 0;

	while( ( person = [enumerator nextObject] ) ) {
		value = [person valueForProperty:@"IRCNickname"];
		count = [value count];
		for( i = 0; i < count; i++ ) {
			if( [[value labelAtIndex:i] caseInsensitiveCompare:[connection server]] == NSOrderedSame ) {
				[connection addUserToNotificationList:[value valueAtIndex:i]];
			}
		}
	}
}

- (void) _disconnected:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *enumerator = [[[_onlineBuddies copy] autorelease] objectEnumerator];
	ABPerson *person = nil;

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		NSEnumerator *nickEnumerator = [[[onlineNicks copy] autorelease] objectEnumerator];
		NSString *nick = nil;
		NSURL *url = nil;

		while( ( nick = [nickEnumerator nextObject] ) ) {
			url = [NSURL URLWithString:nick];
			if( [[url host] isEqualToString:[connection server]] ) {
				NSMutableDictionary *nickInfo = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"];
				[onlineNicks removeObject:nick];
				[nickInfo removeObjectForKey:[url user]];
			}
		}

		if( ! [onlineNicks count] ) [_onlineBuddies removeObject:person];
	}

	[buddies reloadData];
}

- (void) _nicknameChange:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"oldNickname"];
	NSString *new = [[notification userInfo] objectForKey:@"newNickname"];
	NSEnumerator *enumerator = [_onlineBuddies objectEnumerator];
	ABPerson *person = nil;

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		if( [onlineNicks containsObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]] ) {
			if( [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"displayNick"] isEqualToString:[NSString stringWithFormat:@"irc://%@@%@", who, [connection server]]] )
				[[_buddyInfo objectForKey:[person uniqueId]] setObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( new ), MVURLEncodeString( [connection server] )] forKey:@"displayNick"];

			[onlineNicks removeObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
			[onlineNicks addObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( new ), MVURLEncodeString( [connection server] )]];

			[buddies reloadData];

			break;
		}
	}
}

- (void) _saveBuddyList {
	NSMutableArray *list = [NSMutableArray arrayWithCapacity:[_buddyList count]];
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	ABPerson *person = nil;

	while( ( person = [enumerator nextObject] ) )
		[list addObject:[person uniqueId]];

	[[NSUserDefaults standardUserDefaults] setObject:list forKey:@"JVChatBuddies"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) _loadBuddyList {
	NSArray *list = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatBuddies"];
	NSEnumerator *enumerator = [list objectEnumerator];
	NSString *identifier = nil;

	while( ( identifier = [enumerator nextObject] ) ) {
		ABRecord *person = [[ABAddressBook sharedAddressBook] recordForUniqueId:identifier];
		if( [person isKindOfClass:[ABPerson class]] ) {
			[_buddyList addObject:person];
			[_buddyInfo setObject:[NSMutableDictionary dictionary] forKey:[person uniqueId]];
		}
	}
}
@end