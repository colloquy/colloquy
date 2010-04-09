#import "CQConnectionsViewController.h"

#import "CQColloquyApplication.h"
#import "CQTableViewSectionHeader.h"
#import "CQBouncerSettings.h"
#import "CQConnectionTableCell.h"
#import "CQConnectionsController.h"
#import "CQConnectionsNavigationController.h"

#import "UIViewControllerAdditions.h"

#import <ChatCore/MVChatConnection.h>

#define ConnectSheetTag 1
#define DisconnectSheetTag 2

#pragma mark -

@implementation CQConnectionsViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Connections", @"Connections view title");

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:[CQConnectionsController defaultController] action:@selector(showNewConnectionPrompt:)];
	self.navigationItem.leftBarButtonItem = addItem;
	[addItem release];

	self.navigationItem.rightBarButtonItem = self.editButtonItem;

	self.navigationItem.leftBarButtonItem.accessibilityLabel = NSLocalizedString(@"Add connection.", @"Voiceover add connection label");
	self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Edit connections.", @"Voiceover edit connections label");

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameRejectedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidDisconnectNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionAdded:) name:CQConnectionsControllerAddedConnectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionChanged:) name:CQConnectionsControllerChangedConnectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionRemoved:) name:CQConnectionsControllerRemovedConnectionNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionMoved:) name:CQConnectionsControllerMovedConnectionNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bouncerAdded:) name:CQConnectionsControllerAddedBouncerSettingsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bouncerRemoved:) name:CQConnectionsControllerRemovedBouncerSettingsNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	self.tableView.dataSource = nil;
	self.tableView.delegate = nil;

	[_connectTimeUpdateTimer release];

	[super dealloc];
}

#pragma mark -

- (void) _updateConnectTimes {
	NSArray *visibleCells = [self.tableView visibleCells];
	for (CQConnectionTableCell *cell in visibleCells)
		if ([cell isKindOfClass:[CQConnectionTableCell class]])
			[cell updateConnectTime];
}

- (void) _refreshConnection:(MVChatConnection *) connection {
	NSIndexPath *indexPath = [self indexPathForConnection:connection];
	if (!indexPath)
		return;
	CQConnectionTableCell *cell = (CQConnectionTableCell *)[self.tableView cellForRowAtIndexPath:indexPath];
	[cell takeValuesFromConnection:connection];
}

#pragma mark -

- (void) _startUpdatingConnectTimes {
	if (!_connectTimeUpdateTimer)
		_connectTimeUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(_updateConnectTimes) userInfo:nil repeats:YES] retain];
}

- (void) _stopUpdatingConnectTimes {
	[_connectTimeUpdateTimer invalidate];
	[_connectTimeUpdateTimer release];
	_connectTimeUpdateTimer = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.allowsSelectionDuringEditing = YES;

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_active = YES;

	[self.tableView reloadData];

	[self _startUpdatingConnectTimes];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	_active = NO;

	[self _stopUpdatingConnectTimes];
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation duration:(NSTimeInterval) duration {
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

#pragma mark -

- (void) _didChange:(NSNotification *) notification {
	if (_active)
		[self _refreshConnection:notification.object];
}

- (void) _connectionAdded:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	[self connectionAdded:[notification.userInfo objectForKey:@"connection"]];
}

- (void) _connectionChanged:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	[self _refreshConnection:[notification.userInfo objectForKey:@"connection"]];
}

- (void) _connectionRemoved:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	NSUInteger section = [self sectionForConnection:[notification.userInfo objectForKey:@"connection"]];
	if (section == NSNotFound)
		return;

	NSUInteger index = [[notification.userInfo objectForKey:@"index"] unsignedIntegerValue];
	[self connectionRemovedAtIndexPath:[NSIndexPath indexPathForRow:index inSection:section]];
}

- (void) _connectionMoved:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	NSUInteger section = [self sectionForConnection:[notification.userInfo objectForKey:@"connection"]];
	if (section == NSNotFound)
		return;

	NSUInteger index = [[notification.userInfo objectForKey:@"index"] unsignedIntegerValue];
	NSUInteger oldIndex = [[notification.userInfo objectForKey:@"oldIndex"] unsignedIntegerValue];
	[self connectionMovedFromIndexPath:[NSIndexPath indexPathForRow:oldIndex inSection:section] toIndexPath:[NSIndexPath indexPathForRow:index inSection:section]];
}

- (void) _bouncerAdded:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	[self bouncerSettingsAdded:[notification.userInfo objectForKey:@"bouncerSettings"]];
}

- (void) _bouncerRemoved:(NSNotification *) notification {
	if (!_active || _ignoreNotifications)
		return;

	NSUInteger index = [[notification.userInfo objectForKey:@"index"] unsignedIntegerValue];
	[self bouncerSettingsRemovedAtIndex:index];
}

