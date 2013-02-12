#import "CQChatRoomInfoDisplayViewController.h"

#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"
#import "CQPreferencesTextViewCell.h"
#import "CQTextView.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

enum {
	CQChatRoomInfoModes,
	CQChatRoomInfoTopic,
	CQChatRoomInfoBans
};

enum {
	CQChatRoomModeRowOutsideMessages,
	CQChatRoomModeRowTopicByOperators,
	CQChatRoomModeRowModeratedChat,
	CQChatRoomModeRowInviteOnly,
	CQChatRoomModeRowPrivateChat,
	CQChatRoomModeRowSecretChat,
	CQChatRoomModeRowRoomMemberLimit,
	CQChatRoomModeRowPassword,
	CQChatRoomModeRowEditableModeCount
};

@implementation CQChatRoomInfoDisplayViewController
- (id) initWithRoom:(MVChatRoom *) room {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_room = [room retain];
	[_room refreshAttributes];

	NSMutableArray *items = [NSMutableArray array];
	[items addObject:NSLocalizedString(@"Modes", @"Modes segment title")];
	[items addObject:NSLocalizedString(@"Topic", @"Topic segment title")];
	[items addObject:NSLocalizedString(@"Bans", @"Bans segment title")];

	_segmentedControl = [[UISegmentedControl alloc] initWithItems:items];
	_segmentedControl.backgroundColor = [UIColor clearColor];
	_segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	_segmentedControl.selectedSegmentIndex = CQChatRoomInfoModes;

	[_segmentedControl addTarget:self action:@selector(_segmentSelected:) forControlEvents:UIControlEventValueChanged];

	return self;
}

- (void) dealloc {
	[_room release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *flexibleBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
	UIBarButtonItem *segmentedItem = [[UIBarButtonItem alloc] initWithCustomView:_segmentedControl];
	NSArray *items = [NSArray arrayWithObjects:segmentedItem, nil];
	[segmentedItem release];
	[flexibleBarButtonItem release];

	[self.navigationController setToolbarHidden:NO animated:[UIView areAnimationsEnabled]];
	[self setToolbarItems:items animated:[UIView areAnimationsEnabled]];

	[self _refreshBanList:nil];
	[self _segmentSelected:_segmentedControl];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_memberModeChanged:) name:MVChatRoomUserModeChangedNotification object:_room];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roomModesChanged:) name:MVChatRoomModesChangedNotification object:_room];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshBanList:) name:MVChatRoomBannedUsersSyncedNotification object:_room];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_topicChanged:) name:MVChatRoomTopicChangedNotification object:_room];

	_segmentedControl.frame = CGRectInset(self.navigationController.toolbar.bounds, 5, 5);
	_segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch (_segmentedControl.selectedSegmentIndex) {
	case CQChatRoomInfoBans:
		return _bans.count;
	case CQChatRoomInfoTopic:
		return 1;
	case CQChatRoomInfoModes:
		return CQChatRoomModeRowEditableModeCount;
	}

	return 0;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_segmentedControl.selectedSegmentIndex == CQChatRoomInfoTopic) {
		CQPreferencesTextViewCell *textViewCell = [CQPreferencesTextViewCell reusableTableViewCellInTableView:tableView];
		textViewCell.textView.text = [[[NSString alloc] initWithData:_room.topic encoding:_room.encoding] autorelease];
		textViewCell.textView.placeholder = NSLocalizedString(@"Enter Room Topic", @"Enter Room Topic");
		textViewCell.textView.delegate = self;
		textViewCell.textView.dataDetectorTypes = UIDataDetectorTypeNone;

		return textViewCell;
	}

	if (_segmentedControl.selectedSegmentIndex == CQChatRoomInfoBans) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:[NSString stringWithFormat:@"%d", _segmentedControl.selectedSegmentIndex]];
		cell.textLabel.text = [[_bans objectAtIndex:indexPath.row] description];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		return cell;
	}

	if (_segmentedControl.selectedSegmentIndex == CQChatRoomInfoModes) {
		NSUInteger localUserModes = (_room.connection.localUser ? [_room modesForMemberUser:_room.connection.localUser] : 0);
		BOOL canEditModes = (localUserModes > MVChatRoomMemberNoModes) || _room.connection.localUser.isServerOperator;

		NSString *title = nil;
		NSUInteger mode = 0;
		id attribute = nil;
		UIKeyboardType keyboardType = UIKeyboardTypeDefault;

		switch (indexPath.row) {
		case CQChatRoomModeRowOutsideMessages:
			title = NSLocalizedString(@"No outside messages", @"No outside messages cell label");
			mode = MVChatRoomNoOutsideMessagesMode;
			break;
		case CQChatRoomModeRowTopicByOperators:
			title = NSLocalizedString(@"Topic set by ops", @"Topic set by ops cell label");
			mode = MVChatRoomOperatorsOnlySetTopicMode;
			break;
		case CQChatRoomModeRowModeratedChat:
			title = NSLocalizedString(@"Moderated chat", @"Moderated chat cell label");
			mode = MVChatRoomNormalUsersSilencedMode;
			break;
		case CQChatRoomModeRowInviteOnly:
			title = NSLocalizedString(@"Invite-only", @"Invite-only cell label");
			mode = MVChatRoomInviteOnlyMode;
			break;
		case CQChatRoomModeRowPrivateChat:
			title = NSLocalizedString(@"Private chat", @"Private chat cell label");
			mode = MVChatRoomPrivateMode;
			break;
		case CQChatRoomModeRowSecretChat:
			title = NSLocalizedString(@"Secret chat", @"Secret chat cell label");
			mode = MVChatRoomSecretMode;
			break;
		case CQChatRoomModeRowRoomMemberLimit:
			title = NSLocalizedString(@"Member limit", @"Member limit cell label");
			attribute = [_room attributeForMode:MVChatRoomLimitNumberOfMembersMode];
			keyboardType = UIKeyboardTypeNumberPad;
			break;
		case CQChatRoomModeRowPassword:
			title = NSLocalizedString(@"Password", @"Password cell label");
			attribute = [_room attributeForMode:MVChatRoomPassphraseToJoinMode];
			break;
		}

		if (attribute || !mode) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
			cell.textLabel.text = title;
			cell.textField.text = [attribute stringValue];
			cell.textField.enabled = canEditModes;
			cell.textField.keyboardType = keyboardType;
			cell.textField.delegate = self;
			cell.textField.tag = indexPath.row;
			return cell;
		} else {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];
			cell.textLabel.text = title;
			cell.switchControl.on = (_room.modes & mode);
			cell.switchControl.enabled = canEditModes;
			cell.switchControlBlock = ^(UISwitch *switchControl) {
				if (switchControl.on) [_room setMode:mode];
				else [_room removeMode:mode];
			};
			return cell;
		}
	}

	// should never reach this point, but, don't crash if we do
	return [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:[NSString stringWithFormat:@"%d", _segmentedControl.selectedSegmentIndex]];
}

