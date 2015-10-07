#import "CQPreferencesTableViewController.h"

#import "CQPreferencesTextCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  CQPreferencesTableViewController
- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self endEditing];
}

- (void) endEditing {
	[[CQPreferencesTextCell currentEditingCell] endEditing:YES];

	[self.view endEditing:YES];
}
@end

NS_ASSUME_NONNULL_END
