#import "CQConnectionCreationViewController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQConnectionEditViewController.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatConnection.h>

static inline BOOL isDefaultValue(NSString *string) {
	return [string isEqualToString:@"<<default>>"];
}

static inline BOOL isPlaceholderValue(NSString *string) {
	return [string isEqualToString:@"<<placeholder>>"];
}

#pragma mark -

@implementation CQConnectionCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;
	self.delegate = self;
	return self;
}

- (void) dealloc {
	[_editViewController release];
	[_url release];
	[super dealloc];
}

@synthesize url = _url;

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	_editViewController = [[CQConnectionEditViewController alloc] init];
	_editViewController.newConnection = YES;

	MVChatConnection *connection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];
	connection.server = (_url.host.length ? _url.host : @"<<placeholder>>");
	connection.preferredNickname = (_url.user.length ? _url.user : @"<<default>>");
	connection.realName = @"<<default>>";
	connection.username = @"<<default>>";
	connection.automaticallyConnect = YES;
	connection.secure = ([_url.scheme isEqualToString:@"ircs"] || [_url.port unsignedShortValue] == 994);
	connection.serverPort = ([_url.port unsignedShortValue] ? [_url.port unsignedShortValue] : (connection.secure ? 994 : 6667));

	NSString *target = nil;
	if (_url.fragment.length) target = [@"#" stringByAppendingString:[_url.fragment stringByDecodingIllegalURLCharacters]];
	else if (_url.path.length > 1) target = [[_url.path substringFromIndex:1] stringByDecodingIllegalURLCharacters];

	if (target.length)
		connection.automaticJoinedRooms = [NSArray arrayWithObject:target];

	_editViewController.connection = connection;
	[connection release];

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
	_editViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	UIBarButtonItem *connectItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIBarButtonItemStyleDone target:self action:@selector(commit:)];
	_editViewController.navigationItem.rightBarButtonItem = connectItem;
	[connectItem release];

	_editViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_editViewController.navigationItem.rightBarButtonItem.enabled = (_url.host.length ? YES : NO);

	[self pushViewController:_editViewController animated:NO];
}

- (void) viewDidDisappear:(BOOL) animated {
	[_editViewController release];
	_editViewController = nil;
}

#pragma mark -

- (void) cancel:(id) sender {
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	[self.view endEditing:YES];

	MVChatConnection *connection = _editViewController.connection;
	if (isPlaceholderValue(connection.server)) {
		[self cancel:sender];
		return;
	}

	if (isDefaultValue(connection.preferredNickname))
		connection.preferredNickname = [MVChatConnection defaultNickname];

	if (isDefaultValue(connection.realName))
		connection.realName = [MVChatConnection defaultRealName];

	if (isDefaultValue(connection.username))
		connection.username = [MVChatConnection defaultUsername];

	connection.encoding = [MVChatConnection defaultEncoding];

	[[CQConnectionsController defaultController] addConnection:connection];

	[connection connect];

	[CQColloquyApplication sharedApplication].tabBarController.selectedViewController = [CQConnectionsController defaultController];
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewWillDisappear: and viewWillAppear: are not called when this navigation controller is a modal view.
	if (navigationController.topViewController != viewController)
		[navigationController.topViewController viewWillDisappear:animated];
	[viewController viewWillAppear:animated];
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewDidAppear: is not called when this navigation controller is a modal view.
	[viewController viewDidAppear:animated];
}
@end
