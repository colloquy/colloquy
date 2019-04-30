#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) attribute;
+ (NSColor *) colorWithCSSAttributeValue:(NSString *) attribute;
- (NSString *) HTMLAttributeValue;
- (NSString *) CSSAttributeValue;
@end

NS_ASSUME_NONNULL_END

#endif
