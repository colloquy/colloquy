@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area;
- (NSString *) passwordForServer:(NSString *) server area:(NSString *) area;
- (void) removePasswordForServer:(NSString *) server area:(NSString *) area;
@end
