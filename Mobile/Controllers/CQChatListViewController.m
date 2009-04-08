#import "CQChatListViewController.h"

#import "CQChatRoomController.h"
#import "CQChatTableCell.h"
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

	self.editButtonItem.possibleTitles = [NSSet setWithObjects:NSLocalizedString(@"Manage", @"Manage button title"), NSLocalizedString(@"Done", @"Done button title")];
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

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark -

static MVChatConnection *connectionForSection(NSInteger section) {
	NSMutableSet *connections = [NSMutableSet set];

	for (id cntlr in [CQChatController defaultController].chatViewControllers) {
		if ([cntlr conformsToProtocol:@protocol(CQChatViewController)]) {
			id <CQChatViewController> controller = cntlr;
			if (controller.connection) {
				[connections addObject:controller.connection];
				if ((section + 1) == connections.count)
					return controller.connection;
			}
		}
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
		if ([controller isKindOfClass:[CQDirectChatController class]]) {
			CQDirectChatController *currentController = controller;
			if (currentController.connection != currentConnection) {
				if (currentConnection) ++sectionIndex;
				currentConnection = currentController.connection;
			}

			if (currentController.connection == connection)
				return sectionIndex;
		}
	}

	return NSNotFound;
}

static NSUInteger sectionIndexForFileTransfers() {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return NSNotFound;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;

	for (id controller in controllers) {
		if ([controller isKindOfClass:[CQFileTransferController class]]) {
			return sectionIndex + 1;
		} else {
			CQDirectChatController *currentController = controller;
			if (currentController.connection != currentConnection) {
				if (currentConnection) ++sectionIndex;
				currentConnection = currentController.connection;
			}
		}
	}

	return NSNotFound;
}

static NSIndexPath *indexPathForChatController(id controller) {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *connection = nil;
	if ([controller conformsToProtocol:@protocol(CQChatViewController)]) {
		connection = ((id <CQChatViewController>) controller).connection;
	}
	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;
	NSUInteger rowIndex = 0;

	for (id cntrl in controllers) {
		if ([cntrl conformsToProtocol:@protocol(CQChatViewController)]) {
			id <CQChatViewController> currentController = cntrl;
			if (currentController.connection != currentConnection) {
				if (currentConnection) ++sectionIndex;
				currentConnection = currentController.connection;
			}

			if (currentController == controller)
				return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];

			if (currentController.connection == connection && currentController != controller)
				++rowIndex;
		}
		else {
			if (cntrl == controller) {
				return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex+1];
			}
			else {
				++rowIndex;
			}
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
	id message = [info objectForKey:@"message"];

	NSString *messageString = nil;
	NSString *transformedMessageString = nil;
	if ([message isKindOfClass:[NSData class]]) {
		messageString = [[NSString alloc] initWithChatData:message encoding:encoding];
		if (!messageString) messageString = [[NSString alloc] initWithChatData:message encoding:NSASCIIStringEncoding];

		transformedMessageString = [messageString stringByStrippingXMLTags];
		transformedMessageString = [transformedMessageString stringByDecodingXMLSpecialCharacterEntities];
		transformedMessageString = [transformedMessageString stringBySubstitutingEmoticonsForEmoji];
	} else if ([message isKindOfClass:[NSString class]]) {
		transformedMessageString = [message stringByStrippingXMLTags];
		transformedMessageString = [transformedMessageString stringByDecodingXMLSpecialCharacterEntities];
	}

	BOOL action = [[info objectForKey:@"action"] boolValue];

	[cell addMessagePreview:transformedMessageString fromUser:user asAction:action animated:animated];

	[messageString release];
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
	} else if ([chatViewController isMemberOfClass:[CQDirectChatController class]])
		cell.removeConfirmationText = NSLocalizedString(@"Close", @"Close remove confirmation button title");
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

	[super viewWillAppear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	_active = NO;
}

#pragma mark -

