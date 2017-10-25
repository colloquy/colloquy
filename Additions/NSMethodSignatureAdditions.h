#import <Foundation/NSMethodSignature.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMethodSignature (NSMethodSignatureAdditions)
+ (instancetype __nullable) methodSignatureWithReturnAndArgumentTypes:(const char *) retType, ...;
@end

NS_ASSUME_NONNULL_END
