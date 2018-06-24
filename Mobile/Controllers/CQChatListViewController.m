#import "CQChatListViewController.h"

#import "CQBouncerSettings.h"
#import "CQAwayStatusController.h"
#import "CQChatOrderingController.h"
#import "CQChatRoomController.h"
#import "CQChatTableCell.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQConsoleController.h"
#import "CQBouncerEditViewController.h"
#import "CQConnectionEditViewController.h"
#import "CQConnectionsNavigationController.h"
#import "CQPreferencesViewController.h"

#if ENABLE(FILE_TRANSFERS)
#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"
#endif
#import "CQConnectionTableHeaderView.h"

#import <ChatCore/MVChatUser.h>

#import "NSNotificationAdditions.h"

static BOOL showsChatIcons;

#define ConnectSheetTag 10
#define DisconnectSheetTag 20

NS_ASSUME_NONNULL_BEGIN

@interface CQChatListViewController () <CQActionSheetDelegate, UIViewControllerPreviewingDelegate>
@end

@implementation CQChatListViewController {
	id <UIViewControllerPreviewing> _previewingContext;
	CQActionSheet *_currentConnectionActionSheet;
	CQActionSheet *_currentChatViewActionSheet;
	id <CQActionSheetDelegate> _currentChatViewActionSheetDelegate;
	id <CQChatViewController> _previousSelectedChatViewController;
	BOOL _needsUpdate;
	BOOL _ignoreNotifications;
	NSTimer *_connectTimeUpdateTimer;
	NSMapTable *_headerViewsForConnections;
	NSMapTable *_connectionsForHeaderViews;
	NSMapTable *_indexPathsForChatControllers; // never in editing state
}

+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	showsChatIcons = [[CQSettingsController settingsController] boolForKey:@"CQShowsChatIcons"];
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Manage chats.", @"Voiceover manage chats label");

	self.editButtonItem.possibleTitles = [NSSet setWithObjects:NSLocalizedString(@"Manage", @"Manage button title"), NSLocalizedString(@"Done", @"Done button title"), nil];
	self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");

	[self.navigationItem setRightBarButtonItem:self.editButtonItem animated:[self isViewLoaded]];

	UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showPreferences:)];
	self.navigationItem.leftBarButtonItem = settingsItem;
	self.navigationItem.leftBarButtonItem.accessibilityLabel = NSLocalizedString(@"Show Preferences.", @"Voiceover show preferences label");

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_addedChatViewController:) name:CQChatControllerAddedChatViewControllerNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_connectionRemoved:) name:CQConnectionsControllerRemovedConnectionNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshConnectionChatCells:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshConnectionChatCells:) name:MVChatConnectionDidDisconnectNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomPartedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomKickedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatUserNicknameChangedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatUserStatusChangedNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_unreadCountChanged) name:CQChatControllerChangedTotalImportantUnreadCountNotification object:nil];

#if ENABLE(FILE_TRANSFERS)
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshFileTransferCell:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshFileTransferCell:) name:MVFileTransferErrorOccurredNotification object:nil];
#endif

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_updateMessagePreview:) name:CQChatViewControllerRecentMessagesUpdatedNotification object:nil];

#if ENABLE(FILE_TRANSFERS)
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVDownloadFileTransferOfferNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVFileTransferErrorOccurredNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVFileTransferStartedNotification object:nil];
#endif

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameRejectedNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidDisconnectNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_connectionAdded:) name:CQConnectionsControllerAddedConnectionNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_connectionChanged:) name:CQConnectionsControllerChangedConnectionNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_connectionMoved:) name:CQConnectionsControllerMovedConnectionNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_bouncerAdded:) name:CQConnectionsControllerAddedBouncerSettingsNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_bouncerRemoved:) name:CQConnectionsControllerRemovedBouncerSettingsNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_updateUnreadMessages:) name:CQChatViewControllerUnreadMessagesUpdatedNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_connectionDidConnect:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_chatOrderingControllerDidChangeOrdering:) name:CQChatOrderingControllerDidChangeOrderingNotification object:nil];

	_needsUpdate = YES;
	_headerViewsForConnections = [NSMapTable weakToStrongObjectsMapTable];
	_connectionsForHeaderViews = [NSMapTable strongToWeakObjectsMapTable];
	_indexPathsForChatControllers = [NSMapTable strongToStrongObjectsMapTable];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[self unregisterForPreviewingWithContext:_previewingContext];
}

#pragma mark -

#if ENABLE(FILE_TRANSFERS)
static NSInteger sectionIndexForTransfers() {
	return [CQConnectionsController defaultController].bouncers.count + [CQConnectionsController defaultController].directConnections.count;
}
#endif

static id <CQChatViewController> __nullable chatControllerForIndexPath(NSIndexPath *indexPath) {
	if (!indexPath)
		return nil;

	NSArray <id <CQChatViewController>> *controllers = [CQChatOrderingController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:indexPath.section];
	if (!connection)
		return nil;

	NSArray <id <CQChatViewController>> *chatViewControllersForConnection = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];

	if ((NSInteger)chatViewControllersForConnection.count > indexPath.row)
		return chatViewControllersForConnection[indexPath.row];

	return nil;
}

static NSIndexPath * __nullable indexPathForChatController(id <CQChatViewController> controller, BOOL isEditing) {
	if (!controller)
		return nil;

	MVChatConnection *connection = controller.connection;
	NSUInteger sectionIndex = [[CQChatOrderingController defaultController] sectionIndexForConnection:connection];
	if (isEditing)
		sectionIndex++;
	NSInteger rowIndex = -1;

	NSArray <id <CQChatViewController>> *chatViewControllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];
	for (NSUInteger i = 0; i < chatViewControllers.count; i++) {
		if (chatViewControllers[i] == controller) {
			rowIndex = i;
			break;
		}
	}

	if (rowIndex == -1)
		return nil;
	return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
}

