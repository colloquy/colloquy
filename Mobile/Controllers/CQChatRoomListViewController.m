#import "CQChatRoomListViewController.h"

#import "CQChatRoomInfoTableCell.h"
#import "CQProcessChatMessageOperation.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatConnection.h>

static NSOperationQueue *topicProcessingQueue;

@interface CQChatRoomListViewController (CQChatRoomListViewControllerPrivate)
- (void) _processTopicData:(NSData *) topicData room:(NSString *) room;
- (void) _sortRooms;
- (void) _updateTitle;
@end

@implementation CQChatRoomListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_rooms = [[NSMutableArray alloc] init];
	_matchedRooms = [_rooms retain];
	_processedRooms = [[NSMutableSet alloc] init];
	_showingUpdateRow = YES;

	[self _updateTitle];

	return self;
}

- (void) dealloc {
	_searchBar.delegate = nil;

	[_connection release];
	[_rooms release];
	[_matchedRooms release];
	[_processedRooms release];
	[_currentSearchString release];
	[_searchBar release];
	[_selectedRoom release];

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
	_searchBar.text = _currentSearchString;

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

@synthesize target = _target;

@synthesize action = _action;

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionChatRoomListUpdatedNotification object:_connection];

	id old = _connection;
	_connection = [connection retain];
	[old release];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roomListUpdated:) name:MVChatConnectionChatRoomListUpdatedNotification object:connection];

	[connection connect];
	[connection fetchChatRoomList];

	_updatePending = NO;
	[_processedRooms removeAllObjects];
	[_rooms setArray:[_connection.chatRoomListResults allKeys]];

	old = _matchedRooms;
	_matchedRooms = [_rooms retain];
	[old release];

	_showingUpdateRow = !_matchedRooms.count;

	[self _sortRooms];

	[self.tableView reloadData];

	if (_currentSearchString.length)
		[self filterRoomsWithSearchString:_currentSearchString];

	[self _updateTitle];
}

@synthesize selectedRoom = _selectedRoom;

- (void) setSelectedRoom:(NSString *) room {
	id old = _selectedRoom;
	_selectedRoom = [[_connection properNameForChatRoomNamed:room] copy];
	[old release];

	for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
		NSString *rowRoom = [_matchedRooms objectAtIndex:indexPath.row];
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

	NSArray *previousRoomsArray = [_matchedRooms retain];

	if (searchString.length) {
		id old = _matchedRooms;
		_matchedRooms = [[NSMutableArray alloc] init];
		[old release];

		NSArray *searchArray = (_currentSearchString && [searchString hasPrefix:_currentSearchString] ? previousRoomsArray : _rooms);
		for (NSString *room in searchArray) {
			if (![room hasCaseInsensitiveSubstring:searchString])
				continue;
			[_matchedRooms addObject:room];
		}
	} else {
		id old = _matchedRooms;
		_matchedRooms = [_rooms retain];
		[old release];
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

		[indexPaths release];
		indexPaths = [[NSMutableArray alloc] init];

		for (NSString *room in _matchedRooms) {
			if (![previousRoomsSet containsObject:room])
				[indexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
			++index;
		}

		[self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];

		[self.tableView endUpdates];

		[indexPaths release];
		[previousRoomsSet release];
		[matchedRoomsSet release];
	} else {
		[self.tableView reloadData];
	}

	id old = _currentSearchString;
	_currentSearchString = [searchString copy];
	[old release];

	[self _updateTitle];

	[_searchBar becomeFirstResponder];

	[previousRoomsArray release];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return (_showingUpdateRow ? 1 : _matchedRooms.count);
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (_showingUpdateRow) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView withIdentifier:@"Updating"];
		cell.text = NSLocalizedString(@"Updating Chat Room List...", @"Updating chat room list label");
		cell.selectionStyle = UITableViewCellSelectionStyleNone;

		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		[spinner startAnimating];

		cell.accessoryView = spinner;

		[spinner release];

		return cell;
	}

	NSString *room = [_matchedRooms objectAtIndex:indexPath.row];
	NSMutableDictionary *info = [_connection.chatRoomListResults objectForKey:room];

	CQChatRoomInfoTableCell *cell = [CQChatRoomInfoTableCell reusableTableViewCellInTableView:tableView];

	if ([room isEqualToString:_selectedRoom])
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else cell.accessoryType = UITableViewCellAccessoryNone;

	static BOOL firstTime = YES;
	static BOOL showFullName;
	if (firstTime) {
		showFullName = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVShowFullRoomNames"];
		firstTime = NO;
	}

	NSString *roomDisplayName = [info objectForKey:@"roomDisplayString"];
	if (![info objectForKey:@"roomDisplayString"]) {
		roomDisplayName = [_connection displayNameForChatRoomNamed:room];
		[info setObject:roomDisplayName forKey:@"roomDisplayString"];
	}

	cell.name = (showFullName ? room : roomDisplayName);
	cell.memberCount = [[info objectForKey:@"users"] unsignedIntegerValue];

	NSData *topicData = [info objectForKey:@"topic"];
	NSString *topicDisplayString = [info objectForKey:@"topicDisplayString"];
	if (!topicDisplayString && topicData.length)
		[self _processTopicData:topicData room:room];

	cell.topic = topicDisplayString;

	return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_showingUpdateRow) return nil;
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

	id old = _selectedRoom;
	_selectedRoom = [[_matchedRooms objectAtIndex:indexPath.row] copy];
	[old release];

	[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];

	if (!_target || [_target respondsToSelector:_action])
		[[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil];
}

