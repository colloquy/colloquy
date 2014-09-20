#import "CQChatListViewController.h"

#import "CQBouncerSettings.h"
#import "CQAwayStatusController.h"
#import "CQChatOrderingController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "CQConsoleController.h"
#import "CQBouncerEditViewController.h"
#import "CQConnectionEditViewController.h"
#import "CQConnectionsNavigationController.h"
#import "CQPreferencesViewController.h"
#import "CQChatCreationViewController.h"

#if ENABLE(FILE_TRANSFERS)
#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"
#endif
#import "CQTableViewSectionHeader.h"
#import "CQConnectionTableHeaderView.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

static BOOL showsChatIcons;

#define ConnectSheetTag 10
#define DisconnectSheetTag 20

@implementation CQChatListViewController
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

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

	[self userDefaultsChanged];
}

- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:[CQChatController defaultController] action:@selector(showNewChatActionSheet:)];
	self.navigationItem.rightBarButtonItem = addItem;
	self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"New chat.", @"Voiceover new chat label");

	UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showPreferences:)];
	self.navigationItem.leftBarButtonItem = settingsItem;
	self.navigationItem.leftBarButtonItem.accessibilityLabel = NSLocalizedString(@"Show Preferences.", @"Voiceover show preferences label");

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

#if ENABLE(FILE_TRANSFERS)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVDownloadFileTransferOfferNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVFileTransferErrorOccurredNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVFileTransferStartedNotification object:nil];
#endif

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameRejectedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidDisconnectNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionAdded:) name:CQConnectionsControllerAddedConnectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionChanged:) name:CQConnectionsControllerChangedConnectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionMoved:) name:CQConnectionsControllerMovedConnectionNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bouncerAdded:) name:CQConnectionsControllerAddedBouncerSettingsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bouncerRemoved:) name:CQConnectionsControllerRemovedBouncerSettingsNotification object:nil];

	if ([[UIDevice currentDevice] isPadModel]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateUnreadMessages:) name:CQChatViewControllerUnreadMessagesUpdatedNotification object:nil];
	}

	_needsUpdate = YES;
	_headerViewsForConnections = [NSMapTable weakToStrongObjectsMapTable];
	_connectionsForHeaderViews = [NSMapTable strongToWeakObjectsMapTable];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

#if ENABLE(FILE_TRANSFERS)
static NSInteger sectionIndexForTransfers() {
	return [CQConnectionsController defaultController].bouncers.count + [CQConnectionsController defaultController].directConnections.count;
}
#endif

static id <CQChatViewController> chatControllerForIndexPath(NSIndexPath *indexPath) {
	if (!indexPath)
		return nil;

	NSArray *controllers = [CQChatOrderingController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:indexPath.section];
	NSArray *chatViewControllersForConnection = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];

	if (chatViewControllersForConnection.count > indexPath.row)
		return chatViewControllersForConnection[indexPath.row];
	return nil;
}

static NSIndexPath *indexPathForChatController(id <CQChatViewController> controller, BOOL isEditing) {
	if (!controller)
		return nil;

	MVChatConnection *connection = controller.connection;
	NSUInteger sectionIndex = [[CQChatOrderingController defaultController] sectionIndexForConnection:connection];
	if (isEditing)
		sectionIndex++;
	NSUInteger rowIndex = 0;

	NSArray *chatViewControllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];
	for (NSUInteger i = 0; i < chatViewControllers.count; i++) {
		if (chatViewControllers[i] == controller) {
			rowIndex = i;
			break;
		}
	}

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

	NSArray *allFileTransferControllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];

	if (!allFileTransferControllers.count) {
		[self.tableView beginUpdates];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndexForTransfers()] withRowAnimation:animation];
		[self.tableView endUpdates];

		return;
	}

	NSMutableArray *rowsToDelete = [[NSMutableArray alloc] init];
	[rowsToDelete addObject:indexPathForFileTransferController(fileTransferController)];

	[self.tableView beginUpdates];
	[self.tableView deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:animation];
	[self.tableView endUpdates];

	[rowsToDelete release];
}
#endif