#if ENABLE(FILE_TRANSFERS)
static NSIndexPath *indexPathForFileTransferController(CQFileTransferController *controller) {
	return indexPathForChatController((id <CQChatViewController>)controller);
}
#endif

#pragma mark -

#if ENABLE(FILE_TRANSFERS)
- (void) _closeFileTransferController:(CQFileTransferController *) fileTransferController withRowAnimation:(UITableViewRowAnimation) animation {
	[[CQChatController defaultController] closeViewController:fileTransferController];

	NSArray <id <CQChatViewController>> *allFileTransferControllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];

	if (!allFileTransferControllers.count) {
		[self.tableView beginUpdates];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndexForTransfers()] withRowAnimation:animation];
		[self.tableView endUpdates];

		return;
	}

	NSMutableArray <NSIndexPath *> *rowsToDelete = [[NSMutableArray alloc] init];
	[rowsToDelete addObject:indexPathForFileTransferController(fileTransferController)];

	[self.tableView beginUpdates];
	[self.tableView deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:animation];
	[self.tableView endUpdates];

	[rowsToDelete release];
}
#endif

- (void) _closeChatViewControllers:(NSArray <id <CQChatViewController>> *) viewControllersToClose forConnection:(MVChatConnection *) connection withRowAnimation:(UITableViewRowAnimation) animation {
	NSArray <id <CQChatViewController>> *allViewControllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];

	if (!viewControllersToClose.count)
		viewControllersToClose = allViewControllers;

	BOOL hasChatController = NO;
	for (MVChatConnection *connectionToCheck in [CQConnectionsController defaultController].connections) {
		hasChatController = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connectionToCheck].count;

		if (hasChatController)
			break;
	}

	NSMutableArray <NSIndexPath *> *rowsToDelete = [[NSMutableArray alloc] init];

	for (id <CQChatViewController> chatViewController in viewControllersToClose) {
		NSIndexPath *indexPath = indexPathForChatController(chatViewController, self.editing);
		if (!indexPath)
			continue;

		[rowsToDelete addObject:indexPath];
	}

	for (id <CQChatViewController> chatViewController in viewControllersToClose)
		[[CQChatController defaultController] closeViewController:chatViewController];

	NSAssert(rowsToDelete.count == viewControllersToClose.count, @"All controllers must have a row.");

	if (rowsToDelete.count != viewControllersToClose.count) {
		[self.tableView reloadData];

		return;
	}

	NSMutableArray <NSIndexPath *> *visibleIndexes = [self.tableView.indexPathsForVisibleRows mutableCopy];
	[visibleIndexes removeObjectsInArray:rowsToDelete];

	[self.tableView beginUpdates];
	[self.tableView deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:animation];
	[self.tableView reloadRowsAtIndexPaths:visibleIndexes withRowAnimation:UITableViewRowAnimationNone];
	[self.tableView endUpdates];

	[self _refreshIndexPathForChatControllersCache];
}

- (CQChatTableCell *) _chatTableCellForController:(id <CQChatViewController>) controller {
	NSIndexPath *indexPath = indexPathForChatController(controller, self.editing);
	return (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
}

#if ENABLE(FILE_TRANSFERS)
- (CQFileTransferTableCell *) _fileTransferCellForController:(CQFileTransferController *) controller {
	NSIndexPath *indexPath = indexPathForFileTransferController(controller);
	return (CQFileTransferTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
}
#endif

- (void) _addMessagePreview:(NSDictionary *) info withEncoding:(NSStringEncoding) encoding toChatTableCell:(CQChatTableCell *) cell animated:(BOOL) animated {
	MVChatUser *user = info[@"user"];
	NSString *message = info[@"messagePlain"];
	BOOL action = [info[@"action"] boolValue];

	if (!message) {
		message = info[@"message"];
		message = [message stringByStrippingXMLTags];
		message = [message stringByDecodingXMLSpecialCharacterEntities];
	}

	if (!message)
		return;

	[cell addMessagePreview:message fromUser:user asAction:action animated:animated];
}

- (void) _addedChatViewController:(NSNotification *) notification {
	id <CQChatViewController> controller = notification.userInfo[@"controller"];
	[self chatViewControllerAdded:controller];

	if (![CQChatController defaultController].visibleChatController)
		[[CQChatController defaultController] showChatController:controller animated:NO];
}

- (void) _updateMessagePreview:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	CQDirectChatController *chatController = notification.object;
	if (!chatController)
		return;

	CQChatTableCell *cell = [self _chatTableCellForController:chatController];
	if (!cell || ![cell respondsToSelector:@selector(takeValuesFromChatViewController:)])
		return;

	[cell takeValuesFromChatViewController:chatController];

	[self _addMessagePreview:chatController.recentMessages.lastObject withEncoding:chatController.encoding toChatTableCell:cell animated:YES];
}

- (void) _updateUnreadMessages:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	CQDirectChatController *chatController = notification.object;
	if (!chatController)
		return;

	CQChatTableCell *cell = [self _chatTableCellForController:chatController];
	if (!cell || ![cell respondsToSelector:@selector(takeValuesFromChatViewController:)])
		return;

	[cell takeValuesFromChatViewController:chatController];
}

