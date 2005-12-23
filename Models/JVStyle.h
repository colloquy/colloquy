#import "JVChatTranscript.h"

@class JVChatMessage;
@class JVEmoticonSet;

extern NSString *JVStylesScannedNotification;
extern NSString *JVDefaultStyleChangedNotification;
extern NSString *JVDefaultStyleVariantChangedNotification;
extern NSString *JVNewStyleVariantAddedNotification;
extern NSString *JVStyleVariantChangedNotification;

@interface JVStyle : NSObject {
	NSBundle *_bundle;
	NSDictionary *_parameters;
	NSArray *_styleOptions;
	NSArray *_variants;
	NSArray *_userVariants;
	void *_XSLStyle; /* xsltStylesheet */
}
+ (void) scanForStyles;
+ (NSSet *) styles;
+ (id) styleWithIdentifier:(NSString *) identifier;
+ (id) newWithBundle:(NSBundle *) bundle;

+ (id) defaultStyle;
+ (void) setDefaultStyle:(JVStyle *) style;

- (id) initWithBundle:(NSBundle *) bundle;

- (void) unlink;
- (void) reload;
- (BOOL) isCompliant;

- (NSBundle *) bundle;
- (NSString *) identifier;

- (NSString *) transformChatTranscript:(JVChatTranscript *) transcript withParameters:(NSDictionary *) parameters;
- (NSString *) transformChatTranscriptElement:(id <JVChatTranscriptElement>) element withParameters:(NSDictionary *) parameters;
- (NSString *) transformChatMessage:(JVChatMessage *) message withParameters:(NSDictionary *) parameters;
- (NSString *) transformChatTranscriptElements:(NSArray *) elements withParameters:(NSDictionary *) parameters;
- (NSString *) transformXML:(NSString *) xml withParameters:(NSDictionary *) parameters;
- (NSString *) transformXMLDocument:(/* xmlDoc */ void *) document withParameters:(NSDictionary *) parameters;

- (NSComparisonResult) compare:(JVStyle *) style;
- (NSString *) displayName;

- (NSString *) mainVariantDisplayName;
- (NSArray *) variantStyleSheetNames;
- (NSArray *) userVariantStyleSheetNames;
- (BOOL) isUserVariantName:(NSString *) name;
- (NSString *) defaultVariantName;
- (void) setDefaultVariantName:(NSString *) name;

- (JVEmoticonSet *) defaultEmoticonSet;
- (void) setDefaultEmoticonSet:(JVEmoticonSet *) emoticons;

- (NSArray *) styleSheetOptions;

- (void) setMainParameters:(NSDictionary *) parameters;
- (NSDictionary *) mainParameters;

- (NSURL *) baseLocation;
- (NSURL *) mainStyleSheetLocation;
- (NSURL *) variantStyleSheetLocationWithName:(NSString *) name;
- (NSURL *) bodyTemplateLocationWithName:(NSString *) name;
- (NSURL *) XMLStyleSheetLocation;
- (NSURL *) previewTranscriptLocation;

- (NSString *) contentsOfMainStyleSheet;
- (NSString *) contentsOfVariantStyleSheetWithName:(NSString *) name;
- (NSString *) contentsOfBodyTemplateWithName:(NSString *) name;
@end