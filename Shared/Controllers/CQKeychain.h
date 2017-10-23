#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT
@interface CQKeychain : NSObject
#if __has_feature(objc_class_property)
@property (readonly, strong, class) CQKeychain *standardKeychain;
#else
+ (CQKeychain *) standardKeychain;
#endif

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *__nullable) area;
- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *__nullable) area displayValue:(NSString *__nullable)displayValue;
- (NSString *__nullable) passwordForServer:(NSString *) server area:(NSString *__nullable) area;
- (void) removePasswordForServer:(NSString *) server area:(NSString *__nullable) area;

- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *__nullable) area;
- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *__nullable) area displayValue:(NSString *__nullable)displayValue;
- (NSData *__nullable) dataForServer:(NSString *) server area:(NSString *__nullable) area;
- (void) removeDataForServer:(NSString *) server area:(NSString *__nullable) area;
@end

NS_ASSUME_NONNULL_END
