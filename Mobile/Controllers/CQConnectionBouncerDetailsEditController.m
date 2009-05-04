#import "CQConnectionBouncerDetailsEditController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQKeychain.h"
#import "CQPreferencesDeleteCell.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"
#import "NSStringAdditions.h"

#define ServerTableSection 0
#define AuthenticationTableSection 1
#define DeleteTableSection 2

@implementation CQConnectionBouncerDetailsEditController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_newSettings = YES;
	_bouncerIndex = NSNotFound;
	_settings = [[NSMutableDictionary alloc] init];

	[_settings setObject:[NSString locallyUniqueString] forKey:@"identifier"];

	self.title = NSLocalizedString(@"New Bouncer", @"New Bouncer view title");

	return self;
}

- (void) dealloc {
	[_settings release];
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];

	BOOL isValid = self.valid;

	NSString *password = [_settings objectForKey:@"bouncerPassword"];
	[_settings removeObjectForKey:@"bouncerPassword"];

	if (_bouncerIndex != NSNotFound && !_removed) {
		[[CQConnectionsController defaultController] replaceBouncerInfoAtIndex:_bouncerIndex withBouncerInfo:_settings];
	} else if (isValid && !_removed) {
		_bouncerIndex = [CQConnectionsController defaultController].bouncers.count;
		[[CQConnectionsController defaultController] addBouncerInfo:_settings];
		_connection.bouncerIdentifier = [_settings objectForKey:@"identifier"];
	}

	if (password)
		[_settings setObject:password forKey:@"bouncerPassword"];

	// Workaround a bug were the table view is left in a state
	// were it thinks a keyboard is showing.
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark -

@synthesize bouncerIndex = _bouncerIndex;

@synthesize settings = _settings;

@synthesize connection = _connection;

- (void) setSettings:(NSDictionary *) settings {
	[_settings setDictionary:settings];
	_newSettings = NO;

	NSString *description = [_settings objectForKey:@"description"];
	self.title = (description.length ? description : [_settings objectForKey:@"bouncerServer"]);

	NSString *bouncerServer = [_settings objectForKey:@"bouncerServer"];
	NSString *bouncerPassword = [[CQKeychain standardKeychain] passwordForServer:bouncerServer account:@"<<bouncer password>>"];
	if (bouncerPassword) [_settings setObject:bouncerPassword forKey:@"bouncerPassword"];

	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self.tableView reloadData];
}

