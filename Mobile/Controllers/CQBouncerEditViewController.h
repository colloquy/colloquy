#import "CQPreferencesTableViewController.h"

@class CQBouncerSettings;

@interface CQBouncerEditViewController : CQPreferencesTableViewController <UIActionSheetDelegate, UIAlertViewDelegate> {
	@protected
	CQBouncerSettings *_settings;
	BOOL _newBouncer;
}
@property (nonatomic, retain) CQBouncerSettings *settings;
@property (nonatomic, getter=isNewBouncer) BOOL newBouncer;
@end
