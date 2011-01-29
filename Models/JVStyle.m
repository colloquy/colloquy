#import <libxml/tree.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "JVChatMessage.h"
#import "NSBundleAdditions.h"

@interface JVStyle (JVStylePrivate)
+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary;
+ (void) _freeXsltParamArray:(const char **) params;

- (void) _setBundle:(NSBundle *) bundle;
- (void) _setXSLStyle:(NSURL *) location;
- (void) _setStyleOptions:(NSArray *) options;
- (void) _setVariants:(NSArray *) variants;
- (void) _setUserVariants:(NSArray *) variants;
@end

#pragma mark -

static NSMutableSet *allStyles = nil;

NSString *JVStylesScannedNotification = @"JVStylesScannedNotification";
NSString *JVDefaultStyleChangedNotification = @"JVDefaultStyleChangedNotification";
NSString *JVDefaultStyleVariantChangedNotification = @"JVDefaultStyleVariantChangedNotification";
NSString *JVNewStyleVariantAddedNotification = @"JVNewStyleVariantAddedNotification";
NSString *JVStyleVariantChangedNotification = @"JVStyleVariantChangedNotification";

@implementation JVStyle
+ (void) scanForStyles {
	NSMutableSet *styles = [NSMutableSet set];
	if( ! allStyles ) allStyles = [styles retain];

	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:5];
	[paths addObject:[NSString stringWithFormat:@"%@/Styles", [[NSBundle bundleForClass:[self class]] resourcePath]]];
	if( ! [[NSBundle mainBundle] isEqual:[NSBundle bundleForClass:[self class]]] )
		[paths addObject:[NSString stringWithFormat:@"%@/Styles", [[NSBundle mainBundle] resourcePath]]];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles", bundleName] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/Styles", bundleName]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/Styles", bundleName]];

	for( NSString *path in paths ) {
		for( NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] ) {
			NSString *fullPath = [path stringByAppendingPathComponent:file];
			NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NO];
			if( /* [[NSWorkspace sharedWorkspace] isFilePackageAtPath:fullPath] && */ ( [[file pathExtension] caseInsensitiveCompare:@"colloquyStyle"] == NSOrderedSame || [[file pathExtension] caseInsensitiveCompare:@"fireStyle"] == NSOrderedSame || ( [[attributes objectForKey:NSFileHFSTypeCode] unsignedLongValue] == 'coSt' && [[attributes objectForKey:NSFileHFSCreatorCode] unsignedLongValue] == 'coRC' ) ) ) {
				NSBundle *bundle = nil;
				JVStyle *style = nil;
				if( ( bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]] ) ) {
					if( ( style = [[JVStyle newWithBundle:bundle] autorelease] ) ) [styles addObject:style];
					if( [allStyles containsObject:style] && allStyles != styles ) [style reload];
				}
			}
		}
	}

	[allStyles intersectSet:styles];

	[[NSNotificationCenter defaultCenter] postNotificationName:JVStylesScannedNotification object:allStyles];
}

+ (NSSet *) styles {
	return allStyles;
}

+ (id) styleWithIdentifier:(NSString *) identifier {
	for( JVStyle *style in allStyles )
		if( [[style identifier] isEqualToString:identifier] )
			return style;

	NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
	if( bundle ) return [[[JVStyle alloc] initWithBundle:bundle] autorelease];

	return nil;
}

+ (id) newWithBundle:(NSBundle *) bundle {
	id ret = [[self styleWithIdentifier:[bundle bundleIdentifier]] retain];
	if( ! ret ) ret = [[JVStyle alloc] initWithBundle:bundle];
	return ret;
}

+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[self scanForStyles];
		tooLate = YES;
	}
}

#pragma mark -

+ (id) defaultStyle {
	id ret = [self styleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	if( ! ret ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
		ret = [self styleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	}
	return ret;
}

+ (void) setDefaultStyle:(JVStyle *) style {
	JVStyle *oldDefault = [self defaultStyle];
	if( style == oldDefault ) return;

	if( ! style ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
	else [[NSUserDefaults standardUserDefaults] setObject:[style identifier] forKey:@"JVChatDefaultStyle"];

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[self defaultStyle], @"default", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:JVStyleVariantChangedNotification object:oldDefault userInfo:info];
}

#pragma mark -

- (id) initWithBundle:(NSBundle *) bundle {
	if( ( self = [self init] ) ) {
		if( ! bundle ) {
			[self release];
			return nil;
		}

		[allStyles addObject:self];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _clearVariantCache ) name:JVNewStyleVariantAddedNotification object:self];

		_bundle = nil;
		_XSLStyle = NULL;
		_parameters = nil;
		_styleOptions = nil;
		_variants = nil;
		_userVariants = nil;

		[self _setBundle:bundle];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_parameters release];
	_parameters = nil;

	[self _setBundle:nil]; // this will dealloc all other dependant objects
	[self unlink];

	[super dealloc];
}

