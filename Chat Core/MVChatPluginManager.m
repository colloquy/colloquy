#import "MVChatPluginManager.h"
#import "NSNumberAdditions.h"
#import "NSMethodSignatureAdditions.h"

static MVChatPluginManager *sharedInstance = nil;
NSString *MVChatPluginManagerWillReloadPluginsNotification = @"MVChatPluginManagerWillReloadPluginsNotification";
NSString *MVChatPluginManagerDidReloadPluginsNotification = @"MVChatPluginManagerDidReloadPluginsNotification";

#pragma mark -

@implementation MVChatPluginManager
+ (MVChatPluginManager *) defaultManager {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self allocWithZone:nil] init] ) );
}

+ (NSArray *) pluginSearchPaths {
	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSMutableArray *paths = [[NSMutableArray allocWithZone:nil] initWithCapacity:5];

	BOOL directory = NO;
	NSString *pluginsPath = [[NSString stringWithFormat:@"~/Library/Application Support/%@/Plugins", bundleName] stringByExpandingTildeInPath];
	if( [[NSFileManager defaultManager] fileExistsAtPath:pluginsPath isDirectory:&directory] && directory )
		[paths addObject:pluginsPath];
	else [paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/PlugIns", bundleName] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/PlugIns", bundleName]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/PlugIns", bundleName]];
	[paths addObject:[[NSBundle bundleForClass:[self class]] builtInPlugInsPath]];
	if( ! [[NSBundle mainBundle] isEqual:[NSBundle bundleForClass:[self class]]] )
		[paths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	return [paths autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_plugins = [[NSMutableArray allocWithZone:nil] init];
		[self reloadPlugins];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( applicationWillTerminate: ) name:NSApplicationWillTerminateNotification object:[NSApplication sharedApplication]];
	}
	return self;
}

- (void) finalize {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;
	[super finalize];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_plugins release];
	_plugins = nil;

	[super dealloc];
}

#pragma mark -

- (void) reloadPlugins {
	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatPluginManagerWillReloadPluginsNotification object:self];

	if( [_plugins count] ) {
		NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), nil];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
		[invocation setSelector:@selector( unload )];
		[self makePluginsPerformInvocation:invocation];

		// unload all plugins, this resets everything and purges plugins that moved since the last load
		[_plugins removeAllObjects];
	}

	NSArray *paths = [[self class] pluginSearchPaths];
	NSEnumerator *enumerator = [paths objectEnumerator];
	NSString *file = nil, *path = nil;

	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"bundle"] || [[file pathExtension] isEqualToString:@"plugin"] ) {
				NSBundle *bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]];
				if( [bundle load] && [[bundle principalClass] conformsToProtocol:@protocol( MVChatPlugin )] ) {
					id plugin = [[[[bundle principalClass] allocWithZone:nil] initWithManager:self] autorelease];
					if( plugin ) [self addPlugin:plugin];
				}
			}
		}
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatPluginManagerDidReloadPluginsNotification object:self];
}

- (void) addPlugin:(id) plugin {
	if( plugin ) {
		[_plugins addObject:plugin];
		if( [plugin respondsToSelector:@selector( load )] )
			[plugin performSelector:@selector( load )];
	}
}

- (void) removePlugin:(id) plugin {
	if( plugin ) {
		if( [plugin respondsToSelector:@selector( unload )] )
			[plugin performSelector:@selector( unload )];
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
	return [NSArray arrayWithArray:_plugins];
}

- (NSArray *) pluginsThatRespondToSelector:(SEL) selector {
	return [self pluginsOfClass:NULL thatRespondToSelector:selector];
}

- (NSArray *) pluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector {
	NSParameterAssert( selector != NULL );

	NSEnumerator *enumerator = [_plugins objectEnumerator];
	NSMutableArray *qualified = [[[NSMutableArray allocWithZone:nil] init] autorelease];
	id plugin = nil;

	while( ( plugin = [enumerator nextObject] ) )
		if( ( ! class || ( class && [plugin isKindOfClass:class] ) ) && [plugin respondsToSelector:selector] )
			[qualified addObject:plugin];

	return ( [qualified count] ? qualified : nil );
}

#pragma mark -

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation {
	return [self makePluginsPerformInvocation:invocation stoppingOnFirstSuccessfulReturn:NO];
}

- (NSArray *) makePluginsPerformInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop {
	return [self makePluginsOfClass:NULL performInvocation:invocation stoppingOnFirstSuccessfulReturn:stop];
}

- (NSArray *) makePluginsOfClass:(Class) class performInvocation:(NSInvocation *) invocation stoppingOnFirstSuccessfulReturn:(BOOL) stop {
	NSParameterAssert( invocation != nil );
	NSParameterAssert( [invocation selector] != NULL );

	NSEnumerator *enumerator = [[self pluginsOfClass:class thatRespondToSelector:[invocation selector]] objectEnumerator];
	id plugin = nil;

	if( ! enumerator ) return nil;

	NSMutableArray *results = [[[NSMutableArray allocWithZone:nil] init] autorelease];
	NSMethodSignature *sig = [invocation methodSignature];

	while( ( plugin = [enumerator nextObject] ) ) {
		@try {
			[invocation invokeWithTarget:plugin];
		} @catch ( NSException *exception ) {
			NSString *pluginName = [[NSBundle bundleForClass:[plugin class]] objectForInfoDictionaryKey:@"CFBundleName"];
			NSString *reason = [NSString stringWithFormat:@"An error occured when calling %@ of plugin %@. %@.", NSStringFromSelector( [invocation selector] ), pluginName, [exception reason]];
			NSException *new = [NSException exceptionWithName:@"MVChatPluginError" reason:reason userInfo:[exception userInfo]];
			@throw new;
			continue;
		}

		if( ! strcmp( [sig methodReturnType], @encode( id ) ) ) {
			id ret = nil;
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
			} else if( [results count] ) [results addObject:[NSNull null]];
		}
	}

	return results;
}
@end

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
