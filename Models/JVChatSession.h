#import "JVChatTranscript.h"

@interface JVChatSession : NSObject <JVChatTranscriptElement>
@property (readonly) struct _xmlNode *node;
- (struct _xmlNode *) node;
@property (readonly, weak) JVChatTranscript *transcript;
@property (readonly, copy) NSDate *startDate;
@end
