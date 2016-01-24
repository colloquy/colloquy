#if !defined(TARGET_OS_IPHONE) || !TARGET_OS_IPHONE
#import <AppKit/NSColor.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) attribute;
+ (NSColor *) colorWithCSSAttributeValue:(NSString *) attribute;
@property (readonly, copy) NSString *HTMLAttributeValue;
@property (readonly, copy) NSString *CSSAttributeValue;
@end

NS_ASSUME_NONNULL_END

#endif
