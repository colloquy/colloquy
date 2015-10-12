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
@property (readwrite, setter=_setNode:) xmlNode *node;

- (instancetype) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;

@end
