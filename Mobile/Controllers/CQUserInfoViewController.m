//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQUserInfoViewController.h"
#import "CQPreferencesTextCell.h"
#import "CQUserInfoRoomListViewController.h"

#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatConnection.h>

#import "NSDateAdditions.h"

@implementation CQUserInfoViewController
- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	UIBarButtonItem *reloadItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshInformation:)];
	reloadItem.accessibilityLabel = NSLocalizedString(@"Refresh information.", @"Voiceover refresh information label");

	self.navigationItem.rightBarButtonItem = reloadItem;

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];


}

#pragma mark -

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	_updateTimesTimer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(_updateTimes) userInfo:nil repeats:YES];
	_updateInfoTimer = [NSTimer scheduledTimerWithTimeInterval:20. target:self selector:@selector(_updateInfo) userInfo:nil repeats:YES];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[_updateTimesTimer invalidate];
	_updateTimesTimer = nil;

	[_updateInfoTimer invalidate];
	_updateInfoTimer = nil;
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 4;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch (section) {
		case 0: return 2;
		case 1: return 3;
		case 2: return 2;
		case 3: return 2;
	}

	return 0;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue2 inTableView:tableView];
	cell.accessoryType = UITableViewCellAccessoryNone;

	NSInteger section = indexPath.section;
	NSInteger row = indexPath.row;

	NSString *notAvailableString = NSLocalizedString(@"n/a", "Not Applicable or Not Available");

	if (section == 0) {
		if (row == 0) { // Real Name
			cell.textLabel.text = [NSLocalizedString(@"real name", "Real Name user info label") lowercaseString];
			if (_user.realName.length) {
				cell.detailTextLabel.text = _user.realName;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Real Name: %@", @"Voiceover real name label"), _user.realName];
			} else {
				cell.detailTextLabel.text = notAvailableString;
				cell.accessibilityLabel = NSLocalizedString(@"Real name not available.", @"Voiceover real name not available label");
			}
		} else if (row == 1) { // Away Info
			cell.textLabel.text = NSLocalizedString(@"away info", "Away Info user info label");

			NSString *value = [[NSString alloc] initWithData:_user.awayStatusMessage encoding:_user.connection.encoding];
			if (value.length) {
				cell.detailTextLabel.text = value;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Away information: %@", @"Voiceover away information label"), value];
			} else {
				cell.detailTextLabel.text = notAvailableString;
				cell.accessibilityLabel = NSLocalizedString(@"Away information not available.", @"Voiceover away information not available");
			}
		}
	} else if (section == 1) {
		 if (row == 0) { // Class
			cell.textLabel.text = NSLocalizedString(@"Class", "Class user info label");

			NSString *value = nil;
			if (_user.status == MVChatUserOfflineStatus)
				value = notAvailableString;
			else if (_user.identified)
				value = NSLocalizedString(@"Registered User", "Registered user class");
			else if (_user.serverOperator)
				value = NSLocalizedString(@"Server Operator", "Server operator class");
			else value = NSLocalizedString(@"Normal User", "Normal user class");

			cell.detailTextLabel.text = value;

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Class: %@", @"Voiceover class label"), value];
		} else if (row == 1) { // Username
			cell.textLabel.text = NSLocalizedString(@"username", "Username user info label");

			if (_user.username.length) {
				cell.detailTextLabel.text = _user.username;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Username: %@", @"Voiceover username label"), _user.username];
			} else {
				cell.detailTextLabel.text = notAvailableString;
				cell.accessibilityLabel = NSLocalizedString(@"Username not available.", @"Voiceover username not available label");
			}

			cell.detailTextLabel.text = (_user.username.length ? _user.username : notAvailableString);
		} else if (row == 2) { // Hostname
			cell.textLabel.text = NSLocalizedString(@"hostname", "Hostname user info label");

			if (_user.address.length) {
				cell.detailTextLabel.text = _user.address;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Hostname: %@", @"Voiceover hostname label"), _user.address];
			} else {
				cell.detailTextLabel.text = notAvailableString;
				cell.accessibilityLabel = NSLocalizedString(@"Hostname not available.", @"Voiceover hostname not available label");
			}
		}
	} else if (section == 2) {
		if (row == 0) { // Server
			cell.textLabel.text = NSLocalizedString(@"server", "Server user info label");

			if (_user.serverAddress.length) {
				cell.detailTextLabel.text = _user.serverAddress;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Server: %@", @"Voiceover server label"), _user.serverAddress];
			} else {
				cell.detailTextLabel.text = notAvailableString;
				cell.accessibilityLabel = NSLocalizedString(@"Server not available.", @"Voiceover server not available label");
			}
		} else if (row == 1) { // Rooms
			cell.textLabel.text = NSLocalizedString(@"rooms", "Rooms user info label");

			NSArray *rooms = [_user attributeForKey:MVChatUserKnownRoomsAttribute];
			if (rooms) {
				if (rooms.count) {
					NSString *separator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
					NSString *roomsString = [rooms componentsJoinedByString:[NSString stringWithFormat:@"%@ ", separator]];
					cell.detailTextLabel.text = roomsString;
					cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Rooms: %@", @"Voiceover rooms label"), roomsString];
				} else {
					cell.detailTextLabel.text = NSLocalizedString(@"None", @"None label");
					cell.accessibilityLabel = NSLocalizedString(@"Rooms: None", @"Voiceover rooms none label");
				}

				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			} else {
				cell.detailTextLabel.text = notAvailableString;
				cell.accessibilityLabel = NSLocalizedString(@"Rooms not available.", @"Voiceover rooms not available label");
			}
		}
	} else if (section == 3) {
		if (row == 0) { // Connected
			cell.textLabel.text = NSLocalizedString(@"connected", "Connected user info label");

			if (_user.status != MVChatUserOfflineStatus && _user.dateConnected) {
				cell.detailTextLabel.text = humanReadableTimeInterval([_user.dateConnected timeIntervalSinceNow], YES);
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Connected: %@", @"Voiceover Connected label"), cell.detailTextLabel.text];
			} else {
				cell.detailTextLabel.text = NSLocalizedString(@"Offline", "Offline label");
				cell.accessibilityLabel = NSLocalizedString(@"User offline", @"Voiceover user offline label");
			}

			cell.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
		} else if (row == 1) { // Idle Time
			cell.textLabel.text = NSLocalizedString(@"idle time", "Idle Time user info label");

			if (_user.status != MVChatUserOfflineStatus && _user.dateConnected) {
				cell.detailTextLabel.text = humanReadableTimeInterval([NSDate timeIntervalSinceReferenceDate] - _idleTimeStart, YES);
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Connected: %@", @"Voiceover Connected label"), cell.detailTextLabel.text];
			} else {
				cell.detailTextLabel.text = NSLocalizedString(@"Offline", "Offline label");
				cell.accessibilityLabel = NSLocalizedString(@"User offline.", @"Voiceover user offline label");
			}

			cell.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
		}
	}

	return cell;
}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	return (action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	if (action != @selector(copy:))
		return;

	UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
	if (!selectedCell)
		return;

	[UIPasteboard generalPasteboard].string = selectedCell.detailTextLabel.text;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 2 && indexPath.row == 1) {
		[self showJoinedRooms:nil];
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark -

- (IBAction) showJoinedRooms:(id) sender {
	CQUserInfoRoomListViewController *roomsController = [[CQUserInfoRoomListViewController alloc] init];
	roomsController.rooms = [_user attributeForKey:MVChatUserKnownRoomsAttribute];
	roomsController.connection = _user.connection;

	[self.navigationController pushViewController:roomsController animated:YES];
}

- (IBAction) refreshInformation:(id) sender {
	[_user refreshInformation];
}

#pragma mark -

- (void) _informationUpdated:(NSNotification *) notification {
	self.navigationItem.title = _user.nickname;

	_idleTimeStart = ([NSDate timeIntervalSinceReferenceDate] - _user.idleTime);

	if ([self isViewLoaded])
		[self.tableView reloadData];
}

- (void) _idleTimeUpdated:(NSNotification *) notification {
	_idleTimeStart = ([NSDate timeIntervalSinceReferenceDate] - _user.idleTime);
}

- (void) _updateInfo {
	if (!_user.serverOperator)
		[_user refreshInformation];
}

- (void) _updateTimes {
	BOOL online = (_user.status != MVChatUserOfflineStatus && _user.dateConnected);

	// Connected time
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:3];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	if (cell) cell.detailTextLabel.text = (online ? humanReadableTimeInterval([_user.dateConnected timeIntervalSinceNow], YES) : NSLocalizedString(@"Offline", "Offline label"));
	[cell layoutSubviews];

	// Idle time
	indexPath = [NSIndexPath indexPathForRow:1 inSection:3];
	cell = [self.tableView cellForRowAtIndexPath:indexPath];
	if (cell) cell.detailTextLabel.text = (online ? humanReadableTimeInterval([NSDate timeIntervalSinceReferenceDate] - _idleTimeStart, YES) : NSLocalizedString(@"Offline", "Offline label"));
	[cell layoutSubviews];
}

#pragma mark -

- (void) setUser:(MVChatUser *) user {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserAttributeUpdatedNotification object:_user];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserInformationUpdatedNotification object:_user];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserNicknameChangedNotification object:_user];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserStatusChangedNotification object:_user];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserAwayStatusMessageChangedNotification object:_user];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserIdleTimeUpdatedNotification object:_user];

	_user = user;

	_idleTimeStart = ([NSDate timeIntervalSinceReferenceDate] - _user.idleTime);

	[_user refreshInformation];

	if (_user) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_informationUpdated:) name:MVChatUserAttributeUpdatedNotification object:_user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_informationUpdated:) name:MVChatUserInformationUpdatedNotification object:_user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_informationUpdated:) name:MVChatUserNicknameChangedNotification object:_user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_informationUpdated:) name:MVChatUserStatusChangedNotification object:_user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_informationUpdated:) name:MVChatUserAwayStatusMessageChangedNotification object:_user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_idleTimeUpdated:) name:MVChatUserIdleTimeUpdatedNotification object:_user];
	}

	self.navigationItem.title = _user.nickname;

	[self.tableView reloadData];
}
@end
