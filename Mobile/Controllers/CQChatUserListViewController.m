#import "CQChatUserListViewController.h"

#import "CQColloquyApplication.h"
#import "CQUserInfoViewController.h"

#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

#import "UIActionSheetAdditions.h"

static NSString *membersSingleCountFormat;
static NSString *membersFilteredCountFormat;

#define UserIdleTime 600

NS_ASSUME_NONNULL_BEGIN

@interface CQChatUserListViewController () <UIActionSheetDelegate, UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>
@property (atomic, strong) NSMutableArray <MVChatUser *> *users;
@property (atomic, strong) NSMutableArray <MVChatUser *> *matchedUsers;
@end

@implementation CQChatUserListViewController {
@protected
	NSString *_currentSearchString;
	MVChatRoom *_room;
	UISearchController *_searchController;
	QChatUserListMode _listMode;
	id <CQChatUserListViewDelegate> __weak _chatUserDelegate;
}

+ (void) initialize {
	membersSingleCountFormat = NSLocalizedString(@"Members (%u)", @"Members with single count view title");
	membersFilteredCountFormat = NSLocalizedString(@"Members (%u of %u)", @"Members with filtered count view title");
}

- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	_users = [[NSMutableArray alloc] init];
	_matchedUsers = [[NSMutableArray alloc] init];

	return self;
}

- (void) dealloc {
	_chatUserDelegate = nil;
	_searchController.searchResultsUpdater = nil;
	_searchController.delegate = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_listMode == CQChatUserListModeBan)
		return;

	_searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	_searchController.delegate = self;
	_searchController.searchResultsUpdater = self;

	_searchController.searchBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
	_searchController.searchBar.placeholder = NSLocalizedString(@"Search", @"Search placeholder text");
	_searchController.searchBar.accessibilityLabel = NSLocalizedString(@"Search Members", @"Voiceover search members label");
	_searchController.searchBar.tintColor = [UIColor colorWithRed:(190. / 255.) green:(199. / 255.) blue:(205. / 255.) alpha:1.];
	_searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	_searchController.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	[_searchController.searchBar sizeToFit];

	self.tableView.tableHeaderView = _searchController.searchBar;

	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Members", @"Members back button label") style:UIBarButtonItemStylePlain target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;

	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissFromDoneButton)];
	self.navigationItem.rightBarButtonItem = doneButton;

	[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) viewWillAppear:(BOOL) animated {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[super viewWillAppear:animated];

	[self.tableView reloadData];

	if (selectedIndexPath)
		[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark -

- (void) setRoomUsers:(NSArray <MVChatUser *> *) users {
	[self.users setArray:users];
	self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];

	[self.matchedUsers setArray:users];

	[self.tableView reloadData];
}

- (void) setRoom:(MVChatRoom *) room {
	_room = room;

	[self.tableView reloadData];
}

#pragma mark -

- (NSUInteger) _indexForInsertedMatchUser:(MVChatUser *) user withOriginalIndex:(NSUInteger) index {
	return NSNotFound;
//	unsigned long insertionUserStatus = userStatus(user, _room);
//	NSArray <MVChatUser *> *matchedUsers = [self.matchedUsers copy];
//
//	for (NSUInteger i = 0; i < matchedUsers.count; i++) {
//		MVChatUser *matchedUser = matchedUsers[i];
//
//		unsigned long matchedUserStatus = userStatus(matchedUser, _room);
//		if (matchedUserStatus > insertionUserStatus)
//			continue;
//
//		NSComparisonResult comparison = [user.displayName caseInsensitiveCompare:matchedUser.displayName];
//		if (comparison == NSOrderedDescending)
//			continue;
//		if (comparison == NSOrderedSame)
//			continue;
//		return i;
//	}
//
//	return matchedUsers.count;
}

- (NSUInteger) _indexForRemovedMatchUser:(MVChatUser *) user {
	return NSNotFound;
//	NSArray <MVChatUser *> *matchedUsers = [self.matchedUsers copy];
//	for (NSUInteger i = 0; i < matchedUsers.count; i++) {
//		if (user == matchedUsers[i])
//			return i;
//	}
//	return NSNotFound;
}

- (void) _moveUser:(MVChatUser *) user atIndex:(NSUInteger) fromIndex toIndex:(NSUInteger) toIndex withAnimation:(UITableViewRowAnimation) animation {
//	NSParameterAssert(user != nil);
//	NSParameterAssert(fromIndex <= self.users.count);
//	NSParameterAssert(toIndex <= self.users.count);
//
//	[self.users removeObjectAtIndex:fromIndex];
//	[self.users insertObject:user atIndex:toIndex];
//
//	if (!_currentSearchString.length || [user.nickname hasCaseInsensitiveSubstring:_currentSearchString]) {
//		NSInteger removalMatchesIndex = [self _indexForRemovedMatchUser:user];
//		[self.matchedUsers removeObjectAtIndex:removalMatchesIndex];
//
//		NSInteger insertionMatchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:fromIndex];
//		[self.matchedUsers insertObject:user atIndex:insertionMatchesIndex];
//
//		if (insertionMatchesIndex != removalMatchesIndex) {
//			[self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:removalMatchesIndex inSection:0] toIndexPath:[NSIndexPath indexPathForRow:insertionMatchesIndex inSection:0]];
//			[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:removalMatchesIndex inSection:0], [NSIndexPath indexPathForRow:insertionMatchesIndex inSection:0] ] withRowAnimation:UITableViewRowAnimationFade];
//		} else [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:insertionMatchesIndex inSection:0] ] withRowAnimation:UITableViewRowAnimationFade];
//	}
}

- (void) _insertUser:(MVChatUser *) user atIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
//	NSParameterAssert(user != nil);
//	NSParameterAssert(index <= self.users.count);
//
//	[self.users insertObject:user atIndex:index];
//
//	if (!_currentSearchString.length || [user.nickname hasCaseInsensitiveSubstring:_currentSearchString]) {
//		NSInteger matchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:index];
//
//		[self.matchedUsers insertObject:user atIndex:matchesIndex];
//
//		NSArray <NSIndexPath *> *indexPaths = @[[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
//		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
//	}
//
//	if (self.users.count == self.matchedUsers.count)
//		self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
//	else self.title = [NSString stringWithFormat:membersFilteredCountFormat, self.matchedUsers.count, self.users.count];
}

