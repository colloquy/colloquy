#import "CQChatListViewController.h"

#import "CQActionSheet.h"
#import "CQBouncerSettings.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"
#import "CQTableViewSectionHeader.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

static BOOL showsChatIcons;

@implementation CQChatListViewController
+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	showsChatIcons = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowsChatIcons"];
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:[CQChatController defaultController] action:@selector(showNewChatActionSheet:)];
	self.navigationItem.leftBarButtonItem = addItem;
	[addItem release];
	
	self.navigationItem.leftBarButtonItem.accessibilityLabel = NSLocalizedString(@"New chat.", @"Voiceover new chat label");
	self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Manage chats.", @"Voiceover manage chats label");

	self.editButtonItem.possibleTitles = [NSSet setWithObjects:NSLocalizedString(@"Manage", @"Manage button title"), NSLocalizedString(@"Done", @"Done button title"), nil];
	self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");
	self.navigationItem.rightBarButtonItem = self.editButtonItem;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_addedChatViewController:) name:CQChatControllerAddedChatViewControllerNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionRemoved:) name:CQConnectionsControllerRemovedConnectionNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshConnectionChatCells:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshConnectionChatCells:) name:MVChatConnectionDidDisconnectNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomPartedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomKickedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatUserNicknameChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatUserStatusChangedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_unreadCountChanged) name:CQChatControllerChangedTotalImportantUnreadCountNotification object:nil];

#if ENABLE(FILE_TRANSFERS)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshFileTransferCell:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshFileTransferCell:) name:MVFileTransferErrorOccurredNotification object:nil];
#endif

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateMessagePreview:) name:CQChatViewControllerRecentMessagesUpdatedNotification object:nil];

	if ([[UIDevice currentDevice] isPadModel]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateUnreadMessages:) name:CQChatViewControllerUnreadMessagesUpdatedNotification object:nil];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_previousSelectedChatViewController release];
	[_longPressGestureRecognizer release];
	[_currentChatViewActionSheet release];

	[super dealloc];
}

#pragma mark -

static MVChatConnection *connectionForSection(NSUInteger section) {
	NSUInteger workingCount = [CQConnectionsController defaultController].directConnections.count;
	if (section <= workingCount)
		return [[CQConnectionsController defaultController].directConnections objectAtIndex:section];

	for (CQBouncerSettings *settings in [CQConnectionsController defaultController].bouncers) {
		for (MVChatConnection *connection in [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier]) {
			workingCount++;

			if (workingCount == section)
				return connection;
		}
	}

	return nil;
}
 
static NSUInteger sectionIndexForConnection(MVChatConnection *connection) {
	NSUInteger sectionIndex = [[CQConnectionsController defaultController].directConnections indexOfObjectIdenticalTo:connection];
	if (sectionIndex != NSNotFound)
		return sectionIndex;

	for (CQBouncerSettings *settings in [CQConnectionsController defaultController].bouncers) {
		NSArray *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier];
		sectionIndex = [connections indexOfObjectIdenticalTo:connection];

		if (sectionIndex != NSNotFound)
			return sectionIndex;
	}

	return NSNotFound;
}

static id <CQChatViewController> chatControllerForIndexPath(NSIndexPath *indexPath) {
	if (!indexPath)
		return nil;

	MVChatConnection *connection = connectionForSection(indexPath.section);
	if (connection) {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
		if (indexPath.row < controllers.count)
			return [controllers objectAtIndex:indexPath.row];
	}

#if ENABLE(FILE_TRANSFERS)
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	if (indexPath.row < controllers.count)
		return [controllers objectAtIndex:indexPath.row];
#else
	return nil;
#endif
}

