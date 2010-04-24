@class CQTextView;

@interface CQPreferencesTextViewCell : UITableViewCell {
@protected
	CQTextView *_textView;
}
@property (nonatomic, retain) CQTextView *textView;
+ (CGFloat) height;
@end
