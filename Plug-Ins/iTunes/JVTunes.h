#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import "MVChatPlugin.h"

@interface JVTunes : NSObject <MVChatPlugin> {
	NSString *_script;
}
+ (NSString *) executeAppleScriptString:(NSString *) aString;	
@end
