#import "CQChatUserListViewController.h"

#import "CQChatController.h"
#import "CQColloquyApplication.h"
#import "CQDirectChatController.h"
#import "CQWhoisNavController.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatConnection.h>

static NSString *membersSingleCountFormat;
static NSString *membersFilteredCountFormat;

@implementation CQChatUserListViewController
+ (void) initialize {
	membersSingleCountFormat = [NSLocalizedString(@"Members (%u)", @"Members with single count view title") retain];
	membersFilteredCountFormat = [NSLocalizedString(@"Members (%u of %u)", @"Members with filtered count view title") retain];
}

- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	_users = [[NSMutableArray alloc] init];
	_matchedUsers = [[NSMutableArray alloc] init];

	return self;
}

- (void) dealloc {
	[_users release];
	[_matchedUsers release];
	[_currentSearchString release];
	[_room release];
	[_searchBar release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
	_searchBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
	_searchBar.placeholder = NSLocalizedString(@"Search", @"Search placeholder text");
	_searchBar.tintColor = [UIColor colorWithRed:(190. / 255.) green:(199. / 255.) blue:(205. / 255.) alpha:1.];
	_searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	_searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	_searchBar.delegate = self;

	[_searchBar sizeToFit];

	self.tableView.tableHeaderView = _searchBar;
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];

	// Workaround a bug were the table view is left in a state
	// were it thinks a keyboard is showing.
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark -

@synthesize users = _users;

- (void) setUsers:(NSArray *) users {
	[_users setArray:users];
	[_matchedUsers setArray:users];

	self.title = [NSString stringWithFormat:membersSingleCountFormat, users.count];

	[self.tableView reloadData];
}

@synthesize room = _room;

- (void) setRoom:(MVChatRoom *) room {
	id old = _room;
	_room = [room retain];
	[old release];

	[self.tableView reloadData];
}

#pragma mark -

- (NSUInteger) _indexForInsertedMatchUser:(MVChatUser *) user withOriginalIndex:(NSUInteger) index {
	NSInteger matchesIndex = NSNotFound;
	for (NSInteger i = (index - 1); i >= 0; --i) {
		MVChatUser *currentUser = [_users objectAtIndex:i];
		matchesIndex = [_matchedUsers indexOfObjectIdenticalTo:currentUser];
		if (matchesIndex != NSNotFound)
			break;
	}

	if (matchesIndex == NSNotFound)
		matchesIndex = -1;

	return ++matchesIndex;
}

- (NSUInteger) _indexForRemovedMatchUser:(MVChatUser *) user {
	return [_matchedUsers indexOfObjectIdenticalTo:user];
}

- (void) _insertUser:(MVChatUser *) user atIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
	NSParameterAssert(user != nil);
	NSParameterAssert(index <= _users.count);

	[_users insertObject:user atIndex:index];

	if (!_currentSearchString.length || [user.displayName hasCaseInsensitiveSubstring:_currentSearchString]) {
		NSInteger matchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:index];

		[_matchedUsers insertObject:user atIndex:matchesIndex];

		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
	}

	if (_users.count == _matchedUsers.count)
		self.title = [NSString stringWithFormat:membersSingleCountFormat, _users.count];
	else self.title = [NSString stringWithFormat:membersFilteredCountFormat, _matchedUsers.count, _users.count];
}

- (void) _removeUserAtIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
	NSParameterAssert(index <= _users.count);

	MVChatUser *user = [[_users objectAtIndex:index] retain];

	[_users removeObjectAtIndex:index];

	NSUInteger matchesIndex = [self _indexForRemovedMatchUser:user];
	if (matchesIndex != NSNotFound) {
		[_matchedUsers removeObjectAtIndex:matchesIndex];

		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
		[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
	}

	if (_users.count == _matchedUsers.count)
		self.title = [NSString stringWithFormat:membersSingleCountFormat, _users.count];
	else self.title = [NSString stringWithFormat:membersFilteredCountFormat, _matchedUsers.count, _users.count];

	[user release];
}

#pragma mark -

- (void) beginUpdates {
	[self.tableView beginUpdates];
}

- (void) endUpdates {
	[self.tableView endUpdates];
}

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index {
	BOOL searchBarFocused = [_searchBar isFirstResponder];
	[self _insertUser:user atIndex:index withAnimation:UITableViewRowAnimationLeft];

	if (searchBarFocused)
		[_searchBar becomeFirstResponder];
}

- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	if (oldIndex == newIndex)
		return;

	MVChatUser *user = [[_users objectAtIndex:oldIndex] retain];

	BOOL searchBarFocused = [_searchBar isFirstResponder];

	NSInteger oldMatchesIndex = [self _indexForRemovedMatchUser:user];
	NSInteger newMatchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:newIndex];

	if (newMatchesIndex > oldMatchesIndex)
		--newMatchesIndex;

	[self.tableView beginUpdates];

	if (oldMatchesIndex == newMatchesIndex) {
		[self _removeUserAtIndex:oldIndex withAnimation:UITableViewRowAnimationFade];
		[self _insertUser:user atIndex:newIndex withAnimation:UITableViewRowAnimationFade];
	} else {
		[self _removeUserAtIndex:oldIndex withAnimation:(newIndex > oldIndex ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop)];
		[self _insertUser:user atIndex:newIndex withAnimation:(newIndex > oldIndex ? UITableViewRowAnimationTop : UITableViewRowAnimationBottom)];
	}

	[self.tableView endUpdates];

	if (searchBarFocused)
		[_searchBar becomeFirstResponder];

	[user release];
}

- (void) removeUserAtIndex:(NSUInteger) index {
	BOOL searchBarFocused = [_searchBar isFirstResponder];
	[self _removeUserAtIndex:index withAnimation:UITableViewRowAnimationRight];
	if (searchBarFocused)
		[_searchBar becomeFirstResponder];
}

- (void) updateUserAtIndex:(NSUInteger) index {
	NSParameterAssert(index <= _users.count);

	MVChatUser *user = [_users objectAtIndex:index];
	NSUInteger matchesIndex = [_matchedUsers indexOfObjectIdenticalTo:user];
	if (matchesIndex == NSNotFound)
		return;

	BOOL searchBarFocused = [_searchBar isFirstResponder];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:matchesIndex inSection:0] withAnimation:UITableViewRowAnimationFade];

	if (searchBarFocused)
		[_searchBar becomeFirstResponder];
}

#pragma mark -

- (void) searchBar:(UISearchBar *) searchBar textDidChange:(NSString *) searchString {
	if ([searchString isEqualToString:_currentSearchString])
		return;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(filterUsersWithSearchString:) object:nil];

	if (searchString.length)
		[self performSelector:@selector(filterUsersWithSearchString:) withObject:searchString afterDelay:(1. / 3.)];
	else [self filterUsersWithSearchString:searchString];
}

#pragma mark -

