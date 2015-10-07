NS_ASSUME_NONNULL_BEGIN

@interface CQTextView : UITextView {
@protected
	UILabel *_placeholder;
}

@property (nonatomic, copy) NSString *placeholder;
@end

NS_ASSUME_NONNULL_END
