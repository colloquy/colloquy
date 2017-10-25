#include <tgmath.h>
#import "MVBuddyListController.h"

#import "JVBuddy.h"
#import "JVChatController.h"
#import "JVDetailCell.h"
#import "JVInspectorController.h"
#import "JVNotificationController.h"
#import "MVApplicationController.h"
#import "MVChatUserAdditions.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "MVTableView.h"
#import "NSImageAdditions.h"

static MVBuddyListController *sharedInstance = nil;

@interface MVBuddyListController (Private)
- (void) _animateStep:(NSTimer *) timer;
- (void) _manuallySortAndUpdate;
- (void) _sortBuddies;
- (void) _setBuddiesNeedSortAnimated;
- (void) _sortBuddiesAnimated:(id) sender;
- (void) _buddyChanged:(NSNotification *) notification;
- (void) _buddyOnline:(NSNotification *) notification;
- (void) _buddyOffline:(NSNotification *) notification;
- (void) _importOldBuddyList;
- (void) _loadBuddyList;
- (NSMenu *) _menuForBuddy:(JVBuddy *) buddy;
@end

#pragma mark -

@implementation MVBuddyListController
+ (MVBuddyListController *) sharedBuddyList {
	if( ! sharedInstance ) {
		sharedInstance = [self alloc];
		sharedInstance = [sharedInstance initWithWindowNibName:@"MVBuddyList"];
	}

	return sharedInstance;
}

#pragma mark -

- (instancetype) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyOnline: ) name:JVBuddyCameOnlineNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyOffline: ) name:JVBuddyWentOfflineNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyUserCameOnlineNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyUserWentOfflineNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyActiveUserChangedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyUserStatusChangedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyChanged: ) name:JVBuddyUserIdleTimeUpdatedNotification object:nil];

		_onlineBuddies = [[NSMutableSet alloc] initWithCapacity:20];
		_buddyList = [[NSMutableSet alloc] initWithCapacity:40];
		_buddyOrder = [[NSMutableArray alloc] initWithCapacity:40];

		[self _loadBuddyList];

		[JVBuddy setPreferredName:(OSType)[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatBuddyNameStyle"]];

		[self setShowIcons:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowIcons"]];
		[self setShowFullNames:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowFullNames"]];
		[self setShowNicknameAndServer:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowNicknameAndServer"]];
		[self setShowOfflineBuddies:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatBuddyListShowOfflineBuddies"]];
		[self setSortOrder:(OSType)[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatBuddyListSortOrder"]];
	}

	return self;
}

- (void) dealloc {
	[self save];

	[[NSNotificationCenter chatCenter] removeObserver:self];
	if( self == sharedInstance ) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _sortBuddiesAnimated: ) object:nil];
		sharedInstance = nil;
	}
}

- (void) windowDidLoad {
	NSTableColumn *theColumn = nil;

	[(NSPanel *)[self window] setFloatingPanel:NO];
	[(NSPanel *)[self window] setHidesOnDeactivate:NO];
	[[self window] setFrameAutosaveName:@"buddylist"];

	NSWindowCollectionBehavior windowCollectionBehavior = (NSWindowCollectionBehaviorDefault | NSWindowCollectionBehaviorParticipatesInCycle | NSWindowCollectionBehaviorTransient);
	if( floor( NSAppKitVersionNumber ) >= NSAppKitVersionNumber10_7 )
		windowCollectionBehavior |= NSWindowCollectionBehaviorFullScreenAuxiliary;

	[[self window] setCollectionBehavior:windowCollectionBehavior];

	[buddies setVerticalMotionCanBeginDrag:NO];
	[buddies setTarget:self];
	[buddies setDoubleAction:@selector( messageSelectedBuddy: )];

	theColumn = [buddies tableColumnWithIdentifier:@"buddy"];
	JVDetailCell *prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont systemFontOfSize:11.]];
	[theColumn setDataCell:prototypeCell];

	[pickerView addProperty:kABNicknameProperty];
	[pickerView addProperty:kABInstantMessageProperty];
	[pickerView addProperty:kABSocialProfileProperty];
	[pickerView addProperty:kABEmailProperty];

	[pickerView setAllowsMultipleSelection:NO];
	[pickerView setAllowsGroupSelection:NO];
	[pickerView setTarget:self];
	[pickerView setNameDoubleAction:@selector( confirmBuddySelection: )];

	[buddies registerForDraggedTypes:@[NSFilenamesPboardType]];

	if( _showIcons || _showNicknameAndServer ) [buddies setRowHeight:36.];
	else [buddies setRowHeight:18.];

	[buddies reloadData];
	[self _setBuddiesNeedSortAnimated];
}

#pragma mark -

- (void) save {
	NSMutableArray *list = [[NSMutableArray alloc] initWithCapacity:[_buddyList count]];

	for( JVBuddy *buddy in _buddyList ) {
		NSDictionary *buddyRep = [buddy dictionaryRepresentation];
		if( buddyRep ) [list addObject:buddyRep];
	}

	NSURL *saveURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
	saveURL = [[saveURL URLByAppendingPathComponent:@"Colloquy"] URLByAppendingPathComponent:@"Buddy List.plist" isDirectory:NO];
	[list writeToURL:saveURL atomically:YES];
}

#pragma mark -

- (id <JVInspection>) objectToInspect {
	if( [buddies selectedRow] == -1 ) return nil;
	id item = _buddyOrder[[buddies selectedRow]];
	if( [item conformsToProtocol:@protocol( JVInspection )] ) return item;
	else return nil;
}

- (IBAction) getInfo:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	id item = _buddyOrder[[buddies selectedRow]];
	if( [item conformsToProtocol:@protocol( JVInspection )] )
		[[JVInspectorController inspectorOfObject:item] show:sender];
}

