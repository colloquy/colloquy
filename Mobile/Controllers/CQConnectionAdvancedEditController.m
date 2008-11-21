#import "CQConnectionAdvancedEditController.h"

#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionAdvancedEditController
- (id) init {
	if (!(self = [super initWithNibName:@"ConnectionAdvancedEdit" bundle:nil]))
		return nil;

	self.title = NSLocalizedString(@"Advanced", @"Advanced view title");

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

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	[editTableView reloadData];
}

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
		case 2: return NSLocalizedString(@"Alternate Identities", @"Alternate Identities section title");
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
	if (indexPath.section == 2 && indexPath.row == 0)
		return indexPath;
	if (indexPath.section == 3 && indexPath.row == 0)
		return indexPath;
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.label = @"Server Port";
			cell.text = @"";
			cell.textField.placeholder = @"6667";
			cell.textField.keyboardType = UIKeyboardTypeNumberPad;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.delegate = self;

			return cell;
		} else if (indexPath.row == 1) {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

			cell.label = @"Use SSL";

			return cell;
		}
	} else if (indexPath.section == 1) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		if(indexPath.row == 0) {
			cell.label = @"Username";
			cell.text = @"";

			UIDevice *device = [UIDevice currentDevice];
			if ([[device model] hasPrefix:@"iPhone"])
				cell.textField.placeholder = @"iphone";
			else if ([[device model] hasPrefix:@"iPod"])
				cell.textField.placeholder = @"ipod";
			else
				cell.textField.placeholder = @"user";

			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.delegate = self;
		} else if (indexPath.row == 1) {
			cell.label = @"Password";
			cell.text = @"";
			cell.textField.placeholder = @"Optional";
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.secureTextEntry = YES;
			cell.textField.delegate = self;
		} else if (indexPath.row == 2) {
			cell.label = @"Nick Pass.";
			cell.text = @"";
			cell.textField.placeholder = @"Optional";
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			cell.textField.secureTextEntry = YES;
			cell.textField.delegate = self;
		}

		return cell;
	} else if (indexPath.section == 2 && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = @"Nicknames";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textField.placeholder = [NSString stringWithFormat:@"%@_, %1$@__, %1$@___", NSUserName()];
		cell.textField.delegate = self;

		return cell;
	} else if (indexPath.section == 3 && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = @"Commands";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

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
