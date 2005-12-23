#import "JVChatTranscript.h"

@interface JVChatEvent : NSObject <JVChatTranscriptElement> {
	@protected
	/* xmlNode */ void *_node;
	NSString *_eventIdentifier;
	NSScriptObjectSpecifier *_objectSpecifier;
	JVChatTranscript *_transcript;
	NSDate *_date;
	NSString *_name;
	NSTextStorage *_message;
	NSDictionary *_attributes;
	BOOL _loadedMessage;
	BOOL _loadedAttributes;
	BOOL _loadedSmall;
}
- (/* xmlNode */ void *) node;

- (JVChatTranscript *) transcript;
- (NSString *) eventIdentifier;

- (NSDate *) date;
- (NSString *) name;

- (NSTextStorage *) message;
- (NSString *) messageAsPlainText;
- (NSString *) messageAsHTML;

- (NSDictionary *) attributes;
@end

@interface JVMutableChatEvent : JVChatEvent {
	@protected
	/* xmlDoc */ void *_doc;
}
+ (id) chatEventWithName:(NSString *) name andMessage:(id) message;
- (id) initWithName:(NSString *) name andMessage:(id) message;

- (void) setDate:(NSDate *) date;
- (void) setName:(NSString *) name;

- (void) setMessage:(id) message;
- (void) setMessageAsPlainText:(NSString *) message;
- (void) setMessageAsHTML:(NSString *) message;

- (void) setAttributes:(NSDictionary *) attributes;

- (void) setEventIdentifier:(NSString *) identifier;
@end