#pragma mark -

- (IBAction) showBuddyList:(id) sender {
	[[self window] makeKeyAndOrderFront:nil];
}

- (IBAction) hideBuddyList:(id) sender {
	[[self window] orderOut:nil];
}

#pragma mark -

- (void) addBuddy:(JVBuddy *) buddy {
	[_buddyList addObject:buddy];
	if( _showOfflineBuddies && ! [_buddyOrder containsObject:buddy] ) {
		[_buddyOrder addObject:buddy];
		[self _manuallySortAndUpdate];
	}

	[buddy registerWithApplicableConnections];
}

#pragma mark -

- (JVBuddy *) buddyForUser:(MVChatUser *) user {
	for( JVBuddy *buddy in _onlineBuddies )
		if( [[buddy users] containsObject:user] )
			return buddy;

	return nil;
}

- (NSArray *) buddies {
	return _buddyOrder;
}

- (NSSet *) onlineBuddies {
	return _onlineBuddies;
}

#pragma mark -

- (IBAction) showBuddyPickerSheet:(id) sender {
	[self showBuddyList:nil];

	if( self.window.attachedSheet ) {
		[self.window endSheet:self.window.attachedSheet];
	}

	_addPerson = nil;

	_addServers = [[NSMutableSet alloc] init];

	[self.window beginSheet:pickerWindow completionHandler:nil];
}

- (IBAction) cancelBuddySelection:(id) sender {
	if( self.window.attachedSheet ) {
		[self.window endSheet:self.window.attachedSheet];
	}

	_addServers = nil;
}

- (IBAction) confirmBuddySelection:(id) sender {
	if( self.window.attachedSheet ) {
		[self.window endSheet:self.window.attachedSheet];
	}

	ABPerson *person = [[pickerView selectedRecords] lastObject];
	_addPerson = [[person uniqueId] copy];

	[self showNewPersonSheet:nil];
}

#pragma mark -

