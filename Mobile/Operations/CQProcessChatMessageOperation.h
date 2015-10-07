@class CQIgnoreRulesController;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CQInlineGIFImageKey;

@interface CQProcessChatMessageOperation : NSOperation
- (instancetype) initWithMessageData:(NSData *) messageData;
- (instancetype) initWithMessageInfo:(NSDictionary *) messageInfo;

@property (copy) NSString *highlightNickname;
@property (strong) CQIgnoreRulesController *ignoreController;

@property NSStringEncoding encoding;
@property NSStringEncoding fallbackEncoding;

@property (readonly) NSMutableDictionary *processedMessageInfo;
@property (nonatomic, readonly) NSString *processedMessageAsHTML;
@property (nonatomic, readonly) NSString *processedMessageAsPlainText;

@property (weak) id target;
@property SEL action;
@property (strong) id userInfo;
@end

NS_ASSUME_NONNULL_END
