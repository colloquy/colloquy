#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSSet;
@class NSEnumerator;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableDictionary *_plugins;
}
+ (MVChatPluginManager *) defaultManager;

- (NSSet *) plugins;
- (NSSet *) pluginsThatRespondToSelector:(SEL) selector;
- (NSEnumerator *) pluginEnumerator;
@end
