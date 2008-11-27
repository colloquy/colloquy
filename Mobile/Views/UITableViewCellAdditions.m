#import "UITableViewCellAdditions.h"

@implementation UITableViewCell (UITableViewCellColloquyAdditions)
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView {
	return [self reusableTableViewCellInTableView:tableView withIdentifier:NSStringFromClass([self class])];
}

+ (id) reusableTableViewCellInTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier {
	id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (cell) return cell;

	return [[[[self class] alloc] initWithFrame:CGRectZero reuseIdentifier:identifier] autorelease];
}
@end
