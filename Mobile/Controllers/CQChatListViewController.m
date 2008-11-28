#import "CQChatListViewController.h"

#import "CQChatTableCell.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQChatListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.rowHeight = 72.;
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
}

#pragma mark -

static MVChatConnection *connectionForSection(NSInteger section) {
	NSMutableSet *connections = [NSMutableSet set];

	for (CQDirectChatController *controller in [CQChatController defaultController].chatViewControllers) {
		if (controller.connection) {
			[connections addObject:controller.connection];
			if ((section + 1) == connections.count)
				return controller.connection;
		}
	}

	return nil;
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	NSMutableSet *connections = [NSMutableSet set];

	for (CQDirectChatController *controller in [CQChatController defaultController].chatViewControllers)
		if (controller.connection)
			[connections addObject:controller.connection];

	return connections.count ? connections.count : 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if (connection)
		return [[CQChatController defaultController] chatViewControllersForConnection:connection].count;
	return 0;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	return connectionForSection(section).displayName;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
	id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

	CQChatTableCell *cell = [CQChatTableCell reusableTableViewCellInTableView:tableView];

	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

	[cell takeValuesFromChatViewController:chatViewController];

	return cell;
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
	UIViewController *chatViewController = [controllers objectAtIndex:indexPath.row];

	[self.navigationController pushViewController:chatViewController animated:YES];
}
@end