- (IBAction) showNewPersonSheet:(id) sender {
	if( self.window.attachedSheet ) {
		[self.window endSheet:self.window.attachedSheet];
	}

	[servers reloadData];

	if( _addPerson ) {
		ABPerson *person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:_addPerson];
		if( person ) {
			if( ! [[nickname stringValue] length] )
				[nickname setObjectValue:[person valueForProperty:kABNicknameProperty]];
			[firstName setObjectValue:[person valueForProperty:kABFirstNameProperty]];
			[lastName setObjectValue:[person valueForProperty:kABLastNameProperty]];

			ABMultiValue *value = [person valueForProperty:kABEmailProperty];
			NSUInteger index = [value indexForIdentifier:[value primaryIdentifier]];
			if( index != NSNotFound ) [email setObjectValue:[value valueAtIndex:index]];

			[image setImage:[[NSImage alloc] initWithData:[person imageData]]];
		}
	}

	if( [[nickname stringValue] length] && [_addServers count] )
		[addButton setEnabled:YES];
	else [addButton setEnabled:NO];

	[self.window beginSheet:newPersonWindow completionHandler:nil];
}

- (IBAction) cancelNewBuddy:(id) sender {
	if( self.window.attachedSheet ) {
		[self.window endSheet:self.window.attachedSheet];
	}

	[nickname setObjectValue:@""];
	[firstName setObjectValue:@""];
	[lastName setObjectValue:@""];
	[email setObjectValue:@""];
	[image setImage:nil];

	_addPerson = nil;

	_addServers = nil;
}

- (IBAction) confirmNewBuddy:(id) sender {
	if( self.window.attachedSheet ) {
		[self.window endSheet:self.window.attachedSheet];
	}

	JVBuddy *buddy = [[JVBuddy alloc] init];

	[buddy setGivenNickname:[nickname stringValue]];
	[buddy setFirstName:[firstName stringValue]];
	[buddy setLastName:[lastName stringValue]];
	[buddy setPrimaryEmail:[email stringValue]];
	[buddy setPicture:[image image]];

	if( _addPerson ) {
		ABPerson *person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:_addPerson];
		if( person ) [buddy setAddressBookPersonRecord:person];
	}

	MVChatUserWatchRule *rule = [[MVChatUserWatchRule alloc] init];
	[rule setNickname:[nickname stringValue]];

	NSMutableArray *newServers = [[NSMutableArray alloc] initWithCapacity:[_addServers count]];

	for( __strong NSString *server in _addServers ) {
		server = [server stringWithDomainNameSegmentOfAddress];
		if( [server length] )
			[newServers addObject:server];
	}

	[rule setApplicableServerDomains:newServers];

	[buddy addWatchRule:rule];

	[self addBuddy:buddy];

	[self save];

	[nickname setObjectValue:@""];
	[firstName setObjectValue:@""];
	[lastName setObjectValue:@""];
	[email setObjectValue:@""];
	[image setImage:nil];

	_addPerson = nil;

	_addServers = nil;
}

- (void) controlTextDidChange:(NSNotification *) notification {
	if( [[nickname stringValue] length] && [_addServers count] )
		[addButton setEnabled:YES];
	else [addButton setEnabled:NO];
}

#pragma mark -

- (void) setNewBuddyNickname:(NSString *) nick {
	[nickname setObjectValue:nick];
}

- (void) setNewBuddyFullname:(NSString *) name {
	NSRange range = [name rangeOfString:@" "];
	if( range.location != NSNotFound ) {
		[firstName setObjectValue:[name substringToIndex:range.location]];
		if( ( range.location + 1 ) < [name length] ) {
			[lastName setObjectValue:[name substringFromIndex:( range.location + 1 )]];
		} else [lastName setObjectValue:@""];
	} else {
		[firstName setObjectValue:@""];
		[lastName setObjectValue:@""];
	}
}

- (void) setNewBuddyServer:(MVChatConnection *) connection {
	[_addServers addObject:[connection server]];
}

#pragma mark -

- (IBAction) messageSelectedBuddy:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	JVBuddy *buddy = _buddyOrder[[buddies selectedRow]];
	MVChatUser *user = [buddy activeUser];
	if( [user type] != MVChatRemoteUserType ) return;
	[[JVChatController defaultController] chatViewControllerForUser:user ifExists:NO];
}

- (IBAction) sendFileToSelectedBuddy:(id) sender {
	if( [buddies selectedRow] == -1 ) return;
	JVBuddy *buddy = _buddyOrder[[buddies selectedRow]];
	MVChatUser *user = [buddy activeUser];
	[user sendFile:sender];
}

