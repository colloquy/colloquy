#import "CQBouncerCreationViewController.h"

#import "CQBouncerEditViewController.h"
#import "CQBouncerSettings.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "NSStringAdditions.h"

@implementation CQBouncerCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	_settings = [[CQBouncerSettings alloc] init];

	return self;
}

- (void) dealloc {
	[_settings release];
	[_editViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_editViewController)
		return;

	_editViewController = [[CQBouncerEditViewController alloc] init];
	_editViewController.newBouncer = YES;
	_editViewController.settings = _settings;

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
	_editViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	UIBarButtonItem *connectItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIBarButtonItemStyleDone target:self action:@selector(commit:)];
	_editViewController.navigationItem.rightBarButtonItem = connectItem;
	[connectItem release];

	_editViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_editViewController.navigationItem.rightBarButtonItem.enabled = NO;

	[self pushViewController:_editViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return (UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

- (void) cancel:(id) sender {
	[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:YES];
	[self dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	[self.view endEditing:YES];

	[[CQConnectionsController defaultController] addBouncerSettings:_settings];

	[CQColloquyApplication sharedApplication].tabBarController.selectedViewController = [CQConnectionsController defaultController];
	[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:YES];
	[self dismissModalViewControllerAnimated:YES];
}
@end
