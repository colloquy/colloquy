#import "CQBouncerCreationViewController.h"

#import "CQBouncerEditViewController.h"
#import "CQBouncerSettings.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"

@implementation CQBouncerCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;

	_settings = [[CQBouncerSettings alloc] init];

	return self;
}

- (void) dealloc {
	[_settings release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	if (!_rootViewController) {
		CQBouncerEditViewController *editViewController = [[CQBouncerEditViewController alloc] init];
		editViewController.newBouncer = YES;
		editViewController.settings = _settings;

		_rootViewController = editViewController;
	}

	UIBarButtonItem *connectItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIBarButtonItemStyleDone target:self action:@selector(commit:)];
	_rootViewController.navigationItem.rightBarButtonItem = connectItem;
	[connectItem release];

	_rootViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_rootViewController.navigationItem.rightBarButtonItem.enabled = NO;

	[super viewDidLoad];
}

#pragma mark -

- (void) commit:(id) sender {
	[(CQBouncerEditViewController *)_rootViewController endEditing];

	[[CQConnectionsController defaultController] addBouncerSettings:_settings];

	[[CQColloquyApplication sharedApplication] showConnections:nil];

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
