#import "CQTableViewController.h"

@implementation CQTableViewController
- (void) dealloc {
	if ([self isViewLoaded]) {
		self.tableView.dataSource = nil;
		self.tableView.delegate = nil;
	}

	[super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if (interfaceOrientation == UIInterfaceOrientationPortrait)
		return YES;
	if (![[UIDevice currentDevice] isPadModel] && interfaceOrientation == UIDeviceOrientationPortraitUpsideDown)
		return NO;
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}
@end