- (void) _closeChatViewControllers:(NSArray *) viewControllersToClose forConnection:(MVChatConnection *) connection withRowAnimation:(UITableViewRowAnimation) animation {
	@synchronized([CQChatOrderingController defaultController]) {
		NSArray *allViewControllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];

		if (!viewControllersToClose.count)
			viewControllersToClose = allViewControllers;

		BOOL hasChatController = NO;
		for (MVChatConnection *connection in [CQConnectionsController defaultController].connections) {
			hasChatController = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection].count;

			if (hasChatController)
				break;
		}

		if (!hasChatController)
			[self.navigationItem setRightBarButtonItem:nil animated:[self isViewLoaded]];

		if (!(allViewControllers.count - viewControllersToClose.count) && [viewControllersToClose isEqualToArray:allViewControllers]) {
			NSUInteger connectionSection = [[CQChatOrderingController defaultController] sectionIndexForConnection:connection];
			if (connectionSection == NSNotFound)
				return;

			for (id <CQChatViewController> chatViewController in viewControllersToClose)
				[[CQChatController defaultController] closeViewController:chatViewController];

			[self.tableView beginUpdates];
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:connectionSection] withRowAnimation:animation];
			if (![CQChatOrderingController defaultController].chatViewControllers.count)
				[self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
			[self.tableView endUpdates];

			return;
		}

		NSMutableArray *rowsToDelete = [[NSMutableArray alloc] init];

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

		[self.tableView beginUpdates];
		[self.tableView deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:animation];
		[self.tableView endUpdates];
	}
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

#if ENABLE(FILE_TRANSFERS)
	if ([chatViewController isKindOfClass:[CQFileTransferController class]])
		return;
#endif

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

	@synchronized([CQChatOrderingController defaultController]) {
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
}

- (void) _refreshChatCell:(NSNotification *) notification {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	@synchronized([CQChatOrderingController defaultController]) {
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
	if (gestureReconizer.state != UIGestureRecognizerStateBegan)
		return;

	if (self.editing) // do nothing, editing controls are already on screen
		return;

		CGPoint locationInView = [gestureReconizer locationInView:self.tableView];
	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:locationInView];
	if (indexPath) {
		UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
		if (!cell)
			return;

		id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
		if (!chatViewController)
			return;

		if (![chatViewController respondsToSelector:@selector(actionSheet)])
			return;

		_currentChatViewActionSheet = [chatViewController actionSheet];

		_currentChatViewActionSheetDelegate = _currentChatViewActionSheet.delegate;
		_currentChatViewActionSheet.delegate = self;

		[[CQColloquyApplication sharedApplication] showActionSheet:_currentChatViewActionSheet forSender:cell animated:YES];
	}

	for (CQConnectionTableHeaderView *header in _headerViewsForConnections.objectEnumerator.allObjects) {
		// As of iOS 7, [self.tableView hitTest:locationInView withEvent:nil] gives us the subview ov the tableheader view, not the superview's container
		if (CGRectContainsPoint(header.frame, locationInView)) {
			MVChatConnection *connection = [_connectionsForHeaderViews objectForKey:header];
			if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus) {
				_currentConnectionActionSheet = [[UIActionSheet alloc] init];
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
				_currentConnectionActionSheet = [[UIActionSheet alloc] init];
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

			[[CQColloquyApplication sharedApplication] showActionSheet:_currentConnectionActionSheet fromPoint:[gestureReconizer.view convertPoint:locationInView toView:nil]];
		}
	}
}

- (void) _willBecomeActive:(NSNotification *) notification {
	[CQChatController defaultController].totalImportantUnreadCount = 0;
	[self _startUpdatingConnectTimes];

	_active = YES;
}

- (void) _willResignActive:(NSNotification *) notification {
	[self _stopUpdatingConnectTimes];

	_active = NO;
}

