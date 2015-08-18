NS_ASSUME_NONNULL_BEGIN

@interface UITableView (UITableViewColloquyAdditions)
- (void) updateCellAtIndexPath:(NSIndexPath *) indexPath withAnimation:(UITableViewRowAnimation) animation;

- (void) performAction:(SEL) action forCell:(UITableViewCell *) cell sender:(__nullable id) sender;

@property (readonly) NSUInteger numberOfRows;

- (void) hideEmptyCells;
@end

NS_ASSUME_NONNULL_END
