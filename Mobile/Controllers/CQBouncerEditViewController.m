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
static unsigned short UpdateTableSection = 3;
static unsigned short DeleteTableSection = 4;

static BOOL pushAvailable = NO;

#pragma mark -

@implementation CQBouncerEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

#if !TARGET_IPHONE_SIMULATOR
	pushAvailable = [[UIApplication sharedApplication] respondsToSelector:@selector(enabledRemoteNotificationTypes)];
#endif

	if (!pushAvailable) {
		UpdateTableSection = 2;
		DeleteTableSection = 3;
	}

	return self;
}

- (void) dealloc {
	[_settings release];

	[super dealloc];
}

#pragma mark -

@synthesize newBouncer = _newBouncer;

- (void) setNewBouncer:(BOOL) newBouncer {
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
	return (pushAvailable ? 5 : 4);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return 3;
	if (section == AuthenticationTableSection)
		return 2;
	if (pushAvailable && section == PushTableSection)
		return 1;
	if (section == UpdateTableSection)
		return 1;
	if (section == DeleteTableSection)
		return 1;
	return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == UpdateTableSection && indexPath.row == 0)
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == UpdateTableSection && indexPath.row == 0) {
		[[CQConnectionsController defaultController] refreshBouncerConnectionsWithBouncerSettings:_settings];
		[self.navigationController popViewControllerAnimated:YES];
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return NSLocalizedString(@"Colloquy Bouncer Server", @"Colloquy Bouncer Server section title");
	if (section == AuthenticationTableSection)
		return NSLocalizedString(@"Authentication", @"Authentication section title");
	return nil;
}