#pragma mark -

- (void) setShowFullNames:(BOOL) flag {
	_showFullNames = flag;
	[buddies reloadData];
	[self _sortBuddiesAnimated:nil];
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"JVChatBuddyListShowFullNames"];
	[[NSUserDefaults standardUserDefaults] synchronize];
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
	[[NSUserDefaults standardUserDefaults] synchronize];
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
	[[NSUserDefaults standardUserDefaults] synchronize];
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
	[[NSUserDefaults standardUserDefaults] synchronize];
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
	[self _sortBuddiesAnimated:nil];
	[[NSUserDefaults standardUserDefaults] setInteger:order forKey:@"JVChatBuddyListSortOrder"];
	[[NSUserDefaults standardUserDefaults] synchronize];
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

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
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
	JVBuddy *buddy = _buddyOrder[[buddies selectedRow]];
	[_buddyList removeObject:buddy];
	[_onlineBuddies removeObject:buddy];
	[_buddyOrder removeObjectIdenticalTo:buddy];
	[self _manuallySortAndUpdate];
	[self save];
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	if( view == servers )
		return [[[MVConnectionsController defaultController] connections] count];

	if( view == buddies )
		return [_buddyOrder count];

	return 0;
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == servers ) {
		MVChatConnection *connection = [[MVConnectionsController defaultController] connections][row];
		if( [[column identifier] isEqualToString:@"domain"] )
			return [connection server];
		return nil;
	}

	if( view != buddies || row == -1 || row >= (int)[_buddyOrder count] )
		return nil;

	if( [[column identifier] isEqualToString:@"buddy"] ) {
		if( _showIcons ) {
			JVBuddy *buddy = _buddyOrder[row];
			NSImage *ret = [buddy picture];
			if( ! ret ) ret = [[NSImage imageNamed:@"person"] copy];
			[ret setSize:NSMakeSize( 32., 32. )];

			return ret;
		}
	}

	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == servers ) {
		MVChatConnection *connection = [[MVConnectionsController defaultController] connections][row];
		if( [[column identifier] isEqualToString:@"check"] )
			[cell setState:( [_addServers containsObject:[connection server]] )];
		return;
	}

	if( view != buddies || row == -1 || row >= (int)[_buddyOrder count] )
		return;

	if( [[column identifier] isEqualToString:@"buddy"] ) {
		JVBuddy *buddy = _buddyOrder[row];
		MVChatUser *user = [buddy activeUser];

		if( user && ( ! _showFullNames || ! [[buddy compositeName] length] ) ) {
			[cell setMainText:[user nickname]];
			if( _showNicknameAndServer ) [cell setInformationText:[user serverAddress]];
			else [cell setInformationText:nil];
		} else {
			[cell setMainText:[buddy compositeName]];
			if( user && _showNicknameAndServer ) [cell setInformationText:[NSString stringWithFormat:@"%@ (%@)", [user nickname], [user serverAddress]]];
			else [cell setInformationText:nil];
		}

		[cell setEnabled:( [user status] == MVChatUserAvailableStatus || [user status] == MVChatUserAwayStatus )];

		switch( [buddy status] ) {
		case MVChatUserAwayStatus:
			[cell setStatusImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
			break;
		case MVChatUserAvailableStatus:
			if( [buddy idleTime] >= 600. ) [cell setStatusImage:[NSImage imageNamed:NSImageNameStatusPartiallyAvailable]];
			else [cell setStatusImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
			break;
		default:
			[cell setStatusImage:[NSImage imageNamed:NSImageNameStatusNone]];
		}
	} else if( [[column identifier] isEqualToString:@"switch"] ) {
		JVBuddy *buddy = _buddyOrder[row];
		NSSet *users = [buddy users];

		if( [users count] >= 2 ) {
			NSMutableArray *ordered = [[users allObjects] mutableCopy];
			[ordered sortUsingSelector:@selector( compareByNickname: )];

			NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
			[menu setAutoenablesItems:NO];

			MVChatUser *activeUser = [buddy activeUser];

			for( MVChatUser *user in ordered ) {
				NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", [user nickname], [user serverAddress]] action:NULL keyEquivalent:@""];
				if( [user isEqualToChatUser:activeUser] ) [item setState:NSOnState];
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

- (void) tableView:(NSTableView *) tableView setObjectValue:(id) object forTableColumn:(NSTableColumn *) tableColumn row:(NSInteger) row {
	if( tableView == servers ) {
		if( [[tableColumn identifier] isEqualToString:@"check"] ) {
			if( [object isKindOfClass:[NSNumber class]] ) {
				MVChatConnection *connection = [[MVConnectionsController defaultController] connections][row];
				if( [object boolValue] ) [_addServers addObject:[connection server]];
				else [_addServers removeObject:[connection server]];

				if( [[nickname stringValue] length] && [_addServers count] )
					[addButton setEnabled:YES];
				else [addButton setEnabled:NO];
			}
		}

		return;
	}

	if( tableView != buddies || row == -1 || row >= (int)[_buddyOrder count] )
		return;

	JVBuddy *buddy = _buddyOrder[row];
	NSSet *users = [buddy users];

	NSMutableArray *ordered = [[users allObjects] mutableCopy];
	[ordered sortUsingSelector:@selector( compareByNickname: )];

	[buddy setActiveUser:ordered[[object unsignedIntValue]]];


	[buddies reloadData];
	[self _sortBuddiesAnimated:nil];
}

- (NSMenu *) tableView:(MVTableView *) tableView menuForTableColumn:(NSTableColumn *) tableColumn row:(NSInteger) row {
	if( tableView != buddies || row == -1 || row >= (int)[_buddyOrder count] ) return nil;
	JVBuddy *buddy = _buddyOrder[row];
	return [self _menuForBuddy:buddy];
}

- (NSString *) tableView:(MVTableView *) tableView toolTipForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( tableView != buddies || row == -1 || row >= (int)[_buddyOrder count] ) return nil;

	NSMutableString *ret = [[NSMutableString alloc] init];
	JVBuddy *buddy = _buddyOrder[row];
	MVChatUser *user = [buddy activeUser];

	[ret appendFormat:@"%@\n", [buddy compositeName]];
	[ret appendFormat:@"%@ (%@)\n", [user nickname], [user serverAddress]];

	switch( [buddy status] ) {
	case MVChatUserAwayStatus:
		[ret appendString:NSLocalizedString( @"Away", "away buddy status" )];
		break;
	case MVChatUserAvailableStatus:
		if( [buddy idleTime] >= 600. ) [ret appendString:NSLocalizedString( @"Idle", "idle buddy status" )];
		else [ret appendString:NSLocalizedString( @"Available", "available buddy status" )];
		break;
	default:
		[ret appendString:NSLocalizedString( @"Offline", "offline buddy status" )];
	}

	return ret;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	if( [notification object] != buddies ) return;

	BOOL enabled = ! ( [buddies selectedRow] == -1 );
	[sendMessageButton setEnabled:enabled];
	[infoButton setEnabled:enabled];
	[actionButton setEnabled:enabled];

	if( [buddies selectedRow] != -1 ) {
		JVBuddy *buddy = _buddyOrder[[buddies selectedRow]];
		NSMenu *buddyMenu = [[self _menuForBuddy:buddy] copy];
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		menuItem.image = [NSImage imageNamed:NSImageNameActionTemplate];
		[buddyMenu insertItem:menuItem atIndex:0];
		[actionButton setMenu:buddyMenu];
	} else {
		[actionButton setMenu:nil];
	}

	[[JVInspectorController sharedInspector] inspectObject:[self objectToInspect]];
}

- (NSDragOperation) tableView:(NSTableView *) tableView validateDrop:(id <NSDraggingInfo>) info proposedRow:(NSInteger) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( tableView != buddies ) return NSDragOperationNone;

	if( operation == NSTableViewDropOn && row != -1 )
		return NSDragOperationMove;
	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) tableView acceptDrop:(id <NSDraggingInfo>) info row:(NSInteger) row dropOperation:(NSTableViewDropOperation) operation {
	if( tableView != buddies ) return NO;

	NSPasteboard *board = [info draggingPasteboard];
	if( [board availableTypeFromArray:@[NSFilenamesPboardType]] ) {
		BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
		JVBuddy *buddy = _buddyOrder[row];
		MVChatUser *user = [buddy activeUser];
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];

		for( id file in files )
			[[MVFileTransferController defaultController] addFileTransfer:[user sendFile:file passively:passive]];

		return YES;
	}

	return NO;
}

- (NSRange) tableView:(MVTableView *) tableView rowsInRect:(NSRect) rect defaultRange:(NSRange) defaultRange {
	if( tableView != buddies ) return defaultRange;

	if( _animating ) return NSMakeRange( 0, [_buddyOrder count] );
	else return defaultRange;
}

#define curveFunction(t,p) ( pow( 1 - pow( ( 1 - t ), p ), ( p ? ( 1 / p ) : 0. ) ) )
#define easeFunction(t) ( ( sin( ( t * M_PI ) - M_PI_2 ) + 1. ) / 2. )

- (NSRect) tableView:(MVTableView *) tableView rectOfRow:(NSInteger) row defaultRect:(NSRect) defaultRect {
	if( _animating ) {
		NSInteger oldPosition = [_oldPositions[row] intValue];
		NSRect oldR = [tableView originalRectOfRow:oldPosition];
		NSRect newR = [tableView originalRectOfRow:row];

		CGFloat t = _animationPosition;

		NSUInteger count = [_buddyOrder count];
		CGFloat rowPos = ( (CGFloat) row / (CGFloat) count );
		CGFloat rowPosAdjusted = _viewingTop ? ( 1. - rowPos ) : rowPos;
		CGFloat curve = 0.3;
		CGFloat p = rowPosAdjusted * ( curve * 2. ) + 1. - curve;

		t = curveFunction( t, p );
		t = easeFunction( t );

		return NSMakeRect( NSMinX( oldR ) + ( t * ( NSMinX( newR ) - NSMinX( oldR ) ) ), NSMinY( oldR ) + ( t * ( NSMinY( newR ) - NSMinY( oldR ) ) ), NSWidth( newR ), NSHeight( newR ) );
	} else return defaultRect;
}
@end

#pragma mark -

@implementation MVBuddyListController (Private)
- (void) _animateStep:(NSTimer *) timer {
	static NSDate *start = nil;
	if( ! _animationPosition ) {
		start = [NSDate date];
	}

	NSTimeInterval elapsed = fabs( [start timeIntervalSinceNow] );
	_animationPosition = MIN( 1., elapsed / .25 );

	if( fabs( _animationPosition - 1. ) <= 0.01 ) {
		start = nil;

		[timer invalidate];

		_animationPosition = 0.;
		_animating = NO;
	}

	[buddies display];
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
	if( _needsToAnimate ) return; // already queued to animate
	_needsToAnimate = YES;

	[self performSelector:@selector( _sortBuddiesAnimated: ) withObject:nil afterDelay:0.5];
}

- (void) _sortBuddiesAnimated:(id) sender {
	_needsToAnimate = NO;
	if( _animating ) return;

	NSRange visibleRows;
	NSArray *oldOrder = [_buddyOrder copy];

	id selectedObject = nil;
	if( [buddies selectedRow] != -1 && [buddies selectedRow] < (int)[oldOrder count] )
		selectedObject = oldOrder[[buddies selectedRow]];

	[self _sortBuddies];

	if( [oldOrder isEqualToArray:_buddyOrder] ) {
		return;
	}

	if( selectedObject ) {
		[buddies deselectAll:nil];
		[buddies selectRowIndexes:[NSIndexSet indexSetWithIndex:[_buddyOrder indexOfObjectIdenticalTo:selectedObject]] byExtendingSelection:NO];
		[buddies setNeedsDisplay:NO];
	}

	_animating = YES;

	_oldPositions = [NSMutableArray arrayWithCapacity:[_buddyOrder count]];

	for( id object in _buddyOrder )
		[_oldPositions addObject:@([oldOrder indexOfObject:object])];

	visibleRows = [buddies rowsInRect:[buddies visibleRect]];
	_viewingTop = NSMaxRange( visibleRows ) < 0.6 * [_buddyOrder count];

	[NSTimer scheduledTimerWithTimeInterval:( 1. / 240. ) target:self selector:@selector( _animateStep: ) userInfo:nil repeats:YES];
}

- (void) _buddyChanged:(NSNotification *) notification {
	JVBuddy *buddy = [notification object];
	if( ! [_onlineBuddies containsObject:buddy] ) return;
	[self _setBuddiesNeedSortAnimated];
	if( ! _animating ) [buddies reloadData];
}

- (void) _buddyOnline:(NSNotification *) notification {
	JVBuddy *buddy = [notification object];
	if( ! [_buddyList containsObject:buddy] ) return;

	[_onlineBuddies addObject:buddy];
	if( ! [_buddyOrder containsObject:buddy] )
		[_buddyOrder addObject:buddy];

	[self _buddyChanged:notification];

	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	context[@"title"] = NSLocalizedString( @"Buddy Available", "available buddy bubble title" );
	context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"Your buddy %@ is now online.", "available buddy bubble text" ), [buddy displayName]];

	NSImage *icon = [buddy picture];
	if( ! icon ) icon = [NSImage imageNamed:@"person"];
	context[@"image"] = icon;

	[[JVNotificationController defaultController] performNotification:@"JVChatBuddyOnline" withContextInfo:context];
}