- (void) filterUsersWithSearchString:(NSString *) searchString {
	NSArray *previousUsersArray = [_matchedUsers copy];
	NSSet *previousUsersSet = [[NSSet alloc] initWithArray:_matchedUsers];
	NSMutableSet *addedUsers = [[NSMutableSet alloc] init];

	[_matchedUsers removeAllObjects];

	NSArray *searchArray = (_currentSearchString && [searchString hasPrefix:_currentSearchString] ? previousUsersArray : _users);
	for (MVChatUser *user in searchArray) {
		if (!searchString.length || [user.displayName hasCaseInsensitiveSubstring:searchString]) {
			[_matchedUsers addObject:user];
			[addedUsers addObject:user];
		}
	}

	[self.tableView beginUpdates];

	NSUInteger index = 0;
	NSMutableArray *indexPaths = [[NSMutableArray alloc] init];

	for (MVChatUser *user in previousUsersArray) {
		if (![addedUsers containsObject:user])
			[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
		++index;
	}

	[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
	[indexPaths release];

	index = 0;
	indexPaths = [[NSMutableArray alloc] init];

	for (MVChatUser *user in _matchedUsers) {
		if (![previousUsersSet containsObject:user])
			[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
		++index;
	}

	[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
	[indexPaths release];

	[self.tableView endUpdates];

	[addedUsers release];
	[previousUsersSet release];
	[previousUsersArray release];

	id old = _currentSearchString;
	_currentSearchString = [searchString copy];
	[old release];

	if (_users.count == _matchedUsers.count)
		self.title = [NSString stringWithFormat:membersSingleCountFormat, _users.count];
	else self.title = [NSString stringWithFormat:membersFilteredCountFormat, _matchedUsers.count, _users.count];

	[_searchBar becomeFirstResponder];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return _matchedUsers.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatUser *user = [_matchedUsers objectAtIndex:indexPath.row];

	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
	cell.text = user.displayName;

	if (_room) {
		unsigned long modes = [_room modesForMemberUser:user];

		if (user.serverOperator)
			cell.image = [UIImage imageNamed:@"userSuperOperator.png"];
		else if (modes & MVChatRoomMemberFounderMode)
			cell.image = [UIImage imageNamed:@"userFounder.png"];
		else if (modes & MVChatRoomMemberAdministratorMode)
			cell.image = [UIImage imageNamed:@"userAdmin.png"];
		else if (modes & MVChatRoomMemberOperatorMode)
			cell.image = [UIImage imageNamed:@"userOperator.png"];
		else if (modes & MVChatRoomMemberHalfOperatorMode)
			cell.image = [UIImage imageNamed:@"userHalfOperator.png"];
		else if (modes & MVChatRoomMemberVoicedMode)
			cell.image = [UIImage imageNamed:@"userVoice.png"];
		else cell.image = [UIImage imageNamed:@"userNormal.png"];
	} else {
		cell.image = [UIImage imageNamed:@"userNormal.png"];
	}

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	[self.tableView endEditing:YES];

	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	NSUInteger localUserModes = (_room.connection.localUser ? [_room modesForMemberUser:_room.connection.localUser] : 0);
	BOOL showOperatorActions = (localUserModes & (MVChatRoomMemberHalfOperatorMode | MVChatRoomMemberOperatorMode | MVChatRoomMemberAdministratorMode | MVChatRoomMemberFounderMode));

	[sheet addButtonWithTitle:NSLocalizedString(@"Send Message", @"Send Message button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"User Information", @"User Information button title")];
	if (showOperatorActions)
		[sheet addButtonWithTitle:NSLocalizedString(@"Operator Actions...", @"Operator Actions button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	sheet.cancelButtonIndex = (showOperatorActions ? 3 : 2);

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	NSDictionary *context = (NSDictionary *)actionSheet.tag;

	if (buttonIndex == actionSheet.cancelButtonIndex) {
		[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

		[context release]; // Retained earlier
		return;
	}

	MVChatUser *user = [_matchedUsers objectAtIndex:selectedIndexPath.row];

	if (!context) {
		if (buttonIndex == 0) {
			[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

			CQDirectChatController *chatController = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
			[[CQChatController defaultController] showChatController:chatController animated:YES];
		} else if (buttonIndex == 1) {
			[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

			CQWhoisNavController *whoisController = [[CQWhoisNavController alloc] init];
			whoisController.user = user;

			[self presentModalViewController:whoisController animated:YES];

			[whoisController release];
		} else if (buttonIndex == 2) {
			NSSet *features = _room.connection.supportedFeatures;

			NSUInteger localUserModes = (_room.connection.localUser ? [_room modesForMemberUser:_room.connection.localUser] : 0);
			BOOL localUserIsHalfOperator = (localUserModes & MVChatRoomMemberHalfOperatorMode);
			BOOL localUserIsOperator = (localUserModes & MVChatRoomMemberOperatorMode);
			BOOL localUserIsAdministrator = (localUserModes & MVChatRoomMemberAdministratorMode);
			BOOL localUserIsFounder = (localUserModes & MVChatRoomMemberFounderMode);

			NSUInteger selectedUserModes = (user ? [_room modesForMemberUser:user] : 0);
			BOOL selectedUserIsQuieted = (selectedUserModes & MVChatRoomMemberQuietedMode);
			BOOL selectedUserHasVoice = (selectedUserModes & MVChatRoomMemberVoicedMode);
			BOOL selectedUserIsHalfOperator = (selectedUserModes & MVChatRoomMemberHalfOperatorMode);
			BOOL selectedUserIsOperator = (selectedUserModes & MVChatRoomMemberOperatorMode);
			BOOL selectedUserIsAdministrator = (selectedUserModes & MVChatRoomMemberAdministratorMode);
			BOOL selectedUserIsFounder = (selectedUserModes & MVChatRoomMemberFounderMode);

			NSMutableDictionary *context = [[NSMutableDictionary alloc] init]; // Released later in actionSheet:clickedButtonAtIndex: 

			UIActionSheet *operatorSheet = [[UIActionSheet alloc] init];
			operatorSheet.delegate = self;
			operatorSheet.tag = (NSUInteger)context;

			if (localUserIsHalfOperator || localUserIsOperator || localUserIsAdministrator || localUserIsFounder) {
				[operatorSheet addButtonWithTitle:NSLocalizedString(@"Kick from Room", @"Kick from Room button title")];
				[operatorSheet addButtonWithTitle:NSLocalizedString(@"Ban from Room", @"Ban From Room button title")];

				[context setObject:@"kick" forKey:[NSNumber numberWithUnsignedInteger:0]];
				[context setObject:@"ban" forKey:[NSNumber numberWithUnsignedInteger:1]];
			}

			if (localUserIsFounder && [features containsObject:MVChatRoomMemberFounderFeature]) {
				if (selectedUserIsFounder) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Founder", @"Demote from Founder button title")];
				else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Founder", @"Promote to Founder button title")];

				[context setObject:[NSNumber numberWithUnsignedInteger:(MVChatRoomMemberFounderMode | (selectedUserIsFounder ? (1 << 16) : 0))] forKey:[NSNumber numberWithUnsignedInteger:(operatorSheet.numberOfButtons - 1)]];
			}

			if ((localUserIsAdministrator || localUserIsFounder) && ((localUserIsAdministrator && !selectedUserIsFounder) || localUserIsFounder) && [features containsObject:MVChatRoomMemberAdministratorFeature]) {
				if (selectedUserIsAdministrator) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Admin", @"Demote from Admin button title")];
				else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Admin", @"Promote to Admin button title")];

				[context setObject:[NSNumber numberWithUnsignedInteger:(MVChatRoomMemberAdministratorMode | (selectedUserIsAdministrator ? (1 << 16) : 0))] forKey:[NSNumber numberWithUnsignedInteger:(operatorSheet.numberOfButtons - 1)]];
			}

			if ((localUserIsOperator || localUserIsAdministrator || localUserIsFounder) && ((localUserIsOperator && !(selectedUserIsAdministrator || selectedUserIsFounder)) || (localUserIsAdministrator && !selectedUserIsFounder) || localUserIsFounder)) {
				if ([features containsObject:MVChatRoomMemberOperatorFeature]) {
					if (selectedUserIsOperator) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Deomote from Operator", @"Demote from Operator button title")];
					else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Operator", @"Promote to Operator button title")];

					[context setObject:[NSNumber numberWithUnsignedInteger:(MVChatRoomMemberOperatorMode | (selectedUserIsOperator ? (1 << 16) : 0))] forKey:[NSNumber numberWithUnsignedInteger:(operatorSheet.numberOfButtons - 1)]];
				}

				if ([features containsObject:MVChatRoomMemberHalfOperatorFeature]) {
					if (selectedUserIsHalfOperator) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Demote from Half-Operator", @"Demote From Half-Operator button title")];
					else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Promote to Half-Operator", @"Promote to Half-Operator button title")];

					[context setObject:[NSNumber numberWithUnsignedInteger:(MVChatRoomMemberHalfOperatorMode | (selectedUserIsHalfOperator ? (1 << 16) : 0))] forKey:[NSNumber numberWithUnsignedInteger:(operatorSheet.numberOfButtons - 1)]];
				}
			}

			if (localUserIsHalfOperator || localUserIsOperator || localUserIsAdministrator || localUserIsFounder) {
				if ([features containsObject:MVChatRoomMemberVoicedFeature] && ((localUserIsHalfOperator && !(selectedUserIsOperator || selectedUserIsAdministrator || selectedUserIsFounder)) || (localUserIsOperator && !(selectedUserIsAdministrator || selectedUserIsFounder)) || (localUserIsAdministrator && !selectedUserIsFounder) || localUserIsFounder)) {
					if (selectedUserHasVoice) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Remove Voice", @"Remove Voice button title")];
					else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Grant Voice", @"Grant Voice button title")];

					[context setObject:[NSNumber numberWithUnsignedInteger:(MVChatRoomMemberVoicedMode | (selectedUserHasVoice ? (1 << 16) : 0))] forKey:[NSNumber numberWithUnsignedInteger:(operatorSheet.numberOfButtons - 1)]];
				}

				if ([features containsObject:MVChatRoomMemberQuietedFeature]) {
					if (selectedUserIsQuieted) [operatorSheet addButtonWithTitle:NSLocalizedString(@"Remove Force Quiet", @"Rmeove Force Quiet button title")];
					else [operatorSheet addButtonWithTitle:NSLocalizedString(@"Force Quiet", @"Force Quiet button title")];

					[context setObject:[NSNumber numberWithUnsignedInteger:(MVChatRoomMemberQuietedMode | (selectedUserIsQuieted ? (1 << 16) : 0))] forKey:[NSNumber numberWithUnsignedInteger:(operatorSheet.numberOfButtons - 1)]];
				}
			}

			operatorSheet.cancelButtonIndex = [operatorSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

			[[CQColloquyApplication sharedApplication] showActionSheet:operatorSheet];

			[operatorSheet release];
		}
	} else {
		[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

		id action = [context objectForKey:[NSNumber numberWithUnsignedInteger:buttonIndex]];

		if ([action isKindOfClass:[NSNumber class]]) {
			MVChatRoomMemberMode mode = ([action unsignedIntegerValue] & 0x7FFF);
			BOOL removeMode = (([action unsignedIntegerValue] & (1 << 16)) == (1 << 16));

			if (removeMode) [_room removeMode:mode forMemberUser:user];
			else [_room setMode:mode forMemberUser:user];
		} else if ([action isEqual:@"ban"]) {
			MVChatUser *wildcardUser = [MVChatUser wildcardUserWithNicknameMask:nil andHostMask:[NSString stringWithFormat:@"*@%@", user.address]];
			[_room addBanForUser:wildcardUser];
		} else if ([action isEqual:@"kick"]) {
			[_room kickOutMemberUser:user forReason:nil];
		}

		[context release]; // Retained earlier
	}
}
@end