- (CGFloat) tableView:(UITableView *) tableView heightForFooterInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return 50.;
	if (section == PushTableSection && pushAvailable)
		return 50.;
	return 0.;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return NSLocalizedString(@"Requires a Mac running Colloquy with\nthe bouncer enabled in Preferences.", @"Bouncer Server section footer title");
	if (section == PushTableSection && pushAvailable)
		return NSLocalizedString(@"Private messages and highlighted\nroom messages are pushed.", @"Bouncer Push Notification section footer title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == ServerTableSection) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.row == 0) {
			cell.textLabel.text = NSLocalizedString(@"Description", @"Description connection setting label");

			cell.textField.text = ([_settings.displayName isEqualToString:_settings.server] ? @"" : _settings.displayName);

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Description: %@", @"Voiceover description label"), cell.textField.text];
			cell.accessibilityHint = NSLocalizedString(@"Optional", @"Voiceover optional label");

			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(descriptionChanged:);

		} else if (indexPath.row == 1) {
			cell.textLabel.text = NSLocalizedString(@"Address", @"Address connection setting label");

			cell.textField.text = (_settings.server ? _settings.server : @"");

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Address: %@", @"Voiceover address label"), cell.textField.text];
			cell.accessibilityHint = NSLocalizedString(@"Required", @"Voiceover required label");

			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeURL;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverChanged:);
		} else if (indexPath.row == 2) {
			const unsigned short defaultPort = 6667;

			cell.textLabel.text = NSLocalizedString(@"Port", @"Bouncer Port setting label");
			cell.textField.text = (_settings.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _settings.serverPort]);
			cell.textField.placeholder = [NSString stringWithFormat:@"%hu", defaultPort];
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverPortChanged:);

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Port: %hu", @"Voiceover port label"), _settings.serverPort];
		}

		return cell;
	} else if (indexPath.section == AuthenticationTableSection) {
		CQPreferencesTextCell *cell = nil;

		if (indexPath.row == 0) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.textLabel.text = NSLocalizedString(@"Account", @"Account connection setting label");
			cell.textField.text = (_settings.username ? _settings.username : @"");

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Account: %@", @"Voiceover account label"), cell.textField.text];
			cell.accessibilityHint = NSLocalizedString(@"Required", @"Voiceover required label");

			cell.textField.text = (_settings.username ? _settings.username : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(accountChanged:);
		} else if (indexPath.row == 1) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.textLabel.text = NSLocalizedString(@"Password", @"Password connection setting label");
			cell.textField.text = (_settings.password ? _settings.password : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.secureTextEntry = YES;
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(passwordChanged:);

			cell.accessibilityLabel = NSLocalizedString(@"Password", @"Voiceover password label");
			cell.accessibilityHint = NSLocalizedString(@"Required", @"Voiceover required label");
		}

		cell.target = self;

		return cell;
	} else if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.switchAction = @selector(pushEnabled:);
		cell.textLabel.text = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");

		if (_settings.pushNotifications)
			cell.accessibilityLabel = NSLocalizedString(@"Push Notifications: On", @"Voiceover push notifications on label");
		else cell.accessibilityLabel = NSLocalizedString(@"Push Notifications: Off", @"Voiceover push notification off label");

		cell.on = _settings.pushNotifications;

		return cell;
	} else if (indexPath.section == UpdateTableSection && indexPath.row == 0) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];
		UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0., 10., 320., 20.)];

		label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		label.font = [UIFont boldSystemFontOfSize:15.];
		label.textColor = [UIColor colorWithRed:(85. / 255.) green:(102. / 255.) blue:(145. / 255.) alpha:1.];
		label.highlightedTextColor = [UIColor whiteColor];

		[cell.contentView addSubview:label];

		label.text = NSLocalizedString(@"Update Connection List", @"Update Connection List button label");
		label.textAlignment = UITextAlignmentCenter;

		[label release];

		return cell;
	} else if (indexPath.section == DeleteTableSection && indexPath.row == 0) {
		CQPreferencesDeleteCell *cell = [CQPreferencesDeleteCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.deleteAction = @selector(deleteBouncer:);

		[cell.deleteButton setTitle:NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer button title") forState:UIControlStateNormal];

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
	if (sender.textField.text.length || _newBouncer) {
		_settings.server = sender.textField.text;
		if (!_newBouncer)
			self.title = _settings.displayName;
	}

	[self updateConnectButton];

	sender.textField.text = (_settings.server.length ? _settings.server : @"");
}

- (void) serverPortChanged:(CQPreferencesTextCell *) sender {
	NSUInteger newPort = [sender.textField.text integerValue];
	if (newPort)
		_settings.serverPort = (newPort % 65536);

	const unsigned short defaultPort = 6667;
	sender.textField.text = (_settings.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _settings.serverPort]);
}

- (void) descriptionChanged:(CQPreferencesTextCell *) sender {
	_settings.displayName = sender.textField.text;

	if (!_newBouncer)
		self.title = _settings.displayName;
}

- (void) accountChanged:(CQPreferencesTextCell *) sender {
	if (sender.textField.text.length || _newBouncer)
		_settings.username = sender.textField.text;

	[self updateConnectButton];

	sender.textField.text = (_settings.username ? _settings.username : @"");
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	if (sender.textField.text.length || _newBouncer)
		_settings.password = sender.textField.text;

	[self updateConnectButton];

	sender.textField.text = (_settings.password ? _settings.password : @"");
}

- (void) pushEnabled:(CQPreferencesSwitchCell *) sender {
	_settings.pushNotifications = sender.on;

	NSArray *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:_settings.identifier];
	for (MVChatConnection *connection in connections)
		[connection sendPushNotificationCommands]; 
}

- (void) deleteBouncer:(id) sender {
	if ([[UIDevice currentDevice] isPadModel]) {
		UIAlertView *alert = [[UIAlertView alloc] init];
		alert.delegate = self;

		alert.title = NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer alert title");

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];
		[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete alert button title")];

		[alert show];
		[alert release];

		return;
	}

	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer button title")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:sender animated:YES];

	[sheet release];
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;
	[[CQConnectionsController defaultController] removeBouncerSettings:_settings];
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;
	[[CQConnectionsController defaultController] removeBouncerSettings:_settings];
	[self.navigationController popViewControllerAnimated:YES];
}
@end
