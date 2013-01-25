#import "CQPreferencesViewController.h"

#import "CQPreferencesDisplayViewController.h"

@implementation CQPreferencesViewController
- (void) viewDidLoad {
	if (!_rootViewController) {
		CQPreferencesDisplayViewController *preferencesDisplayViewController = [[CQPreferencesDisplayViewController alloc] initWithRootPlist];
		preferencesDisplayViewController.title = NSLocalizedString(@"Settings", @"Settings view title");
		_rootViewController = preferencesDisplayViewController;
	}

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.rightBarButtonItem = doneItem;
	[doneItem release];

    [super viewDidLoad];

	_rootViewController.navigationItem.leftBarButtonItem = nil;
}
@end
