#import "CQConnectionsController.h"
#import "CQConnectionsViewController.h"
#import "CQConnectionCreationViewController.h"
#import "CQConnectionTableCell.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionsViewController
- (id) init {
	if( ! ( self = [super initWithNibName:@"ConnectionsView" bundle:nil] ) )
		return nil;

	self.title = NSLocalizedString(@"Connections", @"Connections view title");

	for( MVChatConnection *connection in [CQConnectionsController defaultController].connections )
		[self addConnection:connection];

	return self;
}

- (void) dealloc {
	[connectionsTableView release];
	[connectionCreationViewController release];
	[_connectTimeUpdateTimer release];
	[super dealloc];
}

- (void) viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector( makeNewConnection: )];
	self.navigationItem.leftBarButtonItem = addItem;
	[addItem release];

	self.navigationItem.rightBarButtonItem = self.editButtonItem;	
}

- (void) didReceiveMemoryWarning {
	if( ! self.view.superview ) {
		[connectionCreationViewController release];
		connectionCreationViewController = nil;
	}

	[super didReceiveMemoryWarning];
}

#pragma mark -

- (void) makeNewConnection:(id) sender {
	if( !connectionCreationViewController )
		connectionCreationViewController = [[CQConnectionCreationViewController alloc] init];
	[self presentModalViewController:connectionCreationViewController animated:YES];
}

#pragma mark -

- (void) _updateConnectTimes {
	NSArray *visibleCells = [connectionsTableView visibleCells];
	for( CQConnectionTableCell *cell in visibleCells )
		[cell updateConnectTime];
}

- (void) _refreshConnection:(MVChatConnection *) connection {
	NSUInteger index = [[CQConnectionsController defaultController].connections indexOfObjectIdenticalTo:connection];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
	CQConnectionTableCell *cell = (CQConnectionTableCell *)[connectionsTableView cellForRowAtIndexPath:indexPath];
	[cell takeValuesFromConnection:connection];
}

#pragma mark -

- (void) _startUpdatingConnectTimes {
	[self _updateConnectTimes];
	if( ! _connectTimeUpdateTimer )
		_connectTimeUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector( _updateConnectTimes ) userInfo:nil repeats:YES] retain];
}

- (void) _stopUpdatingConnectTimes {
	[_connectTimeUpdateTimer invalidate];
	[_connectTimeUpdateTimer release];
	_connectTimeUpdateTimer = nil;
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[self _startUpdatingConnectTimes];
}

- (void) viewWillDisappear:(BOOL) animated {
	[self _stopUpdatingConnectTimes];
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated {
	[super setEditing:editing animated:animated];
	[connectionsTableView setEditing:editing animated:animated];
}

#pragma mark -

- (void) _registerNotificationsForConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didChange: ) name:MVChatConnectionNicknameAcceptedNotification object:connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _willConnect: ) name:MVChatConnectionWillConnectNotification object:connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didConnect: ) name:MVChatConnectionDidConnectNotification object:connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didChange: ) name:MVChatConnectionDidNotConnectNotification object:connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _didDisconnect: ) name:MVChatConnectionDidDisconnectNotification object:connection];

//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _errorOccurred : ) name:MVChatConnectionErrorNotification object:connection];

//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _requestPassword: ) name:MVChatConnectionNeedNicknamePasswordNotification object:connection];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _requestCertificatePassword: ) name:MVChatConnectionNeedCertificatePasswordNotification object:connection];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _requestPublicKeyVerification: ) name:MVChatConnectionNeedPublicKeyVerificationNotification object:connection];
}

- (void) _deregisterNotificationsForConnection:(MVChatConnection *) connection {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNicknameAcceptedNotification object:connection];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionWillConnectNotification object:connection];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionDidConnectNotification object:connection];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionDidNotConnectNotification object:connection];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionDidDisconnectNotification object:connection];

//	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionErrorNotification object:connection];

//	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNeedNicknamePasswordNotification object:connection];
//	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNeedCertificatePasswordNotification object:connection];
//	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionNeedPublicKeyVerificationNotification object:connection];
}

- (void) _willConnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	[self _refreshConnection:connection];

	NSDictionary *extraInfo = [connection.persistentInformation objectForKey:@"CQConnectionsControllerExtraInfo"];
	NSArray *rooms = [extraInfo objectForKey:@"rooms"];
	if( [rooms count] )
		[connection joinChatRoomsNamed:rooms];
}