- (void) _unreadCountChanged {
	NSInteger totalImportantUnreadCount = [CQChatController defaultController].totalImportantUnreadCount;
	if (!_active && totalImportantUnreadCount) {
		self.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%tu)", @"Unread count view title, uses the view's normal title with a number"), self.title, totalImportantUnreadCount];
		self.parentViewController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%tu", totalImportantUnreadCount];
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

- (void) _connectionRemoved:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	MVChatConnection *connection = notification.userInfo[@"connection"];
	[self _closeChatViewControllers:nil forConnection:connection withRowAnimation:UITableViewRowAnimationTop];

	NSUInteger section = [[CQChatOrderingController defaultController] sectionIndexForConnection:notification.userInfo[@"connection"]];
	if (section == NSNotFound)
		return;

	[self connectionRemovedAtSection:section];
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

	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
}

- (void) connectionRemovedAtSection:(NSInteger) section {
	[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];
}

- (void) connectionMovedFromSection:(NSInteger) oldSection toSection:(NSInteger) newSection {
	[self.tableView beginUpdates];
	[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:oldSection] withRowAnimation:(newSection > oldSection ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop)];
	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:newSection] withRowAnimation:(newSection > oldSection ? UITableViewRowAnimationTop : UITableViewRowAnimationBottom)];
	[self.tableView endUpdates];
}

#pragma mark -

- (void) bouncerSettingsAdded:(CQBouncerSettings *) bouncer {
	NSUInteger section = [[CQChatOrderingController defaultController] sectionIndexForConnection:bouncer];
	[self.tableView insertSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];
}

- (void) bouncerSettingsRemovedAtIndex:(NSUInteger) index {
	NSParameterAssert(index != NSNotFound);
	if (index == NSNotFound)
		return;

	NSUInteger section = index + 1;
	[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	BOOL hasChatController = NO;
	@synchronized([CQChatOrderingController defaultController]) {
		for (MVChatConnection *connection in [CQConnectionsController defaultController].connections) {
			hasChatController = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection].count;

			if (hasChatController) {
				[self.navigationItem setRightBarButtonItem:self.editButtonItem animated:YES];

				break;
			}
		}

		self.tableView.rowHeight = 62.;

		if ([[UIDevice currentDevice] isPadModel]) {
			[self resizeForViewInPopoverUsingTableView:self.tableView];
			self.tableView.allowsSelectionDuringEditing = YES;
			self.clearsSelectionOnViewWillAppear = NO;
		}

		if (!_longPressGestureRecognizer) {
			_longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_tableWasLongPressed:)];
			_longPressGestureRecognizer.cancelsTouchesInView = NO;
			_longPressGestureRecognizer.delaysTouchesBegan = YES;
			[self.tableView addGestureRecognizer:_longPressGestureRecognizer];
		}
	}
}

- (void) viewWillAppear:(BOOL) animated {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self _startUpdatingConnectTimes];

	if (_needsUpdate) {
		[self.tableView reloadData];
		_needsUpdate = NO;

//		if (selectedIndexPath)
//			[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	} else {
		id <CQChatViewController> chatViewController = chatControllerForIndexPath(selectedIndexPath);
		CQChatTableCell *cell = (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:selectedIndexPath];
		[self _refreshChatCell:cell withController:chatViewController animated:NO];	
	}

	_active = YES;

	[CQChatController defaultController].totalImportantUnreadCount = 0;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

	[super viewWillAppear:animated];

	// reload data, as the unread counts may be inaccurate due to swiping to change rooms
	[self.tableView reloadData];

	if ([self.navigationController.navigationBar respondsToSelector:@selector(setBarTintColor:)])
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

