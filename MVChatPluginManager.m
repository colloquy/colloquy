#import <Foundation/Foundation.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatPluginManager.h>
#import <ChatCore/MVChatPlugin.h>

static MVChatPluginManager *sharedInstance = nil;

@implementation MVChatPluginManager
+ (MVChatPluginManager *) defaultManager {
	extern MVChatPluginManager *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
		NSEnumerator *enumerator = nil, *denumerator = nil;
		NSString *file = nil, *path = nil;
		NSBundle *bundle = nil;

		[paths addObject:[[NSBundle mainBundle] builtInPlugInsPath]];
		[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath]];
		[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
		[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/PlugIns", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];

		_plugins = [[NSMutableDictionary dictionary] retain];

		enumerator = [paths objectEnumerator];
		while( ( path = [enumerator nextObject] ) ) {
			denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
			while( ( file = [denumerator nextObject] ) ) {
				if( [[file pathExtension] isEqualToString:@"bundle"] || [[file pathExtension] isEqualToString:@"plugin"] ) {
					bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]];
					if( ! [_plugins objectForKey:[bundle bundleIdentifier]] && [bundle load] && [[bundle principalClass] conformsToProtocol:@protocol( MVChatPlugin )] ) {
						id plugin = [[[[bundle principalClass] alloc] initWithManager:self] autorelease];
						[_plugins setObject:plugin forKey:[bundle bundleIdentifier]];
					}
				}
			}
		}
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

- (NSSet *) plugins {
	return [[[NSSet setWithArray:[_plugins allValues]] retain] autorelease];
}

- (NSSet *) pluginsThatRespondToSelector:(SEL) selector {
	NSEnumerator *enumerator = [self pluginEnumerator];
	NSMutableSet *qualified = [NSMutableSet set];
	id plugin = nil;

	while( ( plugin = [enumerator nextObject] ) ) {
		if( [plugin respondsToSelector:selector] )
			[qualified addObject:plugin];
	}

	return [[qualified retain] autorelease];
}

- (NSEnumerator *) pluginEnumerator {
	return [[[_plugins objectEnumerator] retain] autorelease];
}
@end
