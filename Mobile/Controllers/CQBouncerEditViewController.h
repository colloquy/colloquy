#import "CQPreferencesTableViewController.h"

@class CQBouncerSettings;

@interface CQBouncerEditViewController : CQPreferencesTableViewController <UIActionSheetDelegate> {
	@protected
	CQBouncerSettings *_settings;
	BOOL _newBouncer;
}
@property (nonatomic, retain) CQBouncerSettings *settings;
@property (nonatomic, getter=isNewBouncer) BOOL newBouncer;
@end
