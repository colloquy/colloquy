NS_ASSUME_NONNULL_BEGIN

extern NSString *MVChatPluginManagerWillReloadPluginsNotification;
extern NSString *MVChatPluginManagerDidReloadPluginsNotification;
extern NSString *MVChatPluginManagerDidFindInvalidPluginsNotification;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableArray *_plugins;
	NSMutableDictionary *_invalidPlugins;
	BOOL _reloadingPlugins;
}
+ (MVChatPluginManager *) defaultManager;
+ (NSArray *) pluginSearchPaths;

@property(strong, readonly) NSArray *plugins;

- (void) reloadPlugins;
- (void) addPlugin:(id) plugin;
- (void) removePlugin:(id) plugin;

- (NSArray *) pluginsThatRespondToSelector:(SEL) selector;
- (NSArray *) pluginsOfClass:(Class __nullable) class thatRespondToSelector:(SEL) selector;

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
- (NSArray *) makePluginsOfClass:(Class __nullable) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin
- (id) initWithManager:(MVChatPluginManager *) manager;
@end

@interface NSObject (MVChatPluginReloadSupport)
- (void) load;
- (void) unload;
@end

NS_ASSUME_NONNULL_END
