#import <Foundation/Foundation.h>

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableDictionary *_plugins;
}
+ (MVChatPluginManager *) defaultManager;

- (NSSet *) plugins;
- (NSSet *) pluginsThatRespondToSelector:(SEL) selector;
- (NSEnumerator *) pluginEnumerator;
@end
