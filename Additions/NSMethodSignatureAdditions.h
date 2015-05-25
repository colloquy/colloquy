NS_ASSUME_NONNULL_BEGIN

@interface NSMethodSignature (NSMethodSignatureAdditions)
+ (id) methodSignatureWithReturnAndArgumentTypes:(const char *) retType, ...;
@end

NS_ASSUME_NONNULL_END
