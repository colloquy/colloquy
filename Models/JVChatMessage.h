#import "JVChatTranscript.h"
#import "KAIgnoreRule.h"

typedef NS_ENUM(OSType, JVChatMessageType) {
	JVChatMessageNormalType = 'noMt',
	JVChatMessageNoticeType = 'nTMt'
};

@interface JVChatMessage : NSObject <NSMutableCopying, JVChatTranscriptElement>
- (/* xmlNode */ void *) node;

@property (readonly, strong) NSDate *date;

@property (readonly) NSUInteger consecutiveOffset;

@property (readonly, copy) NSString *senderName;
@property (readonly, copy) NSString *senderIdentifier;
@property (readonly, copy) NSString *senderNickname;
@property (readonly, copy) NSString *senderHostmask;
@property (readonly, copy) NSString *senderClass;
@property (readonly, copy) NSString *senderBuddyIdentifier;
@property (readonly) BOOL senderIsLocalUser;

- (NSTextStorage *) body;
@property (readonly, copy) NSString *bodyAsPlainText;
@property (readonly, copy) NSString *bodyAsHTML;

@property (readonly, getter=isAction) BOOL action;
@property (readonly, getter=isHighlighted) BOOL highlighted;
@property (readonly) JVIgnoreMatchResult ignoreStatus;
@property (readonly) JVChatMessageType type;

@property (readonly, strong) NSURL *source;
@property (readonly, weak) JVChatTranscript *transcript;
@property (readonly, copy) NSString *messageIdentifier;

@property (strong) NSScriptObjectSpecifier *objectSpecifier;

- (NSDictionary *) attributes;
- (id) attributeForKey:(id) key;
@end

@interface JVMutableChatMessage : JVChatMessage {
	@protected
	id _sender;
}
+ (instancetype) messageWithText:(id) body sender:(id) sender;
- (instancetype) initWithText:(id) body sender:(id) sender;

@property (readwrite, strong) NSDate *date;

@property (strong) id sender;

- (void) setBody:(id) message;
@property (readwrite, copy) NSString *bodyAsPlainText;
@property (readwrite, copy) NSString *bodyAsHTML;

@property (readwrite, getter=isAction) BOOL action;
@property (readwrite, getter=isHighlighted) BOOL highlighted;
@property (readwrite) JVIgnoreMatchResult ignoreStatus;
@property (readwrite) JVChatMessageType type;

@property (readwrite, strong) NSURL *source;
@property (readwrite, copy) NSString *messageIdentifier;

- (NSMutableDictionary *) attributes;
- (void) setAttributes:(NSDictionary *) attributes;
- (void) setAttribute:(id) object forKey:(id) key;
@end