- (void) _refreshChatCell:(CQChatTableCell *) cell withController:(id <CQChatViewController>) chatViewController animated:(BOOL) animated {
	if (!cell || !chatViewController)
		return;

#if ENABLE(FILE_TRANSFERS)
	if ([chatViewController isKindOfClass:[CQFileTransferController class]])
		return;
#endif

	// final sanity check
	if (![cell respondsToSelector:@selector(takeValuesFromChatViewController:)]) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self.tableView selector:@selector(reloadData) object:nil];
		[self.tableView reloadData];
		return;
	}

	[UIView animateWithDuration:(animated ? .3 : .0) animations:^{
		[cell takeValuesFromChatViewController:chatViewController];

		if ([chatViewController isMemberOfClass:[CQDirectChatController class]] || [chatViewController isMemberOfClass:[CQConsoleController class]])
			cell.showsUserInMessagePreviews = NO;
	}];
}

#if ENABLE(FILE_TRANSFERS)
- (void) _refreshFileTransferCell:(CQFileTransferTableCell *) cell withController:(CQFileTransferController *) controller animated:(BOOL) animated {
	[UIView animateWithDuration:(animated ? .3 : .0) animations:^{
		[cell takeValuesFromController:controller];
	}];
}
#endif

- (void) _refreshConnectionChatCells:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	MVChatConnection *connection = notification.object;
	NSUInteger sectionIndex = [[CQChatOrderingController defaultController] sectionIndexForConnection:connection];
	if (sectionIndex == NSNotFound)
		return;

	if (self.editing)
		sectionIndex++;

	NSUInteger i = 0;
	for (id <CQChatViewController> controller in [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection]) {
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
		controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:target ifExists:YES];
	else if ([target isKindOfClass:[MVChatUser class]])
		controller = [[CQChatOrderingController defaultController] chatViewControllerForUser:target ifExists:YES];

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
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
#endif
		[self performSelector:@selector(_scrollToRevealSeclectedRow) withObject:nil afterDelay:0.];
}

- (void) _willBecomeActive:(NSNotification *) notification {
	[CQChatController defaultController].totalImportantUnreadCount = 0;
	_active = YES;
	[self _startUpdatingConnectTimes];
}

- (void) _willResignActive:(NSNotification *) notification {
	[self _stopUpdatingConnectTimes];

	_active = NO;
}

- (void) _unreadCountChanged {
	NSInteger totalImportantUnreadCount = [CQChatController defaultController].totalImportantUnreadCount;
	if (!_active && totalImportantUnreadCount)
		self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%tu)", @"Unread count view title, uses the view's normal title with a number"), self.title, totalImportantUnreadCount];
	else self.navigationItem.title = self.title;
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

- (void) _startUpdatingConnectTimes {
	NSAssert(_active, @"This should only be called when the view is active (visible).");

	if (!_connectTimeUpdateTimer)
		_connectTimeUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(_updateConnectTimes) userInfo:nil repeats:YES];
}

- (void) _stopUpdatingConnectTimes {
	[_connectTimeUpdateTimer invalidate];
	_connectTimeUpdateTimer = nil;
}

- (void) _updateConnectTimes {
	for (CQConnectionTableHeaderView *cell in _headerViewsForConnections.objectEnumerator.allObjects)
		[cell updateConnectTime];
}

- (void) _refreshConnection:(MVChatConnection *) connection {
	CQConnectionTableHeaderView *headerView = [_headerViewsForConnections objectForKey:connection];
	[headerView takeValuesFromConnection:connection];
}

- (void) _didChange:(NSNotification *) notification {
	if (_active)
		[self _refreshConnection:notification.object];
}

- (void) _chatOrderingControllerDidChangeOrdering:(NSNotification *) notification {
	if (!_active)
		return;

	NSMapTable *existingIndexPathsForChatControllers = [_indexPathsForChatControllers copy];

	[self _refreshIndexPathForChatControllersCache];

	NSMutableArray <NSArray <NSIndexPath *> *> *indexPathPairs = [NSMutableArray array];

	for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
		NSIndexPath *lookupIndexPath = indexPath;
		if (self.editing) {
			if (lookupIndexPath.section == 0)
				continue;

			if (lookupIndexPath.row == 0)
				continue;

			lookupIndexPath = [NSIndexPath indexPathForRow:(lookupIndexPath.row - 1) inSection:(lookupIndexPath.section - 1)];
		}

		id currentChatControllerForIndexPath = chatControllerForIndexPath(lookupIndexPath);
		if (!currentChatControllerForIndexPath)
			continue;

		NSIndexPath *savedIndexPathForChatController = [existingIndexPathsForChatControllers objectForKey:currentChatControllerForIndexPath];
		if (savedIndexPathForChatController && ![indexPath isEqual:savedIndexPathForChatController]) {
			[indexPathPairs addObject:@[ indexPath, savedIndexPathForChatController ]];
		}
	}

	if (indexPathPairs.count) {
		[self.tableView beginUpdates];
		for (NSArray <NSIndexPath *> *indexPathPair in indexPathPairs.reverseObjectEnumerator.allObjects)
			[self.tableView moveRowAtIndexPath:indexPathPair[1] toIndexPath:indexPathPair[0]];
		[self.tableView endUpdates];
	}
}

- (void) _refreshIndexPathForChatControllersCache {
	_indexPathsForChatControllers = [NSMapTable strongToStrongObjectsMapTable];

	for (NSInteger section = 0; section < self.tableView.numberOfSections; section++) {
		if (self.editing && section == 0)
			continue;

		for (NSInteger row = 0; row < [self.tableView numberOfRowsInSection:section]; row++) {
			NSIndexPath *fetchIndexPath = nil;
			if (self.editing)
				fetchIndexPath = [NSIndexPath indexPathForRow:row inSection:(section - 1)];
			else fetchIndexPath = [NSIndexPath indexPathForRow:row inSection:section];

			id chatViewController = chatControllerForIndexPath(fetchIndexPath);
			[_indexPathsForChatControllers setObject:[NSIndexPath indexPathForRow:row inSection:section] forKey:chatViewController];
		}
	}
}

