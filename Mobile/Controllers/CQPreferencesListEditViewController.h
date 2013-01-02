#import "CQPreferencesTableViewController.h"

@interface CQPreferencesListEditViewController : CQPreferencesTableViewController {
	@protected
	id _listItem;
	NSString *_listItemPlaceholder;
	BOOL _viewDisappearing;
}
@property (nonatomic, copy) id listItem;
@property (nonatomic, copy) NSString *listItemPlaceholder;
@end
