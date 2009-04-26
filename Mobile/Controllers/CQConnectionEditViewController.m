#import "CQConnectionEditViewController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionAdvancedEditController.h"
#import "CQConnectionsController.h"
#import "CQKeychain.h"
#import "CQPreferencesDeleteCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

#import <ChatCore/MVChatConnection.h>

static inline BOOL isDefaultValue(NSString *string) {
	return [string isEqualToString:@"<<default>>"];
}

static inline BOOL isPlaceholderValue(NSString *string) {
	return [string isEqualToString:@"<<placeholder>>"];
}

static inline NSString *currentPreferredNickname(MVChatConnection *connection) {
	NSString *preferredNickname = connection.preferredNickname;
	return (isDefaultValue(preferredNickname) ? [MVChatConnection defaultNickname] : preferredNickname);
}

#pragma mark -

@implementation CQConnectionEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;
	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:2] withAnimation:UITableViewRowAnimationNone];

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

- (void) setNewConnection:(BOOL)newConnection {
	if (_newConnection ==  newConnection)
		return;

	_newConnection = newConnection;

	if (_newConnection) self.title = NSLocalizedString(@"New Connection", @"New Connection view title");
	else self.title = _connection.displayName;
}

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	if (!_newConnection)
		self.title = connection.displayName;

	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	if (self.newConnection)
		return 4;
	return 5;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch(section) {
		case 0: return 2;
		case 1: return 2;
		case 2: return 2;
		case 3: return 1;
		case 4: return 1;
		default: return 0;
	}
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ((indexPath.section == 2 && indexPath.row == 1) || (indexPath.section == 3 && indexPath.row == 0))
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 2 && indexPath.row == 1) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		listViewController.title = NSLocalizedString(@"Join Rooms", @"Join Rooms view title");
		listViewController.items = _connection.automaticJoinedRooms;
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQShowsChatIcons"])
			listViewController.itemImage = [UIImage imageNamed:@"roomIconSmall.png"];
		listViewController.addItemLabelText = NSLocalizedString(@"Add chat room", @"Add chat room label");
		listViewController.noItemsLabelText = NSLocalizedString(@"No chat rooms", @"No chat rooms label");
		listViewController.editViewTitle = NSLocalizedString(@"Edit Chat Room", @"Edit Chat Room view title");
		listViewController.editPlaceholder = NSLocalizedString(@"Chat Room", @"Chat Room placeholder");

		listViewController.target = self;
		listViewController.action = @selector(automaticJoinRoomsChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];

		return;
	}

	if (indexPath.section == 3 && indexPath.row == 0) {
		CQConnectionAdvancedEditController *advancedEditViewController = [[CQConnectionAdvancedEditController alloc] init];

		advancedEditViewController.navigationItem.prompt = self.navigationItem.prompt;
		advancedEditViewController.newConnection = _newConnection;
		advancedEditViewController.connection = _connection;

		[self.view endEditing:YES];

		[self.navigationController pushViewController:advancedEditViewController animated:YES];

		[advancedEditViewController release];

		return;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == 0)
		return NSLocalizedString(@"Internet Relay Chat Server", @"Internet Relay Chat Server section title");
	if (section == 1)
		return NSLocalizedString(@"Network Identity", @"Network Identity section title");
	if (section == 2)
		return NSLocalizedString(@"Automatic Actions", @"Automatic Actions section title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.row == 0) {
			cell.label = NSLocalizedString(@"Host Name", @"Host Name connection setting label");
			cell.text = (isPlaceholderValue(_connection.server) ? @"" : _connection.server);
			cell.textField.placeholder = (_newConnection ? @"irc.example.com" : @"");
			cell.textField.keyboardType = UIKeyboardTypeURL;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(serverChanged:);
		} else if (indexPath.row == 1) {
			cell.label = NSLocalizedString(@"Description", @"Description connection setting label");
			cell.text = (![_connection.displayName isEqualToString:_connection.server] ? _connection.displayName : @"");
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(descriptionChanged:);
		}

		return cell;
	} else if (indexPath.section == 1) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.row == 0) {
			cell.label = NSLocalizedString(@"Nickname", @"Nickname connection setting label");
			cell.text = (isDefaultValue(_connection.preferredNickname) ? @"" : _connection.preferredNickname);
			cell.textField.placeholder = [MVChatConnection defaultNickname];
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textEditAction = @selector(nicknameChanged:);
		} else if (indexPath.row == 1) {
			cell.label = NSLocalizedString(@"Real Name", @"Real Name connection setting label");
			cell.text = (isDefaultValue(_connection.realName) ? @"" : _connection.realName);
			cell.textField.placeholder = [MVChatConnection defaultRealName];
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(realNameChanged:);
		}

		return cell;
	} else if (indexPath.section == 2) {
		if (indexPath.row == 0) {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

			cell.target = self;
			cell.switchAction = @selector(autoConnectChanged:);
			cell.label = NSLocalizedString(@"Connect at Launch", @"Connect at Launch connection setting label");
			cell.on = _connection.automaticallyConnect;

			return cell;
		} else if (indexPath.row == 1) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.label = NSLocalizedString(@"Join Rooms", @"Join Rooms connection setting label");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

			if (_connection.automaticJoinedRooms.count)
				cell.text = [_connection.automaticJoinedRooms componentsJoinedByString:@", "];
			else cell.text = NSLocalizedString(@"No Rooms", @"No Rooms label");

			return cell;
		}
	} else if (indexPath.section == 3 && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = NSLocalizedString(@"Advanced", @"Advanced connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		return cell;
	} else if (indexPath.section == 4 && indexPath.row == 0) {
		CQPreferencesDeleteCell *cell = [CQPreferencesDeleteCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.text = NSLocalizedString(@"Delete Connection", @"Delete Connection button title");
		cell.deleteAction = @selector(deleteConnection);

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) serverChanged:(CQPreferencesTextCell *) sender {
	BOOL wasPlaceholder = isPlaceholderValue(_connection.server);

	if (sender.text.length || _newConnection) {
		_connection.server = (sender.text.length ? sender.text : @"<<placeholder>>");
		if (!_newConnection)
			self.title = _connection.displayName;
	}

	BOOL placeholder = isPlaceholderValue(_connection.server);
	if (wasPlaceholder && !placeholder) {
		[[CQKeychain standardKeychain] setPassword:_connection.password forServer:_connection.server account:@"<<server password>>"];
		[[CQKeychain standardKeychain] setPassword:_connection.nicknamePassword forServer:_connection.server account:currentPreferredNickname(_connection)];
	} else if (!placeholder) {
		_connection.password = [[CQKeychain standardKeychain] passwordForServer:_connection.server account:@"<<server password>>"];
		_connection.nicknamePassword = [[CQKeychain standardKeychain] passwordForServer:_connection.server account:currentPreferredNickname(_connection)];
	} else {
		_connection.password = nil;
		_connection.nicknamePassword = nil;
	}

	if (self.navigationItem.rightBarButtonItem.tag == UIBarButtonSystemItemSave)
		self.navigationItem.rightBarButtonItem.enabled = !placeholder;

	[self.tableView reloadData];
}

- (void) nicknameChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length)
		_connection.preferredNickname = sender.text;
	else _connection.preferredNickname = (_newConnection ? @"<<default>>" : sender.textField.placeholder);

	if (!isPlaceholderValue(_connection.server))
		_connection.nicknamePassword = [[CQKeychain standardKeychain] passwordForServer:_connection.server account:currentPreferredNickname(_connection)];
	else _connection.nicknamePassword = nil;

	[self.tableView reloadData];
}

- (void) realNameChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length)
		_connection.realName = sender.text;
	else _connection.realName = (_newConnection ? @"<<default>>" : sender.textField.placeholder);

	[self.tableView reloadData];
}

- (void) descriptionChanged:(CQPreferencesTextCell *) sender {
	_connection.displayName = sender.text;

	if (!_newConnection)
		self.title = _connection.displayName;
}

- (void) autoConnectChanged:(CQPreferencesSwitchCell *) sender {
	_connection.automaticallyConnect = sender.on;
}

- (void) automaticJoinRoomsChanged:(CQPreferencesListViewController *) sender {
	_connection.automaticJoinedRooms = sender.items;
}

- (void) deleteConnection {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Delete Connection", @"Delete Connection button title")];
	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet];

	[sheet release];
}

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (actionSheet.destructiveButtonIndex != buttonIndex)
		return;
	[[CQConnectionsController defaultController] removeConnection:_connection];
	[self.navigationController popViewControllerAnimated:YES];
}
@end