static NSIndexPath *indexPathForChatController(id <CQChatViewController> controller) {
	if (!controller)
		return nil;

	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *connection = nil;
#if ENABLE(FILE_TRANSFERS)
	if ([controller conformsToProtocol:@protocol(CQChatViewController)])
#endif
		connection = ((id <CQChatViewController>) controller).connection;

	NSUInteger rowIndex = 0;

	for (id <CQChatViewController> chatViewController in controllers) {
#if ENABLE(FILE_TRANSFERS)
		if ([chatViewController conformsToProtocol:@protocol(CQChatViewController)]) {
#endif
			if (chatViewController == controller)
				return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndexForConnection(chatViewController.connection)];

			if (chatViewController.connection == connection && chatViewController != controller)
				++rowIndex;
#if ENABLE(FILE_TRANSFERS)
		} else {
			if (chatViewController == controller)
				return [NSIndexPath indexPathForRow:rowIndex inSection:chatViewController.connection + 1];
			++rowIndex;
		}
#endif
	}

	return nil;
}

#pragma mark -

- (void) _closeChatViewControllers:(NSArray *) viewControllersToClose forConnection:(MVChatConnection *) connection withRowAnimation:(UITableViewRowAnimation) animation {
	if (!_active) {
		for (id <CQChatViewController> chatViewController in viewControllersToClose)
			[[CQChatController defaultController] closeViewController:chatViewController];

		_needsUpdate = YES;
		return;
	}

	NSArray *allViewControllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];

	if (!viewControllersToClose.count)
		viewControllersToClose = allViewControllers;

	if ([viewControllersToClose isEqualToArray:allViewControllers]) {
		NSUInteger connectionSection = sectionIndexForConnection(connection);
		if (connectionSection == NSNotFound)
			return;

		for (id <CQChatViewController> chatViewController in viewControllersToClose)
			[[CQChatController defaultController] closeViewController:chatViewController];

		[self.tableView beginUpdates];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:connectionSection] withRowAnimation:animation];
		if (![CQChatController defaultController].chatViewControllers.count)
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];

		return;
	}

	NSMutableArray *rowsToDelete = [[NSMutableArray alloc] init];

	for (id <CQChatViewController> chatViewController in viewControllersToClose) {
		NSIndexPath *indexPath = indexPathForChatController(chatViewController);
		if (!indexPath)
			continue;

		[rowsToDelete addObject:indexPath];
	}

	if (rowsToDelete.count) {
		for (id <CQChatViewController> chatViewController in viewControllersToClose)
			[[CQChatController defaultController] closeViewController:chatViewController];

		[self.tableView deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:animation];
	}

	[rowsToDelete release];
}

- (CQChatTableCell *) _chatTableCellForController:(id <CQChatViewController>) controller {
	NSIndexPath *indexPath = indexPathForChatController(controller);
	return (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
}

#if ENABLE(FILE_TRANSFERS)
- (CQFileTransferTableCell *) _fileTransferCellForController:(CQFileTransferController *) controller {
	NSIndexPath *indexPath = indexPathForChatController(controller);
	return (CQFileTransferTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
}
#endif

- (void) _addMessagePreview:(NSDictionary *) info withEncoding:(NSStringEncoding) encoding toChatTableCell:(CQChatTableCell *) cell animated:(BOOL) animated {
	MVChatUser *user = [info objectForKey:@"user"];
	NSString *message = [info objectForKey:@"messagePlain"];
	BOOL action = [[info objectForKey:@"action"] boolValue];

	if (!message) {
		message = [info objectForKey:@"message"];
		message = [message stringByStrippingXMLTags];
		message = [message stringByDecodingXMLSpecialCharacterEntities];
	}

	if (!message || !user)
		return;

	[cell addMessagePreview:message fromUser:user asAction:action animated:animated];
}

- (void) _addedChatViewController:(NSNotification *) notification {
	id <CQChatViewController> controller = [notification.userInfo objectForKey:@"controller"];
	[self chatViewControllerAdded:controller];
}

- (void) _connectionRemoved:(NSNotification *) notification {
	MVChatConnection *connection = [notification.userInfo objectForKey:@"connection"];
	[self _closeChatViewControllers:nil forConnection:connection withRowAnimation:UITableViewRowAnimationTop];
}

- (void) _updateMessagePreview:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	CQDirectChatController *chatController = notification.object;
	CQChatTableCell *cell = [self _chatTableCellForController:chatController];

	cell.unreadCount = chatController.unreadCount;
	cell.importantUnreadCount = chatController.importantUnreadCount;

	[self _addMessagePreview:chatController.recentMessages.lastObject withEncoding:chatController.encoding toChatTableCell:cell animated:YES];
}

- (void) _updateUnreadMessages:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	CQDirectChatController *chatController = notification.object;
	CQChatTableCell *cell = [self _chatTableCellForController:chatController];

	cell.unreadCount = chatController.unreadCount;
	cell.importantUnreadCount = chatController.importantUnreadCount;
}

