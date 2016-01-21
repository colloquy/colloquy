#import "JVChatTranscript.h"

@interface JVChatEvent : NSObject <JVChatTranscriptElement> {
	@protected
	struct _xmlNode *_node;
	struct _xmlDoc *_doc;
	NSString *_eventIdentifier;
	NSScriptObjectSpecifier *_objectSpecifier;
	__weak JVChatTranscript *_transcript;
	NSDate *_date;
	NSString *_name;
	NSTextStorage *_message;
	NSDictionary *_attributes;
	BOOL _loadedMessage;
	BOOL _loadedAttributes;
	BOOL _loadedSmall;
}
- (/* xmlNode */ void *) node;

@property (readonly, weak) JVChatTranscript *transcript;
@property (readonly, copy) NSString *eventIdentifier;

@property (readonly, strong) NSDate *date;
@property (readonly, copy) NSString *name;

- (NSTextStorage *) message;
@property (readonly, copy) NSString *messageAsPlainText;
@property (readonly, copy) NSString *messageAsHTML;

@property (readonly, copy) NSDictionary *attributes;
@end

@interface JVMutableChatEvent : JVChatEvent
+ (instancetype) chatEventWithName:(NSString *) name andMessage:(id) message;
- (instancetype) initWithName:(NSString *) name andMessage:(id) message;

@property (readwrite, strong) NSDate *date;
@property (readwrite, copy) NSString *name;

- (void) setMessage:(id) message;
@property (readwrite, copy) NSString *messageAsPlainText;
@property (readwrite, copy) NSString *messageAsHTML;

@property (readwrite, copy) NSDictionary *attributes;

@property (readwrite, copy) NSString *eventIdentifier;
@end
