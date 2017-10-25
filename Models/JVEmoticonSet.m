#import "JVEmoticonSet.h"
#import "NSBundleAdditions.h"
#import <ChatCore/NSRegularExpressionAdditions.h>

@interface JVEmoticonSet (JVEmoticonSetPrivate)
- (void) _setBundle:(NSBundle *) bundle;
@end

#pragma mark -

static NSMutableSet *allEmoticonSets = nil;

NSString *JVEmoticonSetsScannedNotification = @"JVEmoticonSetsScannedNotification";

@implementation JVEmoticonSet
@synthesize bundle = _bundle;
+ (void) scanForEmoticonSets {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableSet *styles = [NSMutableSet set];
	if( ! allEmoticonSets ) allEmoticonSets = styles;

	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:5];
	[paths addObject:[[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Emoticons"]];
	if( ! [[NSBundle mainBundle] isEqual:[NSBundle bundleForClass:[self class]]] )
		[paths addObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Emoticons"]];
	NSArray *urls = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask & ~NSSystemDomainMask];
	for (NSURL *url in urls) {
		NSURL *newURL = [url URLByAppendingPathComponent:bundleName];
		newURL = [newURL URLByAppendingPathComponent:@"Emoticons" isDirectory:YES];
		[paths addObject:[newURL path]];
	}

	for( NSString *path in paths ) {
		for( NSString *file in [fm contentsOfDirectoryAtPath:path error:nil] ) {
			NSString *fullPath = [path stringByAppendingPathComponent:file];
			NSDictionary *attributes = [fm attributesOfItemAtPath:fullPath error:nil];
			if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:fullPath] && */ ( [[file pathExtension] caseInsensitiveCompare:@"colloquyEmoticons"] == NSOrderedSame || ( [attributes[NSFileHFSTypeCode] unsignedIntValue] == 'coEm' && [attributes[NSFileHFSCreatorCode] unsignedIntValue] == 'coRC' ) ) ) {
				NSBundle *bundle = nil;
				JVEmoticonSet *emoticon = nil;
				if( ( bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]] ) ) {
					if( ( emoticon = [JVEmoticonSet newWithBundle:bundle] ) ) [styles addObject:emoticon];
				}
			}
		}
	}

	[allEmoticonSets intersectSet:styles];

	[[NSNotificationCenter chatCenter] postNotificationName:JVEmoticonSetsScannedNotification object:allEmoticonSets];
}

+ (NSSet *) emoticonSets {
	return [allEmoticonSets copy];
}

+ (instancetype) emoticonSetWithIdentifier:(NSString *) identifier {
	if( [identifier isEqualToString:@"cc.javelin.colloquy.emoticons.text-only"] )
		return [self textOnlyEmoticonSet];

	for( JVEmoticonSet *emoticon in allEmoticonSets )
		if( [[emoticon identifier] isEqualToString:identifier] )
			return emoticon;

	NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
	if( bundle ) return [[JVEmoticonSet alloc] initWithBundle:bundle];

	return nil;
}

+ (id) newWithBundle:(NSBundle *) bundle {
	id ret = [self emoticonSetWithIdentifier:[bundle bundleIdentifier]];
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

- (instancetype) initWithBundle:(NSBundle *) bundle {
	if( ! bundle ) {
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
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[self _setBundle:nil]; // this will dealloc all other dependant objects
	[self unlink];
}

#pragma mark -

- (void) unlink {
	[allEmoticonSets removeObject:self];
	[[NSNotificationCenter chatCenter] postNotificationName:JVEmoticonSetsScannedNotification object:allEmoticonSets];
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

	for( NSString *key in [self emoticonMappings] ) {
		NSArray *obj = [self emoticonMappings][key];

		for( NSString *str in obj ) {
			NSMutableString *search = [str mutableCopy];
			[search escapeCharactersInSet:escapeSet];

			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(?<=\\s|^)%@(?=\\s|$)", search] options:0 error:nil];
			NSArray *matches = [regex matchesInString:[string string] options:0 range:NSMakeRange( 0, [string string].length )];

			for( NSTextCheckingResult *match in matches ) {
				NSRange foundRange = [match range];
				NSString *startHTML = [string attribute:@"XHTMLStart" atIndex:foundRange.location effectiveRange:NULL];
				NSString *endHTML = [string attribute:@"XHTMLEnd" atIndex:foundRange.location effectiveRange:NULL];
				if( ! startHTML ) startHTML = @"";
				if( ! endHTML ) endHTML = @"";
				[string addAttribute:@"XHTMLStart" value:[startHTML stringByAppendingFormat:@"<span class=\"emoticon %@\"><samp>", key] range:foundRange];
				[string addAttribute:@"XHTMLEnd" value:[@"</samp></span>" stringByAppendingString:endHTML] range:foundRange];
			}

		}
	}
}

#pragma mark -

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

- (NSArray *) emoticonMenuItems {
	NSMutableArray *ret = [NSMutableArray array];
	NSMenuItem *menuItem = nil;
	NSDictionary *info = nil;

	for( info in _emoticonMenu ) {
		if( ! [(NSString *)info[@"name"] length] ) continue;
		menuItem = [[NSMenuItem alloc] initWithTitle:info[@"name"] action:NULL keyEquivalent:@""];
		if( [(NSString *)info[@"image"] length] )
			[menuItem setImage:[[NSImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:info[@"image"] ofType:nil]]];
		[menuItem setRepresentedObject:info[@"insert"]];
		[ret addObject:menuItem];
	}

	return [ret copy];
}

#pragma mark -

- (NSURL *) baseLocation {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] ) return nil;
	return [[self bundle] resourceURL];
}

- (NSURL *) styleSheetLocation {
	if( [[self bundle] isEqual:[NSBundle mainBundle]] ) return nil;
	return [[self bundle] URLForResource:@"emoticons" withExtension:@"css"];
}

#pragma mark -

- (NSString *) contentsOfStyleSheet {
	NSString *contents = [NSString stringWithContentsOfURL:[self styleSheetLocation] encoding:NSUTF8StringEncoding error:NULL];
	return ( contents ? contents : @"" );
}
@end

#pragma mark -

@implementation JVEmoticonSet (JVEmoticonSetPrivate)
- (void) _setBundle:(NSBundle *) bundle {
	NSString *path = [_bundle pathForResource:@"emoticons" ofType:@"plist"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"emoticons" ofType:@"plist"];

	_bundle = bundle;
	_emoticonMappings = path ? [NSDictionary dictionaryWithContentsOfFile:path] : @{};

	NSString *file = [_bundle pathForResource:@"menu" ofType:@"plist"];

	_emoticonMenu = [NSArray arrayWithContentsOfFile:file];
}
@end