- (void) _didConnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	NSMutableDictionary *persistentInformation = [connection.persistentInformation mutableCopy];
	NSMutableDictionary *extraInfo = [[persistentInformation objectForKey:@"CQConnectionsControllerExtraInfo"] mutableCopy];
	if( ! extraInfo ) extraInfo = [[NSMutableDictionary alloc] init];

	[extraInfo setObject:[NSDate date] forKey:@"connectDate"];

	[persistentInformation setObject:extraInfo forKey:@"CQConnectionsControllerExtraInfo"];
	[extraInfo release];

	[connection setPersistentInformation:persistentInformation];
	[persistentInformation release];

	[self _refreshConnection:connection];
}

- (void) _didChange:(NSNotification *) notification {
	[self _refreshConnection:notification.object];
}

- (void) _didDisconnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	NSMutableDictionary *persistentInformation = [connection.persistentInformation mutableCopy];
	NSMutableDictionary *extraInfo = [[persistentInformation objectForKey:@"CQConnectionsControllerExtraInfo"] mutableCopy];

	if( extraInfo ) {
		[extraInfo removeObjectForKey:@"connectDate"];

		[persistentInformation setObject:extraInfo forKey:@"CQConnectionsControllerExtraInfo"];
		[extraInfo release];

		[connection setPersistentInformation:persistentInformation];
	}

	[persistentInformation release];

	[self _refreshConnection:connection];
}

#pragma mark -

- (void) addConnection:(MVChatConnection *) connection {
	[self _registerNotificationsForConnection:connection];
	[connectionsTableView reloadData];
}

- (void) removeConnection:(MVChatConnection *) connection {
	[self _deregisterNotificationsForConnection:connection];
	[connectionsTableView reloadData];
}

#pragma mark -

- (void) confirmConnect {
	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:[connectionsTableView indexPathForSelectedRow].row];

	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.title = [NSString stringWithFormat:@"Do you want to connect\nto \"%@\"?", connection.server];

	[sheet addButtonWithTitle:@"Connect"];
	[sheet addButtonWithTitle:@"Cancel"];

	sheet.cancelButtonIndex = 1;

	[sheet showInView:[CQColloquyApplication sharedApplication].tabBarController.view];
	[sheet release];
}

- (void) confirmDisconnect {
	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:[connectionsTableView indexPathForSelectedRow].row];

	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.title = [NSString stringWithFormat:@"Do you want to disconnect\nfrom \"%@\"?", connection.server];

	[sheet addButtonWithTitle:@"Disconnect"];
	[sheet addButtonWithTitle:@"Cancel"];

	sheet.destructiveButtonIndex = 0;
	sheet.cancelButtonIndex = 1;

	[sheet showInView:[CQColloquyApplication sharedApplication].tabBarController.view];
	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [connectionsTableView indexPathForSelectedRow];

	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:selectedIndexPath.row];
	if( connection.status == MVChatConnectionDisconnectedStatus && actionSheet.cancelButtonIndex != buttonIndex )
		[connection connect];
	else if( actionSheet.destructiveButtonIndex == buttonIndex )
		[connection disconnect];

	[connectionsTableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return [CQConnectionsController defaultController].connections.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:indexPath.row];

	CQConnectionTableCell *cell = (CQConnectionTableCell *)[tableView dequeueReusableCellWithIdentifier:@"CQConnectionTableCell"];
	if( ! cell ) cell = [[[CQConnectionTableCell alloc] init] autorelease];

	[cell takeValuesFromConnection:connection];

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if( ! indexPath )
		return;

	MVChatConnection *connection = [[CQConnectionsController defaultController].connections objectAtIndex:indexPath.row];
	if( connection.status == MVChatConnectionDisconnectedStatus ) [self confirmConnect];
	else [self confirmDisconnect];
}

- (UITableViewCellAccessoryType) tableView:(UITableView *) tableView accessoryTypeForRowWithIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellAccessoryDetailDisclosureButton;
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	CQConnectionsController *connectionsController = [CQConnectionsController defaultController];
	[connectionsController editConnection:[connectionsController.connections objectAtIndex:indexPath.row]];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if( editingStyle != UITableViewCellEditingStyleDelete )
		return;
	[[CQConnectionsController defaultController] removeConnectionAtIndex:indexPath.row];
	[connectionsTableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
}
@end
