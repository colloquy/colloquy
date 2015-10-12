NS_ASSUME_NONNULL_BEGIN

extern NSString *const MVChatPluginManagerWillReloadPluginsNotification;
extern NSString *const MVChatPluginManagerDidReloadPluginsNotification;
extern NSString *const MVChatPluginManagerDidFindInvalidPluginsNotification;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableArray *_plugins;
	NSMutableDictionary *_invalidPlugins;
	BOOL _reloadingPlugins;
}
+ (MVChatPluginManager *) defaultManager;
+ (NSArray<NSString*> *) pluginSearchPaths;

@property(strong, readonly) NSArray<NSBundle*> *plugins;

- (void) reloadPlugins;
- (void) addPlugin:(id) plugin;
- (void) removePlugin:(id) plugin;

- (nullable NSArray<NSBundle*> *) pluginsThatRespondToSelector:(SEL) selector;
- (nullable NSArray<NSBundle*> *) pluginsOfClass:(Class __nullable) class thatRespondToSelector:(SEL) selector;

- (NSArray<id> *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray<id> *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
- (NSArray<id> *) makePluginsOfClass:(Class __nullable) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin
- (instancetype) initWithManager:(MVChatPluginManager *) manager;

@optional
- (void) load;
- (void) unload;
@end

NS_ASSUME_NONNULL_END