- (BOOL) isValid {
	if (!((NSString *)[_settings objectForKey:@"bouncerServer"]).length)
		return NO;
	if (!((NSString *)[_settings objectForKey:@"bouncerUsername"]).length)
		return NO;
	if (!((NSString *)[_settings objectForKey:@"bouncerPassword"]).length)
		return NO;
	return YES;
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return (_newSettings ? 2 : 3);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch( section) {
		case ServerTableSection: return 3;
		case AuthenticationTableSection: return 2;
		case DeleteTableSection: return 1;
		default: return 0;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	switch( section) {
		case ServerTableSection:
			if ([[UIApplication sharedApplication] respondsToSelector:@selector(enabledRemoteNotificationTypes)])
				return NSLocalizedString(@"Colloquy Push Bouncer", @"Colloquy Push Bouncer section title");
			return NSLocalizedString(@"Colloquy Bouncer", @"Colloquy Bouncer section title");
		case AuthenticationTableSection: return NSLocalizedString(@"Authentication", @"Authentication section title");
		default: return nil;
	}
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == ServerTableSection) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.row == 0) {
			NSString *bouncerDescription = [_settings objectForKey:@"description"];

			cell.label = NSLocalizedString(@"Description", @"Description connection setting label");
			cell.text = (bouncerDescription ? bouncerDescription : @"");
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(descriptionChanged:);
		} else if (indexPath.row == 1) {
			NSString *bouncerServer = [_settings objectForKey:@"bouncerServer"];

			cell.label = NSLocalizedString(@"Address", @"Address connection setting label");
			cell.text = (bouncerServer ? bouncerServer : @"");
			cell.textField.placeholder = (_newSettings ? @"irc.example.com" : @"");
			cell.textField.keyboardType = UIKeyboardTypeURL;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverChanged:);
		} else if (indexPath.row == 2) {
			const unsigned short defaultPort = 6667;
			const unsigned short bouncerPort = [[_settings objectForKey:@"bouncerServerPort"] unsignedShortValue];

			cell.target = self;
			cell.textEditAction = @selector(serverPortChanged:);
			cell.label = NSLocalizedString(@"Port", @"Port connection setting label");
			cell.text = (!bouncerPort || bouncerPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", bouncerPort]);
			cell.textField.placeholder = [NSString stringWithFormat:@"%hu", defaultPort];
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		}

		return cell;
	} else if (indexPath.section == AuthenticationTableSection) {
		CQPreferencesTextCell *cell = nil;

		if (indexPath.row == 0) {
			NSString *bouncerUsername = [_settings objectForKey:@"bouncerUsername"];

			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.textEditAction = @selector(usernameChanged:);
			cell.label = NSLocalizedString(@"Account", @"Account connection setting label");
			cell.text = (bouncerUsername ? bouncerUsername : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		} else if (indexPath.row == 1) {
			NSString *bouncerPassword = [_settings objectForKey:@"bouncerPassword"];

			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.textEditAction = @selector(passwordChanged:);
			cell.label = NSLocalizedString(@"Password", @"Password connection setting label");
			cell.text = (bouncerPassword ? bouncerPassword : @"");
			cell.textField.placeholder = NSLocalizedString(@"Required", @"Required connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.secureTextEntry = YES;
		}

		cell.target = self;

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

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (actionSheet.destructiveButtonIndex != buttonIndex)
		return;
	_removed = YES;
	if ([_connection.bouncerIdentifier isEqualToString:[_settings objectForKey:@"identifier"]])
		_connection.bouncerIdentifier = nil;
	[[CQConnectionsController defaultController] removeBouncerInfoAtIndex:_bouncerIndex];
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -

- (void) serverChanged:(CQPreferencesTextCell *) sender {
	BOOL wasPlaceholder = !((NSString *)[_settings objectForKey:@"bouncerServer"]).length;

	if (sender.text.length || _newSettings) {
		[_settings setObject:sender.text forKey:@"bouncerServer"];
		if (!_newSettings && !((NSString *)[_settings objectForKey:@"description"]).length)
			self.title = sender.text;
	}

	NSString *server = [_settings objectForKey:@"bouncerServer"];
	BOOL isPlaceholder = !server.length;
	if (wasPlaceholder && !isPlaceholder) {
		NSString *password = [_settings objectForKey:@"bouncerPassword"];
		[[CQKeychain standardKeychain] setPassword:password forServer:server account:@"<<bouncer password>>"];
	} else if (!isPlaceholder) {
		NSString *password = [[CQKeychain standardKeychain] passwordForServer:server account:@"<<bouncer password>>"];
		[_settings setObject:(password ? password : @"") forKey:@"bouncerPassword"];
	} else {
		[_settings setObject:@"" forKey:@"bouncerPassword"];
	}

	[self.tableView reloadData];
}

- (void) serverPortChanged:(CQPreferencesTextCell *) sender {
	NSUInteger port = [sender.text integerValue];
	if (!port) port = 6667;
	[_settings setObject:[NSNumber numberWithInteger:port] forKey:@"bouncerServerPort"];
}

- (void) descriptionChanged:(CQPreferencesTextCell *) sender {
	[_settings setObject:sender.text forKey:@"description"];

	if (!_newSettings)
		self.title = (sender.text.length ? sender.text : [_settings objectForKey:@"bouncerServer"]);
}

- (void) usernameChanged:(CQPreferencesTextCell *) sender {
	if (!sender.text.length && !_newSettings)
		return;

	[_settings setObject:sender.text forKey:@"bouncerUsername"];
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	if (!sender.text.length && !_newSettings)
		return;

	[_settings setObject:sender.text forKey:@"bouncerPassword"];

	NSString *server = [_settings objectForKey:@"bouncerServer"];
	if (server.length)
		[[CQKeychain standardKeychain] setPassword:sender.text forServer:server account:@"<<bouncer password>>"];
}

- (void) deleteBouncer {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Delete Bouncer", @"Delete Bouncer button title")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	if ([[[self parentViewController] parentViewController] modalViewController])
		[sheet showInView:self.view];
	else [[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}
@end
