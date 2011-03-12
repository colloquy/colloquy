#import "CQConnectionsNavigationController.h"

#import "CQBouncerEditViewController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQConnectionsViewController.h"
#import "CQConnectionEditViewController.h"

@implementation CQConnectionsNavigationController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.title = NSLocalizedString(@"Connections", @"Connections tab title");
	self.tabBarItem.image = [UIImage imageNamed:@"connections.png"];
	self.delegate = self;

	self.navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	self.delegate = nil;

	[_connectionsViewController release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_connectionsViewController)
		return;

	_connectionsViewController = [[CQConnectionsViewController alloc] init];

	[self pushViewController:_connectionsViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[self popToRootViewControllerAnimated:NO];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	if (_wasEditing) {
		[[CQConnectionsController defaultController] saveConnections];
		_wasEditing = NO;
	}
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == _connectionsViewController && _wasEditing) {
		[[CQConnectionsController defaultController] saveConnections];
		_wasEditing = NO;
	}
}

#pragma mark -

- (void) editConnection:(MVChatConnection *) connection {
	CQConnectionEditViewController *editViewController = [[CQConnectionEditViewController alloc] init];
	editViewController.connection = connection;

	_wasEditing = YES;
	[self pushViewController:editViewController animated:YES];

	[editViewController release];
}

- (void) editBouncer:(CQBouncerSettings *) settings {
	CQBouncerEditViewController *editViewController = [[CQBouncerEditViewController alloc] init];
	editViewController.settings = settings;

	_wasEditing = YES;
	[self pushViewController:editViewController animated:YES];

	[editViewController release];
}

#pragma mark -

- (void) _userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	self.navigationBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;
}
@end
