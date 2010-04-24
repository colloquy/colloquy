#import "CQAwayStatusController.h"
#import "CQAwayStatusViewController.h"

@implementation CQAwayStatusController
- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	if (!_rootViewController) {
		CQAwayStatusViewController *viewController = [[CQAwayStatusViewController alloc] init];
		viewController.connection = _connection;

		_rootViewController = viewController;
	}

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	[super viewDidLoad];
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	((CQAwayStatusViewController *)_rootViewController).connection = connection;
}
@end
