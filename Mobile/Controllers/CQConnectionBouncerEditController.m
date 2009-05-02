#import "CQConnectionBouncerEditController.h"

#import "CQConnectionsController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesTextCell.h"
#import "CQKeychain.h"

#import <ChatCore/MVChatConnection.h>

#define EnabledTableSection 0
#define BouncersTableSection 1
#define PushTableSection 2

@implementation CQConnectionBouncerEditController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Bouncer", @"Bouncer view title");

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
//	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:IdentitiesTableSection] withAnimation:UITableViewRowAnimationNone];

	[super viewWillAppear:animated];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];

	// Workaround a bug were the table view is left in a state
	// were it thinks a keyboard is showing.
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark -

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch( section) {
//		case EnabledTableSection: return 1;
//		case BouncersTableSection: return 3;
//		case PushTableSection: return 1;
		default: return 0;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	switch( section) {
		case BouncersTableSection: return NSLocalizedString(@"Choose a Bouncer...", @"Choose a Bouncer section title");
		case PushTableSection: return NSLocalizedString(@"Push Notifications", @"Push Notifications section title");
		default: return nil;
	}

	return nil;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}
@end
