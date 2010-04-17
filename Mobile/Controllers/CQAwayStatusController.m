#import "CQAwayStatusController.h"
#import "CQAwayStatusViewController.h"

@implementation CQAwayStatusController
- (void) viewDidLoad {
	_rootViewController = [[CQAwayStatusViewController alloc] init];

	if (_userInfo)
		((CQAwayStatusViewController *)_rootViewController).connection = _userInfo;

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	[super viewDidLoad];
}

#pragma mark -

- (void) setUserInfo:(id) userInfo {
	id old = _userInfo;
	_userInfo = [userInfo retain];
	[old release];

	if (_rootViewController)
		((CQAwayStatusViewController *)_rootViewController).connection = _userInfo;
}

#pragma mark -

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}
@end
