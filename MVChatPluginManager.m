#import "MVChatPluginManager.h"
#import "NSNumberAdditions.h"
#import "NSMethodSignatureAdditions.h"

static MVChatPluginManager *sharedInstance = nil;
NSString *MVChatPluginManagerWillReloadPluginsNotification = @"MVChatPluginManagerWillReloadPluginsNotification";
NSString *MVChatPluginManagerDidReloadPluginsNotification = @"MVChatPluginManagerDidReloadPluginsNotification";

#pragma mark -

@implementation MVChatPluginManager
+ (MVChatPluginManager *) defaultManager {
	extern MVChatPluginManager *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

+ (NSArray *) pluginSearchPaths {
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	[paths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	return paths;
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_plugins = [[NSMutableArray array] retain];
		[self reloadPlugins];
	}
	return self;
}

- (void) dealloc {
	extern MVChatPluginManager *sharedInstance;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_plugins release];
	_plugins = nil;

	[super dealloc];
}

#pragma mark -

- (void) reloadPlugins {
	NSArray *paths = [[self class] pluginSearchPaths];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	[[NSNotificationCenter defaultCenter] postNotificationName:MVChatPluginManagerWillReloadPluginsNotification object:self];

	NSMethodSignature *signature = [NSMethodSignature methodSignatureWithReturnAndArgumentTypes:@encode( void ), nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:@selector( unload )];
	[self makePluginsPerformInvocation:invocation];

	// unload all plugins, this resets everything and purges plugins that moved since the last load
	[_plugins removeAllObjects];

	enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"bundle"] || [[file pathExtension] isEqualToString:@"plugin"] ) {
				bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]];
				if( [bundle load] && [[bundle principalClass] conformsToProtocol:@protocol( MVChatPlugin )] ) {
					id plugin = [[[[bundle principalClass] alloc] initWithManager:self] autorelease];
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
	NSMutableArray *qualified = [NSMutableArray array];
	id plugin = nil;

	while( ( plugin = [enumerator nextObject] ) )
		if( ( ! class || ( class && [plugin isKindOfClass:class] ) ) && [plugin respondsToSelector:selector] )
			[qualified addObject:plugin];

	return ( [qualified count] ? qualified : nil );
}

#pragma mark -

- (NSEnumerator *) pluginEnumerator {
	return [_plugins objectEnumerator];
}

- (NSEnumerator *) enumeratorOfPluginsThatRespondToSelector:(SEL) selector {
	return [self enumeratorOfPluginsOfClass:NULL thatRespondToSelector:selector];
}

- (NSEnumerator *) enumeratorOfPluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector {
	return [[self pluginsOfClass:class thatRespondToSelector:selector] objectEnumerator];
}

#pragma mark -

- (unsigned int) numberOfPlugins {
	return [_plugins count];
}

- (unsigned int) numberOfPluginsThatRespondToSelector:(SEL) selector {
	return [self numberOfPluginsOfClass:NULL thatRespondToSelector:selector];
}

- (unsigned int) numberOfPluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector {
	NSParameterAssert( selector != NULL );

	unsigned int ret = 0;
	NSEnumerator *enumerator = [_plugins objectEnumerator];
	id plugin = nil;

	while( ( plugin = [enumerator nextObject] ) )
		if( ( ! class || ( class && [plugin isKindOfClass:class] ) ) && [plugin respondsToSelector:selector] )
			ret++;

	return ret;
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

	NSEnumerator *enumerator = [self enumeratorOfPluginsOfClass:class thatRespondToSelector:[invocation selector]];
	id plugin = nil;

	if( ! enumerator ) return nil;

	NSMutableArray *results = [NSMutableArray array];
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