#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>

#import "MVBuddyListController.h"
#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "MVTableView.h"
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
- (void) _sortBuddies;
- (void) _manuallySortAndUpdate;
- (void) _setBuddiesNeedSortAnimated;
- (void) _sortBuddiesAnimatedIfNeeded:(id) sender;
- (void) _addPersonToBuddyList:(ABPerson *) person;
- (void) _registerBuddyWithActiveConnections:(ABPerson *) person;
- (NSMutableDictionary *) _buddyInfo;
@end

#pragma mark -

NSComparisonResult sortBuddiesByLastName( ABPerson *buddy1, ABPerson *buddy2, void *context );
NSComparisonResult sortBuddiesByFirstName( ABPerson *buddy1, ABPerson *buddy2, void *context );
NSComparisonResult sortBuddiesByAvailability( ABPerson *buddy1, ABPerson *buddy2, void *context );

NSComparisonResult sortBuddiesByNickname( ABPerson *buddy1, ABPerson *buddy2, void *context ) {
	MVBuddyListController *self = context;
	NSString *name1 = [[[self _buddyInfo] objectForKey:[buddy1 uniqueId]] objectForKey:@"displayNick"];
	NSString *name2 = [[[self _buddyInfo] objectForKey:[buddy2 uniqueId]] objectForKey:@"displayNick"];
	name1 = [[NSURL URLWithString:name1] user];
	name2 = [[NSURL URLWithString:name2] user];
	return [name1 caseInsensitiveCompare:name2];
}

NSComparisonResult sortBuddiesByServer( ABPerson *buddy1, ABPerson *buddy2, void *context ) {
	MVBuddyListController *self = context;
	NSString *name1 = [[[self _buddyInfo] objectForKey:[buddy1 uniqueId]] objectForKey:@"displayNick"];
	NSString *name2 = [[[self _buddyInfo] objectForKey:[buddy2 uniqueId]] objectForKey:@"displayNick"];
	name1 = [[NSURL URLWithString:name1] host];
	name2 = [[NSURL URLWithString:name2] host];
	NSComparisonResult ret = [name1 caseInsensitiveCompare:name2];
	return ( ret != NSOrderedSame ? ret : sortBuddiesByAvailability( buddy1, buddy2, context ) );
}

NSComparisonResult sortBuddiesByFirstName( ABPerson *buddy1, ABPerson *buddy2, void *context ) {
	MVBuddyListController *self = context;
	if( ! [self showFullNames] ) return sortBuddiesByNickname( buddy1, buddy2, context );
	NSString *name1 = [buddy1 valueForProperty:kABFirstNameProperty];
	NSString *name2 = [buddy2 valueForProperty:kABFirstNameProperty];
	if( ! [name1 length] ) name1 = [buddy1 valueForProperty:kABLastNameProperty];
	if( ! [name2 length] ) name2 = [buddy2 valueForProperty:kABLastNameProperty];
	if( ! [name1 length] ) return NSOrderedAscending;
	if( ! [name2 length] ) return NSOrderedDescending;
	NSComparisonResult ret = [name1 caseInsensitiveCompare:name2];
	return ( ret != NSOrderedSame ? ret : sortBuddiesByLastName( buddy1, buddy2, context ) );
}

NSComparisonResult sortBuddiesByLastName( ABPerson *buddy1, ABPerson *buddy2, void *context ) {
	MVBuddyListController *self = context;
	if( ! [self showFullNames] ) return sortBuddiesByNickname( buddy1, buddy2, context );
	NSString *name1 = [buddy1 valueForProperty:kABLastNameProperty];
	NSString *name2 = [buddy2 valueForProperty:kABLastNameProperty];
	if( ! [name1 length] ) name1 = [buddy1 valueForProperty:kABFirstNameProperty];
	if( ! [name2 length] ) name2 = [buddy2 valueForProperty:kABFirstNameProperty];
	if( ! [name1 length] ) return NSOrderedAscending;
	if( ! [name2 length] ) return NSOrderedDescending;
	NSComparisonResult ret = [name1 caseInsensitiveCompare:name2];
	return ( ret != NSOrderedSame ? ret : sortBuddiesByFirstName( buddy1, buddy2, context ) );
}

