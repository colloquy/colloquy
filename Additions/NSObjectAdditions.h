@interface NSObject (NSObjectAdditions)
+ (id) performPrivateSelector:(NSString *) selectorString;

- (id) performPrivateSelector:(NSString *) selectorString;
- (id) performPrivateSelector:(NSString *) selectorString withObject:(id) object;
- (id) performPrivateSelector:(NSString *) selectorString withObject:(id) object withObject:(id) otherObject;
- (id) performPrivateSelector:(NSString *) selectorString withBoolean:(BOOL) boolean;
- (id) performPrivateSelector:(NSString *) selectorString withUnsignedInteger:(NSUInteger) integer;
- (id) performPrivateSelector:(NSString *) selectorString withRange:(NSRange) range;

#if !defined(COMMAND_LINE_UTILITY)
- (CGPoint) performPrivateSelectorReturningPoint:(NSString *) selectorString;
#endif

- (BOOL) performPrivateSelectorReturningBoolean:(NSString *) selectorString;

- (void) associateObject:(id) object forKey:(void *) key;
- (id) associatedObjectForKey:(void *) key;
@end
