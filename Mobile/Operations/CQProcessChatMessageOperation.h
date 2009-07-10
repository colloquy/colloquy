@interface CQProcessChatMessageOperation : NSOperation {
	NSDictionary *_message;
	NSMutableDictionary *_processedMessage;
	NSString *_highlightNickname;
	NSStringEncoding _encoding;
	id _target;
	SEL _action;
	id _userInfo;
}
- (id) initWithMessageData:(NSData *) messageData;
- (id) initWithMessageInfo:(NSDictionary *) messageInfo;

@property (copy) NSString *highlightNickname;
@property NSStringEncoding encoding;

@property (readonly) NSMutableDictionary *processedMessageInfo;
@property (readonly) NSString *processedMessageAsHTML;
@property (readonly) NSString *processedMessageAsPlainText;

@property (retain) id target;
@property SEL action;
@property (retain) id userInfo;
@end
