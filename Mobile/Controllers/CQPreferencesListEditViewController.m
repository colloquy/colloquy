#import "CQPreferencesListEditViewController.h"

#import "CQPreferencesTextCell.h"

@implementation CQPreferencesListEditViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;
	return self;
}

- (void) dealloc {
	[_listItemText release];
	[_listItemPlaceholder release];
	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];

	_viewDisappearing = NO;

	[((CQPreferencesTextCell *)[[self.tableView visibleCells] objectAtIndex:0]).textField becomeFirstResponder];
}

- (void) viewWillDisappear:(BOOL) animated {
	_viewDisappearing = YES;

	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];

	// Workaround a bug were the table view is left in a state
	// were it thinks a keyboard is showing.
	self.tableView.contentInset = UIEdgeInsetsZero;
	self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark -

@synthesize listItemText = _listItemText;

- (void) setListItemText:(NSString *) listItemText {
	id old = _listItemText;
	_listItemText = [listItemText copy];
	[old release];

	[self.tableView reloadData];
}

@synthesize listItemPlaceholder = _listItemPlaceholder;

- (void) setListItemPlaceholder:(NSString *) listItemPlaceholder {
	id old = _listItemPlaceholder;
	_listItemPlaceholder = [listItemPlaceholder copy];
	[old release];

	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return 1;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

	cell.text = _listItemText;
	cell.textField.placeholder = _listItemPlaceholder;
	cell.textField.clearButtonMode = UITextFieldViewModeAlways;
	cell.textField.returnKeyType = UIReturnKeyDefault;
	cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;

	cell.target = self;
	cell.textEditAction = @selector(listItemChanged:);

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	return nil;
}

#pragma mark -

- (void) listItemChanged:(CQPreferencesTextCell *) sender {
	self.listItemText = sender.text;

	if (_viewDisappearing)
		return;

	[sender.textField becomeFirstResponder];
}
@end
