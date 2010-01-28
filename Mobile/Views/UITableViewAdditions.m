#import "UITableViewAdditions.h"

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

- (void) performAction:(SEL) action forCell:(UITableViewCell *) cell sender:(id) sender {
	id delegate = self.delegate;
	if (![delegate respondsToSelector:@selector(tableView:performAction:forRowAtIndexPath:withSender:)])
		return;

	NSIndexPath *indexPath = [self indexPathForCell:cell];
	if (!indexPath)
		return;

	[delegate tableView:self performAction:action forRowAtIndexPath:indexPath withSender:sender];
}
@end