#pragma mark -

- (void) unlink {
	[allStyles removeObject:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:JVStylesScannedNotification object:allStyles];
}

- (void) reload {
	[self _setXSLStyle:nil];
	[self _setStyleOptions:nil];
	[self _setVariants:nil];
	[self _setUserVariants:nil];

	if( _bundle && ! [self isCompliant] ) [self unlink];
}

- (BOOL) isCompliant {
	BOOL ret = YES;

	if( ! [[self displayName] length] ) ret = NO;
	if( ! [[_bundle pathForResource:@"main" ofType:@"css"] length] ) ret = NO;
	if( ! [[_bundle bundleIdentifier] length] ) ret = NO;

	return ret;
}

#pragma mark -

- (NSBundle *) bundle {
	return _bundle;
}

- (NSString *) identifier {
	return [_bundle bundleIdentifier];
}

#pragma mark -

- (NSString *) transformChatTranscript:(JVChatTranscript *) transcript withParameters:(NSDictionary *) parameters {
	@synchronized( transcript ) {
		if( ! [transcript document] ) return nil;
		return [self transformXMLDocument:[transcript document] withParameters:parameters];
	}
}

- (NSString *) transformChatTranscriptElement:(id <JVChatTranscriptElement>) element withParameters:(NSDictionary *) parameters {
	@synchronized( ( [element transcript] ? (id) [element transcript] : (id) element ) ) {
		xmlDoc *doc = xmlNewDoc( (xmlChar *) "1.0" );
		if( ! doc ) return nil;

		xmlNode *root = xmlDocCopyNode( (xmlNode *) [element node], doc, 1 );
		if( ! root ) return nil;

		xmlDocSetRootElement( doc, root );

		NSString *result = [self transformXMLDocument:doc withParameters:parameters];

		xmlFreeDoc( doc );

		return result;
	}
}

- (NSString *) transformChatMessage:(JVChatMessage *) message withParameters:(NSDictionary *) parameters {
	@synchronized( ( [message transcript] ? (id) [message transcript] : (id) message ) ) {
		// Styles depend on being passed all the messages in the same envelope.
		// This lets them know it is a consecutive message.

		xmlDoc *doc = xmlNewDoc( (xmlChar *) "1.0" );
		if( ! doc ) return nil;

		xmlNode *envelope = xmlDocCopyNode( ((xmlNode *) [message node]) -> parent, doc, 1 );
		if( ! envelope ) return nil;

		xmlDocSetRootElement( doc, envelope );

		NSString *result = [self transformXMLDocument:doc withParameters:parameters];

		xmlFreeDoc( doc );

		return result;
	}
}

- (NSString *) transformChatTranscriptElements:(NSArray *) elements withParameters:(NSDictionary *) parameters {
	JVChatTranscript *transcript = [[JVChatTranscript allocWithZone:[self zone]] initWithElements:elements];
	NSString *ret = [self transformChatTranscript:transcript withParameters:parameters];
	[transcript release];
	return ret;
}

#pragma mark -

- (NSString *) transformXML:(NSString *) xml withParameters:(NSDictionary *) parameters {
	NSParameterAssert( xml != nil );
	if( ! [xml length] ) return @"";

	const char *string = [xml UTF8String];
	if( ! string ) return nil;

	xmlDoc *doc = xmlParseMemory( string, strlen( string ) );
	if( ! doc ) return nil;

	NSString *result = [self transformXMLDocument:doc withParameters:parameters];
	xmlFreeDoc( doc );

	return result;
}

- (NSString *) transformXMLDocument:(void *) document withParameters:(NSDictionary *) parameters {
	NSParameterAssert( document != NULL );

	@synchronized( self ) {
		if( ! _XSLStyle ) [self _setXSLStyle:[self XMLStyleSheetLocation]];
		if( ! _XSLStyle ) return nil;

		NSMutableDictionary *pms = (NSMutableDictionary *)[self mainParameters];
		if( parameters ) {
			pms = [NSMutableDictionary dictionaryWithDictionary:[self mainParameters]];
			[pms addEntriesFromDictionary:parameters];
		}

		xmlDoc *doc = document;
		const char **params = [[self class] _xsltParamArrayWithDictionary:pms];
		xmlDoc *res = NULL;
		xmlChar *result = NULL;
		NSString *ret = nil;
		int len = 0;

		if( ( res = xsltApplyStylesheet( _XSLStyle, doc, params ) ) ) {
			xsltSaveResultToString( &result, &len, res, _XSLStyle );
			xmlFreeDoc( res );
		}

		if( result ) {
			ret = [NSString stringWithUTF8String:(char *) result];
			free( result );
		}

		[[self class] _freeXsltParamArray:params];

		return ret;
	}
}

