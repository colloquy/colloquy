#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>

#import "MVBuddyListController.h"
#import "JVBuddy.h"
#import "JVChatController.h"
#import "MVApplicationController.h"
#import "MVConnectionsController.h"
#import "JVInspectorController.h"
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
@end

#pragma mark -

@interface MVBuddyListController (MVBuddyListControllerPrivate)
- (void) _saveBuddyList;
- (void) _loadBuddyList;
- (void) _sortBuddies;
- (void) _manuallySortAndUpdate;
- (void) _setBuddiesNeedSortAnimated;
- (void) _sortBuddiesAnimatedIfNeeded:(id) sender;
- (void) _addBuddyToList:(JVBuddy *) buddy;
@end

#pragma mark -

@implementation MVBuddyListController
+ (MVBuddyListController *) sharedBuddyList {
	extern MVBuddyListController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:nil] ) );
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"MVBuddyList"] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOnline: ) name:JVBuddyCameOnlineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOffline: ) name:JVBuddyWentOfflineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyNicknameCameOnlineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyNicknameWentOfflineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyNicknameStatusChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyActiveNicknameChangedNotification object:nil];

		_sortTimer = [[NSTimer scheduledTimerWithTimeInterval:( .5 ) target:self selector:@selector( _sortBuddiesAnimatedIfNeeded: ) userInfo:nil repeats:YES] retain];

		_onlineBuddies = [[NSMutableSet set] retain];
		_buddyList = [[NSMutableSet set] retain];
		_buddyOrder = [[NSMutableArray array] retain];
		_picker = nil;
		
		[self _loadBuddyList];

		[JVBuddy setPreferredName:(JVBuddyName)[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatBuddyNameStyle"]];

		[self setShowIcons:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowIcons"]];
		[self setShowFullNames:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowFullNames"]];
		[self setShowNicknameAndServer:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowNicknameAndServer"]];
		[self setShowOfflineBuddies:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowOfflineBuddies"]];
		[self setSortOrder:[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatBuddyListSortOrder"]];
	}
	return self;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[_sortTimer invalidate];
	[super release];
}

- (void) dealloc {
	extern MVBuddyListController *sharedInstance;
	[self _saveBuddyList];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_onlineBuddies release];
	[_buddyList release];
	[_buddyOrder release];
	[_picker release];
	[_oldPositions release];
	[_sortTimer release];
	[_addPerson release];

	_onlineBuddies = nil;
	_buddyList = nil;
	_buddyOrder = nil;
	_picker = nil;
	_oldPositions = nil;
	_sortTimer = nil;
	_addPerson = nil;

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

- (id <JVInspection>) objectToInspect {
	if( [buddies selectedRow] == -1 ) return nil;
	id item = [_buddyOrder objectAtIndex:[buddies selectedRow]];
	if( [item conformsToProtocol:@protocol( JVInspection )] ) return item;
	else return nil;
}

- (IBAction) getInfo:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	id item = [_buddyOrder objectAtIndex:[buddies selectedRow]];
	if( [item conformsToProtocol:@protocol( JVInspection )] )
		[[JVInspectorController inspectorOfObject:item] show:sender];
}

#pragma mark -

- (IBAction) showBuddyList:(id) sender {
	[[self window] orderFront:nil];
}

#pragma mark -

- (JVBuddy *) buddyForNickname:(NSString *) name onServer:(NSString *) address {
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	JVBuddy *buddy = nil;
	NSURL *nick = nil;

	while( ( buddy = [enumerator nextObject] ) ) {
		nick = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( name ), MVURLEncodeString( address )]];
		if( [[buddy nicknames] containsObject:nick] ) return buddy;
	}

	return nil;
}

- (NSArray *) buddies {
	return [[_buddyOrder retain] autorelease];
}

- (NSArray *) onlineBuddies {
	return [_onlineBuddies allObjects];
}

#pragma mark -

- (IBAction) showBuddyPickerSheet:(id) sender {
	[self showBuddyList:nil];

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
		JVBuddy *buddy = [JVBuddy buddyWithPerson:person];
		[self _addBuddyToList:buddy];
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
			[sub setObject:[NSArray arrayWithObject:kABOtherLabel] forKey:@"labels"];
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
			[emailValue addValue:[email objectValue] withLabel:kABOtherLabel];
		}
		[person setValue:emailValue forProperty:kABEmailProperty];

		[person setImageData:[[image image] TIFFRepresentation]];

		[[ABAddressBook sharedAddressBook] save];
	}

	if( person ) {
		JVBuddy *buddy = [JVBuddy buddyWithPerson:person];
		[self _addBuddyToList:buddy];
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

- (IBAction) messageSelectedBuddy:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	JVBuddy *buddy = [_buddyOrder objectAtIndex:[buddies selectedRow]];
	NSURL *url = [buddy activeNickname];
	[[JVChatController defaultManager] chatViewControllerForUser:[url user] withConnection:[[MVConnectionsController defaultManager] connectionForServerAddress:[url host]] ifExists:NO];
}

- (IBAction) sendFileToSelectedBuddy:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	JVBuddy *buddy = [_buddyOrder objectAtIndex:[buddies selectedRow]];
	NSURL *url = [buddy activeNickname];
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
			[connection sendFile:path toUser:[url user]];
	}
}

