#import <Foundation/NSObject.h>
#import "MVChatPlugin.h"

@class NSString;
@class JVChatRoom;

@interface JVTunes : NSObject <MVChatPlugin> {
	NSAppleScript *_script;
}
@end
