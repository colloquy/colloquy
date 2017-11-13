#import "CQBouncerEditViewController.h"

#import "CQBouncerSettings.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQPreferencesDeleteCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

@import OnePasswordExtension;

static unsigned short ServerTableSection = 0;
static unsigned short AuthenticationTableSection = 1;
static unsigned short PushTableSection = 2;
static unsigned short UpdateTableSection = 3;
static unsigned short DeleteTableSection = 4;

#if TARGET_IPHONE_SIMULATOR
static BOOL pushAvailable = NO;
#else
static BOOL pushAvailable = YES;
#endif

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@implementation CQBouncerEditViewController
- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	if (!pushAvailable) {
		UpdateTableSection = 2;
		DeleteTableSection = 3;
	}

	return self;
}

#pragma mark -

- (void) setNewBouncer:(BOOL) newBouncer {
	if (_newBouncer == newBouncer)
		return;

	_newBouncer = newBouncer;

	if (_newBouncer) self.title = NSLocalizedString(@"New Bouncer", @"New Bouncer view title");
	else self.title = _settings.displayName;
}

- (void) setSettings:(CQBouncerSettings *) settings {
	_settings = settings;

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

- (NSIndexPath *__nullable) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
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

- (NSString *__nullable) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return NSLocalizedString(@"Colloquy Bouncer Server", @"Colloquy Bouncer Server section title");
	if (section == AuthenticationTableSection)
		return NSLocalizedString(@"Authentication", @"Authentication section title");
	return nil;
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return NSLocalizedString(@"Requires a Mac running Colloquy with\nthe bouncer enabled in Preferences.", @"Bouncer Server section footer title");
	if (section == PushTableSection && pushAvailable)
		return NSLocalizedString(@"Private messages and highlighted\nroom messages are pushed.", @"Bouncer Push Notification section footer title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == ServerTableSection) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

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

			if ([[OnePasswordExtension sharedExtension] isAppExtensionAvailable]) {
				UIButton *onePasswordButton = [UIButton buttonWithType:UIButtonTypeSystem];
				[onePasswordButton addTarget:self action:@selector(onePasswordActionForPassword:) forControlEvents:UIControlEventTouchUpInside];

				UIImage *onePasswordImage = [UIImage imageNamed:@"onepassword-toolbar" inBundle:[NSBundle bundleForClass:[OnePasswordExtension class]] compatibleWithTraitCollection:nil];
				[onePasswordButton setImage:onePasswordImage forState:UIControlStateNormal];

				cell.textField.rightView = onePasswordButton;
				cell.textField.rightViewMode = UITextFieldViewModeAlways;

				[onePasswordButton sizeToFit];

				onePasswordButton.transform = CGAffineTransformMakeScale(.83, .83);
			}
		}

		if (cell)
			return cell;

		__builtin_unreachable();
	} else if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

		cell.switchAction = @selector(pushEnabled:);
		cell.textLabel.text = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");

		if (_settings.pushNotifications)
			cell.accessibilityLabel = NSLocalizedString(@"Push Notifications: On", @"Voiceover push notifications on label");
		else cell.accessibilityLabel = NSLocalizedString(@"Push Notifications: Off", @"Voiceover push notification off label");

		cell.on = _settings.pushNotifications;

		return cell;
	} else if (indexPath.section == UpdateTableSection && indexPath.row == 0) {
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];

		cell.textLabel.font = [UIFont boldSystemFontOfSize:15.];
		cell.textLabel.textColor = [UIColor colorWithRed:(85. / 255.) green:(102. / 255.) blue:(145. / 255.) alpha:1.];
		cell.textLabel.highlightedTextColor = [UIColor whiteColor];

		cell.textLabel.text = NSLocalizedString(@"Update Connection List", @"Update Connection List button label");
		cell.textLabel.textAlignment = NSTextAlignmentCenter;

		return cell;
	} else if (indexPath.section == DeleteTableSection && indexPath.row == 0) {
		CQPreferencesDeleteCell *cell = [CQPreferencesDeleteCell reusableTableViewCellInTableView:tableView];

		cell.deleteAction = @selector(deleteBouncer:);

		[cell.deleteButton setTitle:NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer button title") forState:UIControlStateNormal];

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	__builtin_unreachable();
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

	NSArray <MVChatConnection *> *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:_settings.identifier];
	for (MVChatConnection *connection in connections)
		[connection sendPushNotificationCommands]; 
}

- (void) deleteBouncer:(__nullable id) sender {
	UIAlertControllerStyle style = UIAlertControllerStyleActionSheet;

	if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular && self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular) {
		style = UIAlertControllerStyleAlert;
	}

	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer alert title") message:@"" preferredStyle:style];
	[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss button title") style:UIAlertActionStyleCancel handler:nil]];
	[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", @"Delete button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[CQConnectionsController defaultController] removeBouncerSettings:_settings];
		[self.navigationController dismissViewControllerAnimated:YES completion:NULL];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (void) onePasswordActionForPassword:(id) sender {
	[[OnePasswordExtension sharedExtension] findLoginForURLString:_settings.server forViewController:self sender:sender completion:^(NSDictionary *loginDictionary, NSError *error) {
		if (!loginDictionary.count) {
			if (error.code != AppExtensionErrorCodeCancelledByUser) {
				UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
				[alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Okay", @"Okay button title") style:UIAlertActionStyleCancel handler:NULL]];
				[self presentViewController:alert animated:YES completion:nil];
			}

			return;
		}

		_settings.password = loginDictionary[AppExtensionPasswordKey];
		_settings.username = _settings.username.length ? _settings.username : loginDictionary[AppExtensionUsernameKey];

		[self.tableView beginUpdates];
		[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:AuthenticationTableSection] withRowAnimation:UITableViewRowAnimationAutomatic];
		[self.tableView endUpdates];

		[self updateConnectButton];
	}];
}
@end

NS_ASSUME_NONNULL_END
