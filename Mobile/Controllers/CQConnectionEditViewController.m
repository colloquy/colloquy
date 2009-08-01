#import "CQConnectionEditViewController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionAdvancedEditController.h"
#import "CQConnectionPushEditController.h"
#import "CQConnectionsController.h"
#import "CQPreferencesDeleteCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

#import <ChatCore/MVChatConnection.h>

static unsigned short ServerTableSection = 0;
static unsigned short PushTableSection = 1;
static unsigned short IdentityTableSection = 2;
static unsigned short AutomaticTableSection = 3;
static unsigned short AdvancedTableSection = 4;
static unsigned short DeleteTableSection = 5;

static BOOL pushAvailable = NO;

static inline __attribute__((always_inline)) BOOL isDefaultValue(NSString *string) {
	return [string isEqualToString:@"<<default>>"];
}

static inline __attribute__((always_inline)) BOOL isPlaceholderValue(NSString *string) {
	return [string isEqualToString:@"<<placeholder>>"];
}

#pragma mark -

@implementation CQConnectionEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

#if !TARGET_IPHONE_SIMULATOR
	pushAvailable = [[UIApplication sharedApplication] respondsToSelector:@selector(enabledRemoteNotificationTypes)];
#endif

	if (!pushAvailable) {
		IdentityTableSection = 1;
		AutomaticTableSection = 2;
		AdvancedTableSection = 3;
		DeleteTableSection = 4;
	}

	return self;
}

- (void) dealloc {
	[_connection release];
	[_servers release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	if (pushAvailable)
		[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:PushTableSection] withAnimation:UITableViewRowAnimationNone];
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:AutomaticTableSection] withAnimation:UITableViewRowAnimationNone];

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

- (void) showDefaultServerList {
	if (!_servers)
		_servers = [[NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Servers" ofType:@"plist"]] retain];

	CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];
	NSMutableArray *servers = [[NSMutableArray alloc] init];
	NSUInteger selectedServerIndex = NSNotFound;

	NSUInteger index = 0;
	for (NSDictionary *serverInfo in _servers) {
		NSString *name = [serverInfo objectForKey:@"Name"];
		NSString *address = [serverInfo objectForKey:@"Address"];
		NSAssert(name.length, @"Server name required.");
		NSAssert(address.length, @"Server address required.");

		[servers addObject:name];

		if ([address isEqualToString:_connection.server])
			selectedServerIndex = index;

		++index;
	}

	listViewController.title = NSLocalizedString(@"Servers", @"Servers view title");
	listViewController.itemImage = [UIImage imageNamed:@"server.png"];
	listViewController.allowEditing = NO;
	listViewController.items = servers;
	listViewController.selectedItemIndex = selectedServerIndex;

	listViewController.target = self;
	listViewController.action = @selector(defaultServerPicked:);

	[self.view endEditing:YES];

	[self.navigationController pushViewController:listViewController animated:YES];

	[listViewController release];
	[servers release];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	if (self.newConnection || !_connection.directConnection)
		return (pushAvailable ? 5 : 4);
	return (pushAvailable ? 6 : 5);
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == ServerTableSection)
		return 2;
	if (pushAvailable && section == PushTableSection)
		return 1;
	if (section == IdentityTableSection)
		return 2;
	if (section == AutomaticTableSection)
		return 2;
	if (section == AdvancedTableSection)
		return 1;
	if (section == DeleteTableSection)
		return 1;
	return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0)
		return indexPath;
	if (indexPath.section == AutomaticTableSection && indexPath.row == 1)
		return indexPath;
	if (indexPath.section == AdvancedTableSection && indexPath.row == 0)
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0) {
		CQConnectionPushEditController *pushEditViewController = [[CQConnectionPushEditController alloc] init];

		pushEditViewController.navigationItem.prompt = self.navigationItem.prompt;
		pushEditViewController.connection = _connection;

		[self.view endEditing:YES];

		[self.navigationController pushViewController:pushEditViewController animated:YES];

		[pushEditViewController release];

		return;
	}

	if (indexPath.section == AutomaticTableSection && indexPath.row == 1) {
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

	if (indexPath.section == AdvancedTableSection && indexPath.row == 0) {
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
	if (section == ServerTableSection)
		return NSLocalizedString(@"Internet Relay Chat Server", @"Internet Relay Chat Server section title");
	if (section == IdentityTableSection)
		return NSLocalizedString(@"Network Identity", @"Network Identity section title");
	if (section == AutomaticTableSection)
		return NSLocalizedString(@"Automatic Actions", @"Automatic Actions section title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == ServerTableSection) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.row == 1) {
			cell.label = NSLocalizedString(@"Address", @"Address connection setting label");
			cell.text = (isPlaceholderValue(_connection.server) ? @"" : _connection.server);
			cell.textField.placeholder = (_newConnection ? @"irc.example.com" : @"");
			if (_connection.directConnection) {
				cell.textField.keyboardType = UIKeyboardTypeURL;
				cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
				cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
				cell.textEditAction = @selector(serverChanged:);
				cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
				cell.accessoryAction = @selector(showDefaultServerList);
			} else {
				cell.enabled = NO;
			}
		} else if (indexPath.row == 0) {
			cell.label = NSLocalizedString(@"Description", @"Description connection setting label");
			cell.text = (![_connection.displayName isEqualToString:_connection.server] ? _connection.displayName : @"");
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(descriptionChanged:);
		}

		cell.accessibilityLabel = [NSString stringWithFormat: @"%@: %@", cell.label, cell.text];
		
		return cell;
	} else if (pushAvailable && indexPath.section == PushTableSection && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = NSLocalizedString(@"Push Notifications", @"Push Notifications connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		if (_connection.pushNotifications)
			cell.text = NSLocalizedString(@"On", @"On label");
		else cell.text = NSLocalizedString(@"Off", @"Off label");

		cell.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", cell.label, cell.text];

		return cell;
	} else if (indexPath.section == IdentityTableSection) {
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
			if (_connection.directConnection) {
				cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
				cell.textEditAction = @selector(realNameChanged:);
			} else {
				cell.enabled = NO;
			}
		}

		cell.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", cell.label, cell.text];

		return cell;
	} else if (indexPath.section == AutomaticTableSection) {
		if (indexPath.row == 0) {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

			cell.target = self;
			cell.switchAction = @selector(autoConnectChanged:);
			cell.label = NSLocalizedString(@"Connect at Launch", @"Connect at Launch connection setting label");
			cell.on = _connection.automaticallyConnect;

			cell.accessibilityLabel = _connection.automaticallyConnect ? cell.label : [NSString stringWithFormat:NSLocalizedString(@"Don't %@.", @"Voiceover don't %@ label"), cell.label];

			return cell;
		} else if (indexPath.row == 1) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.label = NSLocalizedString(@"Join Rooms", @"Join Rooms connection setting label");
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

			if (_connection.automaticJoinedRooms.count) {
				cell.text = [_connection.automaticJoinedRooms componentsJoinedByString:@", "];
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Join %@ automatically.", @"Voiceover join %@ automatically"), cell.text];
			} else {
				cell.text = NSLocalizedString(@"None", @"None label");
				cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Join rooms automatically.", @"Voiceover join rooms automatically label")];
			}

			cell.accessibilityLabel = cell.text;

			return cell;
		}
	} else if (indexPath.section == AdvancedTableSection && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = NSLocalizedString(@"Advanced", @"Advanced connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		return cell;
	} else if (indexPath.section == DeleteTableSection && indexPath.row == 0) {
		CQPreferencesDeleteCell *cell = [CQPreferencesDeleteCell reusableTableViewCellInTableView:tableView];

		cell.target = self;
		cell.text = NSLocalizedString(@"Delete Connection", @"Delete Connection button title");
		cell.deleteAction = @selector(deleteConnection);

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == ServerTableSection && indexPath.row == 1)
		[self showDefaultServerList];
}

