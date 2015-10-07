#import "JVChatTranscript.h"

@interface JVChatSession : NSObject <JVChatTranscriptElement>
- (/* xmlNode */ void *) node;
@property (readonly, weak) JVChatTranscript *transcript;
@property (readonly, copy) NSDate *startDate;
@end
