#import "UIViewControllerAdditions.h"
#import "UITableViewAdditions.h"

#define SectionHeaderHeight 23
#define TableViewCellWidth 320

#define MinimumPopoverHeight 320
#define MaximumPortraitPopoverHeight 876 // 921 (default) - 45 (height of a UITextField)
#define MaximumLandscapePopoverHeight 620 // 665 (default) - 45 (height of a UITextField)

@implementation UIViewController (UIViewControllerAdditions)
- (void) resizeForViewInPopoverUsingTableView:(UITableView *) tableView {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if (![self respondsToSelector:@selector(setContentSizeForViewInPopover:)])
		return;

	NSUInteger numberOfRows = [tableView numberOfRows];
	NSUInteger numberOfSections = [tableView numberOfSections];

	if (!numberOfRows && numberOfSections == 1) {
		self.contentSizeForViewInPopover = CGSizeMake(TableViewCellWidth, MinimumPopoverHeight);
		return;
	}

	UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	CGFloat height = (numberOfSections * SectionHeaderHeight) + (cell.frame.size.height * numberOfRows);

	if (height > MinimumPopoverHeight) {
		if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
			if (height > MaximumPortraitPopoverHeight)
				height = MaximumPortraitPopoverHeight;
		} else if (height > MaximumLandscapePopoverHeight)
			height = MaximumLandscapePopoverHeight;
	} else height = MinimumPopoverHeight;

	self.contentSizeForViewInPopover = CGSizeMake(TableViewCellWidth, height);
#endif
}
@end
