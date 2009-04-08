#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
#define UITableViewRowAnimationNone UITableViewRowAnimationFade
#endif

@interface UITableView (UITableViewColloquyAdditions)
- (void) updateCellAtIndexPath:(NSIndexPath *) indexPath withAnimation:(UITableViewRowAnimation) animation;
@end
