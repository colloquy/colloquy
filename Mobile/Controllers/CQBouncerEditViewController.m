#import "CQBouncerEditViewController.h"

#import "CQBouncerSettings.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQPreferencesDeleteCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

static unsigned short ServerTableSection = 0;
static unsigned short AuthenticationTableSection = 1;
static unsigned short PushTableSection = 2;
static unsigned short DeleteTableSection = 3;

static BOOL pushAvailable = NO;

#pragma mark -

@implementation CQBouncerEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

#if !TARGET_IPHONE_SIMULATOR
	pushAvailable = [[UIApplication sharedApplication] respondsToSelector:@selector(enabledRemoteNotificationTypes)];
#endif

	if (!pushAvailable)
		DeleteTableSection = 2;

	return self;
}

- (void) dealloc {
	[_settings release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];

	// Workaround a bug were the table view is left in a state
	// were it thinks a keyboard is showing.
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark -

@synthesize newBouncer = _newBouncer;

- (void) setNewBOuncer:(BOOL) newBouncer {
	if (_newBouncer ==  newBouncer)
		return;

	_newBouncer = newBouncer;

	if (_newBouncer) self.title = NSLocalizedString(@"New Bouncer", @"New Bouncer view title");
	else self.title = _settings.displayName;
}

@synthesize settings = _settings;

- (void) setSettings:(CQBouncerSettings *) settings {
	id old = _settings;
	_settings = [settings retain];
	[old release];

	if (!_newBouncer)
		self.title = settings.displayName;

	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	if (_newBouncer)
		return (pushAvailable ? 3 : 2);
	return (pushAvailable ? 4 : 3);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return 3;
	if (section == AuthenticationTableSection)
		return 2;
	if (pushAvailable && section == PushTableSection)
		return 1;
	if (section == DeleteTableSection)
		return 1;
	return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return NSLocalizedString(@"Colloquy Bouncer Server", @"Colloquy Bouncer Server section title");
	if (section == AuthenticationTableSection)
		return NSLocalizedString(@"Authentication", @"Authentication section title");
	return nil;
}

- (CGFloat) tableView:(UITableView *) tableView heightForFooterInSection:(NSInteger) section {
	if (section == PushTableSection && pushAvailable)
		return 50.;
	return 0.;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == PushTableSection && pushAvailable)
		return NSLocalizedString(@"Private messages and highlighted\nroom messages are pushed.", @"Bouncer Push Notification section footer title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == ServerTableSection) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.row == 0) {
			cell.label = NSLocalizedString(@"Description", @"Description connection setting label");
			cell.text = (![_settings.displayName isEqualToString:_settings.server] ? _settings.displayName : @"");
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(descriptionChanged:);
		} else if (indexPath.row == 1) {
			cell.label = NSLocalizedString(@"Address", @"Address connection setting label");
			cell.text = (_settings.server ? _settings.server : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeURL;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverChanged:);
		} else if (indexPath.row == 2) {
			const unsigned short defaultPort = 6667;

			cell.label = NSLocalizedString(@"Server Port", @"Server Port connection setting label");
			cell.text = (_settings.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _settings.serverPort]);
			cell.textField.placeholder = [NSString stringWithFormat:@"%hu", defaultPort];
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverPortChanged:);
		}

		return cell;
	} else if (indexPath.section == AuthenticationTableSection) {
		CQPreferencesTextCell *cell = nil;

		if (indexPath.row == 0) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.label = NSLocalizedString(@"Account", @"Account connection setting label");
			cell.text = (_settings.username ? _settings.username : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(accountChanged:);
		} else if (indexPath.row == 1) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.label = NSLocalizedString(@"Password", @"Password connection setting label");
			cell.text = (_settings.password ? _settings.password : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.secureTextEntry = YES;
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(passwordChanged:);
		}

		cell.target = self;

		return cell;
	} else if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.switchAction = @selector(pushEnabled:);
		cell.label = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");
		cell.on = _settings.pushNotifications;

		return cell;
	} else if (indexPath.section == DeleteTableSection && indexPath.row == 0) {
		CQPreferencesDeleteCell *cell = [CQPreferencesDeleteCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.text = NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer button title");
		cell.deleteAction = @selector(deleteBouncer);

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) updateConnectButton {
	if (self.navigationItem.rightBarButtonItem.tag == UIBarButtonSystemItemSave)
		self.navigationItem.rightBarButtonItem.enabled = (_settings.server.length && _settings.username.length && _settings.password.length);
}

- (void) serverChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length || _newBouncer) {
		_settings.server = sender.text;
		if (!_newBouncer)
			self.title = _settings.displayName;
	}

	[self updateConnectButton];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:ServerTableSection] withAnimation:UITableViewRowAnimationNone];
}

- (void) serverPortChanged:(CQPreferencesTextCell *) sender {
	NSUInteger newPort = [sender.text integerValue];
	if (newPort)
		_settings.serverPort = (newPort % 65536);

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:ServerTableSection] withAnimation:UITableViewRowAnimationNone];
}

- (void) descriptionChanged:(CQPreferencesTextCell *) sender {
	_settings.displayName = sender.text;

	if (!_newBouncer)
		self.title = _settings.displayName;
}

- (void) accountChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length || _newBouncer)
		_settings.username = sender.text;

	[self updateConnectButton];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:AuthenticationTableSection] withAnimation:UITableViewRowAnimationNone];
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length || _newBouncer)
		_settings.password = sender.text;

	[self updateConnectButton];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:AuthenticationTableSection] withAnimation:UITableViewRowAnimationNone];
}

- (void) pushEnabled:(CQPreferencesSwitchCell *) sender {
	_settings.pushNotifications = sender.on;
}

- (void) deleteBouncer {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer button title")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (actionSheet.destructiveButtonIndex != buttonIndex)
		return;
	[[CQConnectionsController defaultController] removeBouncerSettings:_settings];
	[self.navigationController popViewControllerAnimated:YES];
}
@end
