#import "CQModalNavigationController.h"

#import "CQColloquyApplication.h"

@implementation CQModalNavigationController
@synthesize userInfo = _userInfo;

- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
		self.modalPresentationStyle = UIModalPresentationFormSheet;

	return self;
}

- (void) dealloc {
	self.delegate = nil;

	[_rootViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	[self pushViewController:_rootViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:animated];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

#pragma mark -

- (void) close:(id) sender {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
