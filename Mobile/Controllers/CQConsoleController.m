#import "CQConsoleController.h"

#import "CQProcessConsoleMessageOperation.h"

#import "MVIRCChatConnection.h"

#import "DDLog.h"
#import "MVDelegateLogger.h"

#define defaultForServer(default, server) \
	[[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"CQConsoleDisplay%@-%@", default, server]];

#define setDefaultForServer(default, server, value) \
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:[NSString stringWithFormat:@"CQConsoleDisplay%@-%@", default, server]];

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

		setDefaultForServer(@"Socket", _connection.server, YES);
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

	self.title = NSLocalizedString(@"Console", @"Console view title");
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_hideNICKs = defaultForServer(@"Nick", _connection.server);
	_hideTraffic = defaultForServer(@"Traffic", _connection.server); // JOIN, PART, KICK, INVITE
	_hideTOPICs = defaultForServer(@"Topic", _connection.server);
	_hideMessages = defaultForServer(@"Messages", _connection.server); // PRIVMSG, NOTICE
	_hideMODEs = defaultForServer(@"Mode", _connection.server);
	_hideNumerics = defaultForServer(@"Numerics", _connection.server); // includes IRCv3 commands such as CAP and AUTHENTICATE
	_hideCTCPs = defaultForServer(@"Ctcp", _connection.server);
	_hidePINGs = defaultForServer(@"Ping", _connection.server);
	_hideUnknown = defaultForServer(@"Unknown", _connection.server); // WALLOP, OLINEs, etc
	_hideSocketInformation = defaultForServer(@"Socket", _connection.server);
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