- (void) _buddyOffline:(NSNotification *) notification {
	JVBuddy *buddy = [notification object];
	if( ! [_onlineBuddies containsObject:buddy] ) return;

	[_onlineBuddies removeObject:buddy];
	if( ! _showOfflineBuddies )
		[_buddyOrder removeObject:buddy];

	[self _buddyChanged:notification];

	MVChatConnection *buddyConnection = [[buddy activeUser] connection];
	if( [buddyConnection isConnected] ) {
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		context[@"title"] = NSLocalizedString( @"Buddy Unavailable", "unavailable buddy bubble title" );
		context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"Your buddy %@ is now offline.", "unavailable buddy bubble text" ), [buddy displayName]];

		NSImage *icon = [buddy picture];
		if( ! icon ) icon = [NSImage imageNamed:@"person"];
		context[@"image"] = icon;

		[[JVNotificationController defaultController] performNotification:@"JVChatBuddyOffline" withContextInfo:context];
	}
}

- (void) _importOldBuddyList {
	NSArray *list = [[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatBuddies"];
	if( ! [list count] ) return;

	for( NSString *identifier in list ) {
		ABPerson *person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:identifier];
		if( ! person ) continue;

		JVBuddy *buddy = [[JVBuddy alloc] init];

		[buddy setPicture:[[NSImage alloc] initWithData:[person imageData]]];
		[buddy setGivenNickname:[person valueForProperty:kABNicknameProperty]];
		[buddy setFirstName:[person valueForProperty:kABFirstNameProperty]];
		[buddy setLastName:[person valueForProperty:kABLastNameProperty]];

		ABMultiValue *value = [person valueForProperty:kABEmailProperty];
		[buddy setPrimaryEmail:[value valueAtIndex:[value indexForIdentifier:[value primaryIdentifier]]]];

		[buddy setSpeechVoice:[person valueForProperty:@"cc.javelin.colloquy.JVBuddy.TTSvoice"]];

		[buddy setAddressBookPersonRecord:person];

		value = [person valueForProperty:@"IRCNickname"];

		for( NSUInteger i = 0; i < [value count]; i++ ) {
			NSString *nick = [value valueAtIndex:i];
			NSString *server = [[value labelAtIndex:i] stringWithDomainNameSegmentOfAddress];
			if( ! [nick length] || ! [server length] )
				continue;

			MVChatUserWatchRule *rule = [[MVChatUserWatchRule alloc] init];
			[rule setNickname:nick];
			[rule setApplicableServerDomains:@[server]];

			[buddy addWatchRule:rule];

		}

		if( buddy && [[buddy watchRules] count] )
			[self addBuddy:buddy];

	}

	[self save];

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatBuddies"];
}

- (void) _loadBuddyList {
	NSURL *saveURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
	saveURL = [[saveURL URLByAppendingPathComponent:@"Colloquy"] URLByAppendingPathComponent:@"Buddy List.plist" isDirectory:NO];

	NSArray *list = [[NSArray alloc] initWithContentsOfURL:saveURL];
	if( ! [list count] ) [self _importOldBuddyList];

	for( NSDictionary *buddyDictionary in list ) {
		JVBuddy *buddy = [[JVBuddy alloc] initWithDictionaryRepresentation:buddyDictionary];
		if( buddy ) [self addBuddy:buddy];
	}

}

- (NSMenu *) _menuForBuddy:(JVBuddy *) buddy {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

	NSArray *standardItems = [[buddy activeUser] standardMenuItems];
	for( NSMenuItem *item in standardItems ) {
		if( [item action] == @selector( addBuddy: ) )
			continue;
		if( [item action] == @selector( toggleIgnore: ) )
			continue;
		[menu addItem:item];
	}

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( NSArray * ), @encode( id ), @encode( id ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	id view = nil;

	[invocation setSelector:@selector( contextualMenuItemsForObject:inView: )];
	MVAddUnsafeUnretainedAddress(buddy, 2);
	MVAddUnsafeUnretainedAddress(view, 2);

	NSArray *results = [[MVChatPluginManager defaultManager] makePluginsPerformInvocation:invocation];
	if( [results count] ) {
		if( [menu numberOfItems ] && ! [[[menu itemArray] lastObject] isSeparatorItem] )
			[menu addItem:[NSMenuItem separatorItem]];

		for( NSArray *items in results ) {
			if( ![items conformsToProtocol:@protocol(NSFastEnumeration)] ) continue;
			for( NSMenuItem *item in items )
				if( [item isKindOfClass:[NSMenuItem class]] )
					[menu addItem:item];
		}

		if( [[[menu itemArray] lastObject] isSeparatorItem] )
			[menu removeItem:[[menu itemArray] lastObject]];
	}

	return menu;
}
@end

#pragma mark -

@implementation JVBuddy (JVBuddyObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[MVBuddyListController class]];
	NSScriptObjectSpecifier *container = [[MVBuddyListController sharedBuddyList] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"buddies" uniqueID:[self uniqueIdentifier]];
}
@end

#pragma mark -

@implementation MVBuddyListController (MVBuddyListControllerScripting)
- (MVChatConnection *) valueInBuddiesAtIndex:(NSUInteger) index {
	return _buddyOrder[index];
}

- (void) addInBuddies:(JVBuddy *) buddy {
	[NSException raise:NSOperationNotSupportedForKeyException format:@"Can't add a buddy."];
}

- (void) insertInBuddies:(JVBuddy *) buddy {
	[NSException raise:NSOperationNotSupportedForKeyException format:@"Can't insert a buddy."];
}

- (void) insertInBuddies:(JVBuddy *) buddy atIndex:(NSUInteger) index {
	[NSException raise:NSOperationNotSupportedForKeyException format:@"Can't insert a buddy."];
}

- (void) removeFromBuddiesAtIndex:(NSUInteger) index {
	JVBuddy *buddy = _buddyOrder[index];
	[_buddyList removeObject:buddy];
	[_onlineBuddies removeObject:buddy];
	[_buddyOrder removeObjectIdenticalTo:buddy];
	[self _manuallySortAndUpdate];
	[self save];
}

- (void) replaceInBuddies:(JVBuddy *) buddy atIndex:(NSUInteger) index {
	[NSException raise:NSOperationNotSupportedForKeyException format:@"Can't replace a buddy."];
}

- (JVBuddy *) valueInBuddiesWithUniqueID:(id) identifier {
	for( JVBuddy *buddy in _buddyList )
		if( [[buddy uniqueIdentifier] isEqualTo:identifier] )
			return buddy;

	return nil;
}

- (JVBuddy *) valueInBuddiesWithName:(NSString *) name {
	for( JVBuddy *buddy in _buddyList )
		if( [[buddy compositeName] isEqualToString:name] )
			return buddy;

	return nil;
}
@end
