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
+ (instancetype) styleWithIdentifier:(NSString *) identifier;
+ (id) newWithBundle:(NSBundle *) bundle;

+ (JVStyle*) defaultStyle;
+ (void) setDefaultStyle:(JVStyle *) style;

- (instancetype) initWithBundle:(NSBundle *) bundle;

- (void) unlink;
- (void) reload;
@property (getter=isCompliant, readonly) BOOL compliant;

@property (readonly, strong) NSBundle *bundle;
@property (readonly, copy) NSString *identifier;

- (NSString *) transformChatTranscript:(JVChatTranscript *) transcript withParameters:(NSDictionary *) parameters;
- (NSString *) transformChatTranscriptElement:(id <JVChatTranscriptElement>) element withParameters:(NSDictionary *) parameters;
- (NSString *) transformChatMessage:(JVChatMessage *) message withParameters:(NSDictionary *) parameters;
- (NSString *) transformChatTranscriptElements:(NSArray *) elements withParameters:(NSDictionary *) parameters;
- (NSString *) transformXML:(NSString *) xml withParameters:(NSDictionary *) parameters;
- (NSString *) transformXMLDocument:(/* xmlDoc */ void *) document withParameters:(NSDictionary *) parameters;

- (NSComparisonResult) compare:(JVStyle *) style;
@property (readonly, copy) NSString *displayName;

@property (readonly, copy) NSString *mainVariantDisplayName;
@property (readonly, copy) NSArray *variantStyleSheetNames;
@property (readonly, copy) NSArray *userVariantStyleSheetNames;
- (BOOL) isUserVariantName:(NSString *) name;
@property (copy, nonatomic) NSString *defaultVariantName;

@property (strong) JVEmoticonSet *defaultEmoticonSet;

@property (readonly, copy) NSArray *styleSheetOptions;

@property (copy) NSDictionary *mainParameters;

@property (readonly, copy) NSURL *baseLocation;
@property (readonly, copy) NSURL *mainStyleSheetLocation;
- (NSURL *) variantStyleSheetLocationWithName:(NSString *) name;
- (NSURL *) bodyTemplateLocationWithName:(NSString *) name;
@property (readonly, copy) NSURL *XMLStyleSheetLocation;
@property (readonly, copy) NSURL *previewTranscriptLocation;

@property (readonly, copy) NSString *contentsOfMainStyleSheet;
- (NSString *) contentsOfVariantStyleSheetWithName:(NSString *) name;
- (NSString *) contentsOfBodyTemplateWithName:(NSString *) name;
@end
