#import "CQAwayStatusController.h"
#import "CQAwayStatusViewController.h"

#import "MVChatConnection.h"

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

- (MVChatConnection *) connection {
	return _connection;
}

- (void) setConnection:(MVChatConnection *) connection {
	_connection = connection;

	((CQAwayStatusViewController *)_rootViewController).connection = connection;
}
@end
