#import "CQPreferencesTableViewController.h"

@interface CQPreferencesListEditViewController : CQPreferencesTableViewController {
	@protected
	NSString *_listItemText;
	NSString *_listItemPlaceholder;
	BOOL _viewDisappearing;
}
@property (nonatomic, copy) NSString *listItemText;
@property (nonatomic, copy) NSString *listItemPlaceholder;
@end
