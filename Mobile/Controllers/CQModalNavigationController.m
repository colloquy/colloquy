#import "CQModalNavigationController.h"

#import "CQColloquyApplication.h"

@implementation CQModalNavigationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

#if __IPHONE_OS_VERSION_MIN_REQUIRED > __IPHONE_3_1
	if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
		self.modalPresentationStyle = UIModalPresentationFormSheet;
#endif

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

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

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

#pragma mark -

- (void) close:(id) sender {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
