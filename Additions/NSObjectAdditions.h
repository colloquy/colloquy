@interface NSObject (NSObjectAdditions)
+ (id) performPrivateSelector:(NSString *) selectorString;

- (id) performPrivateSelector:(NSString *) selectorString;
- (id) performPrivateSelector:(NSString *) selectorString withObject:(id) object;
- (id) performPrivateSelector:(NSString *) selectorString withObject:(id) object withObject:(id) object;
- (id) performPrivateSelector:(NSString *) selectorString withBoolean:(BOOL) boolean;
- (id) performPrivateSelector:(NSString *) selectorString withUnsignedInteger:(NSUInteger) integer;
- (id) performPrivateSelector:(NSString *) selectorString withRange:(NSRange) range;

#if !defined(COMMAND_LINE_UTILITY)
- (CGPoint) performPrivateSelectorReturningPoint:(NSString *) selectorString;
#endif

- (BOOL) performPrivateSelectorReturningBoolean:(NSString *) selectorString;
@end
