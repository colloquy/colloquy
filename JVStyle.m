#import <Cocoa/Cocoa.h>

#import <libxml/xinclude.h>
#import <libxslt/transform.h>
#import <libxslt/xsltutils.h>

#import "JVStyle.h"
#import "MVApplicationController.h"
#import "NSBundleAdditions.h"

@interface JVStyle (JVStylePrivate)
+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary;
+ (void) _freeXsltParamArray:(const char **) params;

- (void) _setBundle:(NSBundle *) bundle;
- (void) _setXSLStyle:(NSString *) path;
- (void) _setStyleOptions:(NSArray *) options;
- (void) _setVariants:(NSArray *) variants;
- (void) _setUserVariants:(NSArray *) variants;
@end

#pragma mark -

static NSMutableSet *allStyles = nil;

NSString *JVStylesScannedNotification = @"JVStylesScannedNotification";
NSString *JVNewStyleVariantAddedNotification = @"JVNewStyleVariantAddedNotification";

@implementation JVStyle
+ (void) scanForStyles {
	extern NSMutableSet *allStyles;

	NSMutableSet *styles = [NSMutableSet set];
	if( ! allStyles ) allStyles = [styles retain];

	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:4];
	[paths addObject:[NSString stringWithFormat:@"%@/Styles", [[NSBundle mainBundle] resourcePath]]];
	[paths addObject:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByExpandingTildeInPath]];
	[paths addObject:[NSString stringWithFormat:@"/Library/Application Support/%@/Styles", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];
	[paths addObject:[NSString stringWithFormat:@"/Network/Library/Application Support/%@/Styles", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]]];

	NSEnumerator *enumerator = [paths objectEnumerator];
	NSString *path = nil;
	while( ( path = [enumerator nextObject] ) ) {
		NSEnumerator *denumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
		NSString *file = nil;
		while( ( file = [denumerator nextObject] ) ) {
			if( [[file pathExtension] caseInsensitiveCompare:@"colloquyStyle"] == NSOrderedSame || [[file pathExtension] caseInsensitiveCompare:@"fireStyle"] == NSOrderedSame ) {
				NSBundle *bundle = nil;
				JVStyle *style = nil;
				if( ( bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/%@", path, file]] ) )
					style = [[JVStyle newWithBundle:bundle] autorelease];
			}
		}
	}

	[allStyles intersectSet:styles];

	[[NSNotificationCenter defaultCenter] postNotificationName:JVStylesScannedNotification object:allStyles]; 
}

+ (NSSet *) styles {
	extern NSMutableSet *allStyles;
	return allStyles;
}

+ (id) styleWithIdentifier:(NSString *) identifier {
	extern NSMutableSet *allStyles;
	NSEnumerator *enumerator = [allStyles objectEnumerator];
	JVStyle *style = nil;

	while( ( style = [enumerator nextObject] ) )
		if( [[style identifier] isEqualToString:identifier] )
			return style;

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
	return [self styleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
}

+ (void) setDefaultStyle:(JVStyle *) style {
	if( ! style ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
	else [[NSUserDefaults standardUserDefaults] setObject:[style identifier] forKey:@"JVChatDefaultStyle"];
}

#pragma mark -

- (id) initWithBundle:(NSBundle *) bundle {
	if( ( self = [self init] ) ) {
		extern NSMutableSet *allStyles;
		[allStyles addObject:self];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _clearVariantCache ) name:JVNewStyleVariantAddedNotification object:self];

		_releasing = NO;
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

- (void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		extern NSMutableSet *allStyles;
		[allStyles removeObject:self];
		_releasing = YES;
	}

	[super release];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self _setBundle:nil]; // this will dealloc all other dependant objects
	[super dealloc];
}

#pragma mark -

- (NSBundle *) bundle {
	return _bundle;
}

- (NSString *) identifier {
	return [_bundle bundleIdentifier];
}

#pragma mark -

- (NSString *) transformXML:(NSString *) xml withParameters:(NSDictionary *) parameters {
	NSParameterAssert( xml != nil );
	if( ! [xml length] ) return @"";

	const char *string = [xml UTF8String];
	if( ! string ) return nil;

	xmlDoc *doc = xmlParseMemory( string, strlen( string ) );
	NSString *result = [self transformXMLDocument:doc withParameters:parameters];
	xmlFreeDoc( doc );

	return result;
}

- (NSString *) transformXMLDocument:(void *) document withParameters:(NSDictionary *) parameters {
	NSParameterAssert( document != NULL );

	if( ! _XSLStyle ) [self _setXSLStyle:[self XMLStyleSheetFilePath]];
	NSAssert( _XSLStyle, @"XSL not allocated." );

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
		ret = [NSString stringWithUTF8String:result];
		free( result );
	}

	[[self class] _freeXsltParamArray:params];

	return [[ret retain] autorelease];
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
	return ( name ? name : NSLocalizedString( @"Normal", "normal style variant menu item title" ) );
}