- (void) _refreshChatCell:(CQChatTableCell *) cell withController:(id <CQChatViewController>) chatViewController animated:(BOOL) animated {
	if (!cell || !chatViewController)
		return;

	if (animated)
		[UIView beginAnimations:nil context:NULL];

	[cell takeValuesFromChatViewController:chatViewController];

	if ([chatViewController isMemberOfClass:[CQDirectChatController class]])
		cell.showsUserInMessagePreviews = NO;

	if (animated)
		[UIView commitAnimations];
}

#if ENABLE(FILE_TRANSFERS)
- (void) _refreshFileTransferCell:(CQFileTransferTableCell *) cell withController:(CQFileTransferController *) controller animated:(BOOL) animated {
	if (animated)
		[UIView beginAnimations:nil context:NULL];

	[cell takeValuesFromController:controller];

	if (animated)
		[UIView commitAnimations];
}
#endif

- (void) _refreshConnectionChatCells:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	MVChatConnection *connection = notification.object;
	NSUInteger sectionIndex = sectionIndexForConnection(connection);
	if (sectionIndex == NSNotFound)
		return;

	NSUInteger i = 0;
	for (id <CQChatViewController> controller in [[CQChatController defaultController] chatViewControllersForConnection:connection]) {
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i++ inSection:sectionIndex];
		CQChatTableCell *cell = (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
		[self _refreshChatCell:cell withController:controller animated:YES];
	}
}

- (void) _refreshChatCell:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	id target = notification.object;
	id <CQChatViewController> controller = nil;
	if ([target isKindOfClass:[MVChatRoom class]])
		controller = [[CQChatController defaultController] chatViewControllerForRoom:target ifExists:YES];
	else if ([target isKindOfClass:[MVChatUser class]])
		controller = [[CQChatController defaultController] chatViewControllerForUser:target ifExists:YES];

	if (!controller)
		return;

	CQChatTableCell *cell = [self _chatTableCellForController:controller];
	[self _refreshChatCell:cell withController:controller animated:YES];
}

- (void) _scrollToRevealSeclectedRow {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath)
		[self.tableView scrollToRowAtIndexPath:selectedIndexPath atScrollPosition:UITableViewScrollPositionNone animated:YES];
}

- (void) _keyboardWillShow:(NSNotification *) notification {
	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
		[self performSelector:@selector(_scrollToRevealSeclectedRow) withObject:nil afterDelay:0.];
}

- (void) _tableWasLongPressed:(UILongPressGestureRecognizer *) gestureReconizer {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if (gestureReconizer.state != UIGestureRecognizerStateBegan)
		return;

	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[gestureReconizer locationInView:self.tableView]];
	if (!indexPath)
		return;

	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	if (!cell)
		return;

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (!chatViewController)
		return;

	if (![chatViewController respondsToSelector:@selector(actionSheet)])
		return;

	[_currentChatViewActionSheet release];
	_currentChatViewActionSheet = [[chatViewController actionSheet] retain];

	_currentChatViewActionSheetDelegate = _currentChatViewActionSheet.delegate;
	_currentChatViewActionSheet.delegate = self;

	[[CQColloquyApplication sharedApplication] showActionSheet:_currentChatViewActionSheet forSender:cell animated:YES];
#endif
}

- (void) _willBecomeActive:(NSNotification *) notification {
	[CQChatController defaultController].totalImportantUnreadCount = 0;
}

