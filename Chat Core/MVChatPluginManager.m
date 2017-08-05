#import "MVChatPluginManager.h"
#import "NSFileManagerAdditions.h"
#import "NSMethodSignatureAdditions.h"
#import "NSNotificationAdditions.h"
#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"

NS_ASSUME_NONNULL_BEGIN

static MVChatPluginManager *sharedInstance = nil;
NSString *const MVChatPluginManagerWillReloadPluginsNotification = @"MVChatPluginManagerWillReloadPluginsNotification";
NSString *const MVChatPluginManagerDidReloadPluginsNotification = @"MVChatPluginManagerDidReloadPluginsNotification";
NSString *const MVChatPluginManagerDidFindInvalidPluginsNotification = @"MVChatPluginManagerDidFindInvalidPluginsNotification";

#pragma mark -

@implementation MVChatPluginManager
+ (MVChatPluginManager *) defaultManager {
	if( ! sharedInstance ) {
		sharedInstance = [self alloc];
		sharedInstance = [sharedInstance init];
	}

	return sharedInstance;
}

+ (NSArray *) pluginSearchPaths {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSArray *appSupports = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask & ~NSSystemDomainMask];
	NSMutableArray<NSString*> *paths = [[NSMutableArray alloc] initWithCapacity:appSupports.count + 2];
	for (NSURL *support in appSupports) {
		NSString *newDir = [support path];
		newDir = [newDir stringByAppendingPathComponent:bundleName];
		newDir = [newDir stringByAppendingPathComponent:@"PlugIns"];
		[paths addObject:newDir];
	}
	[paths addObject:[[NSBundle bundleForClass:[self class]] builtInPlugInsPath]];
	if( ! [[NSBundle mainBundle] isEqual:[NSBundle bundleForClass:[self class]]] )
		[paths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	return paths;
}

#pragma mark -

- (instancetype) init {
	if( ! ( self = [super init] ) )
		return nil;

	_plugins = [[NSMutableArray alloc] init];
	_invalidPlugins = [[NSMutableDictionary alloc] init];
	[self reloadPlugins];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( applicationWillTerminate: ) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];

	return self;
}

#pragma mark -

- (void) reloadPlugins {
	if( _reloadingPlugins ) return;
	_reloadingPlugins = YES;

	[[NSNotificationCenter chatCenter] postNotificationName:MVChatPluginManagerWillReloadPluginsNotification object:self];

	if( _plugins.count ) {
		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setSelector:@selector( unload )];
		[self makePluginsPerformInvocation:invocation];

		// unload all plugins, this resets everything and purges plugins that moved since the last load
		[_plugins removeAllObjects];
	}

	NSMutableArray *invalidPluginList = [[NSMutableArray alloc] init];
	for( NSString *path in [[self class] pluginSearchPaths] ) {
		for( NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] ) {
			if( [[file pathExtension] isEqualToString:@"bundle"] || [[file pathExtension] isEqualToString:@"plugin"] ) {
				NSBundle *bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]];
				NSString *bundleIdentifier = [bundle infoDictionary][@"CFBundleIdentifier"];
				NSString *previousPluginVersion = _invalidPlugins[bundleIdentifier];
				NSString *pluginVersion = [bundle infoDictionary][@"CFBundleVersion"];

				if( pluginVersion.length ) {
					if( [previousPluginVersion isCaseInsensitiveEqualToString:pluginVersion] )
						continue;
					else [_invalidPlugins removeObjectForKey:bundleIdentifier];
				}

				if( ![[NSFileManager defaultManager] canExecutePluginAtPath:bundle.executablePath] ) {
					[invalidPluginList addObject:[path stringByAppendingPathComponent:file]];

					_invalidPlugins[bundleIdentifier] = pluginVersion;

					continue;
				}

				if( [bundle load] && [[bundle principalClass] conformsToProtocol:@protocol( MVChatPlugin )] ) {
					id plugin = [[[bundle principalClass] alloc] initWithManager:self];
					if( plugin ) [self addPlugin:plugin];
				}
			}
		}
	}

	if (invalidPluginList.count) [[NSNotificationCenter chatCenter] postNotificationName:MVChatPluginManagerDidFindInvalidPluginsNotification object:invalidPluginList];
	[[NSNotificationCenter chatCenter] postNotificationName:MVChatPluginManagerDidReloadPluginsNotification object:self];

	_reloadingPlugins = NO;
}

