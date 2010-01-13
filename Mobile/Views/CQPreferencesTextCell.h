@interface CQPreferencesTextCell : UITableViewCell <UITextFieldDelegate> {
	@protected
	UITextField *_textField;
	BOOL _enabled;
	SEL _textEditAction;
}
+ (CQPreferencesTextCell *) currentEditingCell;

@property (nonatomic, readonly) UITextField *textField;

@property (nonatomic, getter = isEnabled) BOOL enabled;

@property (nonatomic) SEL textEditAction;
@end
