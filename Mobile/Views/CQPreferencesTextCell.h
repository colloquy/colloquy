NS_ASSUME_NONNULL_BEGIN

typedef void (^UITextFieldBlock)(UITextField *textField);

@interface CQPreferencesTextCell : UITableViewCell <UITextFieldDelegate> {
	@protected
	UITextField *_textField;
	BOOL _enabled;
	SEL _textEditAction;
	UITextFieldBlock _textFieldBlock;
}
+ (CQPreferencesTextCell *) currentEditingCell;

@property (nonatomic, readonly) UITextField *textField;

@property (nonatomic, getter = isEnabled) BOOL enabled;

@property (nonatomic) SEL textEditAction;
@property (nonatomic, copy) UITextFieldBlock textFieldBlock;
@end

NS_ASSUME_NONNULL_END