NSComparisonResult sortBuddiesByAvailability( ABPerson *buddy1, ABPerson *buddy2, void *context ) {
	MVBuddyListController *self = context;
	int b1 = 0, b2 = 0;
	NSString *displayNick = [[[self _buddyInfo] objectForKey:[buddy1 uniqueId]] objectForKey:@"displayNick"];
	NSMutableSet *onlineNicks = [[[self _buddyInfo] objectForKey:[buddy1 uniqueId]] objectForKey:@"onlineNicks"];
	NSMutableDictionary *info = [[[[self _buddyInfo] objectForKey:[buddy1 uniqueId]] objectForKey:@"nickInfo"] objectForKey:displayNick];

	if( [[info objectForKey:@"away"] boolValue] ) b1 = 2;
	else if( [[info objectForKey:@"idle"] intValue] >= 600. ) b1 = 1;
	else if( [onlineNicks containsObject:displayNick] ) b1 = 0;
	else b1 = 3;

	displayNick = [[[self _buddyInfo] objectForKey:[buddy2 uniqueId]] objectForKey:@"displayNick"];
	onlineNicks = [[[self _buddyInfo] objectForKey:[buddy2 uniqueId]] objectForKey:@"onlineNicks"];
	info = [[[[self _buddyInfo] objectForKey:[buddy2 uniqueId]] objectForKey:@"nickInfo"] objectForKey:displayNick];

	if( [[info objectForKey:@"away"] boolValue] ) b2 = 2;
	else if( [[info objectForKey:@"idle"] intValue] >= 600. ) b2 = 1;
	else if( [onlineNicks containsObject:displayNick] ) b2 = 0;
	else b2 = 3;
	
	if( b1 > b2 ) return NSOrderedDescending;
	else if( b1 < b2 ) return NSOrderedAscending;
	return sortBuddiesByLastName( buddy1, buddy2, context );
}

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

		[[NSTimer scheduledTimerWithTimeInterval:( .5 ) target:self selector:@selector( _sortBuddiesAnimatedIfNeeded: ) userInfo:nil repeats:YES] retain];

		_onlineBuddies = [[NSMutableSet set] retain];
		_buddyInfo = [[NSMutableDictionary dictionary] retain];
		_buddyList = [[NSMutableSet set] retain];
		_buddyOrder = [[NSMutableArray array] retain];
		_picker = nil;
		
		[self _loadBuddyList];

		[self setShowIcons:YES];
		[self setShowFullNames:YES];
		[self setShowNicknameAndServer:YES];
		[self setShowOfflineBuddies:YES];
		[self setSortOrder:MVAvailabilitySortOrder];
	}
	return self;
}

