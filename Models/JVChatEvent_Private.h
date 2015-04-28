//
//  JVChatEvent_JVChatEventPrivate.h
//  Colloquy (Old)
//
//  Created by C.W. Betts on 4/7/15.
//
//

#import "JVChatEvent.h"
#include <libxml/tree.h>

@interface JVChatEvent ()

- (instancetype) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (void) _setNode:(xmlNode *) node;

@end
