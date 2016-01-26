#import "JVChatTranscript.h"

NS_ASSUME_NONNULL_BEGIN

@interface JVChatSession : NSObject <JVChatTranscriptElement> {
	@protected
	struct _xmlNode *_node;
	NSScriptObjectSpecifier *_objectSpecifier;
	__weak JVChatTranscript *_transcript;
	NSDate *_startDate;
}
@property (readonly, nullable) struct _xmlNode *node;
- (nullable struct _xmlNode *) node;
@property (readonly, weak) JVChatTranscript *transcript;
@property (nullable, readonly, copy) NSDate *startDate;
@end

NS_ASSUME_NONNULL_END
