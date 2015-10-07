@class CQTextView;

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesTextViewCell : UITableViewCell
@property (nonatomic, strong) CQTextView *textView;
+ (CGFloat) height;
@end

NS_ASSUME_NONNULL_END
