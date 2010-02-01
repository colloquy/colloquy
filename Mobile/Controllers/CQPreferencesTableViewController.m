#import "CQPreferencesTableViewController.h"

#import "CQPreferencesTextCell.h"

@implementation CQPreferencesTableViewController
- (void) dealloc {
	self.tableView.dataSource = nil;
	self.tableView.delegate = nil;

	[super dealloc];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self endEditing];
}

- (void) endEditing {
	[[CQPreferencesTextCell currentEditingCell] endEditing:YES];

	[self.view endEditing:YES];
}
@end
