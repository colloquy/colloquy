NS_ASSUME_NONNULL_BEGIN

@interface UITableViewCell (UITableViewCellColloquyAdditions)
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView;
+ (id) reusableTableViewCellWithStyle:(UITableViewCellStyle) style inTableView:(UITableView *) tableView;
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier;
+ (id) reusableTableViewCellWithStyle:(UITableViewCellStyle) style inTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier;

- (void) performAction:(SEL) action sender:(__nullable id) sender;
@end

NS_ASSUME_NONNULL_END