- (void) dealloc {
	extern MVBuddyListController *sharedInstance;
	[self _saveBuddyList];

	[_onlineBuddies autorelease];
	[_buddyInfo autorelease];
	[_buddyList autorelease];
	[_buddyOrder autorelease];
	[_picker autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_onlineBuddies = nil;
	_buddyInfo = nil;
	_buddyList = nil;
	_buddyOrder = nil;
	_picker = nil;

	if( self == sharedInstance ) sharedInstance = nil;
	[super dealloc];
}

- (void) windowDidLoad {
	NSTableColumn *theColumn = nil;
	id prototypeCell = nil;

	[(NSPanel *)[self window] setFloatingPanel:NO];
	[(NSPanel *)[self window] setHidesOnDeactivate:NO];

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
	[_picker setPeopleDoubleClickTarget:self andAction:@selector( confirmBuddySelection: )];

	[[_picker peoplePickerView] setFrame:[pickerView frame]];
	[[pickerWindow contentView] replaceSubview:pickerView with:[_picker peoplePickerView]];
	[[_picker peoplePickerView] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

	NSTableView *table = [[[[[[[[(NSView *)_picker -> _mainSplit subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0];
	[table setAllowsMultipleSelection:NO];
	[table setAllowsEmptySelection:NO];

	table = [[[[[[[[(NSView *)_picker -> _mainSplit subviews] objectAtIndex:1] subviews] objectAtIndex:0] subviews] objectAtIndex:0] subviews] objectAtIndex:0];
	[table setAllowsMultipleSelection:NO];
	[table setAllowsEmptySelection:NO];

	[buddies registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

	[buddies reloadData];
	[self _setBuddiesNeedSortAnimated];
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
		[self _addPersonToBuddyList:person];
		[self _saveBuddyList];
		[self _registerBuddyWithActiveConnections:person];
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
		[self _addPersonToBuddyList:person];
		[self _saveBuddyList];
		[self _registerBuddyWithActiveConnections:person];
	}

	[_addPerson autorelease];
	_addPerson = nil;
}

- (void) controlTextDidChange:(NSNotification *) notification {
	if( [(NSString *)[nickname objectValue] length] >= 1 ) [addButton setEnabled:YES];
	else [addButton setEnabled:NO];
}

#pragma mark -

- (IBAction) messageSelectedBuddy:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	ABPerson *buddy = [_buddyOrder objectAtIndex:[buddies selectedRow]];
	NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
	NSURL *url = [NSURL URLWithString:displayNick];
	[[JVChatController defaultManager] chatViewControllerForUser:[url user] withConnection:[[MVConnectionsController defaultManager] connectionForServerAddress:[url host]] ifExists:NO];
}

- (IBAction) sendFileToSelectedBuddy:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	ABPerson *buddy = [_buddyOrder objectAtIndex:[buddies selectedRow]];
	NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
	NSURL *url = [NSURL URLWithString:displayNick];
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setResolvesAliases:YES];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];
	if( [panel runModalForTypes:nil] == NSOKButton ) {
		MVChatConnection *connection = [[MVConnectionsController defaultManager] connectionForServerAddress:[url host]];
		NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
		NSString *path = nil;
		while( ( path = [enumerator nextObject] ) )
			[connection sendFileToUser:[url user] withFilePath:path];
	}
}

#pragma mark -

- (void) setShowFullNames:(BOOL) flag {
	_showFullNames = flag;
	[buddies reloadData];
	[self _setBuddiesNeedSortAnimated];
	[self _sortBuddiesAnimatedIfNeeded:nil];
}

- (BOOL) showFullNames {
	return _showFullNames;
}

- (IBAction) toggleShowFullNames:(id) sender {
	[self setShowFullNames:(! _showFullNames)];
}

#pragma mark -

- (void) setShowNicknameAndServer:(BOOL) flag {
	_showNicknameAndServer = flag;
	if( _showIcons || _showNicknameAndServer ) [buddies setRowHeight:36.];
	else [buddies setRowHeight:18.];
	[buddies reloadData];
}

- (BOOL) showNicknameAndServer {
	return _showNicknameAndServer;
}

- (IBAction) toggleShowNicknameAndServer:(id) sender {
	[self setShowNicknameAndServer:(! _showNicknameAndServer)];
}

#pragma mark -

- (void) setShowIcons:(BOOL) flag {
	_showIcons = flag;
	if( _showIcons || _showNicknameAndServer ) [buddies setRowHeight:36.];
	else [buddies setRowHeight:18.];
	[buddies reloadData];
}

- (BOOL) showIcons {
	return _showIcons;
}

- (IBAction) toggleShowIcons:(id) sender {
	[self setShowIcons:(! _showIcons)];
}

#pragma mark -

- (void) setShowOfflineBuddies:(BOOL) flag {
	_showOfflineBuddies = flag;
	NSMutableSet *offlineBuddies = [NSMutableSet setWithSet:_buddyList];
	[offlineBuddies minusSet:_onlineBuddies];
	if( ! _showOfflineBuddies ) [_buddyOrder removeObjectsInArray:[offlineBuddies allObjects]];
	else [_buddyOrder addObjectsFromArray:[offlineBuddies allObjects]];
	[self _manuallySortAndUpdate];
}

- (BOOL) showOfflineBuddies {
	return _showOfflineBuddies;
}

- (IBAction) toggleShowOfflineBuddies:(id) sender {
	[self setShowOfflineBuddies:(! _showOfflineBuddies)];
}

#pragma mark -

- (void) setSortOrder:(MVBuddyListSortOrder) order {
	_sortOrder = order;
	[self _setBuddiesNeedSortAnimated];
	[self _sortBuddiesAnimatedIfNeeded:nil];
}

- (MVBuddyListSortOrder) sortOrder {
	return _sortOrder;
}

- (IBAction) sortByAvailability:(id) sender {
	[self setSortOrder:MVAvailabilitySortOrder];
}

- (IBAction) sortByFirstName:(id) sender {
	[self setSortOrder:MVFirstNameSortOrder];
}

- (IBAction) sortByLastName:(id) sender {
	[self setSortOrder:MVLastNameSortOrder];
}

- (IBAction) sortByServer:(id) sender {
	[self setSortOrder:MVServerSortOrder];
}

#pragma mark -

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem {
	if( [menuItem action] == @selector( toggleShowFullNames: ) ) {
		[menuItem setState:( _showFullNames ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( toggleShowNicknameAndServer: ) ) {
		[menuItem setState:( _showNicknameAndServer ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( toggleShowIcons: ) ) {
		[menuItem setState:( _showIcons ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( toggleShowOfflineBuddies: ) ) {
		[menuItem setState:( _showOfflineBuddies ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( messageSelectedBuddy: ) ) {
		if( [buddies selectedRow] == -1 ) return NO;
		else return YES;
	} else if( [menuItem action] == @selector( sortByAvailability: ) ) {
		[menuItem setState:( _sortOrder == MVAvailabilitySortOrder ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( sortByFirstName: ) ) {
		[menuItem setState:( _sortOrder == MVFirstNameSortOrder ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( sortByLastName: ) ) {
		[menuItem setState:( _sortOrder == MVLastNameSortOrder ? NSOnState : NSOffState )];
		return YES;
	} else if( [menuItem action] == @selector( sortByServer: ) ) {
		[menuItem setState:( _sortOrder == MVServerSortOrder ? NSOnState : NSOffState )];
		return YES;
	}
	return YES;
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerDelegate)
- (void) clear:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	ABPerson *buddy = [[[_buddyOrder objectAtIndex:[buddies selectedRow]] retain] autorelease];
	[_buddyInfo removeObjectForKey:[buddy uniqueId]];
	[_buddyList removeObject:buddy];
	[_onlineBuddies removeObject:buddy];
	[_buddyOrder removeObjectIdenticalTo:buddy];
	[self _manuallySortAndUpdate];
	[self _saveBuddyList];
}

- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_buddyOrder count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( row == -1 || row >= [_buddyOrder count] ) return nil;

	if( [[column identifier] isEqualToString:@"buddy"] ) {
		if( _showIcons ) {
			NSImage *ret = [[[NSImage imageNamed:@"largePerson"] copy] autorelease];

			if( [[_buddyOrder objectAtIndex:row] imageData] )
				ret = [[[NSImage alloc] initWithData:[[_buddyOrder objectAtIndex:row] imageData]] autorelease];

			[ret setScalesWhenResized:YES];
			[ret setSize:NSMakeSize( 32., 32. )];
			return ret;
		} else if( ! _showIcons ) {
			ABPerson *buddy = [_buddyOrder objectAtIndex:row];
			NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"];
			NSSet *nicks = nil;
			NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];

			if( _showOfflineBuddies ) nicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"allNicks"];
			else nicks = onlineNicks;
	
			if( ! [nicks containsObject:displayNick] || ! displayNick ) {
				if( [onlineNicks count] ) displayNick = [[onlineNicks allObjects] objectAtIndex:0];
				else displayNick = [[nicks allObjects] objectAtIndex:0];
				if( displayNick ) [[_buddyInfo objectForKey:[buddy uniqueId]] setObject:displayNick forKey:@"displayNick"];
			}

			if( [[[[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"nickInfo"] objectForKey:displayNick] objectForKey:@"away"] boolValue] ) 
				return [NSImage imageNamed:@"statusAway"];
			else if( [[[[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"nickInfo"] objectForKey:displayNick] objectForKey:@"idle"] intValue] >= 600. )
				return [NSImage imageNamed:@"statusIdle"];
			else if( [onlineNicks containsObject:displayNick] )
				return [NSImage imageNamed:@"statusAvailable"];
			else return [NSImage imageNamed:@"statusOffline"];
		} else return nil;
	}

	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( row == -1 || row >= [_buddyOrder count] ) return;
	if( [[column identifier] isEqualToString:@"buddy"] ) {
		ABPerson *buddy = [_buddyOrder objectAtIndex:row];
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"];
		NSSet *nicks = nil;
		NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
		NSURL *url = nil;

		if( _showOfflineBuddies ) nicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"allNicks"];
		else nicks = onlineNicks;

		if( ! [nicks containsObject:displayNick] || ! displayNick ) {
			if( [onlineNicks count] ) displayNick = [[onlineNicks allObjects] objectAtIndex:0];
			else displayNick = [[nicks allObjects] objectAtIndex:0];
			if( displayNick ) [[_buddyInfo objectForKey:[buddy uniqueId]] setObject:displayNick forKey:@"displayNick"];
		}

		if( displayNick ) url = [NSURL URLWithString:displayNick];
		if( ! _showFullNames || [[buddy compositeName] isEqualToString:@"No Name"] ) {
			[cell setMainText:[url user]];
			if( _showNicknameAndServer ) [cell setInformationText:[url host]];
			else [cell setInformationText:nil];
		} else {
			[cell setMainText:[buddy compositeName]];
			if( _showNicknameAndServer ) [cell setInformationText:[NSString stringWithFormat:@"%@ (%@)", [url user], [url host]]];
			else [cell setInformationText:nil];
		}

		if( [onlineNicks containsObject:displayNick] ) [cell setEnabled:YES];
		else [cell setEnabled:NO];

		if( _showIcons ) {
			NSDictionary *info = [[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"nickInfo"] objectForKey:displayNick];
			if( [[info objectForKey:@"away"] boolValue] ) [cell setStatusImage:[NSImage imageNamed:@"statusAway"]];
			else if( [[info objectForKey:@"idle"] intValue] >= 600. ) [cell setStatusImage:[NSImage imageNamed:@"statusIdle"]];
			else if( [onlineNicks containsObject:displayNick] ) [cell setStatusImage:[NSImage imageNamed:@"statusAvailable"]];
			else [cell setStatusImage:[NSImage imageNamed:@"statusOffline"]];
		} else [cell setStatusImage:nil];
	} else if( [[column identifier] isEqualToString:@"switch"] ) {
		ABPerson *buddy = [_buddyOrder objectAtIndex:row];
		NSSet *onlineNicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"];
		NSSet *nicks = nil;
		if( _showOfflineBuddies ) nicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"allNicks"];
		else nicks = onlineNicks;
		if( [nicks count] >= 2 ) {
			NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
			NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
			NSMenuItem *item = nil;
			NSEnumerator *nickEnumerator = [nicks objectEnumerator];
			NSString *nick = nil;
			NSURL *url = nil;

			[menu setAutoenablesItems:NO];
			while( ( nick = [nickEnumerator nextObject] ) ) {
				url = [NSURL URLWithString:nick];
				item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", [url user], [url host]] action:NULL keyEquivalent:@""] autorelease];
				if( [nick isEqualToString:displayNick] ) [item setState:NSOnState];
				if( ! [onlineNicks containsObject:nick] ) [item setEnabled:NO];
				[menu addItem:item];
			}

			[cell setMenu:menu];
			[cell setArrowPosition:NSPopUpArrowAtCenter];
			[cell setEnabled:YES];
			if( _showIcons || _showNicknameAndServer ) [cell setControlSize:NSRegularControlSize];
			else [cell setControlSize:NSSmallControlSize];
		} else {
			[cell setArrowPosition:NSPopUpNoArrow];
			[cell setEnabled:NO];
		}
	}
}

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) tableColumn row:(int) row {
	if( row == -1 || row >= [_buddyOrder count] ) return;
	ABPerson *buddy = [_buddyOrder objectAtIndex:row];
	NSArray *nicks = nil;
	if( _showOfflineBuddies ) nicks = [[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"allNicks"] allObjects];
	else nicks = [[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"] allObjects];
	[[_buddyInfo objectForKey:[buddy uniqueId]] setObject:[nicks objectAtIndex:[object unsignedIntValue]] forKey:@"displayNick"];
	[buddies reloadData];
	[self _setBuddiesNeedSortAnimated];
	[self _sortBuddiesAnimatedIfNeeded:nil];
}

- (NSMenu *) tableView:(MVTableView *) tableView menuForTableColumn:(NSTableColumn *) tableColumn row:(int) row {
	return actionMenu;
}

- (NSString *) tableView:(MVTableView *) tableView toolTipForTableColumn:(NSTableColumn *) column row:(int) row {
	if( row == -1 || row >= [_buddyOrder count] ) return nil;
	ABPerson *buddy = [_buddyOrder objectAtIndex:row];
	NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"onlineNicks"];
	NSSet *nicks = nil;
	NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
	NSURL *url = nil;
	NSMutableString *ret = [NSMutableString string];

	if( _showOfflineBuddies ) nicks = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"allNicks"];
	else nicks = onlineNicks;

	[ret appendFormat:@"%@\n", [buddy compositeName]];
	if( displayNick ) {
		url = [NSURL URLWithString:displayNick];
		[ret appendFormat:@"%@ (%@)\n", [url user], [url host]];

		NSDictionary *info = [[[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"nickInfo"] objectForKey:displayNick];
		if( [[info objectForKey:@"away"] boolValue] ) [ret appendString:NSLocalizedString( @"Away", "away buddy status" )];
		else if( [[info objectForKey:@"idle"] intValue] >= 600. ) [ret appendString:NSLocalizedString( @"Idle", "idle buddy status" )];
		else if( [onlineNicks containsObject:displayNick] ) [ret appendString:NSLocalizedString( @"Available", "available buddy status" )];
		else [ret appendString:NSLocalizedString( @"Offline", "offline buddy status" )];
	}
	return ret;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	BOOL enabled = ! ( [buddies selectedRow] == -1 );
	[sendMessageButton setEnabled:enabled];
	[infoButton setEnabled:enabled];
}

- (NSDragOperation) tableView:(NSTableView *) tableView validateDrop:(id <NSDraggingInfo>) info proposedRow:(int) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( operation == NSTableViewDropOn && row != -1 )
		return NSDragOperationMove;
	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) tableView acceptDrop:(id <NSDraggingInfo>) info row:(int) row dropOperation:(NSTableViewDropOperation) operation {
	NSPasteboard *board = [info draggingPasteboard];
	if( [board availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]] ) {
		ABPerson *buddy = [_buddyOrder objectAtIndex:row];
		NSString *displayNick = [[_buddyInfo objectForKey:[buddy uniqueId]] objectForKey:@"displayNick"];
		NSURL *url = [NSURL URLWithString:displayNick];
		MVChatConnection *connection = [[MVConnectionsController defaultManager] connectionForServerAddress:[url host]];
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSEnumerator *enumerator = [files objectEnumerator];
		id file = nil;

		while( ( file = [enumerator nextObject] ) )
			[connection sendFileToUser:[url user] withFilePath:file];

		return YES;
	}

	return NO;
}

- (NSRange) tableView:(MVTableView *) tableView rowsInRect:(NSRect) rect defaultRange:(NSRange) defaultRange {
	if( _animating ) return NSMakeRange( 0, [_buddyOrder count] );
	else return defaultRange;
}

#define curveFunction(t,p) ( pow( 1 - pow( ( 1 - t ), p ), ( 1 / p ) ) )
#define easeFunction(t) ( ( sin( ( t * M_PI ) - M_PI_2 ) + 1. ) / 2. )

- (NSRect) tableView:(MVTableView *) tableView rectOfRow:(int) row defaultRect:(NSRect) defaultRect {
	if( _animating ) {
		// Get the rectangles of where the row originally was, and where it will end up.
		int oldPosition = [[_oldPositions objectAtIndex:row] intValue];
		NSRect oldR = [tableView originalRectOfRow:oldPosition];
		NSRect newR = [tableView originalRectOfRow:row];

		// t will be our fraction between 0 and 1 of how far along the row should be.
		float t = _animationPosition; // start with linear position based on time

		// Adjust t so that the animation is asymmetrical; it will look like it's curved.
		// If viewing the top half of the table, flip it so our rows don't go out of view.
		float rowPos = ( (float) row / [_buddyOrder count] );	// fractional position of row in table
		float rowPosAdjusted = _viewingTop ? ( 1. - rowPos ) : rowPos;
		float curve = 0.3;
		float p = rowPosAdjusted * ( curve * 2. ) + 1. - curve; // 0 -> 0.8; n/2 -> 1.0; n -> 1.2

		t = curveFunction( t, p );	// comment this out to "straighten" the sort
		t = easeFunction( t );  // comment this out to make it linear acceleration

		// Calculate a rectangle between the original and the final rectangles.
		return NSMakeRect( NSMinX( oldR ) + ( t * ( NSMinX( newR ) - NSMinX( oldR ) ) ), NSMinY( oldR ) + ( t * ( NSMinY( newR ) - NSMinY( oldR ) ) ), NSWidth( newR ), NSHeight( newR ) );
	} else return defaultRect;
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerPrivate)
- (void) _animateStep:(NSTimer *) timer {
	static NSDate *start = nil;
	if( ! _animationPosition ) start = [[NSDate date] retain];
	NSTimeInterval elapsed = fabs( [start timeIntervalSinceNow] );
	_animationPosition = MIN( 1., elapsed / .25 );

	if( fabs( _animationPosition - 1. ) <= 0.01 ) {
		[timer invalidate];
		[timer autorelease];
		_animationPosition = 0.;
		_animating = NO;
		[buddies display];
	} else [buddies display];
}

- (void) _manuallySortAndUpdate {
	if( _animationPosition ) return;
	[self _sortBuddies];
	[buddies reloadData];
}

- (void) _sortBuddies {
	if( _sortOrder == MVAvailabilitySortOrder )
		[_buddyOrder sortUsingFunction:sortBuddiesByAvailability context:self];
	else if( _sortOrder == MVFirstNameSortOrder )
		[_buddyOrder sortUsingFunction:sortBuddiesByFirstName context:self];
	else if( _sortOrder == MVLastNameSortOrder )
		[_buddyOrder sortUsingFunction:sortBuddiesByLastName context:self];
	else if( _sortOrder == MVServerSortOrder )
		[_buddyOrder sortUsingFunction:sortBuddiesByServer context:self];
}

- (void) _setBuddiesNeedSortAnimated {
	_needsToAnimate = YES;
}

- (void) _sortBuddiesAnimatedIfNeeded:(id) sender {
	if( ! _needsToAnimate || _animating ) return;
	_needsToAnimate = NO;

	NSRange visibleRows;
	NSArray *oldOrder = [[_buddyOrder copy] autorelease];

	id selectedObject = nil;
	if( [buddies selectedRow] != -1 && [buddies selectedRow] < [oldOrder count] )
		selectedObject = [oldOrder objectAtIndex:[buddies selectedRow]];

	[self _sortBuddies];

	if( selectedObject ) {
		[buddies deselectAll:nil];
		[buddies selectRow:[_buddyOrder indexOfObjectIdenticalTo:selectedObject] byExtendingSelection:NO];
		[buddies setNeedsDisplay:NO];
	}

	if( [oldOrder isEqualToArray:_buddyOrder] ) return;

	_animating = YES;

	[_oldPositions autorelease];
	_oldPositions = [[NSMutableArray arrayWithCapacity:[_buddyOrder count]] retain];
	NSEnumerator *enumerator = [_buddyOrder objectEnumerator];
	id object = nil;

	while( ( object = [enumerator nextObject] ) )
		[_oldPositions addObject:[NSNumber numberWithInt:[oldOrder indexOfObject:object]]];

	visibleRows = [buddies rowsInRect:[buddies visibleRect]];
	_viewingTop = NSMaxRange( visibleRows ) < 0.6 * [_buddyOrder count];

	[[NSTimer scheduledTimerWithTimeInterval:( 1. / 240. ) target:self selector:@selector( _animateStep: ) userInfo:nil repeats:YES] retain];
}

- (NSMutableDictionary *) _buddyInfo {
	return _buddyInfo;
}

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
				if( ! [_buddyOrder containsObject:person] ) {
					[_buddyOrder addObject:person];
					[buddies noteNumberOfRowsChanged];
				}

				NSMutableSet *onlineNicks = nil;
				if( ! ( onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"] ) ) {
					onlineNicks = [NSMutableSet set];
					[[_buddyInfo objectForKey:[person uniqueId]] setObject:onlineNicks forKey:@"onlineNicks"];
				}

				NSMutableDictionary *nickInfo = nil;
				if( ! ( nickInfo = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] ) ) {
					nickInfo = [NSMutableDictionary dictionary];
					[[_buddyInfo objectForKey:[person uniqueId]] setObject:nickInfo forKey:@"nickInfo"];
				}

				NSString *mask = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )];
				[onlineNicks addObject:mask];
				[nickInfo setObject:[NSMutableDictionary dictionary] forKey:mask];

				[self _setBuddiesNeedSortAnimated];
				if( ! _animating ) [buddies reloadData];

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
			NSString *mask = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )];
			[onlineNicks removeObject:mask];
			[nickInfo removeObjectForKey:mask];
			if( ! [onlineNicks count] ) {
				[_onlineBuddies removeObject:person];
				if( ! _showOfflineBuddies ) {
					[_buddyOrder removeObject:person];
					[buddies noteNumberOfRowsChanged];
				}
			}
			[self _setBuddiesNeedSortAnimated];
			if( ! _animating ) [buddies reloadData];
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
	NSMutableSet *onlineNicks = nil;
	NSString *mask = nil;

	while( ( person = [enumerator nextObject] ) ) {
		onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		mask = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )];
		if( [onlineNicks containsObject:mask] ) {
			NSMutableDictionary *info = [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] objectForKey:mask];
			[info setObject:idle forKey:@"idle"];
			[self _setBuddiesNeedSortAnimated];
			if( ! _animating ) [buddies reloadData];
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
	NSMutableSet *onlineNicks = nil;
	NSString *mask = nil;

	while( ( person = [enumerator nextObject] ) ) {
		onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		mask = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )];
		if( [onlineNicks containsObject:mask] ) {
			NSMutableDictionary *info = [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] objectForKey:mask];
			[info setObject:[NSNumber numberWithBool:away] forKey:@"away"];
			[self _setBuddiesNeedSortAnimated];
			if( ! _animating ) [buddies reloadData];
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

	NSEnumerator *tenumerator = [[[MVConnectionsController defaultManager] connections] objectEnumerator];
	MVChatConnection *testConnection = nil;
	unsigned int count = 0;

	while( ( testConnection = [tenumerator nextObject] ) )
		if( [[testConnection server] caseInsensitiveCompare:[connection server]] == NSOrderedSame && [testConnection isConnected] )
			count++;

	if( count >= 1 ) return;

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		NSEnumerator *nickEnumerator = [[[onlineNicks copy] autorelease] objectEnumerator];
		NSString *nick = nil;
		NSURL *url = nil;

		while( ( nick = [nickEnumerator nextObject] ) ) {
			url = [NSURL URLWithString:nick];
			if( [[url host] caseInsensitiveCompare:[connection server]] == NSOrderedSame ) {
				[onlineNicks removeObject:nick];
				[[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"] removeObjectForKey:nick];
				if( [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"displayNick"] isEqualToString:nick] )
					[[_buddyInfo objectForKey:[person uniqueId]] removeObjectForKey:@"displayNick"];
			}
		}

		if( ! [onlineNicks count] ) {
			[_onlineBuddies removeObject:person];
			if( ! _showOfflineBuddies ) {
				[_buddyOrder removeObject:person];
				[buddies noteNumberOfRowsChanged];
			}
		}
	}

	[self _setBuddiesNeedSortAnimated];
	if( ! _animating ) [buddies reloadData];
}

- (void) _nicknameChange:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"oldNickname"];
	NSString *new = [[notification userInfo] objectForKey:@"newNickname"];
	NSEnumerator *enumerator = [_onlineBuddies objectEnumerator];
	ABPerson *person = nil;
	NSString *mask = nil;
	NSString *newMask = nil;

	while( ( person = [enumerator nextObject] ) ) {
		NSMutableSet *onlineNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"onlineNicks"];
		mask = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )];
		if( [onlineNicks containsObject:mask] ) {
			NSMutableSet *allNicks = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"allNicks"];

			newMask = [NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( new ), MVURLEncodeString( [connection server] )];

			if( [[[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"displayNick"] isEqualToString:mask] )
				[[_buddyInfo objectForKey:[person uniqueId]] setObject:newMask forKey:@"displayNick"];

			[allNicks removeObject:mask];
			[allNicks addObject:newMask];

			[onlineNicks removeObject:mask];
			[onlineNicks addObject:newMask];

			NSMutableDictionary *nickInfo = [[_buddyInfo objectForKey:[person uniqueId]] objectForKey:@"nickInfo"];
			NSMutableDictionary *info = [[[nickInfo objectForKey:mask] retain] autorelease];
			[nickInfo removeObjectForKey:mask];
			[nickInfo setObject:info forKey:newMask];

			[self _setBuddiesNeedSortAnimated];
			if( ! _animating ) [buddies reloadData];

			break;
		}
	}
}

