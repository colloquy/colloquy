#import "CQConnectionEditViewController.h"

#import "CQConnectionAdvancedEditController.h"
#import "CQPreferencesTextCell.h"
#import "CQPreferencesDeleteCell.h"
#import "CQPreferencesSwitchCell.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionEditViewController
- (id) init {
	if (!(self = [super initWithNibName:@"ConnectionEdit" bundle:nil]))
		return nil;
	return self;
}

- (void) dealloc {
	[editTableView release];
	[_connection release];
	[_currentEditingTextField resignFirstResponder];
	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	editTableView.sectionHeaderHeight = 10.;
	editTableView.sectionFooterHeight = 10.;
}

- (void) viewWillAppear:(BOOL) animated {
	[editTableView deselectRowAtIndexPath:[editTableView indexPathForSelectedRow] animated:NO];
}

- (void) viewDidAppear:(BOOL)animated {
	[editTableView flashScrollIndicators];
}

- (void) viewWillDisappear:(BOOL)animated {
	[_currentEditingTextField resignFirstResponder];
}

#pragma mark -

@synthesize newConnection = _newConnection;

- (void) setNewConnection:(BOOL)newConnection {
	if (_newConnection ==  newConnection)
		return;

	_newConnection = newConnection;
	advancedEditViewController.newConnection = newConnection;

	if (_newConnection) self.title = NSLocalizedString(@"New Connection", @"New Connection view title");
	else self.title = _connection.server;
}

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	if (!_newConnection)
		self.title = connection.server;

	[editTableView reloadData];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	if (self.newConnection)
		return 3;
	return 4;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch(section) {
		case 0: return 3;
		case 1: return 2;
		case 2: return 1;
		case 3: return 1;
		default: return 0;
	}
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 2 && indexPath.row == 0) {
		if (!advancedEditViewController) {
			advancedEditViewController = [[CQConnectionAdvancedEditController alloc] init];
			advancedEditViewController.navigationItem.prompt = self.navigationItem.prompt;
			advancedEditViewController.newConnection = self.newConnection;
		}

		[self.navigationController pushViewController:advancedEditViewController animated:YES];

		return indexPath;
	}

	if (indexPath.section == 1 && indexPath.row == 1)
		return indexPath;

	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == 0)
		return NSLocalizedString(@"IRC Connection Information", @"IRC Connection Information section title");
	if (section == 1)
		return NSLocalizedString(@"Automatic Actions", @"Automatic Actions section title");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.textField.delegate = self;

		if (indexPath.row == 0) {
			cell.label = @"Server";
			cell.text = _connection.server;
			cell.textField.placeholder = @"irc.example.com";
			cell.textField.keyboardType = UIKeyboardTypeURL;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		} else if (indexPath.row == 1) {
			cell.label = @"Nickname";
			cell.text = _connection.nickname;
			cell.textField.placeholder = NSUserName();
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		} else if (indexPath.row == 2) {
			cell.label = @"Real Name";
			cell.text = _connection.realName;
			cell.textField.placeholder = NSFullUserName();
		}

		return cell;
	} else if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

			cell.label = @"Connect on Launch";

			return cell;
		} else if (indexPath.row == 1) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.label = @"Join Rooms";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

			return cell;
		}
	} else if (indexPath.section == 2 && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = @"Advanced";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		return cell;
	} else if (indexPath.section == 3 && indexPath.row == 0) {
		CQPreferencesDeleteCell *cell = [CQPreferencesDeleteCell reusableTableViewCellInTableView:tableView];

		cell.text = @"Delete Connection";

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

- (void) textFieldDidBeginEditing:(UITextField *) textField {
	id old = _currentEditingTextField;
	_currentEditingTextField = [textField retain];
	[old release];
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	[textField resignFirstResponder];
	return YES;
}

- (void) textFieldDidEndEditing:(UITextField *) textField {
	[_currentEditingTextField release];
	_currentEditingTextField = nil;
}
@end
