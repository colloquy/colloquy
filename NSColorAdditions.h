#import <AppKit/NSColor.h>

@interface NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) hexcolor;
- (NSString *) HTMLAttributeValue;
@end