- (void) _addPersonToBuddyList:(ABPerson *) person {
	[_buddyList addObject:person];
	[_buddyInfo setObject:[NSMutableDictionary dictionary] forKey:[person uniqueId]];

	if( _showOfflineBuddies && ! [_buddyOrder containsObject:person] ) {
		[_buddyOrder addObject:person];
		[self _manuallySortAndUpdate];
	}
}

- (void) _registerBuddyWithActiveConnections:(ABPerson *) person {
	ABMultiValue *value = [person valueForProperty:@"IRCNickname"];
	MVChatConnection *connection = nil;
	unsigned int i = 0, count = [value count];
	for( i = 0; i < count; i++ ) {
		connection = [[MVConnectionsController defaultManager] connectionForServerAddress:[value labelAtIndex:i]];
		if( [connection isConnected] ) [connection addUserToNotificationList:[value valueAtIndex:i]];
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
			NSMutableSet *allNicks = [NSMutableSet set];
			ABMultiValue *value = [person valueForProperty:@"IRCNickname"];
			unsigned int i = 0, count = [value count];
			for( i = 0; i < count; i++ )
				[allNicks addObject:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( [value valueAtIndex:i] ), MVURLEncodeString( [value labelAtIndex:i] )]];

			if( [allNicks count] ) {
				[self _addPersonToBuddyList:(ABPerson *)person];
				[[_buddyInfo objectForKey:[person uniqueId]] setObject:allNicks forKey:@"allNicks"];
			}
		}
	}
}
@end