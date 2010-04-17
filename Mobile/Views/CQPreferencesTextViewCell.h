@class CQTextView;

@interface CQPreferencesTextViewCell : UITableViewCell {
@protected
	CQTextView *_textView;
}
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, retain) CQTextView *textView;
@end
