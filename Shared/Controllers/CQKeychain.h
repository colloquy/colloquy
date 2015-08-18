NS_ASSUME_NONNULL_BEGIN

@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area;
- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area displayValue:(NSString *__nullable)displayValue;
- (NSString *) passwordForServer:(NSString *) server area:(NSString *) area;
- (void) removePasswordForServer:(NSString *) server area:(NSString *) area;

- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *) area;
- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *) area displayValue:(NSString *__nullable)displayValue;
- (NSData *) dataForServer:(NSString *) server area:(NSString *) area;
- (void) removeDataForServer:(NSString *) server area:(NSString *) area;
@end

NS_ASSUME_NONNULL_END