- (NSArray *) variantStyleSheetNames {
	if( ! _variants ) {
		NSMutableArray *ret = [NSMutableArray array];
		NSArray *files = [_bundle pathsForResourcesOfType:@"css" inDirectory:@"Variants"];
		NSEnumerator *enumerator = [files objectEnumerator];
		NSString *file = nil;

		while( ( file = [enumerator nextObject] ) )
			[ret addObject:[[file lastPathComponent] stringByDeletingPathExtension]];

		[self _setVariants:ret];
	}

	return _variants;
}

- (NSArray *) userVariantStyleSheetNames {
	if( ! _userVariants ) {
		NSMutableArray *ret = [NSMutableArray array];
		NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:[[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier]] stringByExpandingTildeInPath]];
		NSEnumerator *enumerator = [files objectEnumerator];
		NSString *file = nil;

		while( ( file = [enumerator nextObject] ) )
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

	path = [[NSString stringWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/%@.css", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier], name] stringByExpandingTildeInPath];
	if( [[NSFileManager defaultManager] isReadableFileAtPath:path] )
		return [NSURL fileURLWithPath:path];

	return nil;
}

- (NSString *) XMLStyleSheetFilePath {
	NSString *path = [_bundle pathForResource:@"main" ofType:@"xsl"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"xsl"];
	return path;
}

- (NSString *) previewTranscriptFilePath {
	NSString *path = [_bundle pathForResource:@"preview" ofType:@"colloquyTranscript"];
	if( ! path ) path = [[NSBundle mainBundle] pathForResource:@"preview" ofType:@"colloquyTranscript"];
	return path;
}

- (NSString *) headerFilePath {
	return [_bundle pathForResource:@"supplement" ofType:@"html"];
}

#pragma mark -

- (NSString *) contentsOfMainStyleSheet {
	NSString *contents = [NSString stringWithContentsOfURL:[self mainStyleSheetLocation]];
	return ( contents ? contents : @"" );
}

- (NSString *) contentsOfVariantStyleSheetWithName:(NSString *) name {
	NSString *contents = [NSString stringWithContentsOfURL:[self variantStyleSheetLocationWithName:name]];
	return ( contents ? contents : @"" );
}

- (NSString *) contentsOfHeaderFile {
	NSString *contents = [NSString stringWithContentsOfFile:[self headerFilePath]];
	return ( contents ? contents : @"" );
}

#pragma mark -

- (NSString *) description {
	return [self identifier];
}
@end

#pragma mark -

@implementation JVStyle (JVStylePrivate)
+ (const char **) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary {
	NSEnumerator *keyEnumerator = [dictionary keyEnumerator];
	NSEnumerator *enumerator = [dictionary objectEnumerator];
	NSString *key = nil;
	NSString *value = nil;
	const char **temp = NULL, **ret = NULL;

	if( ! [dictionary count] ) return NULL;

	ret = temp = malloc( ( ( [dictionary count] * 2 ) + 1 ) * sizeof( char * ) );

	while( ( key = [keyEnumerator nextObject] ) && ( value = [enumerator nextObject] ) ) {
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
	[_bundle load];

	[self _setXSLStyle:nil];
	[self _setStyleOptions:nil];
	[self _setVariants:nil];
	[self _setUserVariants:nil];
	[self setMainParameters:[NSDictionary dictionaryWithContentsOfFile:[_bundle pathForResource:@"parameters" ofType:@"plist"]]];
}

- (void) _setXSLStyle:(NSString *) path {
	if( _XSLStyle ) xsltFreeStylesheet( _XSLStyle );
	_XSLStyle = ( [path length] ? xsltParseStylesheetFile( (const xmlChar *)[path fileSystemRepresentation] ) : NULL );
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