- (void) _connectionAdded:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	[self connectionAdded:notification.userInfo[@"connection"]];
}

- (void) _connectionChanged:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	[self _refreshConnection:notification.userInfo[@"connection"]];
}

- (void) _connectionDidConnect:(NSNotification *) notification {
	if (![self isViewLoaded])
		return;

	// Force UITableView to reload section headers. If we are in an editing state, this will make the tableview display the (i) button
	// correctly, rather than showing the connection timer label.
	if (self.editing) {
		[self.tableView reloadData];
		[self.tableView beginUpdates];
		[self.tableView endUpdates];
	}
}

- (void) _connectionRemoved:(NSNotification *) notification {
	[self.tableView reloadData];
	[self.tableView beginUpdates];
	[self.tableView endUpdates];
}

- (void) _connectionMoved:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	NSUInteger index = [notification.userInfo[@"index"] unsignedIntegerValue];
	NSUInteger oldIndex = [notification.userInfo[@"oldIndex"] unsignedIntegerValue];
	[self connectionMovedFromSection:oldIndex toSection:index];
}

- (void) _bouncerAdded:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	[self bouncerSettingsAdded:notification.userInfo[@"bouncerSettings"]];
}

- (void) _bouncerRemoved:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	NSUInteger index = [notification.userInfo[@"index"] unsignedIntegerValue];
	[self bouncerSettingsRemovedAtIndex:index];
}

#pragma mark -

- (void) connectionAdded:(MVChatConnection *) connection {
	NSInteger sectionIndex = [[CQChatOrderingController defaultController] sectionIndexForConnection:connection];
	if (sectionIndex == -1)
		return;

	if (self.editing)
		sectionIndex++;

	// this happens in situations where bouncers send lots of data in rapid succession, or bouncer hostnames + usernames are small
	// and we have multiple bouncers to parse/insert at once
	__strong __typeof__((self.tableView.dataSource)) dataSource = self.tableView.dataSource;
	if ([dataSource numberOfSectionsInTableView:self.tableView] > sectionIndex) {
		[self.tableView reloadData];
		[self _refreshIndexPathForChatControllersCache];
		return;
	}

	[self.tableView beginUpdates];
	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
	[self.tableView endUpdates];

	[self _refreshIndexPathForChatControllersCache];
}

- (void) connectionRemovedAtSection:(NSInteger) section {
	[self.tableView beginUpdates];
	[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];
	[self.tableView endUpdates];

	[self _refreshIndexPathForChatControllersCache];
}

- (void) connectionMovedFromSection:(NSInteger) oldSection toSection:(NSInteger) newSection {
	[self.tableView beginUpdates];
	[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:oldSection] withRowAnimation:(newSection > oldSection ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop)];
	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:newSection] withRowAnimation:(newSection > oldSection ? UITableViewRowAnimationTop : UITableViewRowAnimationBottom)];
	[self.tableView endUpdates];

	[self _refreshIndexPathForChatControllersCache];
}

#pragma mark -

- (void) bouncerSettingsAdded:(CQBouncerSettings *) bouncer {
	NSUInteger section = [[CQChatOrderingController defaultController] sectionIndexForConnection:bouncer];
	[self.tableView beginUpdates];
	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];
	[self.tableView endUpdates];

	[self _refreshIndexPathForChatControllersCache];
}

- (void) bouncerSettingsRemovedAtIndex:(NSUInteger) index {
	NSParameterAssert(index != NSNotFound);
	if (index == NSNotFound)
		return;

	NSUInteger section = index + 1;
	[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];

	[self _refreshIndexPathForChatControllersCache];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.allowsSelectionDuringEditing = self.view.window.isFullscreen;
	self.clearsSelectionOnViewWillAppear = !self.view.window.isFullscreen;

	[self.tableView hideEmptyCells];
}

- (void) viewWillAppear:(BOOL) animated {
	_active = YES;

	[self _updateConnectTimes];
	[self _startUpdatingConnectTimes];

	[self _refreshIndexPathForChatControllersCache];

	[CQChatController defaultController].totalImportantUnreadCount = 0;
	[[CQChatController defaultController] visibleChatControllerWasHidden];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

	[super viewWillAppear:animated];

	// reload data, as the unread counts may be inaccurate due to swiping to change rooms
	[self.tableView reloadData];

	self.navigationController.navigationBar.barTintColor = nil;
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];

	[self _stopUpdatingConnectTimes];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	_active = NO;
}

- (void) traitCollectionDidChange:(nullable UITraitCollection *) previousTraitCollection {
	self.tableView.allowsSelectionDuringEditing = self.view.window.isFullscreen;
	self.clearsSelectionOnViewWillAppear = !self.view.window.isFullscreen;

	if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
		_previewingContext = [self registerForPreviewingWithDelegate:self sourceView:self.view.window];
	} else if (_previewingContext) {
		[self unregisterForPreviewingWithContext:_previewingContext];
	}
}

#pragma mark -

