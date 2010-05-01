#import "CQChatNavigationController.h"

#import "CQChatController.h"
#import "CQChatListViewController.h"
#import "CQColloquyApplication.h"

@implementation CQChatNavigationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies tab title");
	self.tabBarItem.image = [UIImage imageNamed:@"colloquies.png"];
	self.delegate = self;

	self.navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_unreadCountChanged) name:CQChatControllerChangedTotalImportantUnreadCountNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	self.delegate = nil;

	[_chatListViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_chatListViewController) {
		_chatListViewController = [[CQChatListViewController alloc] init];
		[self pushViewController:_chatListViewController animated:NO];
	}

	[[CQChatController defaultController] showPendingChatControllerAnimated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[CQChatController defaultController].totalImportantUnreadCount = 0;

	_active = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	_active = NO;
}

- (CGSize) contentSizeForViewInPopoverView {
	return CGSizeMake(320., 700.);
}

#pragma mark -

- (void) pushViewController:(UIViewController *) controller animated:(BOOL) animated {
	if ([controller conformsToProtocol:@protocol(CQChatViewController)])
		[_chatListViewController selectChatViewController:(id <CQChatViewController>)controller animatedSelection:NO animatedScroll:animated];
	[super pushViewController:controller animated:animated];
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == self.rootViewController)
		[CQChatController defaultController].totalImportantUnreadCount = 0;
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if ([[UIDevice currentDevice] isPadModel])
		return;
	if (viewController == self.rootViewController && [[CQChatController defaultController] hasPendingChatController])
		[self performSelector:@selector(_showNextChatController) withObject:nil afterDelay:0.33];
}

#pragma mark -

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll {
	[_chatListViewController selectChatViewController:controller animatedSelection:animatedSelection animatedScroll:animatedScroll];
}

#pragma mark -

- (void) _showNextChatController {
	[[CQChatController defaultController] showPendingChatControllerAnimated:YES];
}

- (void) _unreadCountChanged {
	NSInteger totalImportantUnreadCount = [CQChatController defaultController].totalImportantUnreadCount;
	if ((!_active || self.topViewController != _chatListViewController) && totalImportantUnreadCount) {
		_chatListViewController.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%u)", @"Unread count view title, uses the view's normal title with a number"), self.title, totalImportantUnreadCount];
		self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%u", totalImportantUnreadCount];
	} else {
		_chatListViewController.navigationItem.title = self.title;
		self.tabBarItem.badgeValue = nil;
	}
}
@end
