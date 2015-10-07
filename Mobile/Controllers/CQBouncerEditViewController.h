#import "CQPreferencesTableViewController.h"

@class CQBouncerSettings;

NS_ASSUME_NONNULL_BEGIN

@interface CQBouncerEditViewController : CQPreferencesTableViewController
@property (nonatomic, strong) CQBouncerSettings *settings;
@property (nonatomic, getter=isNewBouncer) BOOL newBouncer;
@end

NS_ASSUME_NONNULL_END
