#import "CQChatRoomListViewController.h"

#import "CQChatRoomInfoTableCell.h"
#import "CQConnectionsController.h"
#import "CQProcessChatMessageOperation.h"
#import "NSNotificationAdditions.h"

static NSOperationQueue *topicProcessingQueue;
static BOOL showFullRoomNames;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomListViewController () <UISearchBarDelegate>
@end

@implementation  CQChatRoomListViewController {
@protected
	NSMutableArray *_rooms;
	NSMutableArray *_matchedRooms;
	NSMutableSet *_processedRooms;
	NSString *_currentSearchString;
	UISearchBar *_searchBar;
	BOOL _updatePending;
	BOOL _showingUpdateRow;
}

+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	showFullRoomNames = [[CQSettingsController settingsController] boolForKey:@"JVShowFullRoomNames"];
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter chatCenter] addObserver:[CQChatRoomListViewController class] selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_rooms = [[NSMutableArray alloc] init];
	_matchedRooms = _rooms;
	_processedRooms = [[NSMutableSet alloc] init];
	_showingUpdateRow = YES;

	[self _updateTitle];

	return self;
}

- (void) dealloc {
	_searchBar.delegate = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionChatRoomListUpdatedNotification object:_connection];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
	_searchBar.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
	_searchBar.placeholder = NSLocalizedString(@"Search", @"Search placeholder text");
	_searchBar.tintColor = [UIColor colorWithRed:(190. / 255.) green:(199. / 255.) blue:(205. / 255.) alpha:1.]; 
	_searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	_searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	_searchBar.delegate = self;
	_searchBar.text = _currentSearchString;

	[_searchBar sizeToFit];

	self.tableView.tableHeaderView = _searchBar;
}

#pragma mark -

- (void) setConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionChatRoomListUpdatedNotification object:_connection];

	_connection = connection;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_roomListUpdated:) name:MVChatConnectionChatRoomListUpdatedNotification object:connection];

	[connection connectAppropriately];
	[connection fetchChatRoomList];

	_updatePending = NO;
	[_processedRooms removeAllObjects];
	[_rooms setArray:[_connection.chatRoomListResults allKeys]];

	_matchedRooms = _rooms;

	_showingUpdateRow = !_matchedRooms.count;

	[self _sortRooms];

	[self.tableView reloadData];

	if (_currentSearchString.length)
		[self filterRoomsWithSearchString:_currentSearchString];

	[self _updateTitle];
}

- (void) setSelectedRoom:(NSString *) room {
	_selectedRoom = [[_connection properNameForChatRoomNamed:room] copy];

	if (!_matchedRooms.count)
		return;

	for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
		NSString *rowRoom = _matchedRooms[indexPath.row];
		CQChatRoomInfoTableCell *cell = (CQChatRoomInfoTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
		if ([rowRoom isEqualToString:room])
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		else cell.accessoryType = UITableViewCellAccessoryNone;
	}
}

#pragma mark -

- (void) searchBar:(UISearchBar *) searchBar textDidChange:(NSString *) searchString {
	if ([searchString isEqualToString:_currentSearchString])
		return;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(filterRooms) object:nil];

	NSTimeInterval delay = (searchString.length ? (1. / (double)searchString.length) : (1. / 3.));
	[self performSelector:@selector(filterRooms) withObject:nil afterDelay:delay];
}

#pragma mark -

- (void) filterRooms {
	[self filterRoomsWithSearchString:_searchBar.text];
}

