#import "CQChatRoomInfoDisplayViewController.h"

#import "CQChatUserListViewController.h"

#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"
#import "CQPreferencesTextViewCell.h"
#import "CQTextView.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

#import "NSNotificationAdditions.h"

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

#define CQDefaultRowHeight 42.

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoDisplayViewController () <UITextFieldDelegate, UITextViewDelegate, CQChatUserListViewDelegate>
@end

@implementation CQChatRoomInfoDisplayViewController {
@private
	MVChatRoom *_room;
	NSMutableArray <MVChatUser *> *_bans;
	CQChatRoomInfo _infoType;
}

- (instancetype) initWithStyle:(UITableViewStyle) style {
	NSAssert(NO, @"use -[CQChatRoomInfoDisplayViewController initWithRoom:showingInfoType:] instead");
	return nil;
}

- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil {
	NSAssert(NO, @"use -[CQChatRoomInfoDisplayViewController initWithRoom:showingInfoType:] instead");
	return nil;
}

- (instancetype) initWithCoder:(NSCoder *) aDecoder {
	NSAssert(NO, @"use -[CQChatRoomInfoDisplayViewController initWithRoom:showingInfoType:] instead");
	return nil;
}

- (instancetype) initWithRoom:(MVChatRoom *) room showingInfoType:(CQChatRoomInfo) infoType {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_room = room;

	if (infoType == CQChatRoomInfoModes)
		[_room.connection sendRawMessageWithFormat:@"MODE %@", _room.name];
	else if (infoType == CQChatRoomInfoBans)
		[_room.connection sendRawMessageWithFormat:@"MODE %@ b", _room.name];

	_infoType = infoType;

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.dataSource = self;
	self.tableView.delegate = self;

	[self _updateRoomInfo];
	[self _refreshBanList];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_memberModeChanged:) name:MVChatRoomUserModeChangedNotification object:_room];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_roomModesChanged:) name:MVChatRoomModesChangedNotification object:_room];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshBanList:) name:MVChatRoomBannedUsersSyncedNotification object:_room];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_topicChanged:) name:MVChatRoomTopicChangedNotification object:_room];
}

#pragma mark -

- (BOOL) chatUserListViewController:(CQChatUserListViewController *) chatUserListViewController shouldPresentInformationForUser:(MVChatUser *) user {
	return NO;
}

- (void) chatUserListViewController:(CQChatUserListViewController *) chatUserListViewController didSelectUser:(MVChatUser *) user {
	[chatUserListViewController.navigationController popViewControllerAnimated:[UIView areAnimationsEnabled]];

	NSUInteger indexToAdd = [_bans indexOfObject:user inSortedRange:NSMakeRange(0, _bans.count) options:NSBinarySearchingInsertionIndex usingComparator:^(id one, id two) {
		return [one compareByAddress:two];
	}];

	[_bans insertObject:user atIndex:indexToAdd];

	[self.tableView beginUpdates];
	[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indexToAdd inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
	[self.tableView endUpdates];

	[_room addBanForUser:user];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[super setEditing:editing animated:animated];

	if (_infoType != CQChatRoomInfoBans)
		return;

	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch (_infoType) {
	case CQChatRoomInfoBans:
		if (self.editing)
			return _bans.count + 1;
		return _bans.count;
	case CQChatRoomInfoTopic:
		return 1;
	case CQChatRoomInfoModes:
		return CQChatRoomModeRowEditableModeCount;
	}

	return 0;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_infoType == CQChatRoomInfoTopic) {
		CQPreferencesTextViewCell *textViewCell = [CQPreferencesTextViewCell reusableTableViewCellInTableView:tableView];
		textViewCell.textView.text = [[NSString alloc] initWithData:_room.topic encoding:_room.encoding];
		textViewCell.textView.placeholder = NSLocalizedString(@"Enter Room Topic", @"Enter Room Topic");
		textViewCell.textView.delegate = self;
#if !SYSTEM(TV)
		textViewCell.textView.dataDetectorTypes = UIDataDetectorTypeNone;
#endif

		return textViewCell;
	}

	if (_infoType == CQChatRoomInfoBans) {
		if ((NSUInteger)indexPath.row == _bans.count) {
			UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:@"Add Ban Cell"];
			cell.textLabel.text = NSLocalizedString(@"Add Ban", @"Add Ban cell item");
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			return cell;
		}

		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:@"Ban Cell"];
		cell.textLabel.text = [_bans[indexPath.row] description];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		return cell;
	}

	if (_infoType == CQChatRoomInfoModes) {
		NSUInteger localUserModes = (_room.connection.localUser ? [_room modesForMemberUser:_room.connection.localUser] : 0);
		BOOL canEditModes = (localUserModes > MVChatRoomMemberVoicedMode) || _room.connection.localUser.isServerOperator;

		NSString *title = nil;
		MVChatRoomMode mode = 0;
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
			cell.textField.text = [attribute description];
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

			__weak __typeof__((_room)) weakRoom = _room;
			cell.switchControlBlock = ^(UISwitch *switchControl) {
				__strong __typeof__((weakRoom)) strongRoom = weakRoom;
				if (switchControl.on) [strongRoom setMode:mode];
				else [strongRoom removeMode:mode];
			};
			return cell;
		}
	}

	// should never reach this point, but, don't crash if we do
	return [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:[NSString stringWithFormat:@"%zd", _infoType]];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_infoType != CQChatRoomInfoBans)
		return UITableViewCellEditingStyleNone;
	if ((NSUInteger)indexPath.row == _bans.count)
		return UITableViewCellEditingStyleInsert;
	return UITableViewCellEditingStyleDelete;
}

