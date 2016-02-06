#include <libxml/tree.h>
#include <libxslt/transform.h>
#include <libxslt/xsltutils.h>

#import "JVStyle.h"
#import "JVEmoticonSet.h"
#import "JVChatMessage.h"
#import "NSBundleAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@interface JVStyle (Private)
+ (const char * _Nullable *) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary;
+ (void) _freeXsltParamArray:(const char *__nullable*) params;

- (void) _clearVariantCache;
- (void) _setBundle:(nullable NSBundle *) bundle;
- (void) _setXSLStyle:(nullable NSURL *) location;
- (void) _setStyleOptions:(nullable NSArray *) options;
- (void) _setVariants:(nullable NSArray *) variants;
- (void) _setUserVariants:(nullable NSArray *) variants;
@end

#pragma mark -

static NSMutableSet * __null_unspecified allStyles = nil;

NSString *JVStylesScannedNotification = @"JVStylesScannedNotification";
NSString *JVDefaultStyleChangedNotification = @"JVDefaultStyleChangedNotification";
NSString *JVDefaultStyleVariantChangedNotification = @"JVDefaultStyleVariantChangedNotification";
NSString *JVNewStyleVariantAddedNotification = @"JVNewStyleVariantAddedNotification";
NSString *JVStyleVariantChangedNotification = @"JVStyleVariantChangedNotification";

@implementation JVStyle
+ (void) scanForStyles {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableSet *styles = [[NSMutableSet alloc] init];
	if( ! allStyles ) allStyles = styles;

	NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:5];
	{
		NSString *frameworkStyles = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Styles"];
		[paths addObject:frameworkStyles];
		if( ! [[NSBundle mainBundle] isEqual:[NSBundle bundleForClass:[self class]]] )
			[paths addObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Styles"]];
		NSArray *arr = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:(NSAllDomainsMask & ~NSSystemDomainMask)];
		for (NSURL *loc in arr) {
			NSString *toAddDir = [loc path];
			toAddDir = [toAddDir stringByAppendingPathComponent:bundleName];
			toAddDir = [toAddDir stringByAppendingPathComponent:@"Styles"];
			[paths addObject:toAddDir];
		}
	}

	for( NSString *path in paths ) {
		for( NSString *file in [fm contentsOfDirectoryAtPath:path error:nil] ) {
			NSString *fullPath = [path stringByAppendingPathComponent:file];
			NSDictionary *attributes = [fm attributesOfItemAtPath:fullPath error:NO];
			if( /* [fm isFilePackageAtPath:fullPath] && */ ( [[file pathExtension] caseInsensitiveCompare:@"colloquyStyle"] == NSOrderedSame || [[file pathExtension] caseInsensitiveCompare:@"fireStyle"] == NSOrderedSame || ( [attributes[NSFileHFSTypeCode] unsignedIntValue] == 'coSt' && [attributes[NSFileHFSCreatorCode] unsignedIntValue] == 'coRC' ) ) ) {
				NSBundle *bundle = nil;
				JVStyle *style = nil;
				if( ( bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]] ) ) {
					if( ( style = [JVStyle newWithBundle:bundle] ) ) [styles addObject:style];
					if( [allStyles containsObject:style] && allStyles != styles ) [style reload];
				}
			}
		}
	}

	[allStyles intersectSet:styles];

	[[NSNotificationCenter chatCenter] postNotificationName:JVStylesScannedNotification object:allStyles];
}

+ (NSSet *) styles {
	return allStyles;
}

+ (nullable instancetype) styleWithIdentifier:(NSString *) identifier {
	for( JVStyle *style in allStyles )
		if( [[style identifier] isEqualToString:identifier] )
			return style;

	NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
	if( bundle ) return [[JVStyle alloc] initWithBundle:bundle];

	return nil;
}

+ (nullable id) newWithBundle:(NSBundle *) bundle {
	id ret = [self styleWithIdentifier:[bundle bundleIdentifier]];
	if( ! ret ) ret = [[JVStyle alloc] initWithBundle:bundle];
	return ret;
}

+ (void) initialize {
	//[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[self scanForStyles];
		tooLate = YES;
	}
}

#pragma mark -

+ (JVStyle*) defaultStyle {
	id ret = [self styleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	if( ! ret ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
		ret = [self styleWithIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:@"JVChatDefaultStyle"]];
	}
	return ret;
}

