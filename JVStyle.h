#import <Foundation/NSObject.h>

@class NSBundle;

@interface JVStyle : NSObject {
	NSBundle *_bundle;
	NSArray *_styleOptions;
	void *_XSLStyle; /* xsltStylesheet */
}
+ (void) scanForStyles;
+ (id) styleWithIdentifier:(NSString *) identifier;
+ (id) newWithBundle:(NSBundle *) bundle;

- (id) initWithBundle:(NSBundle *) bundle;

- (NSBundle *) bundle;
- (NSString *) identifier;

- (NSString *) transformXML:(NSString *) xml withParameters:(NSDictionary *) parameters;
- (NSString *) transformXMLDocument:(/* xmlDoc */ void *) document withParameters:(NSDictionary *) parameters;

- (NSString *) displayName;
- (NSString *) defaultVariantDisplayName;
- (NSArray *) variantStyleSheetNames;
- (NSArray *) userVariantStyleSheetNames;
- (BOOL) isUserVariantName:(NSString *) name;

- (NSURL *) baseLocation;
- (NSURL *) mainStyleSheetLocation;
- (NSURL *) variantStyleSheetLocationWithName:(NSString *) name;
- (NSString *) XMLStyleSheetFilePath;
- (NSString *) previewTranscriptFilePath;
- (NSString *) headerFilePath;

- (NSString *) contentsOfMainStyleSheet;
- (NSString *) contentsOfVariantStyleSheetWithName:(NSString *) name;
- (NSString *) contentsOfHeaderFile;
@end
