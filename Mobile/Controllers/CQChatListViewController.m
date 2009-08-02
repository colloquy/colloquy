#import "CQChatListViewController.h"

#import "CQChatRoomController.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"
#import "CQFileTransferController.h"
#import "CQFileTransferTableCell.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

@implementation CQChatListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:[CQChatController defaultController] action:@selector(showNewChatActionSheet)];
	self.navigationItem.leftBarButtonItem = addItem;
	[addItem release];

	self.editButtonItem.possibleTitles = [NSSet setWithObjects:NSLocalizedString(@"Manage", @"Manage button title"), NSLocalizedString(@"Done", @"Done button title"), nil];
	self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");
	self.navigationItem.rightBarButtonItem = self.editButtonItem;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshConnectionChatCells:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshConnectionChatCells:) name:MVChatConnectionDidDisconnectNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomPartedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatRoomKickedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatUserNicknameChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshChatCell:) name:MVChatUserStatusChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshFileTransferCell:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshFileTransferCell:) name:MVFileTransferErrorOccurredNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateMessagePreview:) name:CQChatViewControllerRecentMessagesUpdatedNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark -

static MVChatConnection *connectionForSection(NSUInteger section) {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;

	for (id controller in controllers) {
		if (![controller conformsToProtocol:@protocol(CQChatViewController)])
			continue;

		id <CQChatViewController> chatViewController = controller;
		if (chatViewController.connection != currentConnection) {
			if (currentConnection) ++sectionIndex;
			currentConnection = chatViewController.connection;
		}

		if (sectionIndex == section)
			return chatViewController.connection;
	}

	return nil;
}

static NSUInteger sectionIndexForConnection(MVChatConnection *connection) {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return NSNotFound;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;

	for (id controller in controllers) {
		if (![controller conformsToProtocol:@protocol(CQChatViewController)])
			continue;

		id <CQChatViewController> chatViewController = controller;
		if (chatViewController.connection != currentConnection) {
			if (currentConnection) ++sectionIndex;
			currentConnection = chatViewController.connection;
		}

		if (chatViewController.connection == connection)
			return sectionIndex;
	}

	return NSNotFound;
}

static NSIndexPath *indexPathForChatController(id controller) {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *connection = nil;
	if ([controller conformsToProtocol:@protocol(CQChatViewController)])
		connection = ((id <CQChatViewController>) controller).connection;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;
	NSUInteger rowIndex = 0;

	for (id currentController in controllers) {
		if ([currentController conformsToProtocol:@protocol(CQChatViewController)]) {
			id <CQChatViewController> chatViewController = currentController;
			if (chatViewController.connection != currentConnection) {
				if (currentConnection) ++sectionIndex;
				currentConnection = chatViewController.connection;
			}

			if (chatViewController == controller)
				return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];

			if (chatViewController.connection == connection && chatViewController != controller)
				++rowIndex;
		} else {
			if (currentController == controller)
				return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex + 1];
			++rowIndex;
		}
	}

	return nil;
}

#pragma mark -

- (CQChatTableCell *) _chatTableCellForController:(id <CQChatViewController>) controller {
	NSIndexPath *indexPath = indexPathForChatController(controller);
	return (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
}

- (CQFileTransferTableCell *) _fileTransferCellForController:(CQFileTransferController *) controller {
	NSIndexPath *indexPath = indexPathForChatController(controller);
	return (CQFileTransferTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
}

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

- (void) _refreshChatCell:(CQChatTableCell *) cell withController:(id <CQChatViewController>) chatViewController animated:(BOOL) animated {
	if (animated)
		[UIView beginAnimations:nil context:NULL];

	[cell takeValuesFromChatViewController:chatViewController];

	if ([chatViewController isMemberOfClass:[CQDirectChatController class]])
		cell.showsUserInMessagePreviews = NO;

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	if ([chatViewController isMemberOfClass:[CQChatRoomController class]]) {
		if (chatViewController.available)
			cell.removeConfirmationText = NSLocalizedString(@"Leave", @"Leave remove confirmation button title");
		else cell.removeConfirmationText = NSLocalizedString(@"Close", @"Close remove confirmation button title");
	} else cell.removeConfirmationText = NSLocalizedString(@"Close", @"Close remove confirmation button title");
#endif

	if (animated)
		[UIView commitAnimations];
}

- (void) _refreshFileTransferCell:(CQFileTransferTableCell *) cell withController:(CQFileTransferController *) controller animated:(BOOL) animated {
	if (animated)
		[UIView beginAnimations:nil context:NULL];

	[cell takeValuesFromController:controller];

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	MVFileTransferStatus status = controller.transfer.status;
	if (status == MVFileTransferDoneStatus || status == MVFileTransferStoppedStatus)
		cell.removeConfirmationText = NSLocalizedString(@"Close", @"Close remove confirmation button title");
	else cell.removeConfirmationText = NSLocalizedString(@"Stop", @"Stop remove confirmation button title");
#endif

	if (animated)
		[UIView commitAnimations];
}

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
	[self updateAccessibilityLabelForChatCell:cell];
}

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

- (void) updateAccessibilityLabelForChatCell:(CQChatTableCell *) cell {
	if (cell.importantUnreadCount && cell.importantUnreadCount == cell.unreadCount)
		cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%d highlights in %@", @"Voiceover %d highlights in %@ label"), cell.importantUnreadCount, cell.name];
	else if (cell.importantUnreadCount)
		cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%d highlights and %d unread messages in %@", @"Voiceover %d highlights and %d unread messages in %@ label") , cell.importantUnreadCount, cell.unreadCount, cell.name];
	else if (cell.unreadCount)
		cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"%d unread messages in %@", @"Voiceover %d unread messages in %@ label"), cell.unreadCount, cell.name];
	else cell.accessibilityLabel = cell.name;
}


