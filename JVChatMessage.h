#import <Foundation/NSObject.h>
#import "KAIgnoreRule.h"

@class JVChatTranscript;
@class NSString;
@class NSTextStorage;
@class NSDate;
@class NSScriptObjectSpecifier;

@interface JVChatMessage : NSObject <NSMutableCopying> {
	@protected
	/* xmlNode */ void *_node;
	unsigned long long _messageNumber;
	unsigned long long _envelopeNumber;
	NSScriptObjectSpecifier *_objectSpecifier;
	JVChatTranscript *_transcript;
	id _sender;
	NSString *_htmlMessage;
	NSTextStorage *_attributedMessage;
	NSDate *_date;
	JVIgnoreMatchResult _ignoreStatus;
	BOOL _action;
	BOOL _highlighted;
	BOOL _loaded;
}
+ (id) messageWithNode:(/* xmlNode */ void *) node messageIndex:(unsigned long long) messageIndex andTranscript:(JVChatTranscript *) transcript;
- (id) initWithNode:(/* xmlNode */ void *) node messageIndex:(unsigned long long) messageIndex andTranscript:(JVChatTranscript *) transcript;

- (/* xmlNode */ void *) node;

- (NSDate *) date;
- (id) sender;

- (NSTextStorage *) body;
- (NSString *) bodyAsPlainText;
- (NSString *) bodyAsHTML;

- (BOOL) isAction;
- (BOOL) isHighlighted;
- (JVIgnoreMatchResult) ignoreStatus;

- (JVChatTranscript *) transcript;
- (unsigned long long) messageNumber;
- (unsigned long long) envelopeNumber;

- (NSScriptObjectSpecifier *) objectSpecifier;
- (void) setObjectSpecifier:(NSScriptObjectSpecifier *) objectSpecifier;
@end

@interface JVMutableChatMessage : JVChatMessage
+ (id) messageWithText:(NSTextStorage *) body sender:(NSString *) sender andTranscript:(JVChatTranscript *) transcript;
- (id) initWithText:(NSTextStorage *) body sender:(NSString *) sender andTranscript:(JVChatTranscript *) transcript;

- (void) setNode:(/* xmlNode */ void *) node;

- (void) setDate:(NSDate *) date;
- (void) setSender:(id) sender;

- (void) setBody:(NSAttributedString *) message;
- (void) setBodyAsPlainText:(NSString *) message;
- (void) setBodyAsHTML:(NSString *) message;

- (void) setAction:(BOOL) action;
- (void) setHighlighted:(BOOL) highlighted;
- (void) setIgnoreStatus:(JVIgnoreMatchResult) ignoreStatus;

- (void) setTranscript:(JVChatTranscript *) transcript;
- (void) setMessageNumber:(unsigned long long) number;
- (void) setEnvelopeNumber:(unsigned long long) number;
@end