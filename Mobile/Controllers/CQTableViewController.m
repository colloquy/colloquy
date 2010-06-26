#import "CQTableViewController.h"

@implementation CQTableViewController
- (id) initWithStyle:(UITableViewStyle) style {
	if (!(self = [super initWithStyle:style]))
		return nil;
	return self;
}

- (void) dealloc {
	if ([self isViewLoaded]) {
		self.tableView.dataSource = nil;
		self.tableView.delegate = nil;
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark -

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if (interfaceOrientation == UIInterfaceOrientationPortrait)
		return YES;
	if (![[UIDevice currentDevice] isPadModel] && interfaceOrientation == UIDeviceOrientationPortraitUpsideDown)
		return NO;
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
	if ([[UIDevice currentDevice] isSystemFour])
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadTableView) name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
	if ([[UIDevice currentDevice] isSystemFour])
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
}

#pragma mark -

- (void) _reloadTableView {
	if ([self isViewLoaded])
		[self.tableView reloadData];
}
@end
