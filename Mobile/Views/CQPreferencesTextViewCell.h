@class CQTextView;

@interface CQPreferencesTextViewCell : UITableViewCell {
@protected
	CQTextView *_textView;
}
@property (nonatomic, strong) CQTextView *textView;
+ (CGFloat) height;
@end
