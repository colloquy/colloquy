#import "CQPreferencesTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesListEditViewController : CQPreferencesTableViewController {
	@protected
	id _listItem;
	NSString *_listItemPlaceholder;
	BOOL _viewDisappearing;
}
@property (nonatomic, copy) id listItem;
@property (nonatomic, copy) NSString *listItemPlaceholder;
@end

NS_ASSUME_NONNULL_END
