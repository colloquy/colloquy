//
//  JVChatMessage_Private.h
//  Colloquy (Old)
//
//  Created by C.W. Betts on 4/7/15.
//
//

#import "JVChatMessage.h"
#include <libxml/tree.h>

@class JVChatTranscript;

@interface JVChatMessage ()
- (instancetype) initWithNode:(xmlNode *) node andTranscript:(JVChatTranscript *) transcript;
- (void) _setNode:(xmlNode *) node;
- (void) _loadFromXML;
- (void) _loadSenderFromXML;
- (void) _loadBodyFromXML;
@end
