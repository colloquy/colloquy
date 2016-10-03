#import <Foundation/Foundation.h>

#import "JVChatTranscript.h"
#import "KAIgnoreRule.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(OSType, JVChatMessageType) {
	JVChatMessageNormalType = 'noMt',
	JVChatMessageNoticeType = 'nTMt'
};

@interface JVChatMessage : NSObject <NSMutableCopying, JVChatTranscriptElement> {
	@public
	struct _xmlNode *_node;
	struct _xmlDoc *_doc;
	NSString *_messageIdentifier;
	NSScriptObjectSpecifier *_objectSpecifier;
	__weak JVChatTranscript *_transcript;

	id _senderIdentifier;
	NSString *_senderName;
	NSString *_senderNickname;
	NSString *_senderHostmask;
	NSString *_senderClass;
	NSString *_senderBuddyIdentifier;

	NSTextStorage *_attributedMessage;
	NSDate *_date;
	NSURL *_source;
	JVIgnoreMatchResult _ignoreStatus;
	JVChatMessageType _type;
	NSUInteger _consecutiveOffset;
	BOOL _senderIsLocalUser;
	BOOL _action;
	BOOL _highlighted;
	BOOL _loaded;
	BOOL _bodyLoaded;
	BOOL _senderLoaded;
	NSMutableDictionary *_attributes;
}
@property (readonly, nullable) struct _xmlNode *node;

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

@property (strong, nullable) NSScriptObjectSpecifier *objectSpecifier;

- (NSDictionary<NSString*,id> *) attributes;
- (nullable id) attributeForKey:(id) key;
@end

@interface JVMutableChatMessage : JVChatMessage {
	@protected
	id _sender;
}
+ (instancetype) messageWithText:(id) body sender:(nullable id) sender;
- (instancetype) initWithText:(id) body sender:(nullable id) sender;

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

- (NSMutableDictionary<NSString*,id> *) attributes;
- (void) setAttributes:(NSDictionary<NSObject*,id> *) attributes;
- (void) setAttribute:(id) object forKey:(id) key;
@end

NS_ASSUME_NONNULL_END