#pragma mark -

- (void) defaultServerPicked:(CQPreferencesListViewController *) sender {
	if (sender.selectedItemIndex == NSNotFound)
		return;

	NSDictionary *serverInfo = [_servers objectAtIndex:sender.selectedItemIndex];
	_connection.displayName = [serverInfo objectForKey:@"Name"];
	_connection.server = [serverInfo objectForKey:@"Address"];

	if (!_newConnection)
		self.title = _connection.displayName;

	if (self.navigationItem.rightBarButtonItem.tag == UIBarButtonSystemItemSave)
		self.navigationItem.rightBarButtonItem.enabled = YES;

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:ServerTableSection] withAnimation:UITableViewRowAnimationNone];
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:ServerTableSection] withAnimation:UITableViewRowAnimationNone];
}

- (void) serverChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length || _newConnection) {
		_connection.server = (sender.text.length ? sender.text : @"<<placeholder>>");
		if (!_newConnection)
			self.title = _connection.displayName;
	}

	sender.text = (isPlaceholderValue(_connection.server) ? @"" : _connection.server);

	if (self.navigationItem.rightBarButtonItem.tag == UIBarButtonSystemItemSave)
		self.navigationItem.rightBarButtonItem.enabled = !isPlaceholderValue(_connection.server);
}

- (void) nicknameChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length)
		_connection.preferredNickname = sender.text;
	else _connection.preferredNickname = (_newConnection ? @"<<default>>" : sender.textField.placeholder);

	sender.text = (isDefaultValue(_connection.preferredNickname) ? @"" : _connection.preferredNickname);
}

- (void) realNameChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length)
		_connection.realName = sender.text;
	else _connection.realName = (_newConnection ? @"<<default>>" : sender.textField.placeholder);

	sender.text = (isDefaultValue(_connection.realName) ? @"" : _connection.realName);
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
