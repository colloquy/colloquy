@interface UITableViewCell (UITableViewCellColloquyAdditions)
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView;
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier;
@end
