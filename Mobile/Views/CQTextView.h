@interface CQTextView : UITextView {
@protected
	UILabel *_placeholder;
}

@property (nonatomic, copy) NSString *placeholder;
@end
