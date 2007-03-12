#import "JVEmoticonSet.h"
#import "NSBundleAdditions.h"

@interface JVEmoticonSet (JVEmoticonSetPrivate)
- (void) _setBundle:(NSBundle *) bundle;
@end

#pragma mark -

static NSMutableSet *allEmoticonSets = nil;

NSString *JVEmoticonSetsScannedNotification = @"JVEmoticonSetsScannedNotification";

@implementation JVEmoticonSet
+ (void) scanForEmoticonSets {
	NSMutableSet *styles = [NSMutableSet set];
	if( ! allEmoticonSets ) allEmoticonSets = [styles retain];

	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:5];
	[paths addObject:[NSString stringWithFormat:@"%@/Emoticons", [[NSBundle bundleForClass:[self class]] resourcePath]]];
	if( ! [[NSBundle mainBundle] isEqual:[NSBundle bundleForClass:[self class]]] )
		[paths addObject:[NSString stringWithFormat:@"%@/Emoticons", [[NSBundle mainBundle] resourcePath]]];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Emoticons", bundleName] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/Emoticons", bundleName]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/Emoticons", bundleName]];

	NSEnumerator *enumerator = [paths objectEnumerator];
	NSString *path = nil;
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *file = nil;
		while( ( file = [denumerator nextObject] ) ) {
			NSString *fullPath = [path stringByAppendingPathComponent:file];
			NSDictionary *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:fullPath traverseLink:YES];
			if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:fullPath] && */ ( [[file pathExtension] caseInsensitiveCompare:@"colloquyEmoticons"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coEm' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
				NSBundle *bundle = nil;
				JVEmoticonSet *emoticon = nil;
				if( ( bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]] ) ) {
					if( ( emoticon = [[JVEmoticonSet newWithBundle:bundle] autorelease] ) ) [styles addObject:emoticon];
				}
			}
		}
	}

	[allEmoticonSets intersectSet:styles];

	[[NSNotificationCenter defaultCenter] postNotificationName:JVEmoticonSetsScannedNotification object:allEmoticonSets];
}

+ (NSSet *) emoticonSets {
	return allEmoticonSets;
}

+ (id) emoticonSetWithIdentifier:(NSString *) identifier {
	if( [identifier isEqualToString:@"cc.javelin.colloquy.emoticons.text-only"] )
		return [self textOnlyEmoticonSet];

	NSEnumerator *enumerator = [allEmoticonSets objectEnumerator];
	JVEmoticonSet *emoticon = nil;

	while( ( emoticon = [enumerator nextObject] ) )
		if( [[emoticon identifier] isEqualToString:identifier] )
			return emoticon;

	NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
	if( bundle ) return [[[JVEmoticonSet alloc] initWithBundle:bundle] autorelease];

	return nil;
}

+ (id) newWithBundle:(NSBundle *) bundle {
	id ret = [[self emoticonSetWithIdentifier:[bundle bundleIdentifier]] retain];
	if( ! ret ) ret = [[JVEmoticonSet alloc] initWithBundle:bundle];
	return ret;
}

+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[self scanForEmoticonSets];
		tooLate = YES;
	}
}

#pragma mark -

+ (id) textOnlyEmoticonSet {
	static JVEmoticonSet *ret = nil;
	if( ! ret ) {
		ret = [[JVEmoticonSet alloc] initWithBundle:[NSBundle mainBundle]];
		[allEmoticonSets removeObject:ret];
	}

	return ret;
}

#pragma mark -

- (id) initWithBundle:(NSBundle *) bundle {
	if( ! bundle ) {
		[self release];
		return nil;
	}

	if( ( self = [self init] ) ) {
		[allEmoticonSets addObject:self];

		_bundle = nil;
		[self _setBundle:bundle];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self _setBundle:nil]; // this will dealloc all other dependant objects
	[self unlink];
	[super dealloc];
}

#pragma mark -

- (void) unlink {
	[allEmoticonSets removeObject:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:JVEmoticonSetsScannedNotification object:allEmoticonSets];
}

- (BOOL) isCompliant {
	BOOL ret = YES;

	if( ! [[self displayName] length] ) ret = NO;
	if( ! [[[self bundle] pathForResource:@"emoticons" ofType:@"css"] length] ) ret = NO;
	if( ! [[[self bundle] bundleIdentifier] length] ) ret = NO;

	return ret;
}

#pragma mark -

