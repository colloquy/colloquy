#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

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
