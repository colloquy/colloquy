@interface NSObject (NSObjectAdditions)
+ (id) performPrivateSelector:(NSString *) selectorString;

- (id) performPrivateSelector:(NSString *) selectorString;
- (id) performPrivateSelector:(NSString *) selectorString withObject:(id) object;
- (id) performPrivateSelector:(NSString *) selectorString withBoolean:(BOOL) boolean;
- (id) performPrivateSelector:(NSString *) selectorString withUnsignedInteger:(NSUInteger) integer;
- (id) performPrivateSelector:(NSString *) selectorString withRange:(NSRange) range;

- (CGPoint) performPrivateSelectorReturningPoint:(NSString *) selectorString;
- (BOOL) performPrivateSelectorReturningBoolean:(NSString *) selectorString;
@end
