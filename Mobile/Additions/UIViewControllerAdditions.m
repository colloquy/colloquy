#import "UIViewControllerAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UIViewController (UIViewControllerAdditions)
#if !SYSTEM(TV)
- (BOOL) shouldAutorotate {
	return YES;
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
	return UIInterfaceOrientationPortrait;
}

- (NSUInteger) supportedInterfaceOrientations {
	UIInterfaceOrientationMask supportedOrientations = UIInterfaceOrientationMaskPortrait;
	if ([[UIDevice currentDevice] isPadModel])
		supportedOrientations |= UIInterfaceOrientationMaskPortraitUpsideDown;

	if (![[CQSettingsController settingsController] boolForKey:@"CQDisableLandscape"])
		supportedOrientations |= UIInterfaceOrientationMaskLandscape;

	return supportedOrientations;
}
#endif
@end

NS_ASSUME_NONNULL_END
