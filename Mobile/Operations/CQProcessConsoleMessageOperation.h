typedef enum {
	CQConsoleMessageTypeNick,
	CQConsoleMessageTypeTraffic, // JOIN, PART, KICK, INVITE
	CQConsoleMessageTypeTopic,
	CQConsoleMessageTypeMessage, // PRIVMSG, NOTICE
	CQConsoleMessageTypeMode,
	CQConsoleMessageTypeNumeric, // 00x, CAP, AUTHENTICATE and other IRCv3 extensions
	CQConsoleMessageTypeUnknown, // WALLOP, OLINES, etc
	CQConsoleMessageTypeCTCP,
	CQConsoleMessageTypePing // PING and PONG
} CQConsoleMessageType;

@interface CQProcessConsoleMessageOperation : NSOperation {
	NSMutableString *_message;
	NSMutableDictionary *_processedMessage;
	NSString *_highlightNickname;
	NSStringEncoding _encoding;
	NSStringEncoding _fallbackEncoding;
	id _target;
	SEL _action;
	id _userInfo;
	BOOL _outbound;

	CQConsoleMessageType _messageType;
}

- (id) initWithMessage:(NSString *) message outbound:(BOOL) outbound;

@property NSStringEncoding encoding;
@property NSStringEncoding fallbackEncoding;

@property (readonly) NSMutableDictionary *processedMessageInfo;
@property (readonly) NSString *processedMessageAsHTML;
@property (readonly) NSString *processedMessageAsPlainText;
@property (readonly) CQConsoleMessageType messageType;

@property (retain) id target;
@property SEL action;
@property (retain) id userInfo;
@end
