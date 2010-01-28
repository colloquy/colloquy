@interface UITableViewCell (UITableViewCellColloquyAdditions)
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView;
+ (id) reusableTableViewCellWithStyle:(UITableViewCellStyle) style inTableView:(UITableView *) tableView;
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier;
+ (id) reusableTableViewCellWithStyle:(UITableViewCellStyle) style inTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier;

- (void) performAction:(SEL) action sender:(id) sender;
@end