#pragma mark -

- (NSComparisonResult) compare:(JVStyle *) style {
	return [_bundle compare:[style bundle]];
}

- (NSString *) displayName {
	return [_bundle displayName];
}

#pragma mark -

- (NSString *) mainVariantDisplayName {
	NSString *name = [_bundle objectForInfoDictionaryKey:@"JVBaseStyleVariantName"];
	return ( name.length ? name : NSLocalizedString( @"Normal", "normal style variant menu item title" ) );
}

- (NSArray *) variantStyleSheetNames {
	if( ! _variants ) {
		NSMutableArray *ret = [NSMutableArray array];
		NSArray *files = [_bundle pathsForResourcesOfType:@"css" inDirectory:@"Variants"];

		for( NSString *file in files )
			[ret addObject:[[file lastPathComponent] stringByDeletingPathExtension]];

		[self _setVariants:ret];
	}

	return _variants;
}

- (NSArray *) userVariantStyleSheetNames {
	if( ! _userVariants ) {
		NSMutableArray *ret = [NSMutableArray array];
		NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier]] stringByExpandingTildeInPath] error:nil];

		for( NSString *file in files )
			if( [[file pathExtension] isEqualToString:@"css"] || [[file pathExtension] isEqualToString:@"colloquyVariant"] )
				[ret addObject:[[file lastPathComponent] stringByDeletingPathExtension]];

		[self _setUserVariants:ret];
	}

	return _userVariants;
}