- (void) chatViewControllerAdded:(id) controller {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	NSIndexPath *changedIndexPath = indexPathForChatController(controller, self.editing);
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	if (selectedIndexPath && changedIndexPath.section == selectedIndexPath.section)
		[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	[self.tableView beginUpdates];
	[self.tableView insertRowsAtIndexPaths:@[changedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
	[self.tableView endUpdates];

	if (selectedIndexPath && changedIndexPath.section == selectedIndexPath.section) {
		if (changedIndexPath.row <= selectedIndexPath.row)
			selectedIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row + 1 inSection:selectedIndexPath.section];
		[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	}

	[self _refreshIndexPathForChatControllersCache];
}

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll {
	if (!self.tableView.numberOfSections || _needsUpdate) {
		[self.tableView reloadData];
		_needsUpdate = NO;
	}

	NSIndexPath *indexPath = indexPathForChatController(controller, self.editing);
	if (!indexPath)
		return;

	[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionNone animated:animatedScroll];
	[self.tableView selectRowAtIndexPath:indexPath animated:animatedSelection scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	if (editing == self.editing)
		return;

	[super setEditing:editing animated:animated];
	[self.tableView setEditing:editing animated:animated];

	[self _refreshIndexPathForChatControllersCache];

	if (!editing) // fix the button resets itself back to "Edit", despite the possibleTitle being set to "Manage" on iOS 7.x
		self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");

	[self.tableView beginUpdates];
	if (editing) {
		NSMutableArray <NSIndexPath *> *rowsToInsert = [NSMutableArray array];

		for (NSInteger i = 1; i < [self numberOfSectionsInTableView:self.tableView]; i++) {
			id connection = [[CQChatOrderingController defaultController] connectionAtIndex:(i - 1)];
			if ([connection isKindOfClass:[MVChatConnection class]])
				[rowsToInsert addObject:[NSIndexPath indexPathForRow:0 inSection:i]];
		}

		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
		[self.tableView insertRowsAtIndexPaths:rowsToInsert withRowAnimation:UITableViewRowAnimationMiddle];
	} else {
		NSMutableArray <NSIndexPath *> *rowsToRemove = [NSMutableArray array];

		for (NSInteger i = 1; i < self.tableView.numberOfSections; i++) {
			id connection = [[CQChatOrderingController defaultController] connectionAtIndex:(i - 1)];
			if ([connection isKindOfClass:[MVChatConnection class]])
				[rowsToRemove addObject:[NSIndexPath indexPathForRow:0 inSection:i]];
		}

		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationMiddle];
		[self.tableView deleteRowsAtIndexPaths:rowsToRemove withRowAnimation:UITableViewRowAnimationMiddle];
	}
	[self.tableView endUpdates];
}

#pragma mark -

- (void) actionSheet:(CQActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (actionSheet == _currentChatViewActionSheet) {
		if ([_currentChatViewActionSheetDelegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)])
			[_currentChatViewActionSheetDelegate actionSheet:actionSheet clickedButtonAtIndex:buttonIndex];

		_currentChatViewActionSheetDelegate = nil;
		_currentChatViewActionSheet = nil;

		return;
	}

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (actionSheet == _currentConnectionActionSheet) {
		MVChatConnection *connection = [actionSheet associatedObjectForKey:@"connection"];

		if (actionSheet.tag == ConnectSheetTag) {
			[connection cancelPendingReconnectAttempts];

			if (buttonIndex == 0) {
				connection.temporaryDirectConnection = NO;
				[connection connect];
			} else if (buttonIndex == 1) {
				[[CQChatController defaultController] showConsoleForConnection:connection];
			} else if (buttonIndex == 2 && (connection.temporaryDirectConnection || !connection.directConnection))
				[connection connectDirectly];
		} else if (actionSheet.tag == DisconnectSheetTag) {
			if (buttonIndex == actionSheet.destructiveButtonIndex) {
				if (connection.directConnection) {
					NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
					[connection disconnectWithReason:quitMessageString];
				} else [connection sendRawMessageImmediatelyWithComponents:@"SQUIT :", [MVChatConnection defaultQuitMessage], nil];
			} else if (!connection.directConnection && buttonIndex == 0) {
				NSAttributedString *quitMessageString = [[NSAttributedString alloc] initWithString:[MVChatConnection defaultQuitMessage]];
				[connection disconnectWithReason:quitMessageString];
			} else if (buttonIndex == 1) {
				[[CQChatController defaultController] showConsoleForConnection:connection];
			} else if (connection.connected) {
				if (connection.awayStatusMessage) {
					connection.awayStatusMessage = nil;
				} else {
					CQAwayStatusController *awayStatusController = [[CQAwayStatusController alloc] init];
					awayStatusController.connection = connection;

					[[CQColloquyApplication sharedApplication] presentModalViewController:awayStatusController animated:YES];
				}
			}
		}

		[self _refreshConnection:connection];

		return;
	}
}

#pragma mark -

#if ENABLE(FILE_TRANSFERS)
- (UIViewController *) documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *) controller {
	return self;
}

- (BOOL) documentInteractionController:(UIDocumentInteractionController *) controller canPerformAction:(SEL) action {
	if (action == @selector(print:) && [UIPrintInteractionController canPrintURL:controller.URL])
		return YES;
	return NO;
}
#endif

#pragma mark -


- (nullable UIViewController *) previewingContext:(id <UIViewControllerPreviewing>) previewingContext viewControllerForLocation:(CGPoint) location {
	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
	if (!indexPath)
		return nil;

	id <CQChatViewController> chatController = chatControllerForIndexPath(indexPath);
	if (![chatController respondsToSelector:@selector(previewableViewController)])
		return nil; // eg: file transfers

	if ([chatController respondsToSelector:@selector(markAsRead)])
		[chatController markAsRead];

	UIViewController *viewController = chatController.previewableViewController;
	[viewController associateObject:chatController forKey:@"chatController"];
	return viewController;
}

- (void) previewingContext:(id <UIViewControllerPreviewing>) previewingContext commitViewController:(UIViewController *) viewControllerToCommit {
	[[CQChatController defaultController] showChatController:(id <CQChatViewController>)[viewControllerToCommit associatedObjectForKey:@"chatController"] animated:YES];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	NSInteger numberOfSections = [CQConnectionsController defaultController].connections.count;
	numberOfSections += [CQConnectionsController defaultController].bouncers.count;

	if (self.editing)
		numberOfSections++;

	return numberOfSections;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (self.editing) {
		if (section == 0)
			return 1;
		section--;
	}

	id connection = [[CQChatOrderingController defaultController] connectionAtIndex:section];
	if ([connection isKindOfClass:[CQBouncerSettings class]])
		return 0;

	if (connection) {
		NSInteger numberOfRowsInSection = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection].count;
		if (self.editing)
			numberOfRowsInSection++;
		return numberOfRowsInSection;
	}
#if ENABLE(FILE_TRANSFERS)
	return [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]].count;
