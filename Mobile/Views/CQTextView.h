@interface CQTextView : UITextView <UITextViewDelegate> {
@protected
	NSString *_placeholder;

	UIColor *_textColor;
	UIColor *_placeholderTextColor;
}
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, readonly) BOOL isPlaceholderText;
@property (nonatomic, retain) UIColor *placeholderTextColor;
@end