- (void) _removeUserAtIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
//	NSParameterAssert(index <= self.users.count);
//
//	MVChatUser *user = self.users[index];
//
//	[self.users removeObjectAtIndex:index];
//
//	NSUInteger matchesIndex = [self _indexForRemovedMatchUser:user];
//	if (matchesIndex != NSNotFound) {
//		[self.matchedUsers removeObjectAtIndex:matchesIndex];
//
//		NSArray <NSIndexPath *> *indexPaths = @[[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
//		[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
//	}
//	if (self.users.count == self.matchedUsers.count)
//		self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
//	else self.title = [NSString stringWithFormat:membersFilteredCountFormat, self.matchedUsers.count, self.users.count];
}

#pragma mark -

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index {
	BOOL searchBarFocused = [_searchController isActive];

	[self.tableView reloadData];
//	[self _insertUser:user atIndex:index withAnimation:UITableViewRowAnimationLeft];

	if (searchBarFocused)
		_searchController.active = YES;

	[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	if (oldIndex == newIndex)
		return;

//	MVChatUser *user = self.users[oldIndex];

	BOOL searchBarFocused = [_searchController isActive];

	[self.tableView reloadData];
//	NSInteger oldMatchesIndex = [self _indexForRemovedMatchUser:user];
//	NSInteger newMatchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:newIndex];
//
//	if (newMatchesIndex > oldMatchesIndex)
//		--newMatchesIndex;
//
//	if (oldMatchesIndex == newMatchesIndex) {
//		[self _moveUser:user atIndex:oldIndex toIndex:newIndex withAnimation:UITableViewRowAnimationFade];
//	} else {
//		[self _moveUser:user atIndex:oldIndex toIndex:newIndex withAnimation:(newIndex > oldIndex ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop)];
//	}

	if (searchBarFocused)
		_searchController.active = YES;
}

- (void) removeUserAtIndex:(NSUInteger) index {
	BOOL searchBarFocused = [_searchController isActive];
//
	[self.tableView reloadData];
//	[self _removeUserAtIndex:index withAnimation:UITableViewRowAnimationRight];

	if (searchBarFocused)
		_searchController.active = YES;

	[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) updateUserAtIndex:(NSUInteger) index {
//	NSParameterAssert(index <= self.users.count);
//
//	MVChatUser *user = self.users[index];
//	NSUInteger matchesIndex = [self.matchedUsers indexOfObjectIdenticalTo:user];
//	if (matchesIndex == NSNotFound)
//		return;

	BOOL searchBarFocused = [_searchController isActive];

	[self.tableView reloadData];
//	[self.tableView beginUpdates];
//	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:matchesIndex inSection:0] withAnimation:UITableViewRowAnimationFade];
//	[self.tableView endUpdates];

	if (searchBarFocused)
		_searchController.active = YES;
}

#pragma mark -

- (void) updateSearchResultsForSearchController:(UISearchController *) searchController {
	NSString *searchString = searchController.searchBar.text;
	if ([searchString isEqualToString:_currentSearchString])
		return;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(filterUsers) object:nil];

	NSTimeInterval delay = (searchString.length ? (1. / (double)searchString.length) : (1. / 3.));
	[self performSelector:@selector(filterUsers) withObject:nil afterDelay:delay];
}

- (void) willDismissSearchController:(UISearchController *) searchController {
	// The searching has probably ruined the self.matchedUsers array, so rebuild it here when we display the main results table view/
	[self.matchedUsers setArray:self.users];
	[self.tableView reloadData];

	self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
}

#pragma mark -

- (void) filterUsers {
	[self filterUsersWithSearchString:_searchController.searchBar.text];
}

- (void) filterUsersWithSearchString:(NSString *) searchString {
	NSArray <MVChatUser *> *previousUsersArray = self.matchedUsers;

	if (searchString.length) {
		self.matchedUsers = [[NSMutableArray alloc] init];

		NSArray <MVChatUser *> *searchArray = (_currentSearchString && [searchString hasPrefix:_currentSearchString] ? previousUsersArray : self.users);
		for (MVChatUser *user in searchArray) {
			if (![user.nickname hasCaseInsensitiveSubstring:searchString])
				continue;
			[self.matchedUsers addObject:user];
		}
	} else {
		self.matchedUsers = [self.users mutableCopy];
	}

//	if (ABS((NSInteger)(previousUsersArray.count - self.matchedUsers.count)) < 40) {
//		NSSet *matchedUsersSet = [[NSSet alloc] initWithArray:self.matchedUsers];
//		NSSet *previousUsersSet = [[NSSet alloc] initWithArray:previousUsersArray];
//
//		[_searchController.searchResultsTableView beginUpdates];
//
//		NSUInteger index = 0;
//		NSMutableArray <NSIndexPath *> *indexPaths = [[NSMutableArray alloc] init];
//
//		for (MVChatUser *user in previousUsersArray) {
//			if (![matchedUsersSet containsObject:user])
//				[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
//			++index;
//		}
//
//		[_searchController.searchResultsTableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
//
//		index = 0;
//
//		indexPaths = [[NSMutableArray alloc] init];
//
//		for (MVChatUser *user in self.matchedUsers) {
//			if (![previousUsersSet containsObject:user])
//				[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
//			++index;
//		}
//
//		[_searchController.searchResultsTableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
//		[_searchController.searchResultsTableView endUpdates];
//	} else {
	// TODO
		[self.tableView reloadData];
//	}

	_currentSearchString = [searchString copy];

	if (self.users.count == self.matchedUsers.count)
		self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
	else self.title = [NSString stringWithFormat:membersFilteredCountFormat, self.matchedUsers.count, self.users.count];

	[_searchController.searchBar becomeFirstResponder];
}

#pragma mark -

- (void) viewWillTransitionToSize:(CGSize) size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>) coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

	[self resizeForViewInPopoverUsingTableView:self.tableView];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return self.matchedUsers.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatUser *user = self.matchedUsers[indexPath.row];

	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
	cell.textLabel.text = user.nickname;

	if (_room) {
		unsigned long modes = [_room modesForMemberUser:user];

		if (user.serverOperator)
			cell.imageView.image = [UIImage imageNamed:@"userSuperOperator.png"];
		else if (modes & MVChatRoomMemberFounderMode)
			cell.imageView.image = [UIImage imageNamed:@"userFounder.png"];
		else if (modes & MVChatRoomMemberAdministratorMode)
			cell.imageView.image = [UIImage imageNamed:@"userAdmin.png"];
		else if (modes & MVChatRoomMemberOperatorMode)
			cell.imageView.image = [UIImage imageNamed:@"userOperator.png"];
		else if (modes & MVChatRoomMemberHalfOperatorMode)
			cell.imageView.image = [UIImage imageNamed:@"userHalfOperator.png"];
		else if (modes & MVChatRoomMemberVoicedMode)
			cell.imageView.image = [UIImage imageNamed:@"userVoice.png"];
		else cell.imageView.image = [UIImage imageNamed:@"userNormal.png"];
	} else {
		cell.imageView.image = [UIImage imageNamed:@"userNormal.png"];
	}

	if (_listMode == CQChatUserListModeRoom && self.view.window.isFullscreen)
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	if (user.status == MVChatUserAwayStatus || user.idleTime >= UserIdleTime) {
		cell.imageView.alpha = .5;
		cell.textLabel.alpha = .5;
	} else {
		cell.imageView.alpha = 1.;
		cell.textLabel.alpha = 1.;
	}

	return cell;
}

