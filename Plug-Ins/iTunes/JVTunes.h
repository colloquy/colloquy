#import <Foundation/NSObject.h>
#import "MVChatPlugin.h"

@class NSString;

@interface JVTunes : NSObject <MVChatPlugin> {
	NSString *_script;
}
+ (NSString *) executeAppleScriptString:(NSString *) string;	
@end