- (void) filterRoomsWithSearchString:(NSString *) searchString {
	_searchBar.text = searchString;

	NSArray *previousRoomsArray = _matchedRooms;

	if (searchString.length) {
		_matchedRooms = [[NSMutableArray alloc] init];

		NSArray *searchArray = (_currentSearchString && [searchString hasPrefix:_currentSearchString] ? previousRoomsArray : _rooms);
		for (NSString *room in searchArray) {
			if (![room hasCaseInsensitiveSubstring:searchString])
				continue;
			[_matchedRooms addObject:room];
		}
	} else {
		_matchedRooms = _rooms;
	}

	if (ABS((NSInteger)(previousRoomsArray.count - _matchedRooms.count)) < 40) {
		NSSet *matchedRoomsSet = [[NSSet alloc] initWithArray:_matchedRooms];
		NSSet *previousRoomsSet = [[NSSet alloc] initWithArray:previousRoomsArray];

		[self.tableView beginUpdates];

		NSUInteger index = 0;
		NSMutableArray *indexPaths = [[NSMutableArray alloc] init];

		for (NSString *room in previousRoomsArray) {
			if (![matchedRoomsSet containsObject:room])
				[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
			++index;
		}

		[self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];

		index = 0;

		indexPaths = [[NSMutableArray alloc] init];

		for (NSString *room in _matchedRooms) {
			if (![previousRoomsSet containsObject:room])
				[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
			++index;
		}

		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];

		[self.tableView endUpdates];

	} else {
		[self.tableView reloadData];
	}

	_currentSearchString = [searchString copy];

	[self _updateTitle];

	[_searchBar becomeFirstResponder];

}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return (_showingUpdateRow ? 1 : _matchedRooms.count);
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_showingUpdateRow) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:@"Updating"];

		cell.textLabel.text = NSLocalizedString(@"Updating Chat Room List...", @"Updating chat room list label");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[spinner startAnimating];

		cell.accessoryView = spinner;

		return cell;
	}

	NSString *room = _matchedRooms[indexPath.row];
	NSMutableDictionary *info = _connection.chatRoomListResults[room];

	CQChatRoomInfoTableCell *cell = [CQChatRoomInfoTableCell reusableTableViewCellInTableView:tableView];

	if ([room isEqualToString:_selectedRoom])
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else cell.accessoryType = UITableViewCellAccessoryNone;

	NSString *roomDisplayName = info[@"roomDisplayString"];
	if (!info[@"roomDisplayString"]) {
		roomDisplayName = [_connection displayNameForChatRoomNamed:room];
		info[@"roomDisplayString"] = roomDisplayName;
	}

	cell.name = (showFullRoomNames ? room : roomDisplayName);
	cell.memberCount = [info[@"users"] unsignedIntegerValue];

	NSString *topicDisplayString = info[@"topicDisplayString"];
	if (!topicDisplayString && !self.tableView.dragging && !self.tableView.decelerating) {
		NSData *topicData = info[@"topic"];
		[self _processTopicData:topicData room:room];
	}

	cell.topic = topicDisplayString;

	return cell;
}