+ (void) setDefaultStyle:(nullable JVStyle *) style {
	JVStyle *oldDefault = [self defaultStyle];
	if( style == oldDefault ) return;

	if( ! style ) [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"JVChatDefaultStyle"];
	else [[NSUserDefaults standardUserDefaults] setObject:[style identifier] forKey:@"JVChatDefaultStyle"];

	NSDictionary *info = @{@"default": [self defaultStyle]};
	[[NSNotificationCenter chatCenter] postNotificationName:JVStyleVariantChangedNotification object:oldDefault userInfo:info];
}

#pragma mark -

- (nullable instancetype) initWithBundle:(NSBundle *) bundle {
	if( ( self = [self init] ) ) {
		if( ! bundle ) {
			return nil;
		}

		[allStyles addObject:self];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _clearVariantCache ) name:JVNewStyleVariantAddedNotification object:self];

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
	[[NSNotificationCenter chatCenter] removeObserver:self];

	_parameters = nil;

	[self _setBundle:nil]; // this will dealloc all other dependant objects
	[self unlink];
}

#pragma mark -

- (void) unlink {
	[allStyles removeObject:self];
	[[NSNotificationCenter chatCenter] postNotificationName:JVStylesScannedNotification object:allStyles];
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

@synthesize bundle = _bundle;

- (NSString *) identifier {
	return [_bundle bundleIdentifier];
}

#pragma mark -

- (nullable NSString *) transformChatTranscript:(JVChatTranscript *) transcript withParameters:(NSDictionary *) parameters {
	@synchronized( transcript ) {
		if( ! [transcript document] ) return nil;
		return [self transformXMLDocument:[transcript document] withParameters:parameters];
	}
}

- (nullable NSString *) transformChatTranscriptElement:(id <JVChatTranscriptElement>) element withParameters:(NSDictionary *) parameters {
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

- (nullable NSString *) transformChatMessage:(JVChatMessage *) message withParameters:(NSDictionary *) parameters {
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

- (nullable NSString *) transformChatTranscriptElements:(NSArray *) elements withParameters:(NSDictionary *) parameters {
	JVChatTranscript *transcript = [[JVChatTranscript alloc] initWithElements:elements];
	NSString *ret = [self transformChatTranscript:transcript withParameters:parameters];
	return ret;
}

#pragma mark -

- (nullable NSString *) transformXML:(NSString *) xml withParameters:(NSDictionary *) parameters {
	NSParameterAssert( xml != nil );
	if( ! [xml length] ) return @"";

	const char *string = [xml UTF8String];
	if( ! string ) return nil;

	xmlDoc *doc = xmlParseMemory( string, (int)strlen( string ) );
	if( ! doc ) return nil;

	NSString *result = [self transformXMLDocument:doc withParameters:parameters];
	xmlFreeDoc( doc );

	return result;
}

- (nullable NSString *) transformXMLDocument:(xmlDocPtr) document withParameters:(NSDictionary *) parameters {
	NSParameterAssert( document != NULL );

	@synchronized( self ) {
		if( ! _XSLStyle ) [self _setXSLStyle:[self XMLStyleSheetLocation]];
		if( ! _XSLStyle ) return nil;

		NSMutableDictionary *pms = (NSMutableDictionary *)[self mainParameters];
		if( parameters ) {
			pms = [[NSMutableDictionary alloc] initWithDictionary:[self mainParameters]];
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
			ret = @((char *) result);
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
		NSMutableArray *ret = [[NSMutableArray alloc] init];
		NSArray *files = [_bundle pathsForResourcesOfType:@"css" inDirectory:@"Variants"];

		for( NSString *file in files )
			[ret addObject:[[file lastPathComponent] stringByDeletingPathExtension]];

		[self _setVariants:ret];
	}

	return _variants;
}

- (NSArray *) userVariantStyleSheetNames {
	if( ! _userVariants ) {
		NSMutableArray *ret = [[NSMutableArray alloc] init];
		NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[[NSString alloc] initWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier]] stringByExpandingTildeInPath] error:nil];

		for( NSString *file in files )
			if( [[file pathExtension] isEqualToString:@"css"] || [[file pathExtension] isEqualToString:@"colloquyVariant"] )
				[ret addObject:[[file lastPathComponent] stringByDeletingPathExtension]];

		[self _setUserVariants:ret];
	}

	return _userVariants;
}

- (BOOL) isUserVariantName:(NSString *) name {
	NSString *path = [[[NSString alloc] initWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/%@.css", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier], name] stringByExpandingTildeInPath];
	return [[NSFileManager defaultManager] isReadableFileAtPath:path];
}

- (NSString *) defaultVariantName {
	NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:[[NSString alloc] initWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
	if( [name isAbsolutePath] ) return [[name lastPathComponent] stringByDeletingPathExtension];
	return name;
}

- (void) setDefaultVariantName:(NSString *) name {
	if( [name isEqualToString:[self defaultVariantName]] ) return;

	if( ! [name length] ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:[[NSString alloc] initWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
	} else {
		if( [self isUserVariantName:name] ) {
			NSString *path = [[[NSString alloc] initWithFormat:@"~/Library/Application Support/%@/Styles/Variants/%@/%@.css", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [self identifier], name] stringByExpandingTildeInPath];
			[[NSUserDefaults standardUserDefaults] setObject:path forKey:[[NSString alloc] initWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
		} else {
			[[NSUserDefaults standardUserDefaults] setObject:name forKey:[[NSString alloc] initWithFormat:@"JVChatDefaultStyleVariant %@", [self identifier]]];
		}
	}

	NSDictionary *info = @{@"variant": [self defaultVariantName]};
	[[NSNotificationCenter chatCenter] postNotificationName:JVDefaultStyleVariantChangedNotification object:self userInfo:info];
}

#pragma mark -

- (JVEmoticonSet *) defaultEmoticonSet {
	NSString *defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:[[NSString alloc] initWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
	JVEmoticonSet *emoticon = [JVEmoticonSet emoticonSetWithIdentifier:defaultEmoticons];

	if( ! emoticon ) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:[[NSString alloc] initWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
		defaultEmoticons = [[NSUserDefaults standardUserDefaults] objectForKey:[[NSString alloc] initWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
		emoticon = [JVEmoticonSet emoticonSetWithIdentifier:defaultEmoticons];
		if( ! emoticon ) emoticon = [JVEmoticonSet textOnlyEmoticonSet];
	}

	return emoticon;
}

- (void) setDefaultEmoticonSet:(JVEmoticonSet *) emoticons {
	if( emoticons ) [[NSUserDefaults standardUserDefaults] setObject:[emoticons identifier] forKey:[[NSString alloc] initWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
	else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[[NSString alloc] initWithFormat:@"JVChatDefaultEmoticons %@", [self identifier]]];
}

#pragma mark -

- (NSArray *) styleSheetOptions {
	if( ! _styleOptions ) {
		NSMutableArray *options = [[NSMutableArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"styleOptions" ofType:@"plist"]];
		if( [_bundle objectForInfoDictionaryKey:@"JVStyleOptions"] )
			[options addObjectsFromArray:[_bundle objectForInfoDictionaryKey:@"JVStyleOptions"]];
		[self _setStyleOptions:options];
	}

	return _styleOptions;
}

#pragma mark -

@synthesize mainParameters = _parameters;

#pragma mark -

- (NSURL *) baseLocation {
	return [_bundle resourceURL];
}

- (NSURL *) mainStyleSheetLocation {
	return [_bundle URLForResource:@"main" withExtension:@"css"];
}

- (nullable NSURL *) variantStyleSheetLocationWithName:(NSString *) name {
	if( ! [name length] ) return nil;

	NSURL *URLpath = [_bundle URLForResource:name withExtension:@"css" subdirectory:@"Variants"];
	if( URLpath ) return URLpath;

	NSFileManager *fm = [NSFileManager defaultManager];
	{
		URLpath = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
		URLpath = [URLpath URLByAppendingPathComponent:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] isDirectory:YES];
		URLpath = [URLpath URLByAppendingPathComponent:@"Styles" isDirectory:YES];
		URLpath = [URLpath URLByAppendingPathComponent:@"Variants" isDirectory:YES];
		URLpath = [URLpath URLByAppendingPathComponent:[self identifier] isDirectory:YES];
		URLpath = [URLpath URLByAppendingPathComponent:name isDirectory:NO];
		URLpath = [URLpath URLByAppendingPathExtension:@"css"];
		if ([URLpath checkResourceIsReachableAndReturnError:NULL]) {
			return URLpath;
		}
	}
	NSString *path;
	NSString *root = [[[NSString alloc] initWithFormat:@"~/Library/Application Support/%@/Styles/Variants/", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] stringByStandardizingPath];
	path = [[[NSString alloc] initWithFormat:@"%@/%@/%@.css", root, [self identifier], name] stringByExpandingTildeInPath];
	if( [path hasPrefix:root] && [fm isReadableFileAtPath:path] )
		return [NSURL fileURLWithPath:path];

	return nil;
}

- (nullable NSURL *) bodyTemplateLocationWithName:(NSString *) name {
	if( ! [name length] ) name = @"generic";

	NSURL *path = [_bundle URLForResource:[name stringByAppendingString:@"Template"] withExtension:@"html"];
	if( path ) return path;

	path = [_bundle URLForResource:@"genericTemplate" withExtension:@"html"];
	if( path ) return path;

	path = [[NSBundle mainBundle] URLForResource:[name stringByAppendingString:@"Template"] withExtension:@"html"];
	if( path ) return path;

	path = [[NSBundle mainBundle] URLForResource:@"genericTemplate" withExtension:@"html"];
	if( path ) return path;

	return nil;
}

- (nullable NSURL *) XMLStyleSheetLocation {
	NSURL *path = [_bundle URLForResource:@"main" withExtension:@"xsl"];
	if( path ) return path;

	path = [[NSBundle mainBundle] URLForResource:@"default" withExtension:@"xsl"];
	if( path ) return path;

	return nil;
}

- (nullable NSURL *) previewTranscriptLocation {
	NSURL *path = [_bundle URLForResource:@"preview" withExtension:@"colloquyTranscript"];
	if( path ) return path;

	path = [[NSBundle mainBundle] URLForResource:@"preview" withExtension:@"colloquyTranscript"];
	if( path ) return path;

	return nil;
}

#pragma mark -

- (NSString *) contentsOfMainStyleSheet {
	NSString *contents = [[NSString alloc] initWithContentsOfURL:[self mainStyleSheetLocation] encoding:NSUTF8StringEncoding error:NULL];
	return ( contents ? contents : @"" );
}

- (NSString *) contentsOfVariantStyleSheetWithName:(NSString *) name {
	NSString *contents = [[NSString alloc] initWithContentsOfURL:[self variantStyleSheetLocationWithName:name] encoding:NSUTF8StringEncoding error:NULL];
	return ( contents ? contents : @"" );
}

- (NSString *) contentsOfBodyTemplateWithName:(NSString *) name {
	NSURL *url = [self bodyTemplateLocationWithName:name];
	if( ! url ) return @"";

	NSString *contents = [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL];

	NSURL *resources = [[NSBundle mainBundle] resourceURL];
	return ( contents ? [[NSString alloc] initWithFormat:contents, [resources absoluteString], @""] : @"" );
}

#pragma mark -

- (NSString *) description {
	return [self identifier];
}
@end

#pragma mark -

@implementation JVStyle (Private)
+ (const char * _Nullable *) _xsltParamArrayWithDictionary:(NSDictionary *) dictionary {
	const char **temp = NULL, **ret = NULL;

	if( ! [dictionary count] ) return NULL;

	ret = temp = malloc( ( ( [dictionary count] * 2 ) + 1 ) * sizeof( char * ) );

	for( NSString *key in dictionary ) {
		NSString *value = dictionary[key];

		*(temp++) = (char *) strdup( [key UTF8String] );
		*(temp++) = (char *) strdup( [value UTF8String] );
	}

	*(temp) = NULL;

	return ret;
}

+ (void) _freeXsltParamArray:(const char * __nullable*) params {
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

- (void) _setBundle:(nullable NSBundle *) bundle {
	NSParameterAssert(bundle);

	NSString *file = [bundle pathForResource:@"parameters" ofType:@"plist"];

	_bundle = bundle;

	[self setMainParameters:(file ? [[NSDictionary alloc] initWithContentsOfFile:file] : @{})];

	[self reload];
}

- (void) _setXSLStyle:(nullable NSURL *) location {
	@synchronized( self ) {
		if( _XSLStyle ) xsltFreeStylesheet( _XSLStyle );
		_XSLStyle = ( [[location absoluteString] length] ? xsltParseStylesheetFile( (const xmlChar *)[[location absoluteString] fileSystemRepresentation] ) : NULL );
		if( _XSLStyle ) _XSLStyle -> indent = 0; // this is done because our whitespace escaping causes problems otherwise
	}
}

- (void) _setStyleOptions:(nullable NSArray *) options {
	_styleOptions = options;
}

- (void) _setVariants:(nullable NSArray *) variants {
	_variants = variants;
}

- (void) _setUserVariants:(nullable NSArray *) variants {
	_userVariants = variants;
}
@end

NS_ASSUME_NONNULL_END
