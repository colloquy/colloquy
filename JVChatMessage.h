#import <Foundation/NSObject.h>

@class JVChatTranscript;

@interface JVChatMessage : NSObject {
	@protected
	/* xmlNodePtr */ void *_node;
	unsigned long _messageNumber;
	JVChatTranscript *_transcript;
	NSString *_sender;
	NSString *_htmlMessage;
	NSTextStorage *_attributedMessage;
	NSDate *_date;
	BOOL _action;
	BOOL _highlighted;
	BOOL _loaded;
}
+ (id) messageWithNode:(/* xmlNode */ void *) node andTranscript:(JVChatTranscript *) transcript;
- (id) initWithNode:(/* xmlNode */ void *) node andTranscript:(JVChatTranscript *) transcript;

- (NSDate *) date;
- (NSString *) sender;

- (NSTextStorage *) message;
- (NSString *) messageAsPlainText;
- (NSString *) messageAsHTML;

- (BOOL) isAction;
- (BOOL) isHighlighted;

- (JVChatTranscript *) transcript;
- (unsigned long) messageNumber;
@end
