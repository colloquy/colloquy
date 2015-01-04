#import "CQChatEditViewController.h"

#import "CQBouncerSettings.h"
#import "CQChatController.h"
#import "CQChatRoomListViewController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

static NSUInteger lastSelectedConnectionIndex = NSNotFound;

@implementation CQChatEditViewController
- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;
	return self;
}

#pragma mark -

- (void) setSelectedConnection:(MVChatConnection *) connection {
	_selectedConnection = connection;

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withAnimation:UITableViewRowAnimationNone];
}

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
		MVChatConnection *visibleConnection = [[[CQChatController defaultController] visibleChatController] connection];

		if (visibleConnection != nil) {
			_selectedConnection = visibleConnection;
		} else if (lastSelectedConnectionIndex != NSNotFound) {
			if (lastSelectedConnectionIndex >= _sortedConnections.count && _sortedConnections.count)
				_selectedConnection = [_sortedConnections lastObject];
			else _selectedConnection = _sortedConnections[lastSelectedConnectionIndex];
		} else {
			for (MVChatConnection *connection in _sortedConnections) {
				if (connection.connected) {
					_selectedConnection = connection;
					break;
				}
			}

			if (!_selectedConnection && _sortedConnections.count)
				_selectedConnection = _sortedConnections[0];
		}

		[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withAnimation:UITableViewRowAnimationNone];
	}
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
		for (MVChatConnection *connection in _sortedConnections) {
			if (connection.directConnection)
				[connectionTitles addObject:connection.displayName];
			else [connectionTitles addObject:[NSString stringWithFormat:@"%@ (%@)", connection.displayName, connection.bouncerSettings.displayName]];
		}

		listViewController.title = NSLocalizedString(@"Connections", @"Connections view title");
		listViewController.itemImage = [UIImage imageNamed:@"server.png"];
		listViewController.allowEditing = NO;
		listViewController.items = connectionTitles;
		listViewController.selectedItemIndex = selectedConnectionIndex;

		listViewController.target = self;
		listViewController.action = @selector(connectionChanged:);

		[self endEditing];

		[self.navigationController pushViewController:listViewController animated:YES];

		return;
	}

	if (indexPath.section == 2 && indexPath.row == 0) {
		[[CQChatController defaultController] joinSupportRoom];

		[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];

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
		if (indexPath.section == 0 && indexPath.row == 0) {
			UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];

			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.textLabel.text = NSLocalizedString(@"Connection", @"Connection setting label");
			cell.detailTextLabel.text = (_selectedConnection ? _selectedConnection.displayName : NSLocalizedString(@"None", @"None label"));

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Connection: %@", @"Voiceover connection label"), cell.detailTextLabel.text];

			return cell;
		}

		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		if (indexPath.section == 1 && indexPath.row == 0) {
			cell.textField.text = _name;
			cell.textEditAction = @selector(nameChanged:);
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.keyboardType = UIKeyboardTypeDefault;
			cell.textField.secureTextEntry = NO;

			if (_roomTarget) {
				cell.textLabel.text = NSLocalizedString(@"Name", @"Name setting label");
				if ([_selectedConnection.server hasCaseInsensitiveSubstring:@"undernet"])
					cell.textField.placeholder = @"#undernet";
				else cell.textField.placeholder = @"#help";
				cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;

				cell.accessibilityLabel = NSLocalizedString(@"Room to join.", @"Voiceover room to join label.");
				cell.accessibilityHint = NSLocalizedString(@"The #help room is joined by default.", @"Voiceover help is default room label");
			} else {
				cell.textLabel.text = NSLocalizedString(@"Nickname", @"Nickname setting label");
				cell.textField.placeholder = NSLocalizedString(@"Required", @"Required setting placeholder");

				cell.accessibilityLabel = NSLocalizedString(@"User to message.", @"Voiceover user to message label");
				cell.accessibilityHint = NSLocalizedString(@"Required", @"Voiceover required label");
			}
		} else if (_roomTarget && indexPath.section == 1 && indexPath.row == 1) {
			cell.textField.text = _password;
			cell.textLabel.text = NSLocalizedString(@"Password", @"Password setting label");
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

	UITableViewCell *helpCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	helpCell.textLabel.font = [UIFont boldSystemFontOfSize:15.];
	helpCell.textLabel.textColor = [UIColor colorWithRed:(85. / 255.) green:(102. / 255.) blue:(145. / 255.) alpha:1.];
	helpCell.textLabel.highlightedTextColor = [UIColor whiteColor];
	helpCell.textLabel.backgroundColor = [UIColor clearColor];

	[helpCell.contentView addSubview:helpCell.textLabel];

	helpCell.textLabel.text = NSLocalizedString(@"Join Colloquy Support Room", @"Join Colloquy Support Room label");
	helpCell.textLabel.textAlignment = NSTextAlignmentCenter;

	return helpCell;
}

#pragma mark -

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString {
	CQChatRoomListViewController *listViewController = [[CQChatRoomListViewController alloc] init];

	[self endEditing];

	listViewController.connection = _selectedConnection;
	listViewController.selectedRoom = (_name.length ? _name : @"#help");
	listViewController.target = self;
	listViewController.action = @selector(roomChanged:);

	if (searchString.length)
		[listViewController filterRoomsWithSearchString:searchString];

	listViewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;

	[self.navigationController pushViewController:listViewController animated:YES];

}

#pragma mark -

- (void) nameChanged:(CQPreferencesTextCell *) sender {
	_name = [sender.textField.text copy];

	if (!_roomTarget && self.navigationItem.rightBarButtonItem.tag == UIBarButtonSystemItemSave)
		self.navigationItem.rightBarButtonItem.enabled = (_name.length ? YES : NO);
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	_password = [sender.textField.text copy];
}

- (void) connectionChanged:(CQPreferencesListViewController *) sender {
	_selectedConnection = (sender.selectedItemIndex != NSNotFound ? _sortedConnections[sender.selectedItemIndex] : nil);

	lastSelectedConnectionIndex = sender.selectedItemIndex;

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] withAnimation:UITableViewRowAnimationNone];
}

- (void) roomChanged:(CQChatRoomListViewController *) sender {
	_name = [sender.selectedRoom copy];

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] withAnimation:UITableViewRowAnimationNone];
}
@end