#pragma mark -

- (void) setShowFullNames:(BOOL) flag {
	_showFullNames = flag;
	[buddies reloadData];
	[self _setBuddiesNeedSortAnimated];
	[self _sortBuddiesAnimatedIfNeeded:nil];
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"JVChatBuddyListShowFullNames"];
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
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"JVChatBuddyListShowNicknameAndServer"];
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
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"JVChatBuddyListShowIcons"];
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
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"JVChatBuddyListShowOfflineBuddies"];
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
	[[NSUserDefaults standardUserDefaults] setInteger:order forKey:@"JVChatBuddyListSortOrder"];
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
	} else if( [menuItem action] == @selector( sendFileToSelectedBuddy: ) ) {
		if( [buddies selectedRow] == -1 ) return NO;
		else return YES;
	} else if( [menuItem action] == @selector( getInfo: ) ) {
		if( [buddies selectedRow] == -1 ) return NO;
		else return YES;
	} else if( [menuItem action] == @selector( sortByAvailability: ) ) {
		[menuItem setState:( _sortOrder == MVAvailabilitySortOrder || ! _sortOrder ? NSOnState : NSOffState )];
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
	JVBuddy *buddy = [[[_buddyOrder objectAtIndex:[buddies selectedRow]] retain] autorelease];
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
			JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
			NSImage *ret = [buddy picture];
			if( ! ret ) ret = [[[NSImage imageNamed:@"largePerson"] copy] autorelease];
			[ret setScalesWhenResized:YES];
			[ret setSize:NSMakeSize( 32., 32. )];
			return ret;
		} else if( ! _showIcons ) {
			JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
			switch( [buddy status] ) {
				case JVBuddyAwayStatus: return [NSImage imageNamed:@"statusAway"];
				case JVBuddyIdleStatus: return [NSImage imageNamed:@"statusIdle"];
				case JVBuddyAvailableStatus: return [NSImage imageNamed:@"statusAvailable"];
				default: return [NSImage imageNamed:@"statusOffline"];
			}
		} else return nil;
	}

	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( row == -1 || row >= [_buddyOrder count] ) return;
	if( [[column identifier] isEqualToString:@"buddy"] ) {
		JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
		NSURL *url = [buddy activeNickname];
		if( url && ( ! _showFullNames || ! [[buddy compositeName] length] ) ) {
			[cell setMainText:[url user]];
			if( _showNicknameAndServer ) [cell setInformationText:[url host]];
			else [cell setInformationText:nil];
		} else {
			[cell setMainText:[buddy compositeName]];
			if( url && _showNicknameAndServer ) [cell setInformationText:[NSString stringWithFormat:@"%@ (%@)", [url user], [url host]]];
			else [cell setInformationText:nil];
		}

		[cell setEnabled:[buddy isOnline]];

		if( _showIcons ) {
			switch( [buddy status] ) {
			case JVBuddyAwayStatus:
				[cell setStatusImage:[NSImage imageNamed:@"statusAway"]];
				break;
			case JVBuddyIdleStatus:
				[cell setStatusImage:[NSImage imageNamed:@"statusIdle"]];
				break;
			case JVBuddyAvailableStatus:
				[cell setStatusImage:[NSImage imageNamed:@"statusAvailable"]];
				break;
			default:
				[cell setStatusImage:[NSImage imageNamed:@"statusOffline"]];
			}
		} else [cell setStatusImage:nil];
	} else if( [[column identifier] isEqualToString:@"switch"] ) {
		JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
		NSSet *onlineNicks = [buddy onlineNicknames];
		NSSet *nicks = nil;

		if( _showOfflineBuddies ) nicks = [buddy nicknames];
		else nicks = [buddy onlineNicknames];

		if( [nicks count] >= 2 ) {
			NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
			NSMenuItem *item = nil;
			NSEnumerator *nickEnumerator = [nicks objectEnumerator];
			NSURL *activeNick = [buddy activeNickname];
			NSURL *nick = nil;

			[menu setAutoenablesItems:NO];
			while( ( nick = [nickEnumerator nextObject] ) ) {
				item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", [nick user], [nick host]] action:NULL keyEquivalent:@""] autorelease];
				if( [nick isEqual:activeNick] ) [item setState:NSOnState];
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
	JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
	NSArray *nicks = nil;

	if( _showOfflineBuddies ) nicks = [[buddy nicknames] allObjects];
	else nicks = [[buddy onlineNicknames] allObjects];

	[buddy setActiveNickname:[nicks objectAtIndex:[object unsignedIntValue]]];

	[buddies reloadData];
	[self _setBuddiesNeedSortAnimated];
	[self _sortBuddiesAnimatedIfNeeded:nil];
}

- (NSMenu *) tableView:(MVTableView *) tableView menuForTableColumn:(NSTableColumn *) tableColumn row:(int) row {
	return actionMenu;
}

- (NSString *) tableView:(MVTableView *) tableView toolTipForTableColumn:(NSTableColumn *) column row:(int) row {
	if( row == -1 || row >= [_buddyOrder count] ) return nil;
	NSMutableString *ret = [NSMutableString string];
	JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
	NSURL *url = [buddy activeNickname];

	[ret appendFormat:@"%@\n", [buddy compositeName]];
	[ret appendFormat:@"%@ (%@)\n", [url user], [url host]];

	switch( [buddy status] ) {
	case JVBuddyAwayStatus:
		[ret appendString:NSLocalizedString( @"Away", "away buddy status" )];
		break;
	case JVBuddyIdleStatus:
		[ret appendString:NSLocalizedString( @"Idle", "idle buddy status" )];
		break;
	case JVBuddyAvailableStatus:
		[ret appendString:NSLocalizedString( @"Available", "available buddy status" )];
		break;
	default:
		[ret appendString:NSLocalizedString( @"Offline", "offline buddy status" )];
	}

	return ret;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	BOOL enabled = ! ( [buddies selectedRow] == -1 );
	[sendMessageButton setEnabled:enabled];
	[infoButton setEnabled:enabled];
	[[JVInspectorController sharedInspector] inspectObject:[self objectToInspect]];
}

- (NSDragOperation) tableView:(NSTableView *) tableView validateDrop:(id <NSDraggingInfo>) info proposedRow:(int) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( operation == NSTableViewDropOn && row != -1 )
		return NSDragOperationMove;
	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) tableView acceptDrop:(id <NSDraggingInfo>) info row:(int) row dropOperation:(NSTableViewDropOperation) operation {
	NSPasteboard *board = [info draggingPasteboard];
	if( [board availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]] ) {
		JVBuddy *buddy = [_buddyOrder objectAtIndex:row];
		NSURL *url = [buddy activeNickname];
		MVChatConnection *connection = [[MVConnectionsController defaultManager] connectionForServerAddress:[url host]];
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSEnumerator *enumerator = [files objectEnumerator];
		id file = nil;

		while( ( file = [enumerator nextObject] ) )
			[connection sendFile:file toUser:[url user]];

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
		int oldPosition = [[_oldPositions objectAtIndex:row] intValue];
		NSRect oldR = [tableView originalRectOfRow:oldPosition];
		NSRect newR = [tableView originalRectOfRow:row];

		float t = _animationPosition;

		float rowPos = ( (float) row / [_buddyOrder count] );
		float rowPosAdjusted = _viewingTop ? ( 1. - rowPos ) : rowPos;
		float curve = 0.3;
		float p = rowPosAdjusted * ( curve * 2. ) + 1. - curve;

		t = curveFunction( t, p );
		t = easeFunction( t );

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
	switch( _sortOrder ) {
	default:
	case MVAvailabilitySortOrder:
		[_buddyOrder sortUsingSelector:@selector( availabilityCompare: )];
		break;
	case MVFirstNameSortOrder:
		[_buddyOrder sortUsingSelector:@selector( firstNameCompare: )];
		break;
	case MVLastNameSortOrder:
		[_buddyOrder sortUsingSelector:@selector( lastNameCompare: )];
		break;
	case MVServerSortOrder:
		[_buddyOrder sortUsingSelector:@selector( serverCompare: )];
	}
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

	if( [oldOrder isEqualToArray:_buddyOrder] ) return;
	
	if( selectedObject ) {
		[buddies deselectAll:nil];
		[buddies selectRow:[_buddyOrder indexOfObjectIdenticalTo:selectedObject] byExtendingSelection:NO];
		[buddies setNeedsDisplay:NO];
	}

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

- (void) _buddyOnline:(NSNotification *) notification {
	JVBuddy *buddy = [notification object];
	if( ! [_buddyList containsObject:buddy] ) return;

	[_onlineBuddies addObject:buddy];
	if( ! [_buddyOrder containsObject:buddy] ) {
		[_buddyOrder addObject:buddy];
		[buddies noteNumberOfRowsChanged];
	}

	[self _setBuddiesNeedSortAnimated];
	if( ! _animating ) [buddies reloadData];
}

- (void) _buddyOffline:(NSNotification *) notification {
	JVBuddy *buddy = [notification object];
	if( ! [_onlineBuddies containsObject:buddy] ) return;

	[_onlineBuddies removeObject:buddy];
	if( ! _showOfflineBuddies ) {
		[_buddyOrder removeObject:buddy];
		[buddies noteNumberOfRowsChanged];
	}

	[self _setBuddiesNeedSortAnimated];
	if( ! _animating ) [buddies reloadData];
}

- (void) _buddyChanged:(NSNotification *) notification {
	JVBuddy *buddy = [notification object];
	if( ! [_onlineBuddies containsObject:buddy] ) return;
	[self _setBuddiesNeedSortAnimated];
	if( ! _animating ) [buddies reloadData];
}

- (void) _addBuddyToList:(JVBuddy *) buddy {
	[_buddyList addObject:buddy];
	if( _showOfflineBuddies && ! [_buddyOrder containsObject:buddy] ) {
		[_buddyOrder addObject:buddy];
		[self _manuallySortAndUpdate];
	}
}

- (void) _saveBuddyList {
	NSMutableArray *list = [NSMutableArray arrayWithCapacity:[_buddyList count]];
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	JVBuddy *buddy = nil;

	while( ( buddy = [enumerator nextObject] ) )
		[list addObject:[buddy uniqueIdentifier]];

	[[NSUserDefaults standardUserDefaults] setObject:list forKey:@"JVChatBuddies"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) _loadBuddyList {
	NSArray *list = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatBuddies"];
	NSEnumerator *enumerator = [list objectEnumerator];
	NSString *identifier = nil;

	while( ( identifier = [enumerator nextObject] ) ) {
		JVBuddy *buddy = [JVBuddy buddyWithUniqueIdentifier:identifier];
		if( [[buddy nicknames] count] ) [self _addBuddyToList:buddy];
	}
}
@end

#pragma mark -

@implementation JVBuddy (JVBuddyObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[MVBuddyListController class]];
	NSScriptObjectSpecifier *container = [[MVBuddyListController sharedBuddyList] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"buddies" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerScripting)
- (void) removeFromBuddiesAtIndex:(unsigned) index {
	JVBuddy *buddy = [[[_buddyOrder objectAtIndex:index] retain] autorelease];
	[_buddyList removeObject:buddy];
	[_onlineBuddies removeObject:buddy];
	[_buddyOrder removeObjectIdenticalTo:buddy];
	[self _manuallySortAndUpdate];
	[self _saveBuddyList];
}

- (JVBuddy *) valueInBuddiesWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	JVBuddy *buddy = nil;

	while( ( buddy = [enumerator nextObject] ) )
		if( [[buddy uniqueIdentifier] isEqualTo:identifier] )
			return buddy;

	return nil;
}

- (JVBuddy *) valueInBuddiesWithName:(NSString *) name {
	NSEnumerator *enumerator = [_buddyList objectEnumerator];
	JVBuddy *buddy = nil;

	while( ( buddy = [enumerator nextObject] ) )
		if( [[buddy compositeName] isEqualToString:name] )
			return buddy;

	return nil;
}
@end