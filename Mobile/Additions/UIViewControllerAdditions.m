#import "UIViewControllerAdditions.h"

#define CQMinimumPopoverHeight 320
#define CQMaximumPortraitPopoverHeight 876 // 921 (default) - 45 (height of a UITextField)
#define CQMaximumLandscapePopoverHeight 620 // 665 (default) - 45 (height of a UITextField)

@implementation UIViewController (UIViewControllerAdditions)
- (void) resizeForViewInPopoverUsingTableView:(UITableView *) tableView {
	if (![[UIDevice currentDevice] isPadModel])
		return;

	CGFloat width = self.contentSizeForViewInPopover.width;

	NSUInteger numberOfRows = [tableView numberOfRows];
	NSUInteger numberOfSections = [tableView numberOfSections];

	if (!numberOfRows && numberOfSections == 1) {
		self.contentSizeForViewInPopover = CGSizeMake(width, CQMinimumPopoverHeight);
		return;
	}

	CGFloat height = (numberOfSections * tableView.sectionHeaderHeight) + (numberOfRows * tableView.rowHeight);

	if (height > CQMinimumPopoverHeight) {
		if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
			if (height > CQMaximumPortraitPopoverHeight)
				height = CQMaximumPortraitPopoverHeight;
		} else if (height > CQMaximumLandscapePopoverHeight)
			height = CQMaximumLandscapePopoverHeight;
	} else height = CQMinimumPopoverHeight;

	self.contentSizeForViewInPopover = CGSizeMake(width, height);
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
	return UIInterfaceOrientationMaskPortrait;
}

- (NSUInteger) supportedInterfaceOrientations {
	UIInterfaceOrientationMask supportedOrientations = UIInterfaceOrientationMaskPortrait;
	if (![UIDevice currentDevice].isPhoneModel)
		supportedOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;

	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		supportedOrientations |= UIInterfaceOrientationMaskLandscape;

	return supportedOrientations;
}
@end
