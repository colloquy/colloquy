NS_ASSUME_NONNULL_BEGIN

typedef void (^UITextFieldBlock)(UITextField *textField);

@interface CQPreferencesTextCell : UITableViewCell
+ (CQPreferencesTextCell *) currentEditingCell;

@property (nonatomic, readonly) UITextField *textField;

@property (nonatomic, getter = isEnabled) BOOL enabled;

@property (nonatomic, nullable) SEL textEditAction;
@property (nonatomic, copy, nullable) UITextFieldBlock textFieldBlock;
@end

NS_ASSUME_NONNULL_END
