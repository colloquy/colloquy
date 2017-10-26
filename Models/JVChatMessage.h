#import "JVChatTranscript.h"
#import "KAIgnoreRule.h"

typedef NS_ENUM(OSType, JVChatMessageType) {
	JVChatMessageNormalType = 'noMt',
	JVChatMessageNoticeType = 'nTMt'
};

@interface JVChatMessage : NSObject <NSMutableCopying, JVChatTranscriptElement> {
	@public
	/* xmlNode */ void *_node;
	/* xmlDoc */ void *_doc;
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
- (/* xmlNode */ void *) node;

- (NSDate *) date;

- (NSUInteger) consecutiveOffset;

- (NSString *) senderName;
- (NSString *) senderIdentifier;
- (NSString *) senderNickname;
- (NSString *) senderHostmask;
- (NSString *) senderClass;
- (NSString *) senderBuddyIdentifier;
- (BOOL) senderIsLocalUser;

- (NSTextStorage *) body;
- (NSString *) bodyAsPlainText;
- (NSString *) bodyAsHTML;

- (BOOL) isAction;
- (BOOL) isHighlighted;
- (JVIgnoreMatchResult) ignoreStatus;
- (JVChatMessageType) type;

- (NSURL *) source;
- (JVChatTranscript *) transcript;
- (NSString *) messageIdentifier;

- (NSScriptObjectSpecifier *) objectSpecifier;
- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier;

- (NSDictionary *) attributes;
- (id) attributeForKey:(id) key;
@end

COLLOQUY_EXPORT
@interface JVMutableChatMessage : JVChatMessage {
	@protected
	id _sender;
}
+ (id) messageWithText:(id) body sender:(id) sender;
- (id) initWithText:(id) body sender:(id) sender;

- (void) setDate:(NSDate *) date;

- (id) sender;
- (void) setSender:(id) sender;

- (void) setBody:(id) message;
- (void) setBodyAsPlainText:(NSString *) message;
- (void) setBodyAsHTML:(NSString *) message;

- (void) setAction:(BOOL) action;
- (void) setHighlighted:(BOOL) highlighted;
- (void) setIgnoreStatus:(JVIgnoreMatchResult) ignoreStatus;
- (void) setType:(JVChatMessageType) type;

- (void) setSource:(NSURL *) source;
- (void) setMessageIdentifier:(NSString *) identifier;

- (NSMutableDictionary *) attributes;
- (void) setAttributes:(NSDictionary *) attributes;
- (void) setAttribute:(id) object forKey:(id) key;
@end
