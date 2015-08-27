#import "CQPreferencesViewController.h"

#import "CQPreferencesDisplayViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQPreferencesViewController
- (void) viewDidLoad {
	if (!_rootViewController) {
		CQPreferencesDisplayViewController *preferencesDisplayViewController = [[CQPreferencesDisplayViewController alloc] initWithRootPlist];
		preferencesDisplayViewController.title = NSLocalizedString(@"Settings", @"Settings view title");
		_rootViewController = preferencesDisplayViewController;
	}

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.rightBarButtonItem = doneItem;

	[super viewDidLoad];

	_rootViewController.navigationItem.leftBarButtonItem = nil;
}
@end

NS_ASSUME_NONNULL_END
