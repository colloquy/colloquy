#import <Foundation/NSValue.h>
NS_ASSUME_NONNULL_BEGIN

@interface NSNumber (NSNumberAdditions)
+ (nullable NSNumber *) numberWithBytes:(const void *) bytes objCType:(const char *) type;
@end

NS_ASSUME_NONNULL_END