#pragma mark -

- (CQConnectionsNavigationController *) navigationController {
	CQConnectionsNavigationController *navigationController = (CQConnectionsNavigationController *)super.navigationController;
	if ([navigationController isKindOfClass:[CQConnectionsNavigationController class]])
		return navigationController;
	return nil;
}

#pragma mark -

- (void) connectionAdded:(MVChatConnection *) connection {
	NSIndexPath *indexPath = [self indexPathForConnection:connection];
	NSAssert(indexPath != nil, @"Index path should not be nil.");
	if (!indexPath)
		return;

	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) connectionRemovedAtIndexPath:(NSIndexPath *) indexPath {
	NSParameterAssert(indexPath != nil);
	if (!indexPath)
		return;

	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];

	if ([[UIDevice currentDevice] isPadModel])
		[self resizeForViewInPopoverUsingTableView:self.tableView];
}

- (void) connectionMovedFromIndexPath:(NSIndexPath *) oldIndexPath toIndexPath:(NSIndexPath *) newIndexPath {
	NSParameterAssert(oldIndexPath != nil);
	NSParameterAssert(newIndexPath != nil);
	if (!oldIndexPath || !newIndexPath)
		return;

	[self.tableView beginUpdates];
	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:oldIndexPath] withRowAnimation:(newIndexPath.row > oldIndexPath.row ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop)];
	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:(newIndexPath.row > oldIndexPath.row ? UITableViewRowAnimationTop : UITableViewRowAnimationBottom)];
	[self.tableView endUpdates];
}

#pragma mark -

- (void) bouncerSettingsAdded:(CQBouncerSettings *) bouncer {
	NSUInteger section = [self sectionForBouncerSettings:bouncer];
	NSAssert(section != NSNotFound, @"Index path should not be NSNotFound.");
	if (section == NSNotFound)
		return;

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

- (void) updateConnection:(MVChatConnection *) connection {
	[self _refreshConnection:connection];
}

#pragma mark -

- (NSUInteger) sectionForBouncerSettings:(CQBouncerSettings *) bouncer {
	NSUInteger bouncerSection = [[CQConnectionsController defaultController].bouncers indexOfObjectIdenticalTo:bouncer];
	if (bouncerSection != NSNotFound)
		return bouncerSection + 1;
	return NSNotFound;
}

- (NSUInteger) sectionForConnection:(MVChatConnection *) connection {
	CQBouncerSettings *settings = [[CQConnectionsController defaultController] bouncerSettingsForIdentifier:connection.bouncerIdentifier];
	return [self sectionForBouncerSettings:settings];
}

- (NSIndexPath *) indexPathForConnection:(MVChatConnection *) connection {
	NSUInteger index = [[CQConnectionsController defaultController].directConnections indexOfObjectIdenticalTo:connection];
	if (index != NSNotFound)
		return [NSIndexPath indexPathForRow:index inSection:0];

	if (connection.bouncerIdentifier.length) {
		CQBouncerSettings *settings = [[CQConnectionsController defaultController] bouncerSettingsForIdentifier:connection.bouncerIdentifier];
		NSUInteger bouncerSection = [[CQConnectionsController defaultController].bouncers indexOfObjectIdenticalTo:settings];
		if (bouncerSection != NSNotFound) {
			NSArray *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:connection.bouncerIdentifier];
			index = [connections indexOfObjectIdenticalTo:connection];
			if (index != NSNotFound)
				return [NSIndexPath indexPathForRow:index inSection:(bouncerSection + 1)];
		}
	}

	return nil;
}

- (MVChatConnection *) connectionAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0)
		return [[CQConnectionsController defaultController].directConnections objectAtIndex:indexPath.row];

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	CQBouncerSettings *settings = [bouncers objectAtIndex:(indexPath.section - 1)];
	NSArray *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier];
	return [connections objectAtIndex:indexPath.row];
}

#pragma mark -

