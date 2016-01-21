#import "JVChatTranscript.h"

@interface JVChatSession : NSObject <JVChatTranscriptElement> {
	@protected
	struct _xmlNode *_node;
	NSScriptObjectSpecifier *_objectSpecifier;
	__weak JVChatTranscript *_transcript;
	NSDate *_startDate;
}
@property (readonly) struct _xmlNode *node;
- (struct _xmlNode *) node;
@property (readonly, weak) JVChatTranscript *transcript;
@property (readonly, copy) NSDate *startDate;
@end
