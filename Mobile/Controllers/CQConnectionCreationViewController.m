#import "CQConnectionCreationViewController.h"

#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQConnectionEditViewController.h"

#import <ChatCore/MVChatConnection.h>

static inline __attribute__((always_inline)) BOOL isDefaultValue(NSString *string) {
	return [string isEqualToString:@"<<default>>"];
}

static inline __attribute__((always_inline)) BOOL isPlaceholderValue(NSString *string) {
	return [string isEqualToString:@"<<placeholder>>"];
}

#pragma mark -

@implementation CQConnectionCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;

	_connection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];
	_connection.server = @"<<placeholder>>";
	_connection.preferredNickname = @"<<default>>";
	_connection.realName = @"<<default>>";
	_connection.username = @"<<default>>";
	_connection.automaticallyConnect = YES;
	_connection.secure = NO;
	_connection.serverPort = 6667;
	_connection.encoding = [MVChatConnection defaultEncoding];

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

- (NSURL *) url {
	if (isPlaceholderValue(_connection.server))
		return nil;
	return _connection.url;
}

- (void) setUrl:(NSURL *) url {
	_connection.server = (url.host.length ? url.host : @"<<placeholder>>");
	_connection.preferredNickname = (url.user.length ? url.user : @"<<default>>");
	_connection.secure = ([url.scheme isEqualToString:@"ircs"] || [url.port unsignedShortValue] == 994);
	_connection.serverPort = ([url.port unsignedShortValue] ? [url.port unsignedShortValue] : (_connection.secure ? 994 : 6667));

	NSString *target = nil;
	if (url.fragment.length) target = [@"#" stringByAppendingString:[url.fragment stringByDecodingIllegalURLCharacters]];
	else if (url.path.length > 1) target = [[url.path substringFromIndex:1] stringByDecodingIllegalURLCharacters];

	if (target.length)
		_connection.automaticJoinedRooms = [NSArray arrayWithObject:target];

	_rootViewController.navigationItem.rightBarButtonItem.enabled = (url.host.length ? YES : NO);
}

#pragma mark -

- (void) viewDidLoad {
	if (!_rootViewController) {
		CQConnectionEditViewController *editViewController = [[CQConnectionEditViewController alloc] init];
		editViewController.newConnection = YES;
		editViewController.connection = _connection;

		_rootViewController = editViewController;
	}

	UIBarButtonItem *connectItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIBarButtonItemStyleDone target:self action:@selector(commit:)];
	_rootViewController.navigationItem.rightBarButtonItem = connectItem;
	[connectItem release];

	_rootViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_rootViewController.navigationItem.rightBarButtonItem.enabled = (_connection.server.length && !isPlaceholderValue(_connection.server));

	[super viewDidLoad];
}

#pragma mark -
- (void) commit:(id) sender {
	[(CQConnectionEditViewController *)_rootViewController endEditing];

	if (isPlaceholderValue(_connection.server)) {
		[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
		return;
	}

	if (isDefaultValue(_connection.preferredNickname))
		_connection.preferredNickname = [MVChatConnection defaultNickname];

	if (isDefaultValue(_connection.realName))
		_connection.realName = [MVChatConnection defaultRealName];

	if (isDefaultValue(_connection.username))
		_connection.username = [MVChatConnection defaultUsernameWithNickname:_connection.preferredNickname];

	[[CQConnectionsController defaultController] addConnection:_connection];

	[_connection connect];

	[[CQColloquyApplication sharedApplication] showColloquies:nil];

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}
@end