- (void) _unreadCountChanged {
	NSInteger totalImportantUnreadCount = [CQChatController defaultController].totalImportantUnreadCount;
	if (!_active && totalImportantUnreadCount) {
		self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%u)", @"Unread count view title, uses the view's normal title with a number"), self.title, totalImportantUnreadCount];
		self.parentViewController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%u", totalImportantUnreadCount];
	} else {
		self.navigationItem.title = self.title;
		self.parentViewController.tabBarItem.badgeValue = nil;
	}
}

#if ENABLE(FILE_TRANSFERS)
- (void) _refreshFileTransferCell:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	MVFileTransfer *transfer = notification.object;
	if (!transfer)
		return;

	CQFileTransferController *controller = [[CQChatController defaultController] chatViewControllerForFileTransfer:transfer ifExists:NO];
	CQFileTransferTableCell *cell = [self _fileTransferCellForController:controller];
	[self _refreshFileTransferCell:cell withController:controller animated:YES];
}
#endif

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.rowHeight = 62.;

	if ([[UIDevice currentDevice] isPadModel]) {
		[self resizeForViewInPopoverUsingTableView:self.tableView];
		self.tableView.allowsSelectionDuringEditing = YES;
		self.clearsSelectionOnViewWillAppear = NO;
	}

	if (!_longPressGestureRecognizer && [[UIDevice currentDevice].systemVersion doubleValue] >= 3.2) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
		_longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_tableWasLongPressed:)];
		_longPressGestureRecognizer.cancelsTouchesInView = NO;
		_longPressGestureRecognizer.delaysTouchesBegan = YES;
		[self.tableView addGestureRecognizer:_longPressGestureRecognizer];
#endif
	}
}

