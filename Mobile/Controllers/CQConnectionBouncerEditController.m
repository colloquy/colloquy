#import "CQConnectionBouncerEditController.h"

#import "CQColloquyApplication.h"
#import "CQBouncerSettings.h"
#import "CQConnectionBouncerDetailsEditController.h"
#import "CQConnectionsController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

#import <ChatCore/MVChatConnection.h>

static unsigned short PushEnabledTableSection = 0;
static unsigned short BouncerEnabledTableSection = 0;
static unsigned short BouncersTableSection = 0;

static BOOL pushAvailable = NO;

@implementation CQConnectionBouncerEditController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	pushAvailable = [[UIApplication sharedApplication] respondsToSelector:@selector(enabledRemoteNotificationTypes)];

	if (pushAvailable)
		self.title = NSLocalizedString(@"Push & Bouncer", @"Push and Bouncer view title");
	else self.title = NSLocalizedString(@"Bouncer", @"Bouncer view title");

	_lastSelectedBouncerIndex = NSNotFound;

	if (pushAvailable) {
		PushEnabledTableSection = 0;
		BouncerEnabledTableSection = 1;
		BouncersTableSection = 2;
	} else {
		BouncerEnabledTableSection = 0;
		BouncersTableSection = 1;
	}

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[self.tableView reloadData];

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

	_bouncerEnabled = (_connection.bouncerType == MVChatConnectionColloquyBouncer && _connection.bouncerIdentifier.length);

	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	if (pushAvailable)
		return (_bouncerEnabled ? 3 : 2);
	return (_bouncerEnabled ? 2 : 1);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (pushAvailable && section == PushEnabledTableSection)
		return 1;
	if (section == BouncerEnabledTableSection)
		return 1;
	if (section == BouncersTableSection)
		return ([CQConnectionsController defaultController].bouncers.count + 1);
	return 0;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == BouncersTableSection)
		return NSLocalizedString(@"Choose a Bouncer...", @"Choose a Bouncer section title");
	return nil;
}

- (CGFloat) tableView:(UITableView *) tableView heightForFooterInSection:(NSInteger) section {
	if (section == PushEnabledTableSection)
		return 90.;
	if (section == BouncerEnabledTableSection)
		return 55.;
	return 0.;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (pushAvailable && section == PushEnabledTableSection)
		return NSLocalizedString(@"Private messages and highlighted room messages will be pushed while Colloquy\nisn't open. Push notifications require\nconnecting to a push aware bouncer.", @"Push Notification section footer title");
	if (section == BouncerEnabledTableSection)
		return NSLocalizedString(@"Using a Colloquy bouncer will keep you\nconnected while Colloquy isn't open.", @"Use Bouncer section footer title");
	return nil;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == BouncersTableSection)
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	NSParameterAssert(indexPath.section == BouncersTableSection);

	NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
	NSParameterAssert(indexPath.row < bouncers.count);

	CQConnectionBouncerDetailsEditController *bouncerDetailsController = [[CQConnectionBouncerDetailsEditController alloc] init];
	bouncerDetailsController.settings = [bouncers objectAtIndex:indexPath.row];
	bouncerDetailsController.connection = _connection;

	[self.view endEditing:YES];

	[self.navigationController pushViewController:bouncerDetailsController animated:YES];

	[bouncerDetailsController release];
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == BouncersTableSection) {
		if (indexPath.row >= [CQConnectionsController defaultController].bouncers.count) {
			CQConnectionBouncerDetailsEditController *bouncerDetailsController = [[CQConnectionBouncerDetailsEditController alloc] init];
			bouncerDetailsController.connection = _connection;

			[self.view endEditing:YES];

			[self.navigationController pushViewController:bouncerDetailsController animated:YES];

			[bouncerDetailsController release];
			return;
		} else {
			UITableViewCell *cell = (_lastSelectedBouncerIndex != NSNotFound ? [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_lastSelectedBouncerIndex inSection:BouncersTableSection]] : nil);
			cell.image = nil;
			cell.selectedImage = nil;
			cell.textColor = [UIColor blackColor];
			cell.indentationLevel = 1;

			CQBouncerSettings *settings = [[CQConnectionsController defaultController].bouncers objectAtIndex:indexPath.row];

			_lastSelectedBouncerIndex = indexPath.row;
			_connection.bouncerIdentifier = settings.identifier;

			cell = [tableView cellForRowAtIndexPath:indexPath];
			cell.image = [UIImage imageNamed:@"tableCellCheck.png"];
			cell.selectedImage = [UIImage imageNamed:@"tableCellCheckSelected.png"];
			cell.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
			cell.indentationLevel = 0;

			[tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
			return;
		}
	}
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (pushAvailable && indexPath.section == PushEnabledTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.switchAction = @selector(pushEnabled:);
		cell.label = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");
		cell.on = _connection.pushNotifications;

		return cell;
	} else if (indexPath.section == BouncerEnabledTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.switchAction = @selector(bouncerEnabled:);
		cell.label = NSLocalizedString(@"Colloquy Bouncer", @"Colloquy Bouncer connection setting label");
		cell.on = _bouncerEnabled;

		return cell;
	} else if (indexPath.section == BouncersTableSection) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

		cell.image = nil;
		cell.selectedImage = nil;
		cell.textColor = [UIColor blackColor];
		cell.indentationWidth = 11.5;
		cell.indentationLevel = 1;

		NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
		if (indexPath.row < bouncers.count) {
			CQBouncerSettings *bouncerSettings = [bouncers objectAtIndex:indexPath.row];
			cell.text = bouncerSettings.displayName;
			cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
			if ([_connection.bouncerIdentifier isEqualToString:bouncerSettings.identifier]) {
				_lastSelectedBouncerIndex = indexPath.row;
				cell.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
				cell.image = [UIImage imageNamed:@"tableCellCheck.png"];
				cell.selectedImage = [UIImage imageNamed:@"tableCellCheckSelected.png"];
				cell.indentationLevel = 0;
			}
		} else {
			cell.text = NSLocalizedString(@"Add Bouncer...", @"Add Bouncer connection setting label");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) pushEnabled:(CQPreferencesSwitchCell *) sender {
	_connection.pushNotifications = sender.on;
}

- (void) bouncerEnabled:(CQPreferencesSwitchCell *) sender {
	_bouncerEnabled = sender.on;

	if (!_bouncerEnabled)
		_connection.bouncerType = MVChatConnectionNoBouncer;

	if (sender.on) {
		CQBouncerSettings *settings = _connection.bouncerSettings;

		if (!settings) {
			settings = [[CQConnectionsController defaultController].bouncers lastObject];
			_connection.bouncerSettings = settings;
		}

		_connection.bouncerType = settings.type;

		[self.tableView insertSections:[NSIndexSet indexSetWithIndex:BouncersTableSection] withRowAnimation:UITableViewRowAnimationBottom];
	} else {
		[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:BouncersTableSection] withRowAnimation:UITableViewRowAnimationTop];
	}
}
@end
