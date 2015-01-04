#import "CQChatUserListViewController.h"

#import "CQChatController.h"
#import "CQColloquyApplication.h"
#import "CQChatRoomController.h"
#import "CQUserInfoController.h"
#import "CQUserInfoViewController.h"

#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatConnection.h>

#import "UIActionSheetAdditions.h"

static NSString *membersSingleCountFormat;
static NSString *membersFilteredCountFormat;

#define UserIdleTime 600

@interface CQChatUserListViewController ()
@property (atomic, strong) NSMutableArray *users;
@property (atomic, strong) NSMutableArray *matchedUsers;
@end

@implementation CQChatUserListViewController
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
	_searchBar.delegate = nil;
	_searchController.delegate = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_listMode == CQChatUserListModeBan)
		return;
	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
	_searchBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
	_searchBar.placeholder = NSLocalizedString(@"Search", @"Search placeholder text");
	_searchBar.accessibilityLabel = NSLocalizedString(@"Search Members", @"Voiceover search members label");
	_searchBar.tintColor = [UIColor colorWithRed:(190. / 255.) green:(199. / 255.) blue:(205. / 255.) alpha:1.]; 
	_searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	_searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	[_searchBar sizeToFit];

	self.tableView.tableHeaderView = _searchBar;

	_searchController = [[UISearchDisplayController alloc] initWithSearchBar:_searchBar contentsController:self];
	_searchController.searchResultsDataSource = self;
	_searchController.searchResultsDelegate = self;
	_searchController.delegate = self;

	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Members", @"Members back button label") style:UIBarButtonItemStylePlain target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;

	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissFromDoneButton)];
	self.navigationItem.rightBarButtonItem = doneButton;

	if ([[UIDevice currentDevice] isPadModel])
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

- (void) setRoomUsers:(NSArray *) users {
	@synchronized(self) {
		[self.users setArray:users];
		self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];

		[self.matchedUsers setArray:users];
	}

	[self.tableView reloadData];
}

- (void) setRoom:(MVChatRoom *) room {
	_room = room;

	[self.tableView reloadData];
}

#pragma mark -

- (NSUInteger) _indexForInsertedMatchUser:(MVChatUser *) user withOriginalIndex:(NSUInteger) index {
	NSInteger matchesIndex = NSNotFound;
	@synchronized(self) {
		for (NSInteger i = (index - 1); i >= 0; --i) {
			MVChatUser *currentUser = self.users[i];
			matchesIndex = [self.matchedUsers indexOfObjectIdenticalTo:currentUser];
			if (matchesIndex != NSNotFound)
				break;
		}
	}

	if (matchesIndex == NSNotFound)
		matchesIndex = -1;

	return ++matchesIndex;
}

- (NSUInteger) _indexForRemovedMatchUser:(MVChatUser *) user {
	@synchronized(self) {
		return [self.matchedUsers indexOfObjectIdenticalTo:user];
	}
}

- (void) _moveUser:(MVChatUser *) user atIndex:(NSUInteger) fromIndex toIndex:(NSUInteger) toIndex withAnimation:(UITableViewRowAnimation) animation {
	[self.tableView reloadData];
/*
	@synchronized(self) {
		NSParameterAssert(user != nil);
		NSParameterAssert(fromIndex <= self.users.count);
		NSParameterAssert(toIndex <= self.users.count);

		[self.users removeObjectAtIndex:fromIndex];
		[self.users insertObject:user atIndex:toIndex];

		if (toIndex > fromIndex)
			--toIndex;

		if (!_currentSearchString.length || [user.nickname hasCaseInsensitiveSubstring:_currentSearchString]) {
			NSInteger insertionMatchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:fromIndex];
			NSInteger removalMatchesIndex = [self _indexForRemovedMatchUser:user];

			if (insertionMatchesIndex > removalMatchesIndex)
				--insertionMatchesIndex;

			[self.matchedUsers removeObjectAtIndex:removalMatchesIndex];
			[self.matchedUsers insertObject:user atIndex:insertionMatchesIndex];

			[self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:removalMatchesIndex inSection:0] toIndexPath:[NSIndexPath indexPathForRow:insertionMatchesIndex inSection:0]];
		}
	}
*/
}

- (void) _insertUser:(MVChatUser *) user atIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
	[self.tableView reloadData];
