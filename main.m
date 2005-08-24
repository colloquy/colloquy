#import <libxml/globals.h>
#import <libxml/parser.h>
#import <libxslt/xslt.h>

@interface NSAEDescriptorTranslator : NSObject // Private Foundation Class
+ (id) _descriptorByTranslatingColor:(NSColor *) color ofType:(id) type inSuite:(id) suite;
+ (id) _descriptorByTranslatingTextStorage:(NSTextStorage *) text ofType:(id) type inSuite:(id) suite;
@end

// below are strange workarounds required when using an sdef file.

@interface JVTextStorage : NSTextStorage
@end

@implementation JVTextStorage
- (id) _scriptingDescriptorOfObjectType:(id) type orReasonWhyNot:(id *) reason {
	return [NSAEDescriptorTranslator _descriptorByTranslatingTextStorage:self ofType:type inSuite:nil];
}
@end

@interface JVColor : NSColor
@end

@implementation JVColor
- (id) _scriptingDescriptorOfObjectType:(id) type orReasonWhyNot:(id *) reason {
	return [NSAEDescriptorTranslator _descriptorByTranslatingColor:self ofType:type inSuite:nil];
}
@end

int main( int count, const char *arg[] ) {
	srandom( time( NULL ) );

	xmlInitParser();
	xmlSubstituteEntitiesDefault( 1 );
	xmlLoadExtDtdDefaultValue = 1;

	[JVTextStorage poseAsClass:[NSTextStorage class]];
	[JVColor poseAsClass:[NSColor class]];

	int ret = NSApplicationMain( count, arg );

	xsltCleanupGlobals();
	xmlCleanupParser();
	return ret;
}