- (void) chatViewControllerAdded:(id) controller {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	@synchronized([CQChatOrderingController defaultController]) {
		self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Manage chats.", @"Voiceover manage chats label");

		self.editButtonItem.possibleTitles = [NSSet setWithObjects:NSLocalizedString(@"Manage", @"Manage button title"), NSLocalizedString(@"Done", @"Done button title"), nil];
		self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");

		[self.navigationItem setRightBarButtonItem:self.editButtonItem animated:[self isViewLoaded]];

		NSArray *controllers = nil;
		if ([controller conformsToProtocol:@protocol(CQChatViewController)])
			controllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:((id <CQChatViewController>)controller).connection];
	#if ENABLE(FILE_TRANSFERS)
		else if ([controller isKindOfClass:[CQFileTransferController class]])
			controllers = [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]];
	#endif

		NSIndexPath *changedIndexPath = indexPathForChatController(controller, self.editing);
		NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

		[self.tableView beginUpdates];
		if (selectedIndexPath && changedIndexPath.section == selectedIndexPath.section)
			[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

		[self.tableView beginUpdates];
		if (controllers.count == 1)
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:changedIndexPath.section] withRowAnimation:UITableViewRowAnimationTop];
		else [self.tableView insertRowsAtIndexPaths:@[changedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
		[self.tableView endUpdates];

		if (selectedIndexPath && changedIndexPath.section == selectedIndexPath.section) {
			if (changedIndexPath.row <= selectedIndexPath.row)
				selectedIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row + 1 inSection:selectedIndexPath.section];
			[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
		}

		if ([[UIDevice currentDevice] isPadModel])
			[self resizeForViewInPopoverUsingTableView:self.tableView];
	}
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
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[super setEditing:editing animated:animated];
	[self.tableView setEditing:editing animated:animated];

	if ([[UIDevice currentDevice] isPadModel]) {
		if (editing)
			selectedIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row inSection:selectedIndexPath.section + 1];
		else selectedIndexPath = [NSIndexPath indexPathForRow:selectedIndexPath.row inSection:selectedIndexPath.section - 1];
		[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	}

	if (!editing)
		self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");

	[self.tableView beginUpdates];
	if (editing) {
		NSMutableArray *rowsToInsert = [NSMutableArray array];

		for (NSInteger i = 1; i < [self numberOfSectionsInTableView:self.tableView]; i++)
			[rowsToInsert addObject:[NSIndexPath indexPathForRow:([self tableView:self.tableView numberOfRowsInSection:i] - 1) inSection:i]];

		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
		[self.tableView insertRowsAtIndexPaths:rowsToInsert withRowAnimation:UITableViewRowAnimationBottom];
	} else {
		NSMutableArray *rowsToRemove = [NSMutableArray array];

		for (NSInteger i = 1; i < self.tableView.numberOfSections; i++)
			[rowsToRemove addObject:[NSIndexPath indexPathForRow:([self.tableView numberOfRowsInSection:i] - 1) inSection:i]];

		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
		[self.tableView deleteRowsAtIndexPaths:rowsToRemove withRowAnimation:UITableViewRowAnimationBottom];
	}
	[self.tableView endUpdates];
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
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
				if (connection.directConnection)
					[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
				else [connection sendRawMessageImmediatelyWithComponents:@"SQUIT :", [MVChatConnection defaultQuitMessage], nil];
			} else if (!connection.directConnection && buttonIndex == 0) {
				[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
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

	//	@synchronized([CQChatOrderingController defaultController]) {
//		CQTableViewSectionHeader *header = [actionSheet associatedObjectForKey:@"userInfo"];
//
//		header.selected = NO;
//
//
//		MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:header.section];
//
//		if (buttonIndex == 0) {
//			if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus) {
//				[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
//			} else {
//				[connection cancelPendingReconnectAttempts];
//				[connection connectAppropriately];
//			}
//			return;
//		}
//
//		NSMutableArray *viewsToClose = [[NSMutableArray alloc] init];
//		Class classToClose = Nil;
//
//		if (buttonIndex == 1 && [[CQChatOrderingController defaultController] connectionHasAnyChatRooms:connection])
//			classToClose = [MVChatRoom class];
//		else classToClose = [MVChatUser class];
//
//		NSArray *viewControllers = [[CQChatOrderingController defaultController] chatViewControllersForConnection:connection];
//
//		for (id <CQChatViewController> chatViewController in viewControllers) {
//			if (![chatViewController.target isKindOfClass:classToClose])
//				continue;
//
//			[viewsToClose addObject:chatViewController];
//		}
//
//		[self _closeChatViewControllers:viewsToClose forConnection:connection withRowAnimation:UITableViewRowAnimationTop];
//	}
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

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	NSInteger numberOfSections = [CQConnectionsController defaultController].connections.count;
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

	@synchronized([CQChatOrderingController defaultController]) {
		MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:section];
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
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing) {
		if (indexPath.section == 0) {
			UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
			cell.textLabel.text = NSLocalizedString(@"New Connection", @"New Connection");

			return cell;
		}

		// otherwise, adjust the index to adjust for the 'add new connection' cell
		indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:(indexPath.section - 1)];
	}

	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
	if (self.editing && chatViewController == nil) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
		cell.textLabel.text = NSLocalizedString(@"New Chat", @"New Chat");
		return cell;
	}
