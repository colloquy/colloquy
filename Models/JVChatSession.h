#import "JVChatTranscript.h"

@interface JVChatSession : NSObject <JVChatTranscriptElement> {
	@protected
	struct _xmlNode *_node;
	NSScriptObjectSpecifier *_objectSpecifier;
	__weak JVChatTranscript *_transcript;
	NSDate *_startDate;
}
- (struct _xmlNode *) node;
- (JVChatTranscript *) transcript;
- (NSDate *) startDate;
@end