- (void) confirmConnect:(id) sender {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	MVChatConnection *connection = [self connectionAtIndexPath:selectedIndexPath];

	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = ConnectSheetTag;

	[sheet addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];

	if (connection.temporaryDirectConnection || !connection.directConnection)
		[sheet addButtonWithTitle:NSLocalizedString(@"Connect Directly", @"Connect Directly button title")];

	if (connection.waitingToReconnect)
		[sheet addButtonWithTitle:NSLocalizedString(@"Stop Connection Timer", @"Stop Connection Timer button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:sender animated:YES];

	[sheet release];
}

- (void) confirmDisconnect:(id) sender {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	MVChatConnection *connection = [self connectionAtIndexPath:selectedIndexPath];

	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = DisconnectSheetTag;

	if (connection.directConnection) {
		sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
	} else {
		[sheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
		sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Fully Disconnect", @"Fully Disconnect button title")];
	}

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:sender animated:YES];

	[sheet release];
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	MVChatConnection *connection = [self connectionAtIndexPath:selectedIndexPath];

	if (actionSheet.tag == ConnectSheetTag) {
		[connection cancelPendingReconnectAttempts];

		if (buttonIndex == 0) {
			connection.temporaryDirectConnection = NO;
			[connection connect];
		} else if (buttonIndex == 1 && (connection.temporaryDirectConnection || !connection.directConnection))
			[connection connectDirectly];
	} else if (actionSheet.tag == DisconnectSheetTag) {
		if (buttonIndex == actionSheet.destructiveButtonIndex) {
			if (connection.directConnection)
				[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
			else [connection sendRawMessageImmediatelyWithComponents:@"SQUIT :", [MVChatConnection defaultQuitMessage], nil];
		} else {
			[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
		}
	}

	[self _refreshConnection:connection];
}

#pragma mark -

- (void) tableSectionHeaderSelected:(CQTableViewSectionHeader *) header {
	CQBouncerSettings *settings = [[CQConnectionsController defaultController].bouncers objectAtIndex:(header.section - 1)];
	[self.navigationController editBouncer:settings];

	header.selected = YES;
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return [CQConnectionsController defaultController].bouncers.count + 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == 0)
		return [CQConnectionsController defaultController].directConnections.count;

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	CQBouncerSettings *settings = [bouncers objectAtIndex:(section - 1)];
	return [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier].count;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == 0 && [CQConnectionsController defaultController].directConnections.count && [CQConnectionsController defaultController].bouncers.count)
		return NSLocalizedString(@"Direct Connections", @"Direct Connections section title");
	if (section == 0)
		return nil;

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	CQBouncerSettings *settings = [bouncers objectAtIndex:(section - 1)];
	return settings.displayName;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = [self connectionAtIndexPath:indexPath];

	CQConnectionTableCell *cell = [CQConnectionTableCell reusableTableViewCellInTableView:tableView];

	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	[cell takeValuesFromConnection:connection];

	return cell;
}

- (CGFloat) tableView:(UITableView *) tableView heightForHeaderInSection:(NSInteger) section {
	return 22.;
}

- (UIView *) tableView:(UITableView *) tableView viewForHeaderInSection:(NSInteger) section {
	if (section == 0)
		return nil;

	CQTableViewSectionHeader *view = [[CQTableViewSectionHeader alloc] initWithFrame:CGRectZero];
	view.textLabel.text = [self tableView:tableView titleForHeaderInSection:section];
	view.section = section;

	[view addTarget:self action:@selector(tableSectionHeaderSelected:) forControlEvents:UIControlEventTouchUpInside];

	return [view autorelease];
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = [self connectionAtIndexPath:indexPath];
	if (self.editing)
		[self.navigationController editConnection:connection];
	else if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus)
		[self confirmDisconnect:[tableView cellForRowAtIndexPath:indexPath]];
	else [self confirmConnect:[tableView cellForRowAtIndexPath:indexPath]];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return (indexPath.section == 0 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone);
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	[self.navigationController editConnection:[self connectionAtIndexPath:indexPath]];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	_ignoreNotifications = YES;
	[[CQConnectionsController defaultController] removeConnectionAtIndex:indexPath.row];
	_ignoreNotifications = NO;

	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationRight];
}

- (NSIndexPath *) tableView:(UITableView *) tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *) sourceIndexPath toProposedIndexPath:(NSIndexPath *) proposedDestinationIndexPath {
	if (sourceIndexPath.section == proposedDestinationIndexPath.section)
		return proposedDestinationIndexPath;

	if (proposedDestinationIndexPath.section < sourceIndexPath.section)
		return [NSIndexPath indexPathForRow:0 inSection:sourceIndexPath.section];

	NSUInteger rows = [self tableView:tableView numberOfRowsInSection:sourceIndexPath.section];
	return [NSIndexPath indexPathForRow:(rows - 1) inSection:sourceIndexPath.section];
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	if (fromIndexPath.section != toIndexPath.section) {
		NSAssert(NO, @"Should not reach this point.");
		return;
	}

	if (fromIndexPath.section == 0) {
		_ignoreNotifications = YES;
		[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
		_ignoreNotifications = NO;
		return;
	}

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	CQBouncerSettings *settings = [bouncers objectAtIndex:(fromIndexPath.section - 1)];

	_ignoreNotifications = YES;
	[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row forBouncerIdentifier:settings.identifier];
	_ignoreNotifications = NO;
}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	return (action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	MVChatConnection *connection = [self connectionAtIndexPath:indexPath];
	if (!connection)
		return;

	if (action == @selector(copy:))
		[UIPasteboard generalPasteboard].URL = connection.url;
}
@end
