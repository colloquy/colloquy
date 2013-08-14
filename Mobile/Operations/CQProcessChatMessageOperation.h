@class CQIgnoreRulesController;

@interface CQProcessChatMessageOperation : NSOperation {
	NSDictionary *_message;
	NSMutableDictionary *_processedMessage;
	NSString *_highlightNickname;
	CQIgnoreRulesController *_ignoreController;
	NSStringEncoding _encoding;
	NSStringEncoding _fallbackEncoding;
	id __weak _target;
	SEL _action;
	id _userInfo;
}
- (id) initWithMessageData:(NSData *) messageData;
- (id) initWithMessageInfo:(NSDictionary *) messageInfo;

@property (copy) NSString *highlightNickname;
@property (strong) CQIgnoreRulesController *ignoreController;

@property NSStringEncoding encoding;
@property NSStringEncoding fallbackEncoding;

@property (readonly) NSMutableDictionary *processedMessageInfo;
@property (readonly) NSString *processedMessageAsHTML;
@property (readonly) NSString *processedMessageAsPlainText;

@property (weak) id target;
@property SEL action;
@property (strong) id userInfo;
@end