/*
	@synchronized(self) {
		NSParameterAssert(user != nil);
		NSParameterAssert(index <= self.users.count);

		[self.users insertObject:user atIndex:index];

		if (!_currentSearchString.length || [user.nickname hasCaseInsensitiveSubstring:_currentSearchString]) {
			NSInteger matchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:index];

			[self.matchedUsers insertObject:user atIndex:matchesIndex];

			NSArray *indexPaths = @[[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
			[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
		}

		if (self.users.count == self.matchedUsers.count)
			self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
		else self.title = [NSString stringWithFormat:membersFilteredCountFormat, self.matchedUsers.count, self.users.count];
	}
*/
}

- (void) _removeUserAtIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
	[self.tableView reloadData];
/*
	@synchronized(self) {
		NSParameterAssert(index <= self.users.count);

		MVChatUser *user = self.users[index];

		[self.users removeObjectAtIndex:index];

		NSUInteger matchesIndex = [self _indexForRemovedMatchUser:user];
		if (matchesIndex != NSNotFound) {
			[self.matchedUsers removeObjectAtIndex:matchesIndex];

			NSArray *indexPaths = @[[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
			[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
		}
		if (self.users.count == self.matchedUsers.count)
			self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
		else self.title = [NSString stringWithFormat:membersFilteredCountFormat, self.matchedUsers.count, self.users.count];
	}
 */
}

#pragma mark -

- (void) insertUser:(MVChatUser *) user atIndex:(NSUInteger) index {
	BOOL searchBarFocused = [_searchController isActive];

//	[self.tableView beginUpdates];
	[self _insertUser:user atIndex:index withAnimation:UITableViewRowAnimationLeft];
//	[self.tableView endUpdates];

	if (searchBarFocused)
		[_searchController setActive:YES animated:YES];

	if ([[UIDevice currentDevice] isPadModel]) 
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) moveUserAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex {
	[self.tableView reloadData];
/*
	if (oldIndex == newIndex)
		return;

	@synchronized(self) {
		MVChatUser *user = self.users[oldIndex];

		BOOL searchBarFocused = [_searchController isActive];

		NSInteger oldMatchesIndex = [self _indexForRemovedMatchUser:user];
		NSInteger newMatchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:newIndex];

		if (newMatchesIndex > oldMatchesIndex)
			--newMatchesIndex;

		[self.tableView beginUpdates];

		if (oldMatchesIndex == newMatchesIndex) {
			[self _moveUser:user atIndex:oldIndex toIndex:newIndex withAnimation:UITableViewRowAnimationFade];
		} else {
			[self _moveUser:user atIndex:oldIndex toIndex:newIndex withAnimation:(newIndex > oldIndex ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop)];
		}

		[self.tableView endUpdates];

		if (searchBarFocused)
			[_searchController setActive:YES animated:YES];
	}
 */
}

- (void) removeUserAtIndex:(NSUInteger) index {
	BOOL searchBarFocused = [_searchController isActive];

//	[self.tableView beginUpdates];
	[self _removeUserAtIndex:index withAnimation:UITableViewRowAnimationRight];
//	[self.tableView endUpdates];

	if (searchBarFocused)
		[_searchController setActive:YES animated:YES];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) updateUserAtIndex:(NSUInteger) index {
	[self.tableView reloadData];
/*
	@synchronized(self) {
		NSParameterAssert(index <= self.users.count);

		MVChatUser *user = self.users[index];
		NSUInteger matchesIndex = [self.matchedUsers indexOfObjectIdenticalTo:user];
		if (matchesIndex == NSNotFound)
			return;

		BOOL searchBarFocused = [_searchController isActive];

		[self.tableView beginUpdates];
		[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:matchesIndex inSection:0] withAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];

		if (searchBarFocused)
			[_searchController setActive:YES animated:YES];
	}
 */
}

#pragma mark -

- (BOOL) searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *) searchString {
	if ([searchString isEqualToString:_currentSearchString])
		return NO;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(filterUsers) object:nil];
	
	NSTimeInterval delay = (searchString.length ? (1. / (double)searchString.length) : (1. / 3.));
	[self performSelector:@selector(filterUsers) withObject:nil afterDelay:delay];
	
	return NO;
}

- (void) searchDisplayControllerWillEndSearch:(UISearchDisplayController *) controller {
	@synchronized(self) {
		// The searching has probably ruined the self.matchedUsers array, so rebuild it here when we display the main results table view/
		[self.matchedUsers setArray:self.users];
		[self.tableView reloadData];

		self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
	}
}

