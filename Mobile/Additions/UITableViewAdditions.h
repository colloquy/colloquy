@interface UITableView (UITableViewColloquyAdditions)
- (void) updateCellAtIndexPath:(NSIndexPath *) indexPath withAnimation:(UITableViewRowAnimation) animation;

- (void) performAction:(SEL) action forCell:(UITableViewCell *) cell sender:(id) sender;

@property (readonly) NSUInteger numberOfRows;

- (void) hideEmptyCells;
@end
