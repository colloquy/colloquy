#import "CQPreferencesTableViewController.h"

@class CQBouncerSettings;

NS_ASSUME_NONNULL_BEGIN

@interface CQBouncerEditViewController : CQPreferencesTableViewController <UIActionSheetDelegate, UIAlertViewDelegate> {
	@protected
	CQBouncerSettings *_settings;
	BOOL _newBouncer;
}
@property (nonatomic, strong) CQBouncerSettings *settings;
@property (nonatomic, getter=isNewBouncer) BOOL newBouncer;
@end

NS_ASSUME_NONNULL_END
