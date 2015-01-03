typedef void (^CQColorSelected)(UIColor *);

@interface CQColorPickerTableCell : UITableViewCell
@property (atomic, copy) CQColorSelected colorSelectedBlock;
@property (atomic, copy) UIColor *activeColor;
@property (nonatomic, copy) NSArray *colors;
@end

@interface CQMultiButtonTableCell : UITableViewCell
- (void) addButtonWithConfigurationHandler:(void (^)(UIButton *button)) configurationHandler;

@property (nonatomic, assign) BOOL expands;
@end
