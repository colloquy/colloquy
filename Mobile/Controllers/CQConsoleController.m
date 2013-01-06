#import "CQConsoleController.h"

#import "CQProcessConsoleMessageOperation.h"

#import "MVIRCChatConnection.h"

#import "DDLog.h"
#import "MVDelegateLogger.h"

#define defaultNamed(name) \
	[[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"CQConsoleDisplay%@", name]];

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
	hideSocketInformation = defaultNamed(@"Socket");
}

+ (void) initialize {
	[super initialize];

	static dispatch_once_t pred;
	dispatch_once(&pred, ^{
		[self userDefaultsChanged];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];
	});
}

- (id) initWithTarget:(id) target {
	if (!(self = [super initWithTarget:nil]))
		return self;

	_connection = [target retain];

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

	transcriptView.dataDetectorTypes = UIDataDetectorTypeNone;
	transcriptView.styleIdentifier = @"console";
	transcriptView.allowsStyleChanges = NO;
}

#pragma mark -

- (BOOL) available {
	return YES;
}

- (MVChatConnection *) connection {
	return _connection;
}

- (id) target {
	return _connection;
}

#pragma mark -

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

- (void) _messageProcessed:(CQProcessConsoleMessageOperation *) operation {
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
}
@end
