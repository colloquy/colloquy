#import "UITableViewCellAdditions.h"

@implementation UITableViewCell (UITableViewCellColloquyAdditions)
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView {
	Class class = [self class];
	NSString *className = NSStringFromClass([self class]);

	id cell = [tableView dequeueReusableCellWithIdentifier:className];
	if (cell) return cell;

	return [[[class alloc] initWithFrame:CGRectZero reuseIdentifier:className] autorelease];
}
@end