#if ENABLE(FILE_TRANSFERS)
	if (chatViewController && ![chatViewController isKindOfClass:[CQFileTransferController class]]) {
#else
	if (!chatViewController)
		return nil;
#endif
		CQChatTableCell *cell = [CQChatTableCell reusableTableViewCellInTableView:tableView];

		cell.showsIcon = showsChatIcons;

		[self _refreshChatCell:cell withController:chatViewController animated:NO];

		if ([chatViewController isKindOfClass:[CQDirectChatController class]]) {
			CQDirectChatController *directChatViewController = (CQDirectChatController *)chatViewController;
			NSArray *recentMessages = directChatViewController.recentMessages;
			NSMutableArray *previewMessages = [[NSMutableArray alloc] initWithCapacity:2];

			for (NSInteger i = (recentMessages.count - 1); i >= 0 && previewMessages.count < 2; --i) {
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

	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
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

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (self.editing) {
		if (indexPath.section == 0)
			return UITableViewCellEditingStyleInsert;
		indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:(indexPath.section - 1)];
	}
	if (self.editing && chatControllerForIndexPath(indexPath) == nil)
		return UITableViewCellEditingStyleInsert;
	return UITableViewCellEditingStyleDelete;
}

- (NSString *) tableView:(UITableView *) tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *) indexPath {
	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
#if ENABLE(FILE_TRANSFERS)
	if (chatViewController && ![chatViewController isKindOfClass:[CQFileTransferController class]]) {
#endif
		if ([chatViewController isMemberOfClass:[CQChatRoomController class]] && chatViewController.available)
			return NSLocalizedString(@"Leave", @"Leave confirmation button title");
		return NSLocalizedString(@"Close", @"Close confirmation button title");
#if ENABLE(FILE_TRANSFERS)
	}

	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
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
	CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
	CGPoint midpointOfRect = CGPointMake(CGRectGetMidX(cellRect), CGRectGetMidY(cellRect));

	if (indexPath.section == 0) {
		[[CQConnectionsController defaultController] showNewConnectionPromptFromPoint:midpointOfRect];
		return;
	}

	indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:(indexPath.section - 1)];

	if (editingStyle == UITableViewCellEditingStyleInsert) {
		MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:indexPath.section];
		NSLog(@"%@", connection);
		[[CQChatController defaultController] showNewChatActionSheetForConnection:connection fromPoint:midpointOfRect];
	}

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

	[self _closeChatViewControllers:@[chatViewController] forConnection:chatViewController.connection withRowAnimation:UITableViewRowAnimationRight];
}

#pragma mark -

- (void) tableSectionHeaderSelected:(CQTableViewSectionHeader *) header {
	NSUInteger section = header.section;

	@synchronized([CQChatOrderingController defaultController]) {
		MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:section];
		if (!connection)
			return;

		header.selected = YES;

		UIActionSheet *sheet = [[UIActionSheet alloc] init];
		sheet.delegate = self;

		[sheet associateObject:header forKey:@"userInfo"];

		if (!([[UIDevice currentDevice] isPadModel] && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)))
			sheet.title = connection.displayName;

		if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus)
			sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
		else
			[sheet addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];

		if ([[CQChatOrderingController defaultController] connectionHasAnyChatRooms:connection])
			[sheet addButtonWithTitle:NSLocalizedString(@"Close All Chat Rooms", @"Close all rooms button title")];

		if ([[CQChatOrderingController defaultController] connectionHasAnyPrivateChats:connection])
			[sheet addButtonWithTitle:NSLocalizedString(@"Close All Private Chats", @"Close all private chats button title")];

		sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

		[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:header animated:YES];
	}
}

