#import "CQConnectionPushEditController.h"

#import "CQConnectionsController.h"
#import "CQPreferencesSwitchCell.h"

#define PushEnabledTableSection 0

@implementation CQConnectionPushEditController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Push Notifications", @"Push Notifications view title");

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
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
	if (section == PushEnabledTableSection)
		return 1;
	return 0;
}

- (CGFloat) tableView:(UITableView *) tableView heightForFooterInSection:(NSInteger) section {
	if (section == PushEnabledTableSection)
		return 100.;
	return 0.;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == PushEnabledTableSection && [[UIDevice currentDevice] isPadModel])
		return NSLocalizedString(@"Private messages and highlighted room messages\nare pushed. Push notifications require connecting\nto apush aware bouncer.", @"Push Notification section footer title");
	if (section == PushEnabledTableSection)
		return NSLocalizedString(@"Private messages and highlighted\nroom messages are pushed.\n\nPush notifications require connecting\nto a push aware bouncer.", @"Push Notification section footer title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == PushEnabledTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.switchAction = @selector(pushEnabled:);
		cell.textLabel.text = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");
		cell.on = _connection.pushNotifications;

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) pushEnabled:(CQPreferencesSwitchCell *) sender {
	_connection.pushNotifications = sender.on;
}
@end