#pragma mark -

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_room removeBanForUser:_bans[indexPath.row]];

		[_bans removeObjectAtIndex:indexPath.row];

		[tableView beginUpdates];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
		[tableView endUpdates];
	} else [self _presentUserList];
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!self.editing)
		return;

	if ((NSUInteger)indexPath.row != _bans.count)
		return;

	if (_infoType != CQChatRoomInfoBans)
		return;

	[self _presentUserList];
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

		NSString *currentTopic = [[NSString alloc] initWithData:_room.topic encoding:_room.encoding];;
		if (![currentTopic isEqualToString:textView.text]) {
			NSAttributedString *attributedText = textView.attributedText;
			if (!attributedText) attributedText = [[NSAttributedString alloc] initWithString:textView.text attributes:@{ NSFontAttributeName: textView.font }];
			[_room changeTopic:attributedText];
		}

		return NO;
	}

	return YES;
}

#pragma mark -

- (void) _presentUserList {
	CQChatUserListViewController *chatUserListViewController = [[CQChatUserListViewController alloc] init];
	chatUserListViewController.chatUserDelegate = self;
	chatUserListViewController.listMode = CQChatUserListModeBan;
	chatUserListViewController.room = _room;

	NSMutableSet *users = [_room.memberUsers mutableCopy];
	[users minusSet:_room.bannedUsers];

	[chatUserListViewController setRoomUsers:users.allObjects];

	[self.navigationController pushViewController:chatUserListViewController animated:[UIView areAnimationsEnabled]];
}

- (void) _updateRoomInfo {
	self.tableView.scrollEnabled = (_infoType != CQChatRoomInfoTopic);

	if (_infoType == CQChatRoomInfoBans) {
		self.title = NSLocalizedString(@"Bans", @"Bans segment title");

		NSUInteger localUserModes = (_room.connection.localUser ? [_room modesForMemberUser:_room.connection.localUser] : 0);
		BOOL canEditModes = (localUserModes > MVChatRoomMemberVoicedMode) || _room.connection.localUser.isServerOperator;

		if (canEditModes) {
			[self.navigationItem setRightBarButtonItem:self.editButtonItem animated:[UIView areAnimationsEnabled]];

			self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Edit ban list.", @"Voiceover edit ban list label");
		}
	} else [self.navigationItem setRightBarButtonItem:nil animated:[UIView areAnimationsEnabled]];

	if (_infoType == CQChatRoomInfoTopic) {
		self.title = NSLocalizedString(@"Topic", @"Topic segment title");
		self.tableView.rowHeight = [CQPreferencesTextViewCell height];
	} else {
		if (_infoType == CQChatRoomInfoModes)
			self.title = NSLocalizedString(@"Modes", @"Modes segment title");
		else if (_infoType == CQChatRoomInfoBans)
			self.title = NSLocalizedString(@"Bans", @"Bans segment title");
		self.tableView.rowHeight = CQDefaultRowHeight;
	}

	[self.tableView reloadData];
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
	[self _refreshBanList];
}

- (void) _refreshBanList {
	_bans = [[[_room.bannedUsers allObjects] sortedArrayUsingSelector:@selector(compareByAddress:)] mutableCopy];
}

- (void) _topicChanged:(NSNotification *) notification {
	[self _maybeReloadTopic];
}

#pragma mark -

- (void) _maybeReloadModes {
	if (_infoType != CQChatRoomInfoModes)
		return;

	[self.tableView reloadData];
}

- (void) _maybeReloadTopic {
	if (_infoType != CQChatRoomInfoTopic)
		return;

	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ] withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];
}

- (void) _maybeReloadBans {
	if (_infoType != CQChatRoomInfoBans)
		return;

	[self _refreshBanList];

	// check right bar button item
}
@end

NS_ASSUME_NONNULL_END
