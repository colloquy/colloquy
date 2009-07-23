#import "CQChatRoomListViewController.h"

#import "CQChatRoomInfoTableCell.h"
#import "CQProcessChatMessageOperation.h"

#import <ChatCore/MVChatConnection.h>

static NSOperationQueue *topicProcessingQueue;

@interface CQChatRoomListViewController (CQChatRoomListViewControllerPrivate)
- (void) _processTopicData:(NSData *) topicData room:(NSString *) room;
@end

@implementation CQChatRoomListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_rooms = [[NSMutableArray alloc] init];
	_matchedRooms = [[NSMutableArray alloc] init];

	return self;
}

- (void) dealloc {
	_searchBar.delegate = nil;

	[_connection release];
	[_rooms release];
	[_matchedRooms release];
	[_currentSearchString release];
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

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionChatRoomListUpdatedNotification object:_connection];

	id old = _connection;
	_connection = [connection retain];
	[old release];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_roomListUpdated:) name:MVChatConnectionChatRoomListUpdatedNotification object:connection];

	[connection connect];
	[connection fetchChatRoomList];

	[_rooms setArray:[_connection.chatRoomListResults allKeys]];
	[_rooms sortUsingSelector:@selector(caseInsensitiveCompare:)];

	[_matchedRooms setArray:_rooms];

	[self.tableView reloadData];
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
	
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return _matchedRooms.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSString *room = [_rooms objectAtIndex:indexPath.row];
	NSMutableDictionary *info = [_connection.chatRoomListResults objectForKey:room];

	CQChatRoomInfoTableCell *cell = [CQChatRoomInfoTableCell reusableTableViewCellInTableView:tableView];

//	NSString *roomDisplayString = [info objectForKey:@"roomDisplayString"];
//	if (!roomDisplayString) {
//		roomDisplayString = [_connection displayNameForChatRoomNamed:room];
//		if (roomDisplayString)
//			[info setObject:roomDisplayString forKey:@"roomDisplayString"];
//	}

	cell.name = room;
	cell.memberCount = [[info objectForKey:@"users"] unsignedIntegerValue];

	NSString *topicDisplayString = [info objectForKey:@"topicDisplayString"];
	if (topicDisplayString) {
		cell.topic = topicDisplayString;
	} else {
		[self _processTopicData:[info objectForKey:@"topic"] room:room];
	}

	return cell;
}

#pragma mark -

- (void) _roomListUpdated:(NSNotification *) notification {
	[_rooms setArray:[_connection.chatRoomListResults allKeys]];
	[_rooms sortUsingSelector:@selector(caseInsensitiveCompare:)];

	[_matchedRooms setArray:_rooms];

	[self.tableView reloadData];
}

- (void) _topicProcessed:(CQProcessChatMessageOperation *) operation {
	NSString *room = operation.userInfo;
	NSMutableDictionary *info = [_connection.chatRoomListResults objectForKey:room];

	NSString *topicString = operation.processedMessageAsPlainText;
	if (!topicString)
		return;

	[info setObject:topicString forKey:@"topicDisplayString"];

	for (CQChatRoomInfoTableCell *cell in self.tableView.visibleCells) {
		if (![cell.name isEqualToString:room])
			continue;
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