#pragma mark -

- (void) filterUsers {
	[self filterUsersWithSearchString:_searchBar.text];
}

- (void) filterUsersWithSearchString:(NSString *) searchString {
	@synchronized(self) {
		NSArray *previousUsersArray = self.matchedUsers;

		if (searchString.length) {
			self.matchedUsers = [[NSMutableArray alloc] init];

			NSArray *searchArray = (_currentSearchString && [searchString hasPrefix:_currentSearchString] ? previousUsersArray : self.users);
			for (MVChatUser *user in searchArray) {
				if (![user.nickname hasCaseInsensitiveSubstring:searchString])
					continue;
				[self.matchedUsers addObject:user];
			}
		} else {
			self.matchedUsers = [self.users mutableCopy];
		}

		if (ABS((NSInteger)(previousUsersArray.count - self.matchedUsers.count)) < 40) {
			NSSet *matchedUsersSet = [[NSSet alloc] initWithArray:self.matchedUsers];
			NSSet *previousUsersSet = [[NSSet alloc] initWithArray:previousUsersArray];

			[_searchController.searchResultsTableView beginUpdates];

			NSUInteger index = 0;
			NSMutableArray *indexPaths = [[NSMutableArray alloc] init];

			for (MVChatUser *user in previousUsersArray) {
				if (![matchedUsersSet containsObject:user])
					[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
				++index;
			}

			[_searchController.searchResultsTableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];

			index = 0;

			indexPaths = [[NSMutableArray alloc] init];

			for (MVChatUser *user in self.matchedUsers) {
				if (![previousUsersSet containsObject:user])
					[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
				++index;
			}

			[_searchController.searchResultsTableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
			[_searchController.searchResultsTableView endUpdates];
		} else {
			[_searchController.searchResultsTableView reloadData];
		}

		_currentSearchString = [searchString copy];

		if (self.users.count == self.matchedUsers.count)
			self.title = [NSString stringWithFormat:membersSingleCountFormat, self.users.count];
		else self.title = [NSString stringWithFormat:membersFilteredCountFormat, self.matchedUsers.count, self.users.count];

		[_searchBar becomeFirstResponder];
	}
}

#pragma mark -

- (void) viewWillTransitionToSize:(CGSize) size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>) coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation duration:(NSTimeInterval) duration {
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}
#endif

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	@synchronized(self) {
		return self.matchedUsers.count;
	}
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	@synchronized(self) {
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

		if (_listMode == CQChatUserListModeRoom && ![[UIDevice currentDevice] isPadModel])
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
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	[self endEditing];

	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	@synchronized(self) {
		MVChatUser *user = self.matchedUsers[indexPath.row];

		__strong __typeof__((_chatUserDelegate)) chatUserDelegate = _chatUserDelegate;
		BOOL shouldPresentInformation = YES;
		if (chatUserDelegate && [chatUserDelegate respondsToSelector:@selector(chatUserListViewController:shouldPresentInformationForUser:)])
			shouldPresentInformation = [chatUserDelegate chatUserListViewController:self shouldPresentInformationForUser:user];

		if (shouldPresentInformation) {
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

			UIActionSheet *sheet = [UIActionSheet userActionSheetForUser:user inRoom:_room showingUserInformation:NO];
			sheet.title = cell.textLabel.text;

			[sheet associateObject:cell forKey:@"userInfo"];

			[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:cell animated:YES];

			[tableView deselectRowAtIndexPath:indexPath animated:NO];
		}

		if (chatUserDelegate && [chatUserDelegate respondsToSelector:@selector(chatUserListViewController:didSelectUser:)])
			[chatUserDelegate chatUserListViewController:self didSelectUser:user];
	}
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	@synchronized(self) {
		CQUserInfoViewController *userInfoViewController = [[CQUserInfoViewController alloc] init];
		userInfoViewController.user = self.matchedUsers[indexPath.row];

		[self.navigationController pushViewController:userInfoViewController animated:YES];
	}
}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	return (action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	@synchronized(self) {
		MVChatUser *user = self.matchedUsers[indexPath.row];
		if (!user)
			return;

		if (action == @selector(copy:))
			[UIPasteboard generalPasteboard].string = user.nickname;
	}
}

#pragma mark -

- (void) dismissFromDoneButton {
	[self dismissViewControllerAnimated:YES completion:NULL];
}
@end
