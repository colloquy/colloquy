#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSArray;
@class NSSet;
@class NSEnumerator;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableDictionary *_plugins;
}
+ (MVChatPluginManager *) defaultManager;

- (NSArray *) pluginSearchPaths;
- (void) findAndLoadPlugins;

- (NSSet *) plugins;
- (NSSet *) pluginsThatRespondToSelector:(SEL) selector;
- (NSEnumerator *) pluginEnumerator;
@end

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end