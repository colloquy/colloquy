#if SYSTEM(MAC)
@interface NSColor (NSColorAdditions)
+ (NSColor *) colorWithHTMLAttributeValue:(NSString *) attribute;
+ (NSColor *) colorWithCSSAttributeValue:(NSString *) attribute;
@property (readonly, copy) NSString *HTMLAttributeValue;
@property (readonly, copy) NSString *CSSAttributeValue;
@end
#endif