#else
	return 0;
#endif
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing) {
		if (indexPath.section == 0) {
			UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
			cell.textLabel.text = NSLocalizedString(@"Add New Connection", @"Add New Connection");

			return cell;
		}

		if (indexPath.row == 0) {
			UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
			cell.textLabel.text = NSLocalizedString(@"Add New Chat", @"Add New Chat");
			return cell;
		}

		// otherwise, adjust the index to adjust for the 'add new connection' and 'add new chat' cells
		indexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];
	}

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
#if ENABLE(FILE_TRANSFERS)
	if (chatViewController && ![chatViewController isKindOfClass:[CQFileTransferController class]]) {
#else
	if (!chatViewController)
		__builtin_unreachable();
#endif
		CQChatTableCell *cell = [CQChatTableCell reusableTableViewCellInTableView:tableView];

		cell.showsIcon = showsChatIcons;

		[self _refreshChatCell:cell withController:chatViewController animated:NO];

		if ([chatViewController isKindOfClass:[CQDirectChatController class]]) {
			CQDirectChatController *directChatViewController = (CQDirectChatController *)chatViewController;
			NSArray <NSDictionary *> *recentMessages = directChatViewController.recentMessages;

			NSUInteger capacity = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQPreviewLinesCount"];;
			NSMutableArray <NSDictionary *> *previewMessages = [[NSMutableArray alloc] initWithCapacity:capacity];

			for (NSInteger i = (recentMessages.count - 1); i >= 0 && previewMessages.count < capacity; --i) {
				NSDictionary *message = recentMessages[i];
				MVChatUser *user = message[@"user"];
				if (!user.localUser) [previewMessages insertObject:message atIndex:0];
			}

			for (NSDictionary *message in previewMessages)
				[self _addMessagePreview:message withEncoding:directChatViewController.encoding toChatTableCell:cell animated:NO];
		}

		return cell;
#if ENABLE(FILE_TRANSFERS)
	}

	NSArray <id <CQChatViewController>> *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

	CQFileTransferTableCell *cell = (CQFileTransferTableCell *)[tableView dequeueReusableCellWithIdentifier:@"FileTransferTableCell"];
	if (!cell) {
		UINib *nib = [UINib nibWithNibName:@"FileTransferTableCell" bundle:[NSBundle mainBundle]];

		for (id object in [nib instantiateWithOwner:self options:nil]) {
			if ([object isKindOfClass:[CQFileTransferTableCell class]]) {
				cell = object;
				break;
			}
		}
	}

	cell.showsIcon = showsChatIcons;

	[self _refreshFileTransferCell:cell withController:controller animated:NO];

	return cell;
#endif
}

- (CGFloat) tableView:(UITableView *) tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing && (indexPath.section == 0 || indexPath.row == 0))
		return 62.;

	NSUInteger numberOfLines = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQPreviewLinesCount"];
	CGFloat suggestedHeight = (numberOfLines * [[CQChatTableCell previewLabelFont] lineHeight]) + [[CQChatTableCell nameLabelFont] lineHeight] + 7;
	return fmax(suggestedHeight, 62.);
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing) {
		if (indexPath.section == 0 || indexPath.row == 0)
			return UITableViewCellEditingStyleInsert;
		indexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];
	}
	if (chatControllerForIndexPath(indexPath) == nil)
		return UITableViewCellEditingStyleInsert;
	return UITableViewCellEditingStyleDelete;
}

- (NSArray <UITableViewRowAction *> *__nullable) tableView:(UITableView *) tableView editActionsForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing) {
		if (indexPath.section == 0 || indexPath.row == 0)
			return nil;
		indexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];
	}

	void (^partRoom)(id <CQChatViewController>) = ^(id <CQChatViewController> chatViewController) {
		CQChatRoomController *chatRoomController = (CQChatRoomController *)chatViewController;
		[chatRoomController part];
	};

	UITableViewRowAction *leaveAction = nil;
	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (!chatViewController)
		return nil;

	BOOL canPartRoom = ([chatViewController isMemberOfClass:[CQChatRoomController class]] && chatViewController.available);
	if (canPartRoom) {
		leaveAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:NSLocalizedString(@"Leave", @"Leave confirmation button title") handler:^(UITableViewRowAction *action, NSIndexPath *actionIndexPath) {
			partRoom(chatViewController);
			[tableView updateCellAtIndexPath:actionIndexPath withAnimation:UITableViewRowAnimationFade];
		}];
	}

	UITableViewRowAction *closeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:NSLocalizedString(@"Close", @"Close confirmation button title") handler:^(UITableViewRowAction *action, NSIndexPath *actionIndexPath) {
		if (canPartRoom)
			partRoom(chatViewController);
		[self _closeChatViewControllers:@[chatViewController] forConnection:chatViewController.connection withRowAnimation:UITableViewRowAnimationAutomatic];
	}];

	if (leaveAction) {
		closeAction.backgroundColor = [UIColor colorWithWhite:(200. / 255.) alpha:1.];

		return @[ leaveAction, closeAction ];
	}

	return @[ closeAction ];
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing) {
		if (indexPath.section == 0 || indexPath.row == 0)
			return nil;
		indexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];
	}

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
#if ENABLE(FILE_TRANSFERS)
	if (chatViewController && ![chatViewController isKindOfClass:[CQFileTransferController class]]) {
#endif
		if ([chatViewController isMemberOfClass:[CQChatRoomController class]] && chatViewController.available)
			return NSLocalizedString(@"Leave", @"Leave confirmation button title");
		return NSLocalizedString(@"Close", @"Close confirmation button title");
#if ENABLE(FILE_TRANSFERS)
	}

	NSArray <id <CQChatViewController>> *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

	MVFileTransferStatus status = controller.transfer.status;
	if (status == MVFileTransferDoneStatus || status == MVFileTransferStoppedStatus)
		return NSLocalizedString(@"Close", @"Close confirmation button title");
	if (status == MVFileTransferHoldingStatus)
		return NSLocalizedString(@"Reject", @"Reject confirmation button title");
	return NSLocalizedString(@"Stop", @"Stop confirmation button title");