- (void) viewWillAppear:(BOOL) animated {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	if (_needsUpdate) {
		[self.tableView reloadData];
		_needsUpdate = NO;

		if (selectedIndexPath)
			[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	} else {
		id <CQChatViewController> chatViewController = chatControllerForIndexPath(selectedIndexPath);
		CQChatTableCell *cell = (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:selectedIndexPath];
		[self _refreshChatCell:cell withController:chatViewController animated:NO];	
	}

	_active = YES;

	[CQChatController defaultController].totalImportantUnreadCount = 0;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

	[super viewWillAppear:animated];

	if ([[UIDevice currentDevice] isPadModel] && UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
		_previousContentInset = self.tableView.contentInset;
		self.tableView.contentInset = UIEdgeInsetsZero;
	}
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

	if ([[UIDevice currentDevice] isPadModel] && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
		self.tableView.contentInset = _previousContentInset;
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	_active = NO;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation duration:(NSTimeInterval) duration {
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

#pragma mark -

- (void) chatViewControllerAdded:(id) controller {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	NSArray *controllers = nil;
#if ENABLE(FILE_TRANSFERS)
	if ([controller conformsToProtocol:@protocol(CQChatViewController)])
#endif
		controllers = [[CQChatController defaultController] chatViewControllersForConnection:((id <CQChatViewController>)controller).connection];
#if ENABLE(FILE_TRANSFERS)
	else if ([controller isKindOfClass:[CQFileTransferController class]])
		controllers = [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]];
#endif

	NSIndexPath *changedIndexPath = indexPathForChatController(controller);
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	if (selectedIndexPath && changedIndexPath.section == selectedIndexPath.section)
		[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (controllers.count == 1) {
		[self.tableView beginUpdates];
		if ([CQChatController defaultController].chatViewControllers.count == 1)
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:changedIndexPath.section] withRowAnimation:UITableViewRowAnimationTop];
		[self.tableView endUpdates];
	} else [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:changedIndexPath] withRowAnimation:UITableViewRowAnimationTop];

	if (selectedIndexPath && changedIndexPath.section == selectedIndexPath.section) {
		if (changedIndexPath.row <= selectedIndexPath.row)
			selectedIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row + 1 inSection:selectedIndexPath.section];
//		[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	}

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll {
	if (!self.tableView.numberOfSections || _needsUpdate) {
		[self.tableView reloadData];
		_needsUpdate = NO;
	}

	NSIndexPath *indexPath = indexPathForChatController(controller);
	[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:animatedScroll];
	[self.tableView selectRowAtIndexPath:indexPath animated:animatedSelection scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[super setEditing:editing animated:animated];

	if ([[UIDevice currentDevice] isPadModel])
		[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

	if (!editing)
		self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (actionSheet == _currentChatViewActionSheet) {
		if ([_currentChatViewActionSheetDelegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)])
			[_currentChatViewActionSheetDelegate actionSheet:actionSheet clickedButtonAtIndex:buttonIndex];

		_currentChatViewActionSheetDelegate = nil;

		[_currentChatViewActionSheet release];
		_currentChatViewActionSheet = nil;

		return;
	}

	CQTableViewSectionHeader *header = ((CQActionSheet *)actionSheet).userInfo;

	header.selected = NO;

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	MVChatConnection *connection = connectionForSection(header.section);

	if (buttonIndex == 0) {
		if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus) {
			[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
		} else {
			[connection cancelPendingReconnectAttempts];
			[connection connectAppropriately];
		}
		return;
	}

	NSMutableArray *viewsToClose = [[NSMutableArray alloc] init];
	Class classToClose = Nil;

	if (buttonIndex == 1 && [[CQChatController defaultController] connectionHasAnyChatRooms:connection])
		classToClose = [MVChatRoom class];
	else classToClose = [MVChatUser class];

	NSArray *viewControllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];

	for (id <CQChatViewController> chatViewController in viewControllers) {
		if (![chatViewController.target isKindOfClass:classToClose])
			continue;

		[viewsToClose addObject:chatViewController];
	}

	[self _closeChatViewControllers:viewsToClose forConnection:connection withRowAnimation:UITableViewRowAnimationTop];
}

#pragma mark -

- (void) tableSectionHeaderSelected:(CQTableViewSectionHeader *) header {
	NSUInteger section = header.section;

	MVChatConnection *connection = connectionForSection(section);
	if (!connection)
		return;

	header.selected = YES;

	CQActionSheet *sheet = [[CQActionSheet alloc] init];
	sheet.delegate = self;
	sheet.userInfo = header;

	if (!([[UIDevice currentDevice] isPadModel] && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)))
		sheet.title = connection.displayName;

	if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus)
		sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
	else
		[sheet addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];

	if ([[CQChatController defaultController] connectionHasAnyChatRooms:connection])
		[sheet addButtonWithTitle:NSLocalizedString(@"Close All Chat Rooms", @"Close all rooms button title")];

	if ([[CQChatController defaultController] connectionHasAnyPrivateChats:connection])	
		[sheet addButtonWithTitle:NSLocalizedString(@"Close All Private Chats", @"Close all private chats button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:header animated:YES];

	[sheet release];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return 1;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionCount = 0;

	for (id <CQChatViewController> chatViewController in controllers) {
#if ENABLE(FILE_TRANSFERS)
		if (![chatViewController conformsToProtocol:@protocol(CQChatViewController)])
			continue;
#endif

		if (chatViewController.connection != currentConnection) {
			++sectionCount;
			currentConnection = chatViewController.connection;
		}
	}

	return (sectionCount ? sectionCount : 1);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if (connection)
		return [[CQChatController defaultController] chatViewControllersForConnection:connection].count;
#if ENABLE(FILE_TRANSFERS)
	return [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]].count;
#else
	return 0;
#endif
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if (connection)
		return connection.displayName;
#if ENABLE(FILE_TRANSFERS)
	if ([[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]].count)
		return NSLocalizedString(@"File Transfers", @"File Transfers section title");
#endif
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (chatViewController) {
		CQChatTableCell *cell = [CQChatTableCell reusableTableViewCellInTableView:tableView];

		cell.showsIcon = showsChatIcons;

		[self _refreshChatCell:cell withController:chatViewController animated:NO];

		if ([chatViewController isKindOfClass:[CQDirectChatController class]]) {
			CQDirectChatController *directChatViewController = (CQDirectChatController *)chatViewController;
			NSArray *recentMessages = directChatViewController.recentMessages;
			NSMutableArray *previewMessages = [[NSMutableArray alloc] initWithCapacity:2];

			for (NSInteger i = (recentMessages.count - 1); i >= 0 && previewMessages.count < 2; --i) {
				NSDictionary *message = [recentMessages objectAtIndex:i];
				MVChatUser *user = [message objectForKey:@"user"];
				if (!user.localUser) [previewMessages insertObject:message atIndex:0];
			}

			for (NSDictionary *message in previewMessages)
				[self _addMessagePreview:message withEncoding:directChatViewController.encoding toChatTableCell:cell animated:NO];

			[previewMessages release];
		}

		return cell;
	}

#if ENABLE(FILE_TRANSFERS)
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

	CQFileTransferTableCell *cell = (CQFileTransferTableCell *)[tableView dequeueReusableCellWithIdentifier:@"FileTransferTableCell"];
	if (!cell) {
		NSArray *array = [[NSBundle mainBundle] loadNibNamed:@"FileTransferTableCell" owner:self options:nil];
		for (id object in array) {
			if ([object isKindOfClass:[CQFileTransferTableCell class]]) {
				cell = object;
				break;
			}
		}
	}

	cell.showsIcon = showsChatIcons;

	[self _refreshFileTransferCell:cell withController:controller animated:NO];

	return cell;
#else
	return nil;
#endif
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (NSString *) tableView:(UITableView *) tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *) indexPath {
	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (chatViewController) {
		if ([chatViewController isMemberOfClass:[CQChatRoomController class]] && chatViewController.available)
			return NSLocalizedString(@"Leave", @"Leave remove confirmation button title");
		return NSLocalizedString(@"Close", @"Close remove confirmation button title");
	}

#if ENABLE(FILE_TRANSFERS)
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

	MVFileTransferStatus status = controller.transfer.status;
	if (status == MVFileTransferDoneStatus || status == MVFileTransferStoppedStatus)
		return NSLocalizedString(@"Close", @"Close remove confirmation button title");
	return NSLocalizedString(@"Stop", @"Stop remove confirmation button title");
#else
	return nil;
#endif
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (!chatViewController)
		return;

	if ([chatViewController isMemberOfClass:[CQChatRoomController class]]) {
		CQChatRoomController *chatRoomController = (CQChatRoomController *)chatViewController;
		if (chatRoomController.available) {
			[chatRoomController part];
			[self.tableView updateCellAtIndexPath:indexPath withAnimation:UITableViewRowAnimationFade];
			return;
		}
	}

	[self _closeChatViewControllers:[NSArray arrayWithObject:chatViewController] forConnection:chatViewController.connection withRowAnimation:UITableViewRowAnimationRight];
}

- (CGFloat) tableView:(UITableView *) tableView heightForHeaderInSection:(NSInteger) section {
	return 22.;
}

- (UIView *) tableView:(UITableView *) tableView viewForHeaderInSection:(NSInteger) section {
	if (![CQChatController defaultController].chatViewControllers.count)
		return nil;

	CQTableViewSectionHeader *view = [[CQTableViewSectionHeader alloc] initWithFrame:CGRectZero];
	view.textLabel.text = [self tableView:tableView titleForHeaderInSection:section];
	view.section = section;
	view.disclosureImageView.hidden = YES;

	[view addTarget:self action:@selector(tableSectionHeaderSelected:) forControlEvents:UIControlEventTouchUpInside];

	return [view autorelease];
}

- (void) tableView:(UITableView *) tableView willBeginEditingRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([[UIDevice currentDevice] isPadModel])
		_previousSelectedChatViewController = [chatControllerForIndexPath([self.tableView indexPathForSelectedRow]) retain];
}

- (void) tableView:(UITableView *) tableView didEndEditingRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([[UIDevice currentDevice] isPadModel] && _previousSelectedChatViewController) {
		NSIndexPath *indexPath = indexPathForChatController(_previousSelectedChatViewController);
		if (indexPath)
			[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

		[_previousSelectedChatViewController release];
		_previousSelectedChatViewController = nil;
	}
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (!chatViewController)
		return;

	[[CQChatController defaultController] showChatController:chatViewController animated:YES];

	[[CQColloquyApplication sharedApplication] dismissPopoversAnimated:YES];
}
@end
