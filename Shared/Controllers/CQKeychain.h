#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT
@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area;
- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area displayValue:(NSString *__nullable)displayValue;
- (NSString *__nullable) passwordForServer:(NSString *) server area:(NSString *) area;
- (void) removePasswordForServer:(NSString *) server area:(NSString *) area;

- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *) area;
- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *) area displayValue:(NSString *__nullable)displayValue;
- (NSData *__nullable) dataForServer:(NSString *) server area:(NSString *) area;
- (void) removeDataForServer:(NSString *) server area:(NSString *) area;
@end

NS_ASSUME_NONNULL_END