#endif
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	CGRect cellRect = [tableView.superview convertRect:[self.tableView rectForRowAtIndexPath:indexPath] fromView:tableView];
	CGPoint midpointOfRect = CGPointMake(CGRectGetMidX(cellRect), CGRectGetMidY(cellRect));

	NSIndexPath *chatIndexPath = nil;
	if (self.editing) {
		if (indexPath.section == 0) {
			[[CQConnectionsController defaultController] showNewConnectionPromptFromPoint:midpointOfRect];
			return;
		}

		if (indexPath.row == 0) {
			MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:(indexPath.section - 1)];
			[[CQChatController defaultController] showNewChatActionSheetForConnection:connection fromPoint:midpointOfRect];
			return;
		}

		chatIndexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];
	} else chatIndexPath = indexPath;

	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(chatIndexPath);
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

#if ENABLE(FILE_TRANSFERS)
	if ([chatViewController isKindOfClass:[CQFileTransferController class]]) {
		CQFileTransferController *fileTransferController = (CQFileTransferController *)chatViewController;
		switch (fileTransferController.transfer.status) {
		case MVFileTransferStoppedStatus:
		case MVFileTransferErrorStatus:
		case MVFileTransferDoneStatus:
			[self _closeFileTransferController:fileTransferController withRowAnimation:UITableViewRowAnimationRight];
			break;
		case MVFileTransferNormalStatus:
		case MVFileTransferHoldingStatus:
		default:
			[fileTransferController.transfer cancel];
			[self.tableView updateCellAtIndexPath:indexPath withAnimation:UITableViewRowAnimationFade];
			break;
		}
		return;
	}
#endif

	[self _closeChatViewControllers:@[chatViewController] forConnection:chatViewController.connection withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark -

- (CGFloat) tableView:(UITableView *) tableView heightForHeaderInSection:(NSInteger) section {
	if (self.editing && section == 0)
		return 0.;
	return 44.;
}

- (UIView *__nullable) tableView:(UITableView *) tableView viewForHeaderInSection:(NSInteger) section {
	if (self.editing) {
		if (section == 0)
			return nil;
		section--;
	}

	MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:section];
	if (!connection)
		return nil;

	CQConnectionTableHeaderView *tableHeaderView = [_headerViewsForConnections objectForKey:connection];
	if (tableHeaderView == nil) {
		tableHeaderView = [[CQConnectionTableHeaderView alloc] initWithReuseIdentifier:nil];
		tableHeaderView.tintColor = [UIApplication sharedApplication].keyWindow.tintColor;

		__weak __typeof__((self)) weakSelf = self;
		__weak __typeof__((tableView)) weakTableView = tableView;
		__weak __typeof__((tableHeaderView)) weakTableHeaderView = tableHeaderView;
		tableHeaderView.selectedConnectionHeaderView = ^{
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			__strong __typeof__((weakTableView)) strongTableView = weakTableView;
			__strong __typeof__((weakTableHeaderView)) strongTableHeaderView = weakTableHeaderView;
			NSDictionary *userInfo = @{ @"connection": connection, @"section": @(section) };
			[strongSelf tableView:strongTableView didSelectHeader:strongTableHeaderView withUserInfo:userInfo];
		};
		[_headerViewsForConnections setObject:tableHeaderView forKey:connection];
		[_connectionsForHeaderViews setObject:connection forKey:tableHeaderView];
	}
	[tableHeaderView takeValuesFromConnection:connection];

	return tableHeaderView;
}

