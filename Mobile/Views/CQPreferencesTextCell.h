@interface CQPreferencesTextCell : UITableViewCell <UITextFieldDelegate> {
	@protected
	UILabel *_label;
	UITextField *_textField;
	BOOL _editable;
	SEL _textEditAction;
}
@property (nonatomic, copy) NSString *label;

@property (nonatomic, readonly) UITextField *textField;

@property (nonatomic, assign) BOOL editable;

@property (nonatomic) SEL textEditAction;
@end
