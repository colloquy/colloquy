#if !((defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE) || (defined(TARGET_OS_TV) && TARGET_OS_TV))
#import <AppKit/NSColor.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (NSColorAdditions)
+ (nullable NSColor *) colorWithHTMLAttributeValue:(NSString *) attribute;
+ (nullable NSColor *) colorWithCSSAttributeValue:(NSString *) attribute;
@property (readonly, copy) NSString *HTMLAttributeValue;
@property (readonly, copy) NSString *CSSAttributeValue;
@end

NS_ASSUME_NONNULL_END

#endif