- (BOOL) isUserVariantName:(NSString *) name {
	NSString *path = [[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/%@.css", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier], name] stringByExpandingTildeInPath];
	return [[NSFileManager defaultManager] isReadableFileAtPath:path];
}

- (NSString *) defaultVariantName {
	NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
	if( [name isAbsolutePath] ) return [[name lastPathComponent] stringByDeletingPathExtension];
	return name;
}

- (void) setDefaultVariantName:(NSString *) name {
	if( [name isEqualToString:[self defaultVariantName]] ) return;

	if( ! [name length] ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
	} else {
		if( [self isUserVariantName:name] ) {
			NSString *path = [[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/%@.css", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier], name] stringByExpandingTildeInPath];
			[[NSUserDefaults standardUserDefaults] setObject:path forKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
		} else {
			[[NSUserDefaults standardUserDefaults] setObject:name forKey:[NSString stringWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
		}
	}

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[self defaultVariantName], @"variant", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:JVDefaultStyleVariantChangedNotification object:self userInfo:info];
}

#pragma mark -

- (JVEmoticonSet *) defaultEmoticonSet {
	NSString *defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
	JVEmoticonSet *emoticon = [JVEmoticonSet emoticonSetWithIdentifier:defaultEmoticons];

	if( ! emoticon ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
		defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
		emoticon = [JVEmoticonSet emoticonSetWithIdentifier:defaultEmoticons];
		if( ! emoticon ) emoticon = [JVEmoticonSet textOnlyEmoticonSet];
	}

	return emoticon;
}

- (void) setDefaultEmoticonSet:(JVEmoticonSet *) emoticons {
	if( emoticons ) [[NSUserDefaults standardUserDefaults] setObject:[emoticons identifier] forKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
	else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
}

#pragma mark -

- (NSArray *) styleSheetOptions {
	if( ! _styleOptions ) {
		NSMutableArray *options = [NSMutableArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"styleOptions" ofType:@"plist"]];
		if( [_bundle objectForInfoDictionaryKey:@"JVStyleOptions"] )
			[options addObjectsFromArray:[_bundle objectForInfoDictionaryKey:@"JVStyleOptions"]];
		[self _setStyleOptions:options];
	}

	return _styleOptions;
}

#pragma mark -

- (void) setMainParameters:(NSDictionary *) parameters {
	[_parameters autorelease];
	_parameters = [parameters retain];
}

- (NSDictionary *) mainParameters {
	return _parameters;
}

#pragma mark -

- (NSURL *) baseLocation {
	return [NSURL fileURLWithPath:[_bundle resourcePath]];
}

- (NSURL *) mainStyleSheetLocation {
	return [NSURL fileURLWithPath:[_bundle pathForResource:@"main" ofType:@"css"]];
}

- (NSURL *) variantStyleSheetLocationWithName:(NSString *) name {
	if( ! [name length] ) return nil;

	NSString *path = [_bundle pathForResource:name ofType:@"css" inDirectory:@"Variants"];
	if( path ) return [NSURL fileURLWithPath:path];

	NSString *root = [[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles/Variants/", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByStandardizingPath];
	path = [[NSString stringWithFormat:@"%@/%@/%@.css", root, [self identifier], name] stringByExpandingTildeInPath];
	if( [path hasPrefix:root] && [[NSFileManager defaultManager] isReadableFileAtPath:path] )
		return [NSURL fileURLWithPath:path];

	return nil;
}

- (NSURL *) bodyTemplateLocationWithName:(NSString *) name {
	if( ! [name length] ) name = @"generic";

	NSString *path = [_bundle pathForResource:[name stringByAppendingString:@"Template"] ofType:@"html"];
	if( path ) return [NSURL fileURLWithPath:path];

	path = [_bundle pathForResource:@"genericTemplate" ofType:@"html"];
	if( path ) return [NSURL fileURLWithPath:path];

	path = [[NSBundle mainBundle] pathForResource:[name stringByAppendingString:@"Template"] ofType:@"html"];
	if( path ) return [NSURL fileURLWithPath:path];

	path = [[NSBundle mainBundle] pathForResource:@"genericTemplate" ofType:@"html"];
	if( path ) return [NSURL fileURLWithPath:path];

	return nil;
}

- (NSURL *) XMLStyleSheetLocation {
	NSString *path = [_bundle pathForResource:@"main" ofType:@"xsl"];
	if( path ) return [NSURL fileURLWithPath:path];

	path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"xsl"];
	if( path ) return [NSURL fileURLWithPath:path];

	return nil;
}

- (NSURL *) previewTranscriptLocation {
	NSString *path = [_bundle pathForResource:@"preview" ofType:@"colloquyTranscript"];
	if( path ) return [NSURL fileURLWithPath:path];

	path = [[NSBundle mainBundle] pathForResource:@"preview" ofType:@"colloquyTranscript"];
	if( path ) return [NSURL fileURLWithPath:path];

	return nil;
}

#pragma mark -

- (NSString *) contentsOfMainStyleSheet {
	NSString *contents = [NSString stringWithContentsOfURL:[self mainStyleSheetLocation] encoding:NSUTF8StringEncoding error:NULL];
	return ( contents ? contents : @"" );
}

- (NSString *) contentsOfVariantStyleSheetWithName:(NSString *) name {
	NSString *contents = [NSString stringWithContentsOfURL:[self variantStyleSheetLocationWithName:name] encoding:NSUTF8StringEncoding error:NULL];
	return ( contents ? contents : @"" );
}

- (NSString *) contentsOfBodyTemplateWithName:(NSString *) name {
	NSURL *url = [self bodyTemplateLocationWithName:name];
	if( ! url ) return @"";

	NSString *contents = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];

	NSURL *resources = [NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]];
	return ( contents ? [NSString stringWithFormat:contents, [resources absoluteString], @""] : @"" );
}

#pragma mark -

- (NSString *) description {
	return [self identifier];
}
@end

#pragma mark -

@implementation JVStyle (JVStylePrivate)
+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary {
	const char **temp = NULL, **ret = NULL;

	if( ! [dictionary count] ) return NULL;

	ret = temp = malloc( ( ( [dictionary count] * 2 ) + 1 ) * sizeof( char * ) );

	for( NSString *key in dictionary ) {
		NSString *value = [dictionary objectForKey:key];

		*(temp++) = (char *) strdup( [key UTF8String] );
		*(temp++) = (char *) strdup( [value UTF8String] );
	}

	*(temp) = NULL;

	return ret;
}

+ (void) _freeXsltParamArray:(const char **) params {
	const char **temp = params;

	if( ! params ) return;

	while( *(temp) ) {
		free( (void *)*(temp++) );
		free( (void *)*(temp++) );
	}

	free( params );
}

#pragma mark -

- (void) _clearVariantCache {
	[self _setVariants:nil];
	[self _setUserVariants:nil];
}

- (void) _setBundle:(NSBundle *) bundle {
	[_bundle autorelease];
	_bundle = [bundle retain];

	[self setMainParameters:[NSDictionary dictionaryWithContentsOfFile:[_bundle pathForResource:@"parameters" ofType:@"plist"]]];

	[_bundle load];
	[self reload];
}

- (void) _setXSLStyle:(NSURL *) location {
	@synchronized( self ) {
		if( _XSLStyle ) xsltFreeStylesheet( _XSLStyle );
		_XSLStyle = ( [[location absoluteString] length] ? xsltParseStylesheetFile( (const xmlChar *)[[location absoluteString] fileSystemRepresentation] ) : NULL );
		if( _XSLStyle ) ((xsltStylesheetPtr) _XSLStyle) -> indent = 0; // this is done because our whitespace escaping causes problems otherwise
	}
}

- (void) _setStyleOptions:(NSArray *) options {
	[_styleOptions autorelease];
	_styleOptions = [options retain];
}

- (void) _setVariants:(NSArray *) variants {
	[_variants autorelease];
	_variants = [variants retain];
}

- (void) _setUserVariants:(NSArray *) variants {
	[_userVariants autorelease];
	_userVariants = [variants retain];
}
@end
