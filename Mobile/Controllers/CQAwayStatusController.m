#import "CQAwayStatusController.h"
#import "CQAwayStatusViewController.h"

#import "MVChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQAwayStatusController
- (void) viewDidLoad {
	if (!_rootViewController) {
		CQAwayStatusViewController *viewController = [[CQAwayStatusViewController alloc] init];
		viewController.connection = _connection;

		_rootViewController = viewController;
	}

	[super viewDidLoad];
}

#pragma mark -

- (void) setConnection:(MVChatConnection *) connection {
	_connection = connection;

	((CQAwayStatusViewController *)_rootViewController).connection = connection;
}
@end

NS_ASSUME_NONNULL_END
