#import "CQTableViewController.h"

@implementation CQTableViewController
- (id) initWithStyle:(UITableViewStyle) style {
	if (!(self = [super initWithStyle:style]))
		return nil;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableView) name:NSUserDefaultsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTableView) name:UIApplicationWillEnterForegroundNotification object:nil];

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

- (void) reloadTableView {
	if ([self isViewLoaded])
		[self.tableView reloadData];
}
@end
