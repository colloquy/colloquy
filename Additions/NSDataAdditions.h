#import <Foundation/NSData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (NSDataAdditions)
+ (NSData *) dataWithBase64EncodedString:(NSString *) string;
- (instancetype) initWithBase64EncodedString:(NSString *) string;

@property (readonly, copy) NSString *mv_base64Encoding;
- (NSString *) base64EncodingWithLineLength:(NSUInteger) lineLength;

- (BOOL) hasPrefixBytes:(const void *) prefix length:(NSUInteger) length;
- (BOOL) hasSuffixBytes:(const void *) suffix length:(NSUInteger) length;
@end

NS_ASSUME_NONNULL_END