- (NSIndexPath *__nullable) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	[self endEditing];

	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatUser *user = self.matchedUsers[indexPath.row];

	__strong __typeof__((_chatUserDelegate)) chatUserDelegate = _chatUserDelegate;
	BOOL shouldPresentInformation = YES;
	if (chatUserDelegate && [chatUserDelegate respondsToSelector:@selector(chatUserListViewController:shouldPresentInformationForUser:)])
		shouldPresentInformation = [chatUserDelegate chatUserListViewController:self shouldPresentInformationForUser:user];

	if (shouldPresentInformation) {
		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

		BOOL showingUserInformation = _listMode == CQChatUserListModeRoom && !self.view.window.isFullscreen;
		UIActionSheet *sheet = [UIActionSheet userActionSheetForUser:user inRoom:_room showingUserInformation:showingUserInformation];
		sheet.title = cell.textLabel.text;

		[sheet associateObject:cell forKey:@"userInfo"];

		[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:cell animated:YES];

		[tableView deselectRowAtIndexPath:indexPath animated:NO];
	}

	if (chatUserDelegate && [chatUserDelegate respondsToSelector:@selector(chatUserListViewController:didSelectUser:)])
		[chatUserDelegate chatUserListViewController:self didSelectUser:user];
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	CQUserInfoViewController *userInfoViewController = [[CQUserInfoViewController alloc] init];
	userInfoViewController.user = self.matchedUsers[indexPath.row];

	[self.navigationController pushViewController:userInfoViewController animated:YES];
}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(__nullable id) sender {
	return (action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(__nullable id) sender {
	MVChatUser *user = self.matchedUsers[indexPath.row];
	if (!user)
		return;

	if (action == @selector(copy:))
		[UIPasteboard generalPasteboard].string = user.nickname;
}

#pragma mark -

- (void) traitCollectionDidChange:(nullable UITraitCollection *) previousTraitCollection {
	if ([self isViewLoaded])
		[self.tableView reloadData];
}

#pragma mark -

- (void) dismissFromDoneButton {
	[self dismissViewControllerAnimated:YES completion:NULL];
}
@end

NS_ASSUME_NONNULL_END
