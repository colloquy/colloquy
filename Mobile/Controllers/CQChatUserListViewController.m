#import "CQChatUserListViewController.h"

#import "CQChatController.h"
#import "CQColloquyApplication.h"
#import "CQDirectChatController.h"
#import "CQWhoisNavController.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatConnection.h>

static NSString *_membersString = nil;
static NSString *_membersFormat = @"%@ (%d)";

@implementation CQChatUserListViewController
+ (void) initialize {
    if (self == [CQChatUserListViewController class]) {
        _membersString = NSLocalizedString(@"Members", @"Members view title");
    }
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
	self.title = [NSString stringWithFormat:_membersFormat, _membersString, users.count];
	
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
    self.title = [NSString stringWithFormat:_membersFormat, _membersString, _users.count];

	if (!_currentSearchString.length || [user.displayName hasCaseInsensitiveSubstring:_currentSearchString]) {
		NSInteger matchesIndex = [self _indexForInsertedMatchUser:user withOriginalIndex:index];

		[_matchedUsers insertObject:user atIndex:matchesIndex];

		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
	}
}

- (void) _removeUserAtIndex:(NSUInteger) index withAnimation:(UITableViewRowAnimation) animation {
	NSParameterAssert(index <= _users.count);

	MVChatUser *user = [[_users objectAtIndex:index] retain];

	[_users removeObjectAtIndex:index];
    self.title = [NSString stringWithFormat:_membersFormat, _membersString, _users.count];

	NSUInteger matchesIndex = [self _indexForRemovedMatchUser:user];
	if (matchesIndex != NSNotFound) {
		[_matchedUsers removeObjectAtIndex:matchesIndex];

		NSArray *indexPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:matchesIndex inSection:0]];
		[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
	}

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

	[sheet addButtonWithTitle:NSLocalizedString(@"Send Message", @"Send Message button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"User Information", @"User Information button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	sheet.cancelButtonIndex = 2;

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	MVChatUser *user = [_matchedUsers objectAtIndex:selectedIndexPath.row];

	if (buttonIndex == 0) {
		CQDirectChatController *chatController = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:chatController animated:YES];
	} else if (buttonIndex == 1) {
		CQWhoisNavController *whoisController = [[CQWhoisNavController alloc] init];
		whoisController.user = user;

		[self presentModalViewController:whoisController animated:YES];

		[whoisController release];
	}
}
@end
