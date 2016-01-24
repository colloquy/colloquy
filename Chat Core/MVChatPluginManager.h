#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MVChatPluginManagerWillReloadPluginsNotification;
extern NSString *const MVChatPluginManagerDidReloadPluginsNotification;
extern NSString *const MVChatPluginManagerDidFindInvalidPluginsNotification;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableArray<NSBundle*> *_plugins;
	NSMutableDictionary<NSString*,NSString*> *_invalidPlugins;
	BOOL _reloadingPlugins;
}
+ (MVChatPluginManager *) defaultManager;
+ (NSArray<NSString*> *) pluginSearchPaths;

@property(strong, readonly) NSArray<NSBundle*> *plugins;

- (void) reloadPlugins;
- (void) addPlugin:(NSBundle *) plugin;
- (void) removePlugin:(NSBundle *) plugin;

- (nullable NSArray<NSBundle*> *) pluginsThatRespondToSelector:(SEL) selector;
- (nullable NSArray<NSBundle*> *) pluginsOfClass:(Class __nullable) class thatRespondToSelector:(SEL) selector;

- (NSArray<id> *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray<id> *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
- (NSArray<id> *) makePluginsOfClass:(Class __nullable) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin
- (instancetype) initWithManager:(MVChatPluginManager *) manager;

#pragma mark MVChatPluginReloadSupport
@optional
- (void) load;
- (void) unload;
@end

NS_ASSUME_NONNULL_END
