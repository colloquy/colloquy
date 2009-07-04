@class CQBouncerSettings;

@interface CQBouncerEditViewController : UITableViewController <UIActionSheetDelegate> {
	@protected
	CQBouncerSettings *_settings;
	BOOL _newBouncer;
}
@property (nonatomic, retain) CQBouncerSettings *settings;
@property (nonatomic, getter=isNewBouncer) BOOL newBouncer;
@end