- (void) addChatViewController:(id) cntlr {
	if (!_active) {
		_needsUpdate = YES;
		return;
	}
	if ([cntlr conformsToProtocol:@protocol(CQChatViewController)]) {
		id <CQChatViewController> controller = cntlr;
		if ([[CQChatController defaultController] chatViewControllersForConnection:controller.connection].count == 1) {
			NSUInteger sectionIndex = sectionIndexForConnection(controller.connection);
			[self.tableView beginUpdates];
			if ([CQChatController defaultController].chatViewControllers.count == 1)
				[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationTop];
			[self.tableView endUpdates];
		} else {
			NSIndexPath *changedIndexPath = indexPathForChatController(controller);
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:changedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
		}
	} else if ([cntlr isKindOfClass:[CQFileTransferController class]]) {
		CQFileTransferController *controller = cntlr;
		if ([[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]].count == 1) {
			NSUInteger section = sectionIndexForFileTransfers();
			[self.tableView beginUpdates];
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationTop];
			[self.tableView endUpdates];
		} else {
			NSIndexPath *changedIndexPath = indexPathForChatController(controller);
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:changedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
		}
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

- (void) addMessagePreview:(NSDictionary *) info forChatController:(id <CQChatViewController>) controller {
	CQChatTableCell *cell = [self _chatTableCellForController:controller];

	if ([controller respondsToSelector:@selector(unreadCount)])
		cell.unreadCount = controller.unreadCount;

	if ([controller respondsToSelector:@selector(importantUnreadCount)])
		cell.importantUnreadCount = controller.importantUnreadCount;

	[self _addMessagePreview:info withEncoding:controller.encoding toChatTableCell:cell animated:YES];
}

#pragma mark -

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[super setEditing:editing animated:animated];

	if (!editing)
		self.editButtonItem.title = NSLocalizedString(@"Manage", @"Manage button title");
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	NSMutableSet *connections = [NSMutableSet set];

	for (id controller in [CQChatController defaultController].chatViewControllers)
		if ([controller conformsToProtocol:@protocol(CQChatViewController)]) {
			if (((id <CQChatViewController>) controller).connection)
				[connections addObject:((id <CQChatViewController>) controller).connection];
		} else {
			[connections addObject:[NSNull null]];
		}

	return connections.count ? connections.count : 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if (connection) {
		return [[CQChatController defaultController] chatViewControllersForConnection:connection].count;
	} else {
		return [[CQChatController defaultController] chatViewControllersOfClass:[CQFileTransferController class]].count;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if (connection) {
		return connection.displayName;
	}
	else {
		if ([[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]].count) {
			return NSLocalizedString(@"File Transfers", @"File Transfers section title");
		}
		else {
			return @"";
		}
	}
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
		}

		return cell;
	} else {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
		CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

		//CQFileTransferTableCell *cell = [CQFileTransferTableCell reusableTableViewCellInTableView:tableView];
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

		//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.accessoryType = UITableViewCellAccessoryNone;

		[self _refreshFileTransferCell:cell withController:controller animated:NO];

		return cell;
	}
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (NSString *) tableView:(UITableView *) tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	if (connection) {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
		id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

		if ([chatViewController isMemberOfClass:[CQChatRoomController class]]) {
			if (chatViewController.available)
				return NSLocalizedString(@"Leave", @"Leave remove confirmation button title");
			return  NSLocalizedString(@"Close", @"Close remove confirmation button title");
		} else if ([chatViewController isMemberOfClass:[CQDirectChatController class]])
			return NSLocalizedString(@"Close", @"Close remove confirmation button title");
	} else {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersKindOfClass:[CQFileTransferController class]];
		CQFileTransferController *controller = [controllers objectAtIndex:indexPath.row];

		MVFileTransferStatus status = controller.transfer.status;
		if (status == MVFileTransferDoneStatus || status == MVFileTransferStoppedStatus)
			return NSLocalizedString(@"Close", @"Close remove confirmation button title");
		return NSLocalizedString(@"Stop", @"Stop remove confirmation button title");
	}

	return nil;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	MVChatConnection *connection = connectionForSection(indexPath.section);
	NSArray *controllers;
	id controller;
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
	if (connection) {
		NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
		id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

		[[CQChatController defaultController] showChatController:chatViewController animated:YES];
	}
}
@end
