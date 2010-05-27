#import "CQPreferencesTableViewController.h"

#import "CQPreferencesTextCell.h"

@implementation CQPreferencesTableViewController
- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self endEditing];
}

- (void) endEditing {
	[[CQPreferencesTextCell currentEditingCell] endEditing:YES];

	[self.view endEditing:YES];
}
@end
