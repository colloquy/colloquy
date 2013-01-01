#import "CQViewController.h"

@implementation CQViewController
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if (interfaceOrientation == UIInterfaceOrientationPortrait)
		return YES;
	if (![[UIDevice currentDevice] isPadModel] && interfaceOrientation == UIDeviceOrientationPortraitUpsideDown)
		return NO;
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
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
