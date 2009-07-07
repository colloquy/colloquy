@interface CQPreferencesTextCell : UITableViewCell <UITextFieldDelegate> {
	@protected
	UILabel *_label;
	UITextField *_textField;
	BOOL _enabled;
	SEL _textEditAction;
}
@property (nonatomic, copy) NSString *label;

@property (nonatomic, readonly) UITextField *textField;

@property (nonatomic, getter = isEnabled) BOOL enabled;

@property (nonatomic) SEL textEditAction;
@end
