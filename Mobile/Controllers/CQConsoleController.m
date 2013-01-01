#import "CQConsoleController.h"

#import "CQConsoleSettingsViewController.h"

#import "CQProcessConsoleMessageOperation.h"

#import "MVIRCChatConnection.h"

#import "DDLog.h"
#import "MVDelegateLogger.h"

BOOL defaultForServer(NSString *defaultName, NSString *serverName) {
	return [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"CQConsoleDisplay%@-%@", defaultName, serverName]];
}

NSString *const CQConsoleHideNickKey = @"Nick";
NSString *const CQConsoleHideTrafficKey = @"Traffic";
NSString *const CQConsoleHideTopicKey = @"Topic";
NSString *const CQConsoleHideMessagesKey = @"Messages";
NSString *const CQConsoleHideModeKey = @"Mode";
NSString *const CQConsoleHideNumericKey = @"Numeric";
NSString *const CQConsoleHideUnknownKey = @"Unknown";
NSString *const CQConsoleHideCtcpKey = @"Ctcp";
NSString *const CQConsoleHidePingKey = @"Ping";
NSString *const CQConsoleHideSocketKey = @"Socket";

@interface CQDirectChatController (Private)
+ (NSOperationQueue *) chatMessageProcessingQueue;

- (void) _addPendingComponent:(id) component;
@end

@implementation CQConsoleController
- (id) initWithTarget:(id) target {
	if (!(self = [super initWithTarget:nil]))
		return self;

	_connection = [target retain];

	NSString *key = [NSString stringWithFormat:@"CQConsolePreferencesSet-%@", _connection.server];
	if (![[NSUserDefaults standardUserDefaults] boolForKey:key]) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:[NSString stringWithFormat:@"CQConsoleDisplaySocket-%@", _connection.server]];
	}

	_delegateLogger = [[MVDelegateLogger alloc] initWithDelegate:self];

	[DDLog addLogger:_delegateLogger];

	return self;
}

- (void) dealloc {
	[DDLog removeLogger:_delegateLogger];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatConnectionGotRawMessageNotification object:_connection];

	[_delegateLogger release];
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotRawMessage:) name:MVChatConnectionGotRawMessageNotification object:_connection];

	self.navigationItem.title = NSLocalizedString(@"Console", @"Console view title");

	UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize target:self action:@selector(showSettings:)];
	self.navigationItem.rightBarButtonItem = settingsItem;
	[settingsItem release];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_hideNICKs = defaultForServer(CQConsoleHideNickKey, _connection.server);
	_hideTraffic = defaultForServer(CQConsoleHideTrafficKey, _connection.server);
	_hideTOPICs = defaultForServer(CQConsoleHideTopicKey, _connection.server);
	_hideMessages = defaultForServer(CQConsoleHideMessagesKey, _connection.server);
	_hideMODEs = defaultForServer(CQConsoleHideModeKey, _connection.server);
	_hideNumerics = defaultForServer(CQConsoleHideNumericKey, _connection.server);
	_hideCTCPs = defaultForServer(CQConsoleHideCtcpKey, _connection.server);
	_hidePINGs = defaultForServer(CQConsoleHidePingKey, _connection.server);
	_hideUnknown = defaultForServer(CQConsoleHideUnknownKey, _connection.server);
	_hideSocketInformation = defaultForServer(CQConsoleHideSocketKey, _connection.server);
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

- (id) target {
	return _connection;
}

#pragma mark -

- (void) addMessage:(NSString *) message outbound:(BOOL) outbound {
	NSParameterAssert(message != nil);

	CQProcessConsoleMessageOperation *operation = [[CQProcessConsoleMessageOperation alloc] initWithMessage:message outbound:outbound];
	operation.encoding = self.encoding;
	operation.fallbackEncoding = self.connection.encoding;

	operation.target = self;
	operation.action = @selector(_messageProcessed:);

	[[CQDirectChatController chatMessageProcessingQueue] addOperation:operation];

	[operation release];
}

- (void) showSettings:(id) sender {
	CQConsoleSettingsViewController *settingsViewController = [[CQConsoleSettingsViewController alloc] initWithConnection:_connection];
	[self.navigationController pushViewController:settingsViewController animated:YES];
	[settingsViewController release];
}

#pragma mark -

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	[_connection sendRawMessage:text];

	[self addMessage:@{ @"message": [text dataUsingEncoding:_connection.encoding], @"outbound": @(YES) }];

	return YES;
}

#pragma mark -

- (void) _gotRawMessage:(NSNotification *) notification {
	[self addMessage:notification.userInfo[@"message"] outbound:notification.userInfo[@"outbound"]];
}

- (void) socketTrafficDidOccur:(NSString *) socketTraffic context:(void *) context {
	if (_hideSocketInformation)
		return;

	if (context != _connection._chatConnection)
		return;

	[self addMessage:socketTraffic outbound:NO];
}

#pragma mark -

- (void) _messageProcessed:(CQProcessConsoleMessageOperation *) operation {
	if (_hideMessages && operation.messageType == CQConsoleMessageTypeMessage)
		return;
	if (_hideTraffic && operation.messageType == CQConsoleMessageTypeTraffic)
		return;
	if (_hideNICKs && operation.messageType == CQConsoleMessageTypeNick)
		return;
	if (_hideTOPICs && operation.messageType == CQConsoleMessageTypeTopic)
		return;
	if (_hideMODEs && operation.messageType == CQConsoleMessageTypeMode)
		return;
	if (_hideNumerics && operation.messageType == CQConsoleMessageTypeNumeric)
		return;
	if (_hideCTCPs && operation.messageType == CQConsoleMessageTypeCTCP)
		return;
	if (_hidePINGs && operation.messageType == CQConsoleMessageTypePing)
		return;
	if (_hideUnknown && operation.messageType == CQConsoleMessageTypeUnknown)
		return;

	[self _addPendingComponent:operation.processedMessageInfo];
}
@end