#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.rowHeight = 62.;
}

- (void) viewWillAppear:(BOOL) animated {
	if (_needsUpdate) {
		[self.tableView reloadData];
		_needsUpdate = NO;
	}

	_active = YES;

	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath) {
		MVChatConnection *connection = connectionForSection(selectedIndexPath.section);
		if (connection) {
			NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
			id <CQChatViewController> chatViewController = [controllers objectAtIndex:selectedIndexPath.row];
			CQChatTableCell *cell = (CQChatTableCell *)[self.tableView cellForRowAtIndexPath:selectedIndexPath];
			[self _refreshChatCell:cell withController:chatViewController animated:NO];
		}
	}

	self.navigationItem.leftBarButtonItem.accessibilityLabel = NSLocalizedString(@"New chat room.", @"Voiceover new chat room label");
	self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Manage chat rooms.", @"Voiceover manage chat rooms label");

	[super viewWillAppear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	_active = NO;
}

#pragma mark -

- (void) addChatViewController:(id) controller {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}

	NSArray *controllers = nil;
	if ([controller conformsToProtocol:@protocol(CQChatViewController)])
		controllers = [[CQChatController defaultController] chatViewControllersForConnection:((id <CQChatViewController>)controller).connection];
	else if ([controller isKindOfClass:[CQFileTransferController class]])
		controllers = [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]];
	else {
		NSAssert(NO, @"Should not reach this point.");
		return;
	}

	NSIndexPath *changedIndexPath = indexPathForChatController(controller);
	if (controllers.count == 1) {
		[self.tableView beginUpdates];
		if ([CQChatController defaultController].chatViewControllers.count == 1)
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:changedIndexPath.section] withRowAnimation:UITableViewRowAnimationTop];
		[self.tableView endUpdates];
	} else {
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:changedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
	}
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
	[super setEditing:editing animated:animated];

	if (!editing)
		self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return 1;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionCount = 0;

	for (id controller in controllers) {
		if (![controller conformsToProtocol:@protocol(CQChatViewController)])
			break;

		id <CQChatViewController> chatViewController = controller;
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
	return [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]].count;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if (connection)
		return connection.displayName;

	if ([[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]].count)
		return NSLocalizedString(@"File Transfers", @"File Transfers section title");

	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	if (connection) {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
		id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

		CQChatTableCell *cell = [CQChatTableCell reusableTableViewCellInTableView:tableView];

		cell.showsIcon = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowsChatIcons"];

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

			cell.accessibilityLabel = cell.name;			
			cell.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
		}
		
		[self updateAccessibilityLabelForChatCell:cell];
		
		return cell;
	}

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

	cell.showsIcon = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowsChatIcons"];

	[self _refreshFileTransferCell:cell withController:controller animated:NO];

	return cell;
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (NSString *) tableView:(UITableView *) tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	if (connection) {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
		id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

		if ([chatViewController isMemberOfClass:[CQChatRoomController class]] && chatViewController.available)
			return NSLocalizedString(@"Leave", @"Leave remove confirmation button title");
		return NSLocalizedString(@"Close", @"Close remove confirmation button title");
	}

	NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
	CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

	MVFileTransferStatus status = controller.transfer.status;
	if (status == MVFileTransferDoneStatus || status == MVFileTransferStoppedStatus)
		return NSLocalizedString(@"Close", @"Close remove confirmation button title");
	return NSLocalizedString(@"Stop", @"Stop remove confirmation button title");
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	MVChatConnection *connection = connectionForSection(indexPath.section);
	NSArray *controllers = nil;
	id controller = nil;

	if (connection) {
		controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
		id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];
		controller = chatViewController;

		if ([chatViewController isKindOfClass:[CQChatRoomController class]]) {
			CQChatRoomController *chatRoomController = (CQChatRoomController *)chatViewController;
			if (chatRoomController.available) {
				[chatRoomController part];
				[self.tableView updateCellAtIndexPath:indexPath withAnimation:UITableViewRowAnimationFade];
				return;
			}
		}
	} else {
		controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
		CQFileTransferController *fileTransferController = [controllers objectAtIndex:indexPath.row];
		controller = fileTransferController;

		if (fileTransferController.transfer.status != MVFileTransferDoneStatus && fileTransferController.transfer.status != MVFileTransferStoppedStatus) {
			[fileTransferController.transfer cancel];
			[self.tableView updateCellAtIndexPath:indexPath withAnimation:UITableViewRowAnimationFade];
			return;
		}
	}

	[[CQChatController defaultController] closeViewController:controller];

	if (controllers.count == 1) {
		[self.tableView beginUpdates];
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationRight];
		if (![CQChatController defaultController].chatViewControllers.count)
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
		[self.tableView endUpdates];
	} else {
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
	}
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	if (!connection)
		return;

	NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
	id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

	[[CQChatController defaultController] showChatController:chatViewController animated:YES];
}
@end
