#import "UIViewControllerAdditions.h"

#define CQMinimumPopoverHeight 320
#define CQMaximumPortraitPopoverHeight 876 // 921 (default) - 45 (height of a UITextField)
#define CQMaximumLandscapePopoverHeight 620 // 665 (default) - 45 (height of a UITextField)

@implementation UIViewController (UIViewControllerAdditions)
- (void) resizeForViewInPopoverUsingTableView:(UITableView *) tableView {
	if (![UIDevice currentDevice].isPadModel)
		return;

	CGFloat width = self.preferredContentSize.width;

	NSUInteger numberOfRows = [tableView numberOfRows];
	NSUInteger numberOfSections = [tableView numberOfSections];

	if (!numberOfRows && numberOfSections == 1) {
		self.preferredContentSize = CGSizeMake(width, CQMinimumPopoverHeight);
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

	self.preferredContentSize = CGSizeMake(width, height);
}

- (BOOL) shouldAutorotate {
	return YES;
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
	return UIInterfaceOrientationPortrait;
}

- (NSUInteger) supportedInterfaceOrientations {
	UIInterfaceOrientationMask supportedOrientations = UIInterfaceOrientationMaskPortrait;
	if ([UIDevice currentDevice].isPadModel)
		supportedOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;

	if (![[CQSettingsController settingsController] boolForKey:@"CQDisableLandscape"])
		supportedOrientations |= UIInterfaceOrientationMaskLandscape;

	return supportedOrientations;
}
@end