- (NSIndexPath *__nullable) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_showingUpdateRow)
		return nil;
	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([_searchBar isFirstResponder]) [_searchBar resignFirstResponder];

	UITableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:indexPath];

	for (UITableViewCell *cell in self.tableView.visibleCells) {
		if (selectedCell == cell)
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		else cell.accessoryType = UITableViewCellAccessoryNone;
	}

	_selectedRoom = [_matchedRooms[indexPath.row] copy];

	[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

	__strong __typeof__((_target)) strongTarget = _target;
	if (!strongTarget || [strongTarget respondsToSelector:_action])
		[[UIApplication sharedApplication] sendAction:_action to:strongTarget from:self forEvent:nil];
}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return !_showingUpdateRow;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(__nullable id) sender {
	return (!_showingUpdateRow && action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(__nullable id) sender {
	if (_showingUpdateRow)
		return;

	NSString *selectedRoom = _matchedRooms[indexPath.row];
	if (!selectedRoom)
		return;

	if (action == @selector(copy:))
		[UIPasteboard generalPasteboard].string = selectedRoom;
}

#pragma mark -

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL) decelerate {
	if (!decelerate)
		[self _updateVisibleTopics];
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *) scrollView {
	[self _updateVisibleTopics];
}

#pragma mark -

static NSComparisonResult sortUsingMemberCount(id one, id two, void *context) {
	NSDictionary *rooms = (__bridge NSDictionary *)(context);
	NSDictionary *oneInfo = rooms[one];
	NSDictionary *twoInfo = rooms[two];
	NSUInteger oneUsers = [oneInfo[@"users"] unsignedIntegerValue];
	NSUInteger twoUsers = [twoInfo[@"users"] unsignedIntegerValue];

	if (oneUsers > twoUsers)
		return NSOrderedAscending;
	if (twoUsers > oneUsers)
		return NSOrderedDescending;

	return [oneInfo[@"roomDisplayString"] caseInsensitiveCompare:twoInfo[@"roomDisplayString"]];
}

- (void) _sortRooms {
	[_rooms sortUsingFunction:sortUsingMemberCount context:(__bridge void *)(_connection.chatRoomListResults)];
}

- (void) _updateRoomsSoon {
	if (_updatePending)
		return;

	[self performSelector:@selector(_updateRooms) withObject:nil afterDelay:1.];

	_updatePending = YES;
}

- (void) _updateTitle {
	if (!_rooms.count || _showingUpdateRow) {
		self.title = NSLocalizedString(@"Rooms", @"Rooms list view title");
		return;
	}

	static NSNumberFormatter *numberFormatter;
	if (!numberFormatter) {
		numberFormatter = [[NSNumberFormatter alloc] init];
        numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
		numberFormatter.positiveFormat = NSLocalizedString(@"#,##0", @"Plain large number format string");
	}

	NSString *formattedCount = [numberFormatter stringFromNumber:@(_matchedRooms.count)];
	self.title = [NSString stringWithFormat:NSLocalizedString(@"Rooms (%@)", @"Rooms list view title with count"), formattedCount];
}

- (void) _updateVisibleTopics {
	NSDictionary *chatRoomListResults = _connection.chatRoomListResults;
	for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
		if (indexPath.row >= (NSInteger)_matchedRooms.count)
			continue;

		NSString *room = _matchedRooms[indexPath.row];
		NSMutableDictionary *info = chatRoomListResults[room];

		NSString *topicDisplayString = info[@"topicDisplayString"];
		if (!topicDisplayString) {
			NSData *topicData = info[@"topic"];
			[self _processTopicData:topicData room:room];
			continue;
		}

		CQChatRoomInfoTableCell *cell = (CQChatRoomInfoTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
		if (!cell.topic.length)
			cell.topic = topicDisplayString;
	}
}

- (void) _updateRooms {
	if (!_processedRooms.count)
		return;

	BOOL animatedInsert = (_processedRooms.count < 40);

	BOOL wasShowingUpdateRow = _showingUpdateRow;
	_showingUpdateRow = NO;

	if (wasShowingUpdateRow && animatedInsert)
		[self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];

	[_rooms addObjectsFromArray:[_processedRooms allObjects]];

	[self _sortRooms];

	if (_matchedRooms != _rooms) {
		if (_currentSearchString.length) {
			for (NSString *room in _processedRooms) {
				if ([room hasCaseInsensitiveSubstring:_currentSearchString])
					[_matchedRooms addObject:room];
			}
		} else {
			[_matchedRooms addObjectsFromArray:[_processedRooms allObjects]];
		}

		[_matchedRooms sortUsingFunction:sortUsingMemberCount context:(__bridge void *)(_connection.chatRoomListResults)];
	}

	if (animatedInsert) {
		NSMutableArray *indexPaths = [[NSMutableArray alloc] initWithCapacity:_processedRooms.count];

		NSUInteger index = 0;
		for (NSString *room in _matchedRooms) {
			if ([_processedRooms containsObject:room])
				[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
			++index;
		}

		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
	} else {
		[self.tableView reloadData];
	}

	[self _updateTitle];

	[_processedRooms removeAllObjects];

	_updatePending = NO;
}

- (void) _roomListUpdated:(NSNotification *) notification {
	NSDictionary *chatRoomListResults = _connection.chatRoomListResults;
	NSSet *roomsAdded = notification.userInfo[@"added"];
	for (NSString *room in roomsAdded) {
		NSMutableDictionary *info = chatRoomListResults[room];
		info[@"roomDisplayString"] = [_connection displayNameForChatRoomNamed:room];

		[_processedRooms addObject:room];
	}

	NSSet *roomsUpdated = (notification.userInfo)[@"updated"];
	for (NSString *room in roomsUpdated) {
		NSMutableDictionary *info = chatRoomListResults[room];
		info[@"roomDisplayString"] = [_connection displayNameForChatRoomNamed:room];
	}

	if (_processedRooms.count)
		[self _updateRoomsSoon];
}

- (void) _topicProcessed:(CQProcessChatMessageOperation *) operation {
	NSString *room = operation.userInfo;
	NSMutableDictionary *info = (_connection.chatRoomListResults)[room];

	NSString *topicString = operation.processedMessageAsPlainText;

	// Remove the modes that some servers prepend to the topic. Maybe use this info to show custom icons for locked rooms?
	if (topicString.length >= 5)
		topicString = [topicString stringByReplacingOccurrencesOfRegex:@"^\\[\\+[a-zA-Z]+\\] " withString:@""];

	info[@"topicDisplayString"] = topicString;

	if (self.tableView.dragging || self.tableView.decelerating)
		return;

	for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
		if (indexPath.row >= (NSInteger)_matchedRooms.count)
			continue;

		NSString *rowRoom = _matchedRooms[indexPath.row];
		if (![rowRoom isEqualToString:room])
			continue;

		CQChatRoomInfoTableCell *cell = (CQChatRoomInfoTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
		cell.topic = topicString;
		break;
	}
}

- (void) _processTopicData:(NSData *) topicData room:(NSString *) room {
	if (!topicData.length || !room.length)
		return;

	if (!topicProcessingQueue) {
		topicProcessingQueue = [[NSOperationQueue alloc] init];
		topicProcessingQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
	}

	CQProcessChatMessageOperation *operation = [[CQProcessChatMessageOperation alloc] initWithMessageData:topicData];
	operation.encoding = _connection.encoding;

	operation.target = self;
	operation.action = @selector(_topicProcessed:);
	operation.userInfo = room;

	[topicProcessingQueue addOperation:operation];

}
@end

NS_ASSUME_NONNULL_END
