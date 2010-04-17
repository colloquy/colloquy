@interface CQTextView : UITextView <UITextViewDelegate> {
@protected
	NSString *_placeholder;

	UIColor *_textColor;
	UIColor *_placeholderTextColor;
}
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, retain) UIColor *placeholderTextColor;
@end
