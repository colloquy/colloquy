@interface MVChatPluginManager : NSObject {
	@private
	NSMutableArray *_plugins;
}
+ (MVChatPluginManager *) defaultManager;
+ (NSArray *) pluginSearchPaths;

- (void) findAndLoadPlugins;

- (NSArray *) plugins;
- (NSArray *) pluginsThatRespondToSelector:(SEL) selector;
- (NSArray *) pluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector;

- (NSEnumerator *) pluginEnumerator;
- (NSEnumerator *) enumeratorOfPluginsThatRespondToSelector:(SEL) selector;
- (NSEnumerator *) enumeratorOfPluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector;

- (unsigned int) numberOfPlugins;
- (unsigned int) numberOfPluginsThatRespondToSelector:(SEL) selector;
- (unsigned int) numberOfPluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector;

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
- (NSArray *) makePluginsOfClass:(Class) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end
