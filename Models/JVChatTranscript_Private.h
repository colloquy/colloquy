//
//  JVChatTranscript_Private.h
//  Colloquy (Old)
//
//  Created by C.W. Betts on 4/7/15.
//
//

#import "JVChatTranscript.h"

@class JVChatMessage;

@interface JVChatTranscript ()
- (void) _loadMessage:(JVChatMessage *) message;
- (void) _loadSenderForMessage:(JVChatMessage *) message;
- (void) _loadBodyForMessage:(JVChatMessage *) message;
@end
