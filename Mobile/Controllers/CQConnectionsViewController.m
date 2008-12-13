#import "CQConnectionsViewController.h"

#import "CQConnectionsController.h"
#import "CQConnectionTableCell.h"

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
		[cell updateConnectTime];
}

- (void) _refreshConnection:(MVChatConnection *) connection {
	NSUInteger index = [[CQConnectionsController defaultController].connections indexOfObjectIdenticalTo:connection];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
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

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
	[self _startUpdatingConnectTimes];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];
	[self _stopUpdatingConnectTimes];
}

#pragma mark -

- (void) _didChange:(NSNotification *) notification {
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

- (void) confirmConnect {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	[sheet addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	sheet.cancelButtonIndex = 1;

	[sheet showInView:self.view.window];
	[sheet release];
}

- (void) confirmDisconnect {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	[sheet addButtonWithTitle:NSLocalizedString(@"Disconnect", @"Disconnect button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	sheet.destructiveButtonIndex = 0;
	sheet.cancelButtonIndex = 1;

	[sheet showInView:self.view.window];
	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:selectedIndexPath.row];
	if (connection.status == MVChatConnectionDisconnectedStatus && actionSheet.cancelButtonIndex != buttonIndex)
		[connection connect];
	else if (actionSheet.destructiveButtonIndex == buttonIndex)
		[connection disconnect];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return [CQConnectionsController defaultController].connections.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:indexPath.row];

	CQConnectionTableCell *cell = [CQConnectionTableCell reusableTableViewCellInTableView:tableView];

	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

	[cell takeValuesFromConnection:connection];

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:indexPath.row];
	if (connection.status == MVChatConnectionConnectingStatus || connection.status == MVChatConnectionConnectedStatus)
		[self confirmDisconnect];
	else [self confirmConnect];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	CQConnectionsController *connectionsController = [CQConnectionsController defaultController];
	[connectionsController editConnection:[connectionsController.connections objectAtIndex:indexPath.row]];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;
	[[CQConnectionsController defaultController] removeConnectionAtIndex:indexPath.row];
	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
}
@end
