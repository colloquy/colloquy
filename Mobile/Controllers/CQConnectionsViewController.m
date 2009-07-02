#import "CQConnectionsViewController.h"

#import "CQColloquyApplication.h"
#import "CQBouncerSettings.h"
#import "CQConnectionTableCell.h"
#import "CQConnectionsController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionsViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Connections", @"Connections view title");

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:[CQConnectionsController defaultController] action:@selector(showModalNewConnectionView)];
	self.navigationItem.leftBarButtonItem = addItem;
	[addItem release];

	self.navigationItem.rightBarButtonItem = self.editButtonItem;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameAcceptedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionNicknameRejectedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionWillConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidNotConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChange:) name:MVChatConnectionDidDisconnectNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

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

#pragma mark -

- (void) _didChange:(NSNotification *) notification {
	if (_active)
		[self _refreshConnection:notification.object];
}

#pragma mark -

- (void) addConnection:(MVChatConnection *) connection {
	[self.tableView reloadData];
}

- (void) removeConnection:(MVChatConnection *) connection {
	[self.tableView reloadData];
}

#pragma mark -

- (void) addConnection:(MVChatConnection *) connection forBouncerIdentifier:(NSString *) identifier {
	[self.tableView reloadData];
}

- (void) removeConnection:(MVChatConnection *) connection forBouncerIdentifier:(NSString *) identifier {
	[self.tableView reloadData];
}

#pragma mark -

- (NSIndexPath *) indexPathForConnection:(MVChatConnection *) connection {
	NSUInteger index = [[CQConnectionsController defaultController].connections indexOfObjectIdenticalTo:connection];
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
		return [[CQConnectionsController defaultController].connections objectAtIndex:indexPath.row];

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	CQBouncerSettings *settings = [bouncers objectAtIndex:(indexPath.section - 1)];
	NSArray *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier];
	return [connections objectAtIndex:indexPath.row];
}

#pragma mark -

- (void) confirmConnect {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	MVChatConnection *connection = [self connectionAtIndexPath:selectedIndexPath];

	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = 1;

	[sheet addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];
	if (connection.waitingToReconnect)
		[sheet addButtonWithTitle:NSLocalizedString(@"Stop Connection Timer", @"Stop Connection Timer button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}

- (void) confirmDisconnect {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = 2;

	sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	MVChatConnection *connection = [self connectionAtIndexPath:selectedIndexPath];

	if (actionSheet.tag == 1) {
		if (buttonIndex == 1 && connection.waitingToReconnect)
			[connection cancelPendingReconnectAttempts];
		else if (!connection.connected)
			[connection connect];
	} else if (actionSheet.tag == 2) {
		if (buttonIndex == actionSheet.destructiveButtonIndex)
			[connection disconnectWithReason:[MVChatConnection defaultQuitMessage]];
	}

	[self _refreshConnection:connection];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return [CQConnectionsController defaultController].bouncers.count + 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == 0)
		return [CQConnectionsController defaultController].connections.count;

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	CQBouncerSettings *settings = [bouncers objectAtIndex:(section - 1)];
	return [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier].count;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == 0 && [CQConnectionsController defaultController].connections.count && [CQConnectionsController defaultController].bouncers.count)
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

	if (indexPath.section == 0)
		cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
	else cell.accessoryType = UITableViewCellAccessoryNone;

	[cell takeValuesFromConnection:connection];

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = [self connectionAtIndexPath:indexPath];
	if (self.editing)
		[[CQConnectionsController defaultController] editConnection:connection];
	else if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus)
		[self confirmDisconnect];
	else [self confirmConnect];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	CQConnectionsController *connectionsController = [CQConnectionsController defaultController];
	[connectionsController editConnection:[self connectionAtIndexPath:indexPath]];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	[[CQConnectionsController defaultController] removeConnectionAtIndex:indexPath.row];
	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	return (indexPath.section == 0);
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
}
@end
