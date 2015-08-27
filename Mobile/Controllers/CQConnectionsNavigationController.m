#import "CQConnectionsNavigationController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQConnectionsNavigationController
- (void) viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close button title") style:UIBarButtonItemStyleDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = doneItem;
}

- (void) close:(__nullable id) sender {
	[[CQConnectionsController defaultController] saveConnections];

	[super close:sender];
}
@end

NS_ASSUME_NONNULL_END
