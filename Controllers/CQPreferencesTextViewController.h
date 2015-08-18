#import "CQTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesTextViewController : CQTableViewController {
	UITextView *_textView;
}

@property (nonatomic, copy) NSString *text;
@end

NS_ASSUME_NONNULL_END