#pragma mark -

static NSComparisonResult sortUsingMemberCount(id one, id two, void *context) {
	NSDictionary *rooms = context;
	NSDictionary *oneInfo = [rooms objectForKey:one];
	NSDictionary *twoInfo = [rooms objectForKey:two];
	NSUInteger oneUsers = [[oneInfo objectForKey:@"users"] unsignedIntegerValue];
	NSUInteger twoUsers = [[twoInfo objectForKey:@"users"] unsignedIntegerValue];

	if (oneUsers > twoUsers)
		return NSOrderedAscending;
	if (twoUsers > oneUsers)
		return NSOrderedDescending;

	return [[oneInfo objectForKey:@"roomDisplayString"] caseInsensitiveCompare:[twoInfo objectForKey:@"roomDisplayString"]];
}

- (void) _sortRooms {
	[_rooms sortUsingFunction:sortUsingMemberCount context:_connection.chatRoomListResults];
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

	NSString *formattedCount = [numberFormatter stringFromNumber:[NSNumber numberWithInteger:_matchedRooms.count]];
	self.title = [NSString stringWithFormat:NSLocalizedString(@"Rooms (%@)", @"Rooms list view title with count"), formattedCount];
}

- (void) _updateRooms {
	if (!_processedRooms.count)
		return;

	BOOL animatedInsert = (_processedRooms.count < 40);

	BOOL wasShowingUpdateRow = _showingUpdateRow;
	_showingUpdateRow = NO;

	if (wasShowingUpdateRow && animatedInsert)
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];

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

		[_matchedRooms sortUsingFunction:sortUsingMemberCount context:_connection.chatRoomListResults];
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

		[indexPaths release];
	} else {
		[self.tableView reloadData];
	}

	[self _updateTitle];

	[_processedRooms removeAllObjects];

	_updatePending = NO;
}

- (void) _roomListUpdated:(NSNotification *) notification {
	NSSet *roomsAdded = [notification.userInfo objectForKey:@"added"];
	for (NSString *room in roomsAdded) {
		NSMutableDictionary *info = [_connection.chatRoomListResults objectForKey:room];
		[info setObject:[_connection displayNameForChatRoomNamed:room] forKey:@"roomDisplayString"];

		[_processedRooms addObject:room];
	}

	NSSet *roomsUpdated = [notification.userInfo objectForKey:@"updated"];
	for (NSString *room in roomsUpdated) {
		NSMutableDictionary *info = [_connection.chatRoomListResults objectForKey:room];
		[info setObject:[_connection displayNameForChatRoomNamed:room] forKey:@"roomDisplayString"];
	}

	if (_processedRooms.count)
		[self _updateRoomsSoon];
}

- (void) _topicProcessed:(CQProcessChatMessageOperation *) operation {
	NSString *room = operation.userInfo;
	NSMutableDictionary *info = [_connection.chatRoomListResults objectForKey:room];

	NSString *topicString = operation.processedMessageAsPlainText;
	if (topicString.length)
		[info setObject:topicString forKey:@"topicDisplayString"];

	for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
		NSString *rowRoom = [_matchedRooms objectAtIndex:indexPath.row];
		if (![rowRoom isEqualToString:room])
			continue;
		CQChatRoomInfoTableCell *cell = (CQChatRoomInfoTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
		cell.topic = topicString;
		break;
	}
}

- (void) _processTopicData:(NSData *) topicData room:(NSString *) room {
	if (!topicData || !room.length)
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

	[operation release];
}
@end
