NS_ASSUME_NONNULL_BEGIN

typedef void (^CQColorSelected)(UIColor *);

@interface CQColorPickerTableCell : UITableViewCell
@property (atomic, copy) CQColorSelected colorSelectedBlock;
@property (nonatomic, copy) UIColor *activeColor;
@property (nonatomic, copy) NSArray <UIColor *> *colors;
@end

@interface CQMultiButtonTableCell : UITableViewCell
- (void) addButtonWithConfigurationHandler:(void (^)(UIButton *button)) configurationHandler;

@property (nonatomic, assign) BOOL expands;
@end

NS_ASSUME_NONNULL_END
