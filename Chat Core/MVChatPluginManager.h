#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MVChatPluginManagerWillReloadPluginsNotification;
extern NSString *const MVChatPluginManagerDidReloadPluginsNotification;
extern NSString *const MVChatPluginManagerDidFindInvalidPluginsNotification;

@protocol MVChatPlugin;

@interface MVChatPluginManager : NSObject {
	@private
	NSMutableArray<id<MVChatPlugin>> *_plugins;
	NSMutableDictionary<NSString*,NSString*> *_invalidPlugins;
	BOOL _reloadingPlugins;
}
+ (MVChatPluginManager *) defaultManager;
+ (NSArray<NSString*> *) pluginSearchPaths;

@property(strong, readonly) NSArray<id<MVChatPlugin>> *plugins;

- (void) reloadPlugins;
- (void) addPlugin:(id <MVChatPlugin>) plugin;
- (void) removePlugin:(id <MVChatPlugin>) plugin;

- (nullable NSArray<id<MVChatPlugin>> *) pluginsThatRespondToSelector:(SEL) selector;
- (nullable NSArray<id<MVChatPlugin>> *) pluginsOfClass:(Class __nullable) class thatRespondToSelector:(SEL) selector;

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation;
- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
- (NSArray *) makePluginsOfClass:(Class __nullable) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop;
@end

@protocol MVChatPlugin <NSObject>
- (null_unspecified instancetype) initWithManager:(MVChatPluginManager *) manager;

#pragma mark MVChatPluginReloadSupport
@optional
- (void) load;
- (void) unload;
@end

NS_ASSUME_NONNULL_END
