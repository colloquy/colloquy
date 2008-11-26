#import "CQChatsViewController.h"

#import "CQChatTableCell.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQChatsViewController
- (id) init {
	if( ! ( self = [super init] ) )
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies view title");

	return self;
}

- (void) dealloc {
	[_chatsTableView release];
	[super dealloc];
}

- (void) loadView {
	CGRect screenBounds = [UIScreen mainScreen].bounds;

	UIView *view = [[UIView alloc] initWithFrame:screenBounds];
	view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	self.view = view;
	[view release];

	_chatsTableView = [[UITableView alloc] initWithFrame:screenBounds style:UITableViewStylePlain];
	_chatsTableView.dataSource = self;
	_chatsTableView.delegate = self;
	_chatsTableView.rowHeight = 72.;
	_chatsTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

	[self.view addSubview:_chatsTableView];
}

- (void) didReceiveMemoryWarning {
	if( ! self.view.superview ) {
		[_chatsTableView release];
		_chatsTableView = nil;
	}

	[super didReceiveMemoryWarning];
}

#pragma mark -

static MVChatConnection *connectionForSection(NSInteger section) {
	NSMutableSet *connections = [NSMutableSet set];

	for( CQDirectChatController *controller in [CQChatController defaultController].chatViewControllers ) {
		if( controller.connection ) {
			[connections addObject:controller.connection];
			if( ( section + 1 ) == connections.count )
				return controller.connection;
		}
	}

	return nil;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	NSMutableSet *connections = [NSMutableSet set];

	for( CQDirectChatController *controller in [CQChatController defaultController].chatViewControllers )
		if( controller.connection )
			[connections addObject:controller.connection];

	return connections.count ? connections.count : 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if( connection )
		return [[CQChatController defaultController] chatViewControllersForConnection:connection].count;
	return 0;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	MVChatConnection *connection = connectionForSection(section);
	if( connection )
		return connection.displayName;
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	MVChatConnection *connection = connectionForSection(indexPath.section);
	NSArray *controllers = [[CQChatController defaultController] chatViewControllersForConnection:connection];
	id <CQChatViewController> chatViewController = [controllers objectAtIndex:indexPath.row];

	CQChatTableCell *cell = [CQChatTableCell reusableTableViewCellInTableView:tableView];

	[cell takeValuesFromChatViewController:chatViewController];

	return cell;
}

- (UITableViewCellAccessoryType) tableView:(UITableView *) tableView accessoryTypeForRowWithIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellAccessoryDisclosureIndicator;
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	return UITableViewCellEditingStyleDelete;
}
@end
