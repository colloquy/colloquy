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

	NSIndexPath *selectedIndexPath = [self indexPathForSelectedRow];
	BOOL selected = (selectedIndexPath && indexPath.section == selectedIndexPath.section && indexPath.row == selectedIndexPath.row);
	CGPoint contentOffset = self.contentOffset;

	if (selected)
		[self deselectRowAtIndexPath:indexPath animated:NO];

	if ([self respondsToSelector:@selector(reloadRowsAtIndexPaths:withRowAnimation:)]) {
		[self reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
	} else {
		[self beginUpdates];

		[self deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
		[self insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];

		[self endUpdates];
	}

	[self setContentOffset:contentOffset animated:NO];

	if (selected)
		[self selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}
@end
