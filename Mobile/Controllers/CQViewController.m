#import "CQViewController.h"

@implementation CQViewController
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if (interfaceOrientation == UIInterfaceOrientationPortrait)
		return YES;
	if (![[UIDevice currentDevice] isPadModel] && interfaceOrientation == UIDeviceOrientationPortraitUpsideDown)
		return NO;
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}
@end
