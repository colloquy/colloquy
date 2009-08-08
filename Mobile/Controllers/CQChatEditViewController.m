#import "CQChatEditViewController.h"

#import "CQChatController.h"
#import "CQChatRoomListViewController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

static NSUInteger lastSelectedConnectionIndex = NSNotFound;

@implementation CQChatEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;
	return self;
}

- (void) dealloc {
	[_name release];
	[_password release];
	[_sortedConnections release];
	[_selectedConnection release];

	[super dealloc];
}

#pragma mark -

@synthesize roomTarget = _roomTarget;

@synthesize selectedConnection = _selectedConnection;

- (void) setSelectedConnection:(MVChatConnection *) connection {
	id old = _selectedConnection;
	_selectedConnection = [connection retain];
	[old release];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withAnimation:UITableViewRowAnimationNone];
}

@synthesize name = _name;

@synthesize password = _password;

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_roomTarget) self.title = NSLocalizedString(@"Join Chat Room", @"Join Chat Room view title");
	else self.title = NSLocalizedString(@"Message User", @"Message User view title");
}

static NSInteger sortConnections(MVChatConnection *a, MVChatConnection *b, void *context) {
	return [a.displayName compare:b.displayName];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	if (!_sortedConnections) {
		_sortedConnections = [[[CQConnectionsController defaultController].connections allObjects] mutableCopy];
		[_sortedConnections sortUsingFunction:sortConnections context:NULL];
	}

	if (!_selectedConnection) {
		if (lastSelectedConnectionIndex == NSNotFound) {
			for (MVChatConnection *connection in _sortedConnections) {
				if (connection.connected) {
					_selectedConnection = [connection retain];
					break;
				}
			}

			if (!_selectedConnection && _sortedConnections.count)
				_selectedConnection = [_sortedConnections objectAtIndex:0];
		} else {
			if (lastSelectedConnectionIndex >= _sortedConnections.count && _sortedConnections.count)
				_selectedConnection = [_sortedConnections lastObject];
			else _selectedConnection = [_sortedConnections objectAtIndex:lastSelectedConnectionIndex];
		}
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
	return (_roomTarget ? 3 : 2);
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

		NSUInteger selectedConnectionIndex = [_sortedConnections indexOfObjectIdenticalTo:_selectedConnection];
		NSMutableArray *connectionTitles = [[NSMutableArray alloc] init];
		for (MVChatConnection *connection in _sortedConnections)
			[connectionTitles addObject:connection.displayName];

		listViewController.title = NSLocalizedString(@"Connections", @"Connections view title");
		listViewController.itemImage = [UIImage imageNamed:@"server.png"];
		listViewController.allowEditing = NO;
		listViewController.items = connectionTitles;
		listViewController.selectedItemIndex = selectedConnectionIndex;

		listViewController.target = self;
		listViewController.action = @selector(connectionChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];
		[connectionTitles release];

		return;
	}

	if (indexPath.section == 2 && indexPath.row == 0) {
		[[CQChatController defaultController] joinSupportRoom];

		[self dismissModalViewControllerAnimated:YES];

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

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
	if (_roomTarget && indexPath.section == 1 && indexPath.row == 0) {
		[self showRoomListFilteredWithSearchString:nil];
		return;
	}
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section <= 1) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.target = self;

		if (indexPath.section == 0 && indexPath.row == 0) {
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.label = NSLocalizedString(@"Connection", @"Connection setting label");
			cell.textField.secureTextEntry = NO;
			cell.text = (_selectedConnection ? _selectedConnection.displayName : NSLocalizedString(@"None", @"None label"));

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Connection: %@", @"Voiceover connection label"), cell.text];
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
				cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

				cell.accessibilityLabel = NSLocalizedString(@"Room to join.", @"Voiceover room to join label.");
				cell.accessibilityHint = NSLocalizedString(@"The #help room is joined by default.", @"Voiceover help is default room label");
			} else {
				cell.label = NSLocalizedString(@"Nickname", @"Nickname setting label");
				cell.textField.placeholder = NSLocalizedString(@"Required", @"Required setting placeholder");

				cell.accessibilityLabel = NSLocalizedString(@"User to message.", @"Voiceover user to message label");
				cell.accessibilityHint = NSLocalizedString(@"Required", @"Voiceover required label");
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

			cell.accessibilityLabel = NSLocalizedString(@"Room password.", @"Voiceover room password label");
			cell.accessibilityHint = NSLocalizedString(@"Optional", @"Voiceover optional label");
		}

		return cell;
	}

	UITableViewCell *helpCell = [UITableViewCell reusableTableViewCellInTableView:tableView];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0., 10., 320., 20.)];

	label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	label.font = [UIFont boldSystemFontOfSize:15.];
	label.textColor = [UIColor colorWithRed:(85. / 255.) green:(102. / 255.) blue:(145. / 255.) alpha:1.];
	label.highlightedTextColor = [UIColor whiteColor];

	[helpCell.contentView addSubview:label];

	label.text = NSLocalizedString(@"Join Colloquy Support Room", @"Join Colloquy Support Room label");
	label.textAlignment = UITextAlignmentCenter;

	[label release];

	return helpCell;
}

#pragma mark -

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString {
	CQChatRoomListViewController *listViewController = [[CQChatRoomListViewController alloc] init];

	[self.view endEditing:YES];

	listViewController.connection = _selectedConnection;
	listViewController.selectedRoom = (_name.length ? _name : @"#help");
	listViewController.target = self;
	listViewController.action = @selector(roomChanged:);

	if (searchString.length)
		[listViewController filterRoomsWithSearchString:searchString];

	listViewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;

	[self.navigationController pushViewController:listViewController animated:YES];

	[listViewController release];
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
	id old = _selectedConnection;
	_selectedConnection = (sender.selectedItemIndex != NSNotFound ? [_sortedConnections objectAtIndex:sender.selectedItemIndex] : nil);
	[old release];

	lastSelectedConnectionIndex = sender.selectedItemIndex;

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withAnimation:UITableViewRowAnimationNone];
}

- (void) roomChanged:(CQChatRoomListViewController *) sender {
	id old = _name;
	_name = [sender.selectedRoom copy];
	[old release];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] withAnimation:UITableViewRowAnimationNone];
}
@end
