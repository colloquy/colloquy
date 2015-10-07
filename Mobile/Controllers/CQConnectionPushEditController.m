#import "CQConnectionPushEditController.h"

#import "CQAlertView.h"
#import "CQConnectionsController.h"
#import "CQPreferencesSwitchCell.h"

#define PushEnabledTableSection 0

NS_ASSUME_NONNULL_BEGIN

@implementation CQConnectionPushEditController
- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Push Notifications", @"Push Notifications view title");

	return self;
}

#pragma mark -

- (void) setConnection:(MVChatConnection *) connection {
	_connection = connection;

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

- (NSString *__nullable) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == PushEnabledTableSection && [UIDevice currentDevice].isPadModel && self.view.window.isFullscreen)
		return NSLocalizedString(@"Private messages and highlighted room messages\nare pushed. Push notifications require connecting\nto a push aware bouncer.", @"Push Notification section footer title");
	if (section == PushEnabledTableSection)
		return NSLocalizedString(@"Private messages and highlighted\nroom messages are pushed.\n\nPush notifications require connecting\nto a push aware bouncer.", @"Push Notification section footer title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == PushEnabledTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.switchAction = @selector(pushEnabled:);
		cell.textLabel.text = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");
		cell.on = _connection.pushNotifications;

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	[self.tableView beginUpdates];
	[self.tableView reloadRowsAtIndexPaths:self.tableView.indexPathsForVisibleRows withRowAnimation:UITableViewRowAnimationAutomatic];
	[self.tableView endUpdates];
}

#pragma mark -

- (void) pushEnabled:(CQPreferencesSwitchCell *) sender {
	if (_connection.connected || self.newConnection)
		_connection.pushNotifications = sender.on;
	else {
		UIAlertView *alertView = [[CQAlertView alloc] initWithTitle:@"Connection Required" message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Okay", @"Okay button title") otherButtonTitles:nil];
		if (_connection.pushNotifications)
			alertView.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to disable push notifications for %@. Please connect and try again." , @"Unable to turn push notifications off message"), _connection.displayName];
		else alertView.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to enable push notifications for %@. Please connect and try again." , @"Unable to turn push notifications off message"), _connection.displayName];
		[alertView show];
	}
}
@end

NS_ASSUME_NONNULL_END
