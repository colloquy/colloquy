#import "CQConsoleController.h"

@import CocoaLumberjack;

#import "CQProcessConsoleMessageOperation.h"

#import "NSAttributedStringAdditions.h"
#import "NSNotificationAdditions.h"

#import "MVDelegateLogger.h"
#import "MVIRCChatConnection.h"

static BOOL showNICKs;
static BOOL showTraffic; // JOIN, PART, KICK, INVITE
static BOOL showTOPICs;
static BOOL showMessages; // PRIVMSG, NOTICE
static BOOL showMODEs;
static BOOL showNumerics; // includes IRCv3 commands such as CAP and AUTHENTICATE
static BOOL showUnknown; // WALLOP, OLINEs, etc
static BOOL showCTCPs;
static BOOL showPINGs;
static BOOL showSocketInformation;
static BOOL verbose;

NS_ASSUME_NONNULL_BEGIN

#define defaultNamed(name) \
	[[CQSettingsController settingsController] boolForKey:[NSString stringWithFormat:@"CQConsoleDisplay%@", name]];

@interface CQDirectChatController (Private) <MVLoggingDelegate>
+ (NSOperationQueue *) chatMessageProcessingQueue;
+ (void) userDefaultsChanged;

- (void) _addPendingComponent:(id) component;
- (BOOL) _sendText:(MVChatString *) text;
@end

@implementation CQConsoleController {
	MVChatConnection *_connection;

	MVDelegateLogger *_delegateLogger;
}

+ (void) userDefaultsChanged {
	[super userDefaultsChanged];

	showNICKs = defaultNamed(@"Nick");
	showTraffic = defaultNamed(@"Traffic");
	showTOPICs = defaultNamed(@"Topic");
	showMessages = defaultNamed(@"Messages");
	showMODEs = defaultNamed(@"Mode");
	showNumerics = defaultNamed(@"Numeric");
	showCTCPs = defaultNamed(@"Unknown");
	showPINGs = defaultNamed(@"Ping");
	showUnknown = defaultNamed(@"Ctcp");
	showSocketInformation = defaultNamed(@"Socket");

	verbose = defaultNamed(@"Verbose");
}

+ (void) initialize {
	[super initialize];

	static dispatch_once_t pred;
	dispatch_once(&pred, ^{
		[self userDefaultsChanged];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
	});
}

- (instancetype) initWithTarget:(__nullable id) target {
	if (!(self = [super initWithTarget:nil]))
		return self;

	_connection = target;

	_delegateLogger = [[MVDelegateLogger alloc] initWithDelegate:self];

	[DDLog addLogger:_delegateLogger];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_gotRawMessage:) name:MVChatConnectionGotRawMessageNotification object:_connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_connectionWillConnect:) name:MVChatConnectionWillConnectNotification object:_connection];

	return self;
}

- (void) dealloc {
	[DDLog removeLogger:_delegateLogger];

	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatConnectionGotRawMessageNotification object:_connection];


}

#pragma mark -

- (void) awakeFromNib {
	[super awakeFromNib];

	transcriptView.styleIdentifier = @"console";
	transcriptView.allowsStyleChanges = NO;
}

- (void) viewDidLoad {
	[super viewDidLoad];

	self.navigationItem.title = NSLocalizedString(@"Console", @"Console view title");

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
	operation.target = self;
	operation.action = @selector(_consoleMessageProcessed:);

	operation.verbose = verbose;

	[[CQDirectChatController chatMessageProcessingQueue] addOperation:operation];
}

#pragma mark -

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(MVChatString *) text {
	if ([super _sendText:text])
		return YES;

	[_connection sendRawMessage:MVChatStringAsString(text)];

	NSData *data = nil;
	if ([text respondsToSelector:@selector(dataUsingEncoding:)])
		data = [text performPrivateSelector:@"dataUsingEncoding" withUnsignedInteger:_connection.encoding];
	else if ([text respondsToSelector:@selector(string)])
		data = [text.string dataUsingEncoding:_connection.encoding];

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

- (void) delegateLogger:(MVDelegateLogger *) delegateLogger socketTrafficDidOccur:(NSString *) socketTraffic context:(int) context {
	if (!showSocketInformation)
		return;

	if (context != (int)((__bridge void *)_connection._chatConnection))
		return;

	[self addMessage:socketTraffic outbound:NO];
}

#pragma mark -

- (void) _consoleMessageProcessed:(CQProcessConsoleMessageOperation *) operation {
	// For some reason, we occasionally get CQProcessChatMessageOperation's in here, which is bad
	if (![operation respondsToSelector:@selector(messageType)])
		return;

	if (!showMessages && operation.messageType == CQConsoleMessageTypeMessage)
		return;
	if (!showTraffic && operation.messageType == CQConsoleMessageTypeTraffic)
		return;
	if (!showNICKs && operation.messageType == CQConsoleMessageTypeNick)
		return;
	if (!showTOPICs && operation.messageType == CQConsoleMessageTypeTopic)
		return;
	if (!showMODEs && operation.messageType == CQConsoleMessageTypeMode)
		return;
	if (!showNumerics && operation.messageType == CQConsoleMessageTypeNumeric)
		return;
	if (!showCTCPs && operation.messageType == CQConsoleMessageTypeCTCP)
		return;
	if (!showPINGs && operation.messageType == CQConsoleMessageTypePing)
		return;
	if (!showUnknown && operation.messageType == CQConsoleMessageTypeUnknown)
		return;

	if (!_recentMessages)
		_recentMessages = [[NSMutableArray alloc] init];
	[_recentMessages addObject:operation.processedMessageInfo];

	while (_recentMessages.count > 10)
		[_recentMessages removeObjectAtIndex:0];

	[self _addPendingComponent:operation.processedMessageInfo];

	[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerRecentMessagesUpdatedNotification object:self];
}

#pragma mark -

- (void) _connectionWillConnect:(NSNotification *) notification {
	if (![[CQSettingsController settingsController] boolForKey:@"CQConsoleDisplayClearOnConnect"])
		return;

	[self clearController];

	_recentMessages = nil;
}
@end

NS_ASSUME_NONNULL_END
