typedef NS_ENUM(NSInteger, CQConsoleMessageType) {
	CQConsoleMessageTypeNick,
	CQConsoleMessageTypeTraffic, // JOIN, PART, KICK, INVITE
	CQConsoleMessageTypeTopic,
	CQConsoleMessageTypeMessage, // PRIVMSG, NOTICE
	CQConsoleMessageTypeMode,
	CQConsoleMessageTypeNumeric, // 00x, CAP, AUTHENTICATE and other IRCv3 extensions
	CQConsoleMessageTypeUnknown, // WALLOP, OLINES, etc
	CQConsoleMessageTypeCTCP,
	CQConsoleMessageTypePing // PING and PONG
};

@interface CQProcessConsoleMessageOperation : NSOperation {
	NSMutableString *_message;
	NSMutableDictionary *_processedMessage;
	NSString *_highlightNickname;
	NSStringEncoding _encoding;
	NSStringEncoding _fallbackEncoding;
	id __weak _target;
	SEL _action;
	id _userInfo;
	BOOL _outbound;

	CQConsoleMessageType _messageType;
	BOOL _verbose;
}

- (instancetype) initWithMessage:(NSString *) message outbound:(BOOL) outbound;

@property BOOL verbose;
@property NSStringEncoding encoding;
@property NSStringEncoding fallbackEncoding;

@property (readonly) NSMutableDictionary *processedMessageInfo;
@property (readonly) NSString *processedMessageAsHTML;
@property (readonly) NSString *processedMessageAsPlainText;
@property (readonly) CQConsoleMessageType messageType;

@property (weak) id target;
@property SEL action;
@property (strong) id userInfo;
@end
