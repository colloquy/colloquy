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
			cell.label = NSLocalizedString(@"Description", @"Description connection setting label");

			if (![_settings.displayName isEqualToString:_settings.server]) {
				cell.text = @"";
				cell.accessibilityLabel = NSLocalizedString(@"Bouncer Server Description.", @"Voiceover bouncer server description label");
				cell.accessibilityHint = NSLocalizedString(@"Optional.", @"Voiceover optional label");
			} else {
				cell.text = _settings.displayName;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Bouncer server description: %@", @"Voiceover bouncer server description: %@ label"), cell.text];
			}

			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(descriptionChanged:);

		} else if (indexPath.row == 1) {
			cell.label = NSLocalizedString(@"Address", @"Address connection setting label");

			if (_settings.server.length) {
				cell.text = _settings.server;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Bouncer server address: %@.", @"Voiceover bouncer server address: %@ label"), cell.text];
			} else {
				cell.text = @"";
				cell.accessibilityLabel = NSLocalizedString(@"Bouncer server address.", @"Voiceover bouncer server address label");
				cell.accessibilityHint = NSLocalizedString(@"Required.", @"Voiceover required hint");
			}

			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeURL;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverChanged:);
		} else if (indexPath.row == 2) {
			const unsigned short defaultPort = 6667;

			cell.label = NSLocalizedString(@"Port", @"Bouncer Port setting label");
			cell.text = (_settings.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _settings.serverPort]);
			cell.textField.placeholder = [NSString stringWithFormat:@"%hu", defaultPort];
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverPortChanged:);

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Bouncer Port %hu.", @"Voiceover Bouncer Port: %hu"), _settings.serverPort];
		}

		return cell;
	} else if (indexPath.section == AuthenticationTableSection) {
		CQPreferencesTextCell *cell = nil;

		if (indexPath.row == 0) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.label = NSLocalizedString(@"Account", @"Account connection setting label");
			if (_settings.username) {
				cell.text = _settings.username;
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Bouncer Account: %@.", @"Voiceover bouncer account: %@ label"), cell.text];
			} else {
				cell.text = @"";
				cell.accessibilityLabel = NSLocalizedString(@"Bouncer Account.", @"Voiceover bouncer account label");
				cell.accessibilityHint = NSLocalizedString(@"Required.", @"Voiceover required label");
			}

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
			cell.accessibilityLabel = NSLocalizedString(@"Bouncer server password.", @"Voiceover bouncer server password label");
			cell.accessibilityHint = NSLocalizedString(@"Required", @"Voiceover required label");
		}

		cell.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
		cell.target = self;

		return cell;
	} else if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.switchAction = @selector(pushEnabled:);
		cell.label = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");

		if (_settings.pushNotifications) cell.accessibilityLabel = NSLocalizedString(@"Push notifications enabled.", @"Voiceover push notifications disabled");
		else cell.accessibilityLabel = NSLocalizedString(@"Push notifications disabled.", @"Voiceover push notification disabled");

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

	sender.text = (_settings.server.length ? _settings.server : @"");
}

- (void) serverPortChanged:(CQPreferencesTextCell *) sender {
	NSUInteger newPort = [sender.text integerValue];
	if (newPort)
		_settings.serverPort = (newPort % 65536);

	const unsigned short defaultPort = 6667;
	sender.text = (_settings.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _settings.serverPort]);
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

	sender.text = (_settings.username ? _settings.username : @"");
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length || _newBouncer)
		_settings.password = sender.text;

	[self updateConnectButton];

	sender.text = (_settings.password ? _settings.password : @"");
}

- (void) pushEnabled:(CQPreferencesSwitchCell *) sender {
	_settings.pushNotifications = sender.on;

	NSArray *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:_settings.identifier];
	for (MVChatConnection *connection in connections)
		[connection sendPushNotificationCommands]; 
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
