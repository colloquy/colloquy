#import "CQConnectionAdvancedEditController.h"

#import "CQConnectionsController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesTextCell.h"
#import "CQKeychain.h"

#import <ChatCore/MVChatConnection.h>

static inline BOOL isDefaultValue(NSString *string) {
	return [string isEqualToString:@"<<default>>"];
}

static inline BOOL isPlaceholderValue(NSString *string) {
	return [string isEqualToString:@"<<placeholder>>"];
}

static inline __attribute__((always_inline)) NSString *currentPreferredNickname(MVChatConnection *connection) {
	NSString *preferredNickname = connection.preferredNickname;
	return (isDefaultValue(preferredNickname) ? [MVChatConnection defaultNickname] : preferredNickname);
}

#pragma mark -

@implementation CQConnectionAdvancedEditController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Advanced", @"Advanced view title");

	return self;
}

- (void) dealloc {
	[_connection release];
	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2] withAnimation:UITableViewRowAnimationFade];
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:3] withAnimation:UITableViewRowAnimationFade];

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

@synthesize newConnection = _newConnection;

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
	return 4;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch( section) {
		case 0: return 2;
		case 1: return 3;
		case 2: return 1;
		case 3: return 1;
		default: return 0;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	switch( section) {
		case 0: return NSLocalizedString(@"Connection Settings", @"Connection Settings section title");
		case 1: return NSLocalizedString(@"Authentication", @"Authentication section title");
		case 2: return NSLocalizedString(@"Alternate Network Identities", @"Alternate Network Identities section title");
		case 3: return NSLocalizedString(@"Automatic Actions", @"Automatic Actions section title");
		default: return nil;
	}

	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == 1)
		return NSLocalizedString(@"The nickname password is used to\nauthenicate with services (e.g. NickServ).", @"Authentication section footer title");
	return nil;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ((indexPath.section == 2 && indexPath.row == 0) || (indexPath.section == 3 && indexPath.row == 0))
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 2 && indexPath.row == 0) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		listViewController.title = NSLocalizedString(@"Nicknames", @"Nicknames view title");
		listViewController.items = _connection.alternateNicknames;
		listViewController.addItemLabelText = NSLocalizedString(@"Add nickname", @"Add nickname label");
		listViewController.noItemsLabelText = NSLocalizedString(@"No nicknames", @"No nicknames label");
		listViewController.editViewTitle = NSLocalizedString(@"Edit Nickname", @"Edit Nickname view title");
		listViewController.editPlaceholder = NSLocalizedString(@"Nickname", @"Nickname placeholder");

		listViewController.target = self;
		listViewController.action = @selector(alternateNicknamesChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];

		return;
	}

	if (indexPath.section == 3 && indexPath.row == 0) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		listViewController.title = NSLocalizedString(@"Commands", @"Commands view title");
		listViewController.items = _connection.automaticCommands;
		listViewController.addItemLabelText = NSLocalizedString(@"Add command", @"Add command label");
		listViewController.noItemsLabelText = NSLocalizedString(@"No commands", @"No commands label");
		listViewController.editViewTitle = NSLocalizedString(@"Edit Command", @"Edit Command view title");
		listViewController.editPlaceholder = NSLocalizedString(@"Command", @"Command placeholder");

		listViewController.target = self;
		listViewController.action = @selector(automaticCommandsChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];

		return;
	}
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			unsigned short defaultPort = _connection.secure ? 994 : 6667;

			cell.target = self;
			cell.textEditAction = @selector(serverPortChanged:);
			cell.label = NSLocalizedString(@"Server Port", @"Server Port connection setting label");
			cell.text = (_connection.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _connection.serverPort]);
			cell.textField.placeholder = [NSString stringWithFormat:@"%hu", defaultPort];
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;

			return cell;
		} else if (indexPath.row == 1) {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

			cell.target = self;
			cell.switchAction = @selector(secureChanged:);
			cell.label = NSLocalizedString(@"Use SSL", @"Use SSL connection setting label");
			cell.on = _connection.secure;

			return cell;
		}
	} else if (indexPath.section == 1) {
		CQPreferencesTextCell *cell = nil;

		if(indexPath.row == 0) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.textEditAction = @selector(usernameChanged:);
			cell.label = NSLocalizedString(@"Username", @"Username connection setting label");
			cell.text = (isDefaultValue(_connection.username) ? @"" : _connection.username);
			cell.textField.placeholder = (isDefaultValue(_connection.preferredNickname) ? [[MVChatConnection defaultNickname] lowercaseString] : [_connection.preferredNickname lowercaseString]);
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		} else if (indexPath.row == 1) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.textEditAction = @selector(passwordChanged:);
			cell.label = NSLocalizedString(@"Password", @"Password connection setting label");
			cell.text = _connection.password;
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.secureTextEntry = YES;
		} else if (indexPath.row == 2) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.textEditAction = @selector(nicknamePasswordChanged:);
			cell.label = NSLocalizedString(@"Nick Pass.", @"Nickname Password connection setting label");
			cell.text = _connection.nicknamePassword;
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.secureTextEntry = YES;
		}

		cell.target = self;

		return cell;
	} else if (indexPath.section == 2 && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		if (_connection.alternateNicknames.count)
			cell.text = [_connection.alternateNicknames componentsJoinedByString:@", "];

		if (_connection.alternateNicknames.count)
			cell.text = [_connection.alternateNicknames componentsJoinedByString:@", "];
		else cell.textField.placeholder = [NSString stringWithFormat:@"%@_, %1$@__, %1$@___", currentPreferredNickname(_connection)];

		cell.label = NSLocalizedString(@"Nicknames", @"Nicknames connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		return cell;
	} else if (indexPath.section == 3 && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = NSLocalizedString(@"Commands", @"Commands connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		NSArray *commands = _connection.automaticCommands;
		if (commands.count == 1)
			cell.text = NSLocalizedString(@"1 Command", @"One Command label");
		else if (commands.count)
			cell.text = [NSString stringWithFormat:NSLocalizedString(@"%u Commands", @"Multiple Commands label"), commands.count];
		else cell.text = NSLocalizedString(@"No Commands", @"No Commands label");

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) serverPortChanged:(CQPreferencesTextCell *) sender {
	_connection.serverPort = [sender.text longLongValue];

	[self.tableView reloadData];
}

- (void) secureChanged:(CQPreferencesSwitchCell *) sender {
	_connection.secure = sender.on;

	if (_connection.secure && _connection.serverPort == 6667)
		_connection.serverPort = 994;
	else if (!_connection.secure && _connection.serverPort == 994)
		_connection.serverPort = 6667;

	[self.tableView reloadData];
}

- (void) usernameChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length)
		_connection.username = sender.text;
	else _connection.username = (_newConnection ? @"<<default>>" : sender.textField.placeholder);

	[self.tableView reloadData];
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	_connection.password = sender.text;

	if (!isPlaceholderValue(_connection.server))
		[[CQKeychain standardKeychain] setPassword:_connection.password forServer:_connection.server account:nil];
}

- (void) nicknamePasswordChanged:(CQPreferencesTextCell *) sender {
	_connection.nicknamePassword = sender.text;

	if (!isPlaceholderValue(_connection.server))
		[[CQKeychain standardKeychain] setPassword:_connection.nicknamePassword forServer:_connection.server account:currentPreferredNickname(_connection)];
}

- (void) alternateNicknamesChanged:(CQPreferencesListViewController *) sender {
	_connection.alternateNicknames = sender.items;
}

- (void) automaticCommandsChanged:(CQPreferencesListViewController *) sender {
	_connection.automaticCommands = sender.items;
}
@end