- (CGFloat) tableView:(UITableView *) tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_segmentedControl.selectedSegmentIndex == CQChatRoomInfoTopic)
		return [CQPreferencesTextViewCell height];
	return 42.;
}

#pragma mark -

- (void) textFieldDidEndEditing:(UITextField *) textField {
	if (textField.tag == CQChatRoomModeRowRoomMemberLimit)
		[_room setMode:MVChatRoomLimitNumberOfMembersMode withAttribute:textField.text];
	else if (textField.tag == CQChatRoomModeRowPassword)
		[_room setMode:MVChatRoomPassphraseToJoinMode withAttribute:textField.text];
}

#pragma mark -

- (BOOL) textView:(UITextView *) textView shouldChangeTextInRange:(NSRange) range replacementText:(NSString *) text {
	if ([text isEqualToString:@"\n"]) {
		[textView resignFirstResponder];

		NSString *currentTopic = [[[NSString alloc] initWithData:_room.topic encoding:_room.encoding] autorelease];;
		if (![currentTopic isEqualToString:textView.text])
			[_room changeTopic:textView.text];

		return NO;
	}

	return YES;
}

#pragma mark -

- (void) _segmentSelected:(id) sender {
	self.title = [_segmentedControl titleForSegmentAtIndex:_segmentedControl.selectedSegmentIndex];

	[self.tableView reloadData];

	self.tableView.scrollEnabled = (_segmentedControl.selectedSegmentIndex != CQChatRoomInfoTopic);
}

#pragma mark -

- (void) _memberModeChanged:(NSNotification *) notification {
	[self _maybeReloadModes];
	[self _maybeReloadTopic];
	[self _maybeReloadBans];
}

- (void) _roomModesChanged:(NSNotification *) notification {
	[self _maybeReloadModes];
	[self _maybeReloadTopic];
}

- (void) _refreshBanList:(NSNotification *) notification {
	_bans = [[[_room.bannedUsers allObjects] sortedArrayUsingSelector:@selector(compareByAddress:)] copy];

	// reload list, maybe. And get insert/remove nicely.
}

- (void) _topicChanged:(NSNotification *) notification {
	[self _maybeReloadTopic];
}

#pragma mark -

- (void) _maybeReloadModes {
	if (_segmentedControl.selectedSegmentIndex != CQChatRoomInfoModes)
		return;

	[self.tableView reloadData];
}

- (void) _maybeReloadTopic {
	if (_segmentedControl.selectedSegmentIndex != CQChatRoomInfoTopic)
		return;

	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]  withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];
}

- (void) _maybeReloadBans {
	if (_segmentedControl.selectedSegmentIndex != CQChatRoomInfoBans)
		return;

	[self _refreshBanList:nil];

	// check right bar button item
}
@end
