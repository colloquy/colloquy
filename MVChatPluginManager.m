#import "MVChatPluginManager.h"
#import "MVChatScriptPlugin.h"
#import "NSNumberAdditions.h"
#import "NSMethodSignatureAdditions.h"

static MVChatPluginManager *sharedInstance = nil;

#pragma mark -

@implementation MVChatPluginManager
+ (MVChatPluginManager *) defaultManager {
	extern MVChatPluginManager *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_plugins = [[NSMutableDictionary dictionary] retain];
		[self findAndLoadPlugins];
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

- (NSArray *) pluginSearchPaths {
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	[paths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	return paths;
}

- (void) findAndLoadPlugins {
	NSArray *paths = [self pluginSearchPaths];
	NSEnumerator *enumerator = nil, *denumerator = nil;
	NSString *file = nil, *path = nil;
	NSBundle *bundle = nil;

	// unload all plugins, this resets everything and purges plugins that moved since the last load
	[_plugins removeAllObjects];

	enumerator = [paths objectEnumerator];
	while( ( path = [enumerator nextObject] ) ) {
		denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] isEqualToString:@"bundle"] || [[file pathExtension] isEqualToString:@"plugin"] ) {
				bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]];
				if( ! [_plugins objectForKey:[bundle bundleIdentifier]] && [bundle load] && [[bundle principalClass] conformsToProtocol:@protocol( MVChatPlugin )] ) {
					id plugin = [[[[bundle principalClass] alloc] initWithManager:self] autorelease];
					if( plugin ) [_plugins setObject:plugin forKey:[bundle bundleIdentifier]];
				}
			} else if( [[file pathExtension] isEqualToString:@"scpt"] || [[file pathExtension] isEqualToString:@"applescript"] ) {
				NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", path, file]] error:NULL] autorelease];
				if( ! [script compileAndReturnError:nil] ) continue;
				MVChatScriptPlugin *plugin = [[[MVChatScriptPlugin alloc] initWithScript:script andManager:self] autorelease];
				if( plugin ) [_plugins setObject:plugin forKey:[script scriptIdentifier]];
			}
		}
	}
}

#pragma mark -

- (NSSet *) plugins {
	return [NSSet setWithArray:[_plugins allValues]];
}

- (NSSet *) pluginsThatRespondToSelector:(SEL) selector {
	return [self pluginsOfClass:NULL thatRespondToSelector:selector];
}

- (NSSet *) pluginsOfClass:(Class) class thatRespondToSelector:(SEL) selector {
	NSParameterAssert( selector != NULL );

	NSEnumerator *enumerator = [_plugins objectEnumerator];
	NSMutableSet *qualified = [NSMutableSet set];
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
			NSLog( @"An error occured when calling %@ of plugin %@. %@.", NSStringFromSelector( [invocation selector] ), pluginName, [exception reason] );
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