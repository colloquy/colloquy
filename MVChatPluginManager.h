#import <Foundation/NSObject.h>
#import <Foundation/NSMethodSignature.h>

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
- (NSEnumerator *) enumeratorOfPluginsThatRespondToSelector:(SEL) selector;

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end
