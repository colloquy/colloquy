#import "UITableViewAdditions.h"

@implementation UITableView (UITableViewColloquyAdditions)
- (void) updateCellAtIndexPath:(NSIndexPath *) indexPath withAnimation:(UITableViewRowAnimation) animation {
	NSParameterAssert(indexPath != nil);

	NSArray *indexPaths = [NSArray arrayWithObject:indexPath];

	NSIndexPath *selectedIndexPath = [self indexPathForSelectedRow];
	BOOL selected = (selectedIndexPath && indexPath.section == selectedIndexPath.section && indexPath.row == selectedIndexPath.row);

	if (selected)
		[self deselectRowAtIndexPath:indexPath animated:NO];

	[self beginUpdates];

	[self deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
	[self insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];

	[self endUpdates];

	if (selected)
		[self selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}
@end
