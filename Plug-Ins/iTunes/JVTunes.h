#import <Foundation/NSObject.h>
#import "MVChatPlugin.h"

@class NSString;

@interface JVTunes : NSObject <MVChatPlugin> {
	NSString *_script;
	MVChatPluginManager* _manager;
}
+ (NSString *) executeAppleScriptString:(NSString *) string;	
@end
