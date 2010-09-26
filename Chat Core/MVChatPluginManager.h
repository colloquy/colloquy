extern NSString *MVChatPluginManagerWillReloadPluginsNotification;
extern NSString *MVChatPluginManagerDidReloadPluginsNotification;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableArray *_plugins;
	BOOL _reloadingPlugins;
}
+ (MVChatPluginManager *) defaultManager;
+ (NSArray *) pluginSearchPaths;

@property(readonly) NSArray *plugins;

- (void) reloadPlugins;
- (void) addPlugin:(id) plugin;
- (void) removePlugin:(id) plugin;

- (NSArray *) pluginsThatRespondToSelector:(SEL) selector;
- (NSArray *) pluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector;

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
- (NSArray *) makePluginsOfClass:(Class) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end

@interface NSObject (MVChatPluginReloadSupport)
- (void) load;
- (void) unload;
@end
