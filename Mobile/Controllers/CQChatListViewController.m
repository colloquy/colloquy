#import "CQChatListViewController.h"

#import "CQChatRoomController.h"
#import "CQChatTableCell.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQChatListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStylePlain]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(startNewChat)];
	self.navigationItem.leftBarButtonItem = addItem;
	[addItem release];

	self.navigationItem.rightBarButtonItem = self.editButtonItem;

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

static NSUInteger sectionIndexForConnection(MVChatConnection *connection) {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return NSNotFound;

	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;

	for (CQDirectChatController *currentController in controllers) {
		if (currentController.connection != currentConnection) {
			if (currentConnection) ++sectionIndex;
			currentConnection = currentController.connection;
		}

		if (currentController.connection == connection)
			return sectionIndex;
	}

	return NSNotFound;
}

static NSIndexPath *indexPathForChatController(id <CQChatViewController> controller) {
	NSArray *controllers = [CQChatController defaultController].chatViewControllers;
	if (!controllers.count)
		return nil;

	MVChatConnection *connection = controller.connection;
	MVChatConnection *currentConnection = nil;
	NSUInteger sectionIndex = 0;
	NSUInteger rowIndex = 0;

	for (CQDirectChatController *currentController in controllers) {
		if (currentController.connection != currentConnection) {
			if (currentConnection) ++sectionIndex;
			currentConnection = currentController.connection;
		}

		if (currentController == controller)
			return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];

		if (currentController.connection == connection && currentController != controller)
			++rowIndex;
	}

	return nil;
}

#pragma mark -

- (void) startNewChat {
	
}

#pragma mark -

- (void) addChatViewController:(id <CQChatViewController>) controller {
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

	if ([chatViewController isMemberOfClass:[CQChatRoomController class]])
		cell.removeLabelText = NSLocalizedString(@"Leave", @"Leave remove control label");
	else if ([chatViewController isMemberOfClass:[CQDirectChatController class]])
		cell.removeLabelText = NSLocalizedString(@"Close", @"Close remove control label");

	[cell takeValuesFromChatViewController:chatViewController];

	return cell;
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	MVChatConnection *connection = connectionForSection(indexPath.section);
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
	id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

	[[CQChatController defaultController] closeViewController:chatViewController];

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
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
	UIViewController *chatViewController = [controllers objectAtIndex:indexPath.row];

	[self.navigationController pushViewController:chatViewController animated:YES];
}
@end