- (void) tableView:(UITableView *) tableView didSelectHeader:(UITableViewHeaderFooterView *) headerView withUserInfo:(NSDictionary *) userInfo {
	NSInteger section = [userInfo[@"section"] integerValue];
	if (self.editing) {
		id connection = userInfo[@"connection"];
		UIViewController *editViewController = nil;
		if ([connection isKindOfClass:[MVChatConnection class]]) {
			CQConnectionEditViewController *connectionEditViewController = [[CQConnectionEditViewController alloc] init];
			connectionEditViewController.connection = connection;

			editViewController = connectionEditViewController;
		} else {
			CQBouncerEditViewController *bouncerEditViewController = [[CQBouncerEditViewController alloc] init];
			bouncerEditViewController.settings = connection;

			editViewController = bouncerEditViewController;
		}

		CQConnectionsNavigationController *navigationController = [[CQConnectionsNavigationController alloc] initWithRootViewController:editViewController];
		[[CQColloquyApplication sharedApplication] presentModalViewController:navigationController animated:YES];

		return;
	}

	MVChatConnection *connection = userInfo[@"connection"];
	if ([connection isKindOfClass:[CQBouncerSettings class]])
		 return;

	if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus) {
		_currentConnectionActionSheet = [[CQActionSheet alloc] init];
		_currentConnectionActionSheet.delegate = self;
		_currentConnectionActionSheet.tag = DisconnectSheetTag;

		_currentConnectionActionSheet.title = connection.displayName;

		if (connection.directConnection) {
			_currentConnectionActionSheet.destructiveButtonIndex = [_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
		} else {
			[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
			_currentConnectionActionSheet.destructiveButtonIndex = [_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Fully Disconnect", @"Fully Disconnect button title")];
		}

		[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Show Console", @"Show Console")];

		if (connection.connected) {
			if (connection.awayStatusMessage)
				[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Remove Away Status", "Remove Away Status button title")];
			else [_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Set Away Status…", "Set Away Status… button title")];
		}
	} else {
		_currentConnectionActionSheet = [[CQActionSheet alloc] init];
		_currentConnectionActionSheet.delegate = self;
		_currentConnectionActionSheet.tag = ConnectSheetTag;

		_currentConnectionActionSheet.title = connection.displayName;

		[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];
		[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Show Console", @"Show Console")];

		if (connection.temporaryDirectConnection || !connection.directConnection)
			[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Connect Directly", @"Connect Directly button title")];

		if (connection.waitingToReconnect)
			[_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Stop Connection Timer", @"Stop Connection Timer button title")];
	}

	[_currentConnectionActionSheet associateObject:connection forKey:@"connection"];

	_currentConnectionActionSheet.cancelButtonIndex = [_currentConnectionActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	CGRect converted = [tableView.superview convertRect:[tableView rectForHeaderInSection:section] fromView:tableView];
	CGPoint presentationPoint = CGPointZero;
	presentationPoint.x = CGRectGetMidX(converted);

	// Work around a bug on iOS 8(.1?) (on iPad?) where the tableview thinks the section header at the top of the screen
	// is scrolled because the tableview has been scrolled to the point where there are rows behind it
	NSIndexPath *firstVisibleRowIndexPath = tableView.indexPathsForVisibleRows.firstObject;
	if (section == firstVisibleRowIndexPath.section && [UIDevice currentDevice].isPadModel)
		presentationPoint.y = 86.;
	else presentationPoint.y = CGRectGetMidY(converted);

	[[CQColloquyApplication sharedApplication] showActionSheet:_currentConnectionActionSheet fromPoint:presentationPoint];
}

#pragma mark -

- (void) tableView:(UITableView *) tableView willBeginEditingRowAtIndexPath:(NSIndexPath *) indexPath {
	_previousSelectedChatViewController = chatControllerForIndexPath([self.tableView indexPathForSelectedRow]);
}

- (void) tableView:(UITableView *) tableView didEndEditingRowAtIndexPath:(nullable NSIndexPath *) indexPath {
	if (_previousSelectedChatViewController) {
		indexPath = indexPathForChatController(_previousSelectedChatViewController, self.editing);
		if (indexPath)
			[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

		_previousSelectedChatViewController = nil;
	}
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	NSIndexPath *chatIndexPath = nil;

	if (self.editing) {
		if (indexPath.section == 0) {
			CGRect cellRect = [tableView.superview convertRect:[self.tableView rectForRowAtIndexPath:indexPath] fromView:tableView];
			CGPoint midpointOfRect = CGPointMake(CGRectGetMidX(cellRect), CGRectGetMidY(cellRect));

			[[CQConnectionsController defaultController] showNewConnectionPromptFromPoint:midpointOfRect];

			return;
		} else {
			chatIndexPath = [NSIndexPath indexPathForRow:(indexPath.row - 1) inSection:(indexPath.section - 1)];

			if (indexPath.row == 0) {
				CGRect cellRect = [tableView.superview convertRect:[self.tableView rectForRowAtIndexPath:indexPath] fromView:tableView];
				CGPoint midpointOfRect = CGPointMake(CGRectGetMidX(cellRect), CGRectGetMidY(cellRect));

				MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:chatIndexPath.section];
				[[CQChatController defaultController] showNewChatActionSheetForConnection:connection fromPoint:midpointOfRect];

				return;
			}
		}
	} else {
		chatIndexPath = indexPath;
	}

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(chatIndexPath);
#if ENABLE(FILE_TRANSFERS)
	if (chatViewController && ![chatViewController isKindOfClass:[CQFileTransferController class]]) {
#endif
		[[CQChatController defaultController] showChatController:chatViewController animated:YES];

		[[CQColloquyApplication sharedApplication] dismissPopoversAnimated:YES];

#if ENABLE(FILE_TRANSFERS)
		return;
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSArray <id <CQChatViewController>> *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];
	if (controller.transfer.upload || controller.transfer.status != MVFileTransferDoneStatus)
		return;

	MVDownloadFileTransfer *downloadTransfer = (MVDownloadFileTransfer *)controller.transfer;
	UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL URLWithString:downloadTransfer.destination]];
	interactionController.delegate = self;

	[interactionController presentPreviewAnimated:[UIView areAnimationsEnabled]];
#endif
}

#pragma mark -

- (void) showPreferences:(__nullable id) sender {
//	if ([UIDevice currentDevice].systemNine)
//		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
//	else {
		CQPreferencesViewController *preferencesViewController = [[CQPreferencesViewController alloc] init];

		[[CQColloquyApplication sharedApplication] presentModalViewController:preferencesViewController animated:[UIView areAnimationsEnabled]];
//	}
}
@end

NS_ASSUME_NONNULL_END
