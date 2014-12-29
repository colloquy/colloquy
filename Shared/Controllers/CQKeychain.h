@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area;
- (NSString *) passwordForServer:(NSString *) server area:(NSString *) area;
- (void) removePasswordForServer:(NSString *) server area:(NSString *) area;

- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *) area;
- (NSData *) dataForServer:(NSString *) server area:(NSString *) area;
- (void) removeDataForServer:(NSString *) server area:(NSString *) area;
@end