- (void) performEmoticonSubstitution:(NSMutableAttributedString *) string {
	if( ! [string length] ) return;

	NSCharacterSet *escapeSet = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	NSEnumerator *keyEnumerator = [[self emoticonMappings] keyEnumerator];
	NSEnumerator *objEnumerator = [[self emoticonMappings] objectEnumerator];
	NSEnumerator *srcEnumerator = nil;
	NSString *str = nil;
	NSString *key = nil;
	NSArray *obj = nil;

	while( ( key = [keyEnumerator nextObject] ) && ( obj = [objEnumerator nextObject] ) ) {
		srcEnumerator = [obj objectEnumerator];
		while( ( str = [srcEnumerator nextObject] ) ) {
			NSMutableString *search = [str mutableCopy];
			[search escapeCharactersInSet:escapeSet];

			AGRegex *regex = [[AGRegex alloc] initWithPattern:[NSString stringWithFormat:@"(?<=\\s|^)%@(?=\\s|$)", search]];
			NSArray *matches = [regex findAllInString:[string string]];
			NSEnumerator *enumerator = [matches objectEnumerator];
			AGRegexMatch *match = nil;

			while( ( match = [enumerator nextObject] ) ) {
				NSRange foundRange = [match range];
				NSString *startHTML = [string attribute:@"XHTMLStart" atIndex:foundRange.location effectiveRange:NULL];
				NSString *endHTML = [string attribute:@"XHTMLEnd" atIndex:foundRange.location effectiveRange:NULL];
				if( ! startHTML ) startHTML = @"";
				if( ! endHTML ) endHTML = @"";
				[string addAttribute:@"XHTMLStart" value:[startHTML stringByAppendingFormat:@"<span class=\"emoticon %@\"><samp>", key] range:foundRange];
				[string addAttribute:@"XHTMLEnd" value:[@"</samp></span>" stringByAppendingString:endHTML] range:foundRange];
			}

			[search release];
			[regex release];
		}
	}
}

#pragma mark -

- (NSBundle *) bundle {
	return _bundle;
}

- (NSString *) identifier {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] )
		return @"cc.javelin.colloquy.emoticons.text-only";
	return [[self bundle] bundleIdentifier];
}

#pragma mark -

- (NSComparisonResult) compare:(JVEmoticonSet *) emoticon {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] )
		return NSOrderedAscending;
	return [[self bundle] compare:[emoticon bundle]];
}

- (NSString *) displayName {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] )
		return NSLocalizedString( @"Text Only", "text only emoticons display name" );
	return [[self bundle] displayName];
}

#pragma mark -

- (NSDictionary *) emoticonMappings {
	return _emoticonMappings;
}

- (NSArray *) emoticonMenuItems {
	NSMutableArray *ret = [NSMutableArray array];
	NSEnumerator *enumerator = [_emoticonMenu objectEnumerator];
	NSMenuItem *menuItem = nil;
	NSDictionary *info = nil;

	while( ( info = [enumerator nextObject] ) ) {
		if( ! [(NSString *)[info objectForKey:@"name"] length] ) continue;
		menuItem = [[[NSMenuItem alloc] initWithTitle:[info objectForKey:@"name"] action:NULL keyEquivalent:@""] autorelease];
		if( [(NSString *)[info objectForKey:@"image"] length] )
			[menuItem setImage:[[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:[info objectForKey:@"image"] ofType:nil]] autorelease]];
		[menuItem setRepresentedObject:[info objectForKey:@"insert"]];
		[ret addObject:menuItem];
	}

	return [NSArray arrayWithArray:ret];
}

#pragma mark -

- (NSURL *) baseLocation {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] ) return nil;
	return [NSURL fileURLWithPath:[[self bundle] resourcePath]];
}

- (NSURL *) styleSheetLocation {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] ) return nil;
	return [NSURL fileURLWithPath:[[self bundle] pathForResource:@"emoticons" ofType:@"css"]];
}

#pragma mark -

- (NSString *) contentsOfStyleSheet {
	NSString *contents = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
		contents = [NSString performSelector:@selector( stringWithContentsOfURL: ) withObject:[self styleSheetLocation]];
	else contents = [NSString stringWithContentsOfURL:[self styleSheetLocation] encoding:NSUTF8StringEncoding error:NULL];
	return ( contents ? contents : @"" );
}
@end

#pragma mark -

@implementation JVEmoticonSet (JVEmoticonSetPrivate)
- (void) _setBundle:(NSBundle *) bundle {
	[_bundle autorelease];
	_bundle = [bundle retain];

	NSString *path = [[self bundle] pathForResource:@"emoticons" ofType:@"plist"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"emoticons" ofType:@"plist"];

	[_emoticonMappings autorelease];
	_emoticonMappings = [[NSDictionary dictionaryWithContentsOfFile:path] retain];

	[_emoticonMenu autorelease];
	_emoticonMenu = [[NSArray arrayWithContentsOfFile:[[self bundle] pathForResource:@"menu" ofType:@"plist"]] retain];
}
@end
