#import <AppKit/NSAttributedString.h>

@interface NSAttributedString (NSAttributedStringHTMLAdditions)
+ (NSDictionary *) linkAttributesForTarget:(NSString *) link;
+ (NSDictionary *) linkAttributesForTarget:(NSString *) link usingColor:(NSColor *) color withUnderline:(BOOL) underline;
+ (NSAttributedString *) attributedStringWithHTML:(NSData *) html usingEncoding:(NSStringEncoding) encoding documentAttributes:(NSDictionary **) dict;
- (NSData *) HTMLWithOptions:(NSDictionary *) options usingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) loss;
@end

@interface NSMutableAttributedString (NSMutableAttributedStringImageAdditions)
- (void) preformImageSubstitutionWithDictionary:(NSDictionary *) dict;
- (void) preformHTMLBackgroundColoring;
- (void) preformLinkHighlighting;
- (void) preformLinkHighlightingUsingColor:(NSColor *) linkColor withUnderline:(BOOL) underline;
@end