- (void) addPlugin:(id<MVChatPlugin>) plugin {
	if( plugin ) {
		[_plugins addObject:plugin];
		if( [plugin respondsToSelector:@selector( load )] )
			[plugin load];
	}
}

- (void) removePlugin:(id<MVChatPlugin>) plugin {
	if( plugin ) {
		if( [plugin respondsToSelector:@selector( unload )] )
			[plugin unload];
		[_plugins removeObject:plugin];
	}
}

- (void) applicationWillTerminate:(NSNotification *) notification {
	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( unload )];
	[self makePluginsPerformInvocation:invocation];
	[_plugins removeAllObjects];
}

#pragma mark -

- (NSArray *) plugins {
	return [_plugins copy];
}

- (nullable NSArray *) pluginsThatRespondToSelector:(SEL) selector {
	return [self pluginsOfClass:NULL thatRespondToSelector:selector];
}

- (nullable NSArray *) pluginsOfClass:(Class __nullable) class thatRespondToSelector:(SEL) selector {
	NSParameterAssert( selector != NULL );

	NSMutableArray *qualified = [[NSMutableArray alloc] init];

	for( id plugin in _plugins )
		if( ( ! class || ( class && [plugin isKindOfClass:class] ) ) && [plugin respondsToSelector:selector] )
			[qualified addObject:plugin];

	return ( qualified.count ? qualified : @[] );
}

#pragma mark -

- (nullable NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation {
	return [self makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (nullable NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop {
	return [self makePluginsOfClass:NULL performInvocation:invocation stoppingOnFirstSuccessfulReturn:stop];
}

- (nullable NSArray *) makePluginsOfClass:(Class __nullable) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop {
	NSParameterAssert( invocation != nil );
	NSParameterAssert( [invocation selector] != NULL );

	NSArray *plugins = [self pluginsOfClass:class thatRespondToSelector:[invocation selector]];

	if( ! plugins ) return nil;

	NSMutableArray *results = [[NSMutableArray alloc] init];
	NSMethodSignature *sig = [invocation methodSignature];

	for ( id<MVChatPlugin> plugin in plugins ) {
		@try {
			[invocation invokeWithTarget:plugin];
		} @catch ( NSException *exception ) {
			NSString *pluginName = [[NSBundle bundleForClass:[plugin class]] objectForInfoDictionaryKey:@"CFBundleName"];
			NSLog( @"An error occured when calling %@ of plugin %@. %@.", NSStringFromSelector( [invocation selector] ), pluginName, [exception reason] );
			continue;
		}

		if( ! strcmp( [sig methodReturnType], @encode( id ) ) ) {
			__unsafe_unretained id ret = nil;
			[invocation getReturnValue:&ret];
			if( ret ) [results addObject:ret];
			else [results addObject:[NSNull null]];
			if( stop && ret ) return results;
		} else {
			void *ret = ( [sig methodReturnLength] ? malloc( [sig methodReturnLength] ) : NULL );
			if( ret ) {
				[invocation getReturnValue:ret];
				id res = [NSNumber numberWithBytes:ret objCType:[sig methodReturnType]];
				if( ! res ) res = [NSValue valueWithBytes:ret objCType:[sig methodReturnType]];
				free( ret );
				[results addObject:res];
				if( [res isKindOfClass:[NSNumber class]] && stop && [res boolValue] ) return results;
			} else if( results.count ) [results addObject:[NSNull null]];
		}
	}

	return results;
}
@end

NS_ASSUME_NONNULL_END

#pragma mark -

@interface MVReloadPluginsScriptCommand : NSScriptCommand {}
@end

#pragma mark -

@implementation MVReloadPluginsScriptCommand
- (id) performDefaultImplementation {
	[[MVChatPluginManager defaultManager] reloadPlugins];
	return nil;
}
@end
