#import "CQWelcomeController.h"

#import "CQColloquyApplication.h"
#import "CQHelpTopicsViewController.h"
#import "CQWelcomeViewController.h"

@implementation CQWelcomeController
@synthesize shouldShowOnlyHelpTopics = _shouldShowOnlyHelpTopics;

- (void) viewDidLoad {
	if (_shouldShowOnlyHelpTopics && !_rootViewController)
		_rootViewController = [[CQHelpTopicsViewController alloc] init];
	else if (!_rootViewController)
		_rootViewController = [[CQWelcomeViewController alloc] init];

	[super viewDidLoad];
}

- (void) close:(id) sender {
	if (!_shouldShowOnlyHelpTopics)
		[[CQColloquyApplication sharedApplication] showConnections:nil];

	[super close:sender];
}
@end