- (CGFloat) tableView:(UITableView *) tableView heightForHeaderInSection:(NSInteger) section {
	@synchronized([CQChatOrderingController defaultController]) {
		if (![CQChatOrderingController defaultController].chatViewControllers.count)
			return 0.;
		if (self.editing && section == 0)
			return 0.;
		return 44.;
	}
}

- (UIView *) tableView:(UITableView *) tableView viewForHeaderInSection:(NSInteger) section {
	if (self.editing) {
		if (section == 0)
			return nil;
		section--;
	}
	@synchronized([CQChatOrderingController defaultController]) {
		if (![CQChatOrderingController defaultController].chatViewControllers.count)
			return nil;

		MVChatConnection *connection = [[CQChatOrderingController defaultController] connectionAtIndex:section];
		if (!connection)
			return nil;

		CQConnectionTableHeaderView *tableCell = [_headerViewsForConnections objectForKey:connection];
		if (tableCell == nil) {
			tableCell = [[CQConnectionTableHeaderView alloc] initWithReuseIdentifier:nil];
			tableCell.tintColor = [CQColloquyApplication sharedApplication].window.tintColor;

			__weak __typeof__((self)) weakSelf = self;
			__weak __typeof__((tableView)) weakTableView = tableView;
			__weak __typeof__((tableCell)) weakTableCell = tableCell;
			tableCell.selectedConnectionHeaderView = ^{
				__strong __typeof__((weakSelf)) strongSelf = weakSelf;
				__strong __typeof__((weakTableView)) strongTableView = weakTableView;
				__strong __typeof__((weakTableCell)) strongTableCell = weakTableCell;
				[strongSelf tableView:strongTableView didSelectHeader:strongTableCell forSectionAtIndex:section];
			};
			[_headerViewsForConnections setObject:tableCell forKey:connection];
			[_connectionsForHeaderViews setObject:connection forKey:tableCell];
		}
		[tableCell takeValuesFromConnection:connection];

		return tableCell;
	}
}

- (void) tableView:(UITableView *) tableView didSelectHeader:(UITableViewHeaderFooterView *) headerView forSectionAtIndex:(NSInteger) section {
	if (!self.editing)
		return;

	id connection = [[CQChatOrderingController defaultController] connectionAtIndex:section];

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
}

#pragma mark -

- (void) tableView:(UITableView *) tableView willBeginEditingRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([[UIDevice currentDevice] isPadModel])
		_previousSelectedChatViewController = chatControllerForIndexPath([self.tableView indexPathForSelectedRow]);
}

- (void) tableView:(UITableView *) tableView didEndEditingRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([[UIDevice currentDevice] isPadModel] && _previousSelectedChatViewController) {
		NSIndexPath *indexPath = indexPathForChatController(_previousSelectedChatViewController, self.editing);
		if (indexPath)
			[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];

		_previousSelectedChatViewController = nil;
	}
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	id <CQChatViewController> chatViewController = chatControllerForIndexPath(indexPath);
#if ENABLE(FILE_TRANSFERS)
	if (chatViewController && ![chatViewController isKindOfClass:[CQFileTransferController class]]) {
#endif
		[[CQChatController defaultController] showChatController:chatViewController animated:YES];

		[[CQColloquyApplication sharedApplication] dismissPopoversAnimated:YES];

#if ENABLE(FILE_TRANSFERS)
		return;
	}

	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
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

- (void) showPreferences:(id) sender {
	CQPreferencesViewController *preferencesViewController = [[CQPreferencesViewController alloc] init];

	[[CQColloquyApplication sharedApplication] presentModalViewController:preferencesViewController animated:[UIView areAnimationsEnabled]];

}
@end
