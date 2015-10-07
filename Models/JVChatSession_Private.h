//
//  JVChatSession_Private.h
//  Colloquy (Old)
//
//  Created by C.W. Betts on 4/7/15.
//
//

#import "JVChatSession.h"
#include <libxml/tree.h>

@class JVChatTranscript;

@interface JVChatSession ()
- (instancetype) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (void) _setNode:(xmlNode *) node;
@end
