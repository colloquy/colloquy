#import "CQWelcomeNavigationController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQWelcomeViewController.h"

@implementation CQWelcomeNavigationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	return self;
}

- (void) dealloc {
	[_welcomeViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_welcomeViewController)
		return;

	_welcomeViewController = [[CQWelcomeViewController alloc] init];

	UIBarButtonItem *connectItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_welcomeViewController.navigationItem.rightBarButtonItem = connectItem;
	[connectItem release];

	[self pushViewController:_welcomeViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}

#pragma mark -

- (void) close:(id) sender {
	[self.view endEditing:YES];

	[CQColloquyApplication sharedApplication].tabBarController.selectedViewController = [CQConnectionsController defaultController];
	[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:YES];
	[self dismissModalViewControllerAnimated:YES];
}
@end
