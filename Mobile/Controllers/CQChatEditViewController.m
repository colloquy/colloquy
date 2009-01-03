#import "CQChatEditViewController.h"

#import "CQConnectionsController.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

static NSUInteger lastSelectedConnectionIndex = NSNotFound;

@implementation CQChatEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;
	_selectedConnectionIndex = NSNotFound;
	return self;
}

- (void) dealloc {
	[_name release];
	[_password release];

	[super dealloc];
}

#pragma mark -

@synthesize roomTarget = _roomTarget;

- (BOOL) isRoomTarget {
	return _roomTarget;
}

@synthesize selectedConnectionIndex = _selectedConnectionIndex;

@synthesize name = _name;

@synthesize password = _password;

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_roomTarget) self.title = NSLocalizedString(@"Join Chat Room", @"Join Chat Room view title");
	else self.title = NSLocalizedString(@"Message User", @"Message User view title");
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	if (_selectedConnectionIndex == NSNotFound) {
		NSArray *connections = [CQConnectionsController defaultController].connections;
		if (lastSelectedConnectionIndex == NSNotFound) {
			NSUInteger i = 0;
			for (MVChatConnection *connection in [CQConnectionsController defaultController].connections) {
				if (_selectedConnectionIndex == NSNotFound && connection.connected) {
					_selectedConnectionIndex = i;
					break;
				}

				++i;
			}

			if (_selectedConnectionIndex == NSNotFound)
				_selectedConnectionIndex = 0;
		} else {
			_selectedConnectionIndex = lastSelectedConnectionIndex;
		}

		if (!connections.count)
			_selectedConnectionIndex = NSNotFound;
		if (_selectedConnectionIndex >= connections.count && connections.count)
			_selectedConnectionIndex = (connections.count - 1);
	}
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

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 2;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch (section) {
		case 0: return 1;
		case 1: return (_roomTarget ? 2 : 1);
		case 2: return 1;
	}

	return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ((indexPath.section == 0 && indexPath.row == 0) || (indexPath.section == 2 && indexPath.row == 0))
		return indexPath;
	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0 && indexPath.row == 0) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		NSMutableArray *connections = [[NSMutableArray alloc] init];
		for (MVChatConnection *connection in [CQConnectionsController defaultController].connections)
			[connections addObject:connection.displayName];

		listViewController.title = NSLocalizedString(@"Connections", @"Connections view title");
		listViewController.itemImage = [UIImage imageNamed:@"server.png"];
		listViewController.allowEditing = NO;
		listViewController.items = connections;
		listViewController.selectedItemIndex = _selectedConnectionIndex;

		listViewController.target = self;
		listViewController.action = @selector(connectionChanged:);

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];
		[connections release];

		return;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == 0)
		return NSLocalizedString(@"Chat Server", @"Chat Server section title");
	if (section == 1 && _roomTarget)
		return NSLocalizedString(@"Chat Room Information", @"Chat Room section title");
	if (section == 1)
		return NSLocalizedString(@"User Identity", @"User Identity section title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section <= 1) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.section == 0 && indexPath.row == 0) {
			MVChatConnection *connection = nil;
			if (_selectedConnectionIndex != NSNotFound)
				connection = [[CQConnectionsController defaultController].connections objectAtIndex:_selectedConnectionIndex];

			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.label = NSLocalizedString(@"Connection", @"Connection setting label");
			cell.textField.secureTextEntry = NO;
			if (connection) cell.text = connection.displayName;
			else cell.text = NSLocalizedString(@"None", @"None setting label");
		} else if (indexPath.section == 1 && indexPath.row == 0) {
			cell.text = _name;
			cell.textEditAction = @selector(nameChanged:);
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.keyboardType = UIKeyboardTypeDefault;
			cell.textField.secureTextEntry = NO;

			if (_roomTarget) {
				cell.label = NSLocalizedString(@"Name", @"Name setting label");
				cell.textField.placeholder = @"#help";
			} else {
				cell.label = NSLocalizedString(@"Nickname", @"Nickname setting label");
				cell.textField.placeholder = NSLocalizedString(@"Required", @"Required setting placeholder");
			}
		} else if (_roomTarget && indexPath.section == 1 && indexPath.row == 1) {
			cell.text = _password;
			cell.label = NSLocalizedString(@"Password", @"Password setting label");
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.secureTextEntry = YES;
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional setting placeholder");
			cell.textEditAction = @selector(passwordChanged:);
		}

		return cell;
	}

	UITableViewCell *helpCell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	helpCell.text = NSLocalizedString(@"Join Colloquy Support Room", @"Join Colloquy Support Room label");
	helpCell.textAlignment = UITextAlignmentCenter;

	return helpCell;
}

#pragma mark -

- (void) nameChanged:(CQPreferencesTextCell *) sender {
	id old = _name;
	_name = [sender.text copy];
	[old release];

	if (!_roomTarget && self.navigationItem.rightBarButtonItem.tag == UIBarButtonSystemItemSave)
		self.navigationItem.rightBarButtonItem.enabled = (_name.length ? YES : NO);	
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	id old = _password;
	_password = [sender.text copy];
	[old release];
}

- (void) connectionChanged:(CQPreferencesListViewController *) sender {
	_selectedConnectionIndex = sender.selectedItemIndex;
	lastSelectedConnectionIndex = _selectedConnectionIndex;

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withAnimation:UITableViewRowAnimationFade];
}
@end
