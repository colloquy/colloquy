#import <AppKit/NSColor.h>

@interface NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) hexcolor;
+ (NSColor *) colorWithCSSAttributeValue:(NSString *) attribute;
- (NSString *) HTMLAttributeValue;
- (NSString *) CSSAttributeValue;
@end
