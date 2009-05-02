#import "UITableViewAdditions.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@interface UITableView (UITableViewNew)
- (void) reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation) animation;
@end
#endif

@implementation UITableView (UITableViewColloquyAdditions)
- (void) updateCellAtIndexPath:(NSIndexPath *) indexPath withAnimation:(UITableViewRowAnimation) animation {
	NSParameterAssert(indexPath != nil);

	NSArray *indexPaths = [NSArray arrayWithObject:indexPath];

	if ([self respondsToSelector:@selector(reloadRowsAtIndexPaths:withRowAnimation:)]) {
		[self reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
		return;
	}

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
