#import "CQConsoleController.h"

#import "CQProcessConsoleMessageOperation.h"

#import "MVIRCChatConnection.h"

#import "DDLog.h"
#import "MVDelegateLogger.h"

#define defaultNamed(name) \
	[[CQSettingsController settingsController] boolForKey:[NSString stringWithFormat:@"CQConsoleDisplay%@", name]];

static BOOL hideNICKs;
static BOOL hideTraffic; // JOIN, PART, KICK, INVITE
static BOOL hideTOPICs;
static BOOL hideMessages; // PRIVMSG, NOTICE
static BOOL hideMODEs;
static BOOL hideNumerics; // includes IRCv3 commands such as CAP and AUTHENTICATE
static BOOL hideUnknown; // WALLOP, OLINEs, etc
static BOOL hideCTCPs;
static BOOL hidePINGs;
static BOOL hideSocketInformation;
static BOOL verbose;

@interface CQDirectChatController (Private)
+ (NSOperationQueue *) chatMessageProcessingQueue;
+ (void) userDefaultsChanged;

- (void) _addPendingComponent:(id) component;
@end

@implementation CQConsoleController
+ (void) userDefaultsChanged {
	[super userDefaultsChanged];

	hideNICKs = defaultNamed(@"Nick");
	hideTraffic = defaultNamed(@"Traffic");
	hideTOPICs = defaultNamed(@"Topic");
	hideMessages = defaultNamed(@"Messages");
	hideMODEs = defaultNamed(@"Mode");
	hideNumerics = defaultNamed(@"Numeric");
	hideCTCPs = defaultNamed(@"Unknown");
	hidePINGs = defaultNamed(@"Ping");
	hideUnknown = defaultNamed(@"Ctcp");
	hideSocketInformation = !defaultNamed(@"Socket");

	verbose = defaultNamed(@"Verbose");
}

+ (void) initialize {
	[super initialize];

	static dispatch_once_t pred;
	dispatch_once(&pred, ^{
		[self userDefaultsChanged];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
	});
}

- (id) initWithTarget:(id) target {
	if (!(self = [super initWithTarget:nil]))
		return self;

	_connection = [target retain];

	_delegateLogger = [[MVDelegateLogger alloc] initWithDelegate:self];

	[DDLog addLogger:_delegateLogger];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotRawMessage:) name:MVChatConnectionGotRawMessageNotification object:_connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionWillConnect:) name:MVChatConnectionWillConnectNotification object:_connection];

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

	self.navigationItem.title = NSLocalizedString(@"Console", @"Console view title");

	transcriptView.styleIdentifier = @"console";
	transcriptView.allowsStyleChanges = NO;

	[transcriptView noteTopicChangeTo:@"" by:@""];
}

#pragma mark -

- (BOOL) available {
	return _connection.connected;
}

- (MVChatConnection *) connection {
	return _connection;
}

- (id) target {
	return _connection;
}

#pragma mark -

- (UIImage *) icon {
	return [UIImage imageNamed:@"console.png"];
}

- (NSString *) title {
	return NSLocalizedString(@"Console", @"Console cell title");
}

#pragma mark -

- (NSUInteger) unreadCount {
	return 0;
}

- (NSUInteger) importantUnreadCount {
	return 0;
}

#pragma mark -

- (void) addMessage:(NSString *) message outbound:(BOOL) outbound {
	NSParameterAssert(message != nil);

	CQProcessConsoleMessageOperation *operation = [[CQProcessConsoleMessageOperation alloc] initWithMessage:message outbound:outbound];
	operation.encoding = self.encoding;
	operation.fallbackEncoding = self.connection.encoding;

	operation.target = self;
	operation.action = @selector(_consoleMessageProcessed:);

	operation.verbose = verbose;

	[[CQDirectChatController chatMessageProcessingQueue] addOperation:operation];

	[operation release];
}

#pragma mark -

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	[_connection sendRawMessage:text];

	NSData *data = [text dataUsingEncoding:_connection.encoding];
	if (!data)
		return YES;

	[self addMessage:@{ @"message": data, @"outbound": @(YES) }];

	return YES;
}

#pragma mark -

- (void) _insertTimestamp {
	// do nothing, this is a method from CQDirectChatController we don't want to execute
}

#pragma mark -

- (void) _gotRawMessage:(NSNotification *) notification {
	[self addMessage:notification.userInfo[@"message"] outbound:[notification.userInfo[@"outbound"] boolValue]];
}

- (void) socketTrafficDidOccur:(NSString *) socketTraffic context:(void *) context {
	if (hideSocketInformation)
		return;

	if (context != _connection._chatConnection)
		return;

	[self addMessage:socketTraffic outbound:NO];
}

#pragma mark -

- (void) _consoleMessageProcessed:(CQProcessConsoleMessageOperation *) operation {
	// For some reason, we occasionally get CQProcessChatMessageOperation's in here, which is bad
	if (![operation respondsToSelector:@selector(messageType)])
		return;

	if (!hideMessages && operation.messageType == CQConsoleMessageTypeMessage)
		return;
	if (!hideTraffic && operation.messageType == CQConsoleMessageTypeTraffic)
		return;
	if (!hideNICKs && operation.messageType == CQConsoleMessageTypeNick)
		return;
	if (!hideTOPICs && operation.messageType == CQConsoleMessageTypeTopic)
		return;
	if (!hideMODEs && operation.messageType == CQConsoleMessageTypeMode)
		return;
	if (!hideNumerics && operation.messageType == CQConsoleMessageTypeNumeric)
		return;
	if (!hideCTCPs && operation.messageType == CQConsoleMessageTypeCTCP)
		return;
	if (!hidePINGs && operation.messageType == CQConsoleMessageTypePing)
		return;
	if (!hideUnknown && operation.messageType == CQConsoleMessageTypeUnknown)
		return;

	if (!_recentMessages)
		_recentMessages = [[NSMutableArray alloc] init];
	[_recentMessages addObject:operation.processedMessageInfo];

	while (_recentMessages.count > 10)
		[_recentMessages removeObjectAtIndex:0];

	[self _addPendingComponent:operation.processedMessageInfo];

	[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerRecentMessagesUpdatedNotification object:self];
}

#pragma mark -

- (void) _connectionWillConnect:(NSNotification *) notification {
	if (![[CQSettingsController settingsController] boolForKey:@"CQConsoleDisplayClearOnConnect"])
		return;

	[self clearController];

	[_recentMessages release];
	_recentMessages = nil;
}
